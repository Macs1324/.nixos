// Rendering: grains are scattered into one canvas-wide "owner" buffer (which
// grain sits on each pixel), packed with their colour and sub-pixel position
// ("packed"), then each output splats them: a pixel is the average of the
// grains around it, weighted by how close each one is to its centre (a tent
// of 1 px). Moving grains blend smoothly instead of leaving hard-edged holes;
// a grain resting on a pixel centre, as every grain does at home, gives
// exactly its own pixel, so the desktop stays pixel-exact. A pixel no grain
// comes near widens the tent to 2 px. (Splatting every grain, not just each
// pixel's owner, looked the same and cost 2-3x the GPU time.)

struct View {
    origin: vec2<f32>,    // this output's rectangle in the canvas
    size: vec2<f32>,
    alpha: f32,           // fades the unlock handoff overlay
    srgb_surface: u32,    // 1 if the surface re-encodes to sRGB on write
    dot_count: u32,
    dot_radius: f32,
    n_outputs: u32,
    canvas_w: u32,
    canvas_h: u32,
    _pad0: u32,
    dots: array<vec4<f32>, 64>,  // xy centre (canvas px), z opacity
}

// ---- scatter (one pass per frame, all outputs) --------------------------------

@group(0) @binding(0) var<uniform> P: Params;
@group(0) @binding(1) var<storage, read> grains: array<vec4<f32>>;
@group(0) @binding(2) var<storage, read_write> owner_rw: array<atomic<u32>>;
@group(0) @binding(3) var<storage, read> bound: array<u32>;

// Owner entries: grain id + 1, with the top bit set for grains bound to an
// attractor so they win their pixel: the image stays on top of the storm.
const BOUND: u32 = 0x80000000u;
const ID_MASK: u32 = 0x7fffffffu;

@compute @workgroup_size(256)
fn scatter(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(num_workgroups) nw: vec3<u32>) {
    let i = gid.x + gid.y * nw.x * 256u;
    if (i >= P.n_grains) { return; }
    let w = u32(P.canvas.x);
    let p = min(vec2<u32>(grains[i].xy), vec2<u32>(w, u32(P.canvas.y)) - 1u);
    // Highest key wins: bound grains first, then the same grain every frame,
    // so nothing flickers.
    let key = select(i + 1u, (i + 1u) | BOUND, bound[i] != 0u);
    atomicMax(&owner_rw[p.y * w + p.x], key);
}

// ---- pack (one pass per frame, per canvas pixel) --------------------------------

@group(0) @binding(4) var<storage, read> outs: array<OutRect>;
@group(0) @binding(5) var shot: texture_2d<f32>;
// Per canvas pixel, 0 = no grain: its owner's colour (rgb8) and position
// within the pixel (4 bits per axis, 1..15 so no grain packs to 0; 8 = the
// centre, where every grain rests at home).
@group(0) @binding(6) var<storage, read_write> packed_rw: array<u32>;

fn home_of(i: u32) -> vec2<i32> {
    for (var k = 0u; k < P.n_outputs; k++) {
        let o = outs[k];
        let w = u32(o.size.x);
        let n = w * u32(o.size.y);
        if (i >= o.offset && i < o.offset + n) {
            let j = i - o.offset;
            return vec2<i32>(o.origin) + vec2<i32>(i32(j % w), i32(j / w));
        }
    }
    return vec2<i32>(0);
}

@compute @workgroup_size(16, 16)
fn pack(@builtin(global_invocation_id) id: vec3<u32>) {
    let w = u32(P.canvas.x);
    if (id.x >= w || id.y >= u32(P.canvas.y)) { return; }
    let pi = id.y * w + id.x;
    let o = atomicLoad(&owner_rw[pi]) & ID_MASK;
    if (o == 0u) {
        packed_rw[pi] = 0u;
        return;
    }
    let off = clamp(grains[o - 1u].xy - vec2<f32>(id.xy), vec2<f32>(0.0), vec2<f32>(1.0));
    let q = vec2<u32>(round(off * 14.0)) + 1u;
    let c = vec3<u32>(round(textureLoad(shot, home_of(o - 1u), 0).rgb * 255.0));
    packed_rw[pi] = (c.r << 24u) | (c.g << 16u) | (c.b << 8u) | (q.x << 4u) | q.y;
}

// ---- compose (per output) ----------------------------------------------------

@group(1) @binding(0) var<uniform> V: View;
@group(1) @binding(2) var<storage, read> packed: array<u32>;

fn packed_at(p: vec2<i32>) -> u32 {
    if (p.x < 0 || p.y < 0 || p.x >= i32(V.canvas_w) || p.y >= i32(V.canvas_h)) { return 0u; }
    return packed[u32(p.y) * V.canvas_w + u32(p.x)];
}

fn colour_of(v: u32) -> vec3<f32> {
    return vec3<f32>(f32(v >> 24u), f32((v >> 16u) & 255u), f32((v >> 8u) & 255u)) / 255.0;
}

/// Where the grain packed in `v` sits, relative to its pixel's corner.
fn offset_of(v: u32) -> vec2<f32> {
    return (vec2<f32>(f32((v >> 4u) & 15u), f32(v & 15u)) - 1.0) / 14.0;
}

fn srgb_to_linear(c: vec3<f32>) -> vec3<f32> {
    return select(pow((c + 0.055) / 1.055, vec3<f32>(2.4)), c / 12.92, c <= vec3<f32>(0.04045));
}

@vertex
fn compose_vs(@builtin(vertex_index) i: u32) -> @builtin(position) vec4<f32> {
    let uv = vec2<f32>(f32((i << 1u) & 2u), f32(i & 2u));
    return vec4<f32>(uv * 2.0 - 1.0, 0.0, 1.0);
}

@fragment
fn compose_fs(@builtin(position) frag: vec4<f32>) -> @location(0) vec4<f32> {
    let p = vec2<i32>(V.origin) + vec2<i32>(frag.xy);
    // Splat: every grain within 1 px of this pixel's centre, tent-weighted;
    // if none, within 2 px.
    var col = vec3<f32>(0.0);
    for (var r = 1; r <= 2; r++) {
        var sum = vec3<f32>(0.0);
        var weight = 0.0;
        for (var dy = -r; dy <= r; dy++) {
            for (var dx = -r; dx <= r; dx++) {
                let v = packed_at(p + vec2<i32>(dx, dy));
                if (v == 0u) { continue; }
                let d = abs(vec2<f32>(f32(dx), f32(dy)) + offset_of(v) - 0.5) / f32(r);
                let w = max(1.0 - d.x, 0.0) * max(1.0 - d.y, 0.0);
                sum += colour_of(v) * w;
                weight += w;
            }
        }
        if (weight > 1e-4) {
            col = sum / weight;
            break;
        }
    }
    // Password dots: a soft dark halo keeps them readable on any colour.
    let c = V.origin + frag.xy;
    for (var i = 0u; i < V.dot_count; i++) {
        let d = V.dots[i];
        let dist = length(c - d.xy);
        let halo = (1.0 - smoothstep(V.dot_radius, V.dot_radius * 2.4, dist)) * 0.45 * d.z;
        col = mix(col, vec3<f32>(0.0), halo);
        let core = (1.0 - smoothstep(V.dot_radius - 1.0, V.dot_radius + 0.5, dist)) * d.z;
        col = mix(col, vec3<f32>(0.93, 0.95, 0.98), core);
    }
    if (V.srgb_surface == 1u) {
        col = srgb_to_linear(col);
    }
    return vec4<f32>(col * V.alpha, V.alpha);
}

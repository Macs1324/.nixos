// Rendering: grains are scattered into one canvas-wide "owner" buffer (which
// grain sits on each pixel), then each output looks its pixels up there. A
// pixel no grain landed on takes the nearest grain within a few pixels, so
// every pixel on screen is an original screenshot pixel.

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

// ---- compose (per output) ----------------------------------------------------

@group(1) @binding(0) var<uniform> V: View;
@group(1) @binding(1) var<storage, read> outs: array<OutRect>;
@group(1) @binding(2) var<storage, read> owner: array<u32>;
@group(1) @binding(3) var shot: texture_2d<f32>;

// Gaps are the 1-3 px holes of randomly scattered grains; beyond this the
// pixel shows the nearest grain found so far, or black.
const SEARCH: i32 = 4;

fn owner_at(p: vec2<i32>) -> u32 {
    if (p.x < 0 || p.y < 0 || p.x >= i32(V.canvas_w) || p.y >= i32(V.canvas_h)) { return 0u; }
    return owner[u32(p.y) * V.canvas_w + u32(p.x)] & ID_MASK;
}

fn home_of(i: u32) -> vec2<i32> {
    for (var k = 0u; k < V.n_outputs; k++) {
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
    var id = owner_at(p);
    // Nearest grain, ring by ring; stop at the first ring that has one.
    for (var r = 1; r <= SEARCH && id == 0u; r++) {
        var best = 1e9;
        for (var dy = -r; dy <= r; dy++) {
            for (var dx = -r; dx <= r; dx++) {
                if (max(abs(dx), abs(dy)) != r) { continue; }
                let c = owner_at(p + vec2<i32>(dx, dy));
                let d = f32(dx * dx + dy * dy);
                if (c != 0u && d < best) {
                    best = d;
                    id = c;
                }
            }
        }
    }
    var col = vec3<f32>(0.0);
    if (id != 0u) {
        col = textureLoad(shot, home_of(id - 1u), 0).rgb;
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

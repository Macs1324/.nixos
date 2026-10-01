// Grain update: one grain per screenshot pixel, carried by the fluid.
// A grain is vec4(position px, velocity px/s).

@group(0) @binding(0) var<uniform> P: Params;
@group(0) @binding(1) var<storage, read_write> grains: array<vec4<f32>>;
@group(0) @binding(2) var<storage, read> outs: array<OutRect>;
@group(0) @binding(3) var psi: texture_2d<f32>;
// Attractors (attract.wgsl): the target pixel each grain is bound to, and the
// target image (rgb colour, a firmness; 0 = no target).
@group(0) @binding(4) var<storage, read_write> bound: array<atomic<u32>>;
@group(0) @binding(5) var targets: texture_2d<f32>;
// Density correction potential (fluid.wgsl `dsource`), and the grain count
// per fluid cell it is computed from (for the next step).
@group(0) @binding(6) var phi: texture_2d<f32>;
@group(0) @binding(7) var<storage, read_write> counts: array<atomic<u32>>;
// Quiet-zone strength per fluid cell over home positions (fluid.wgsl
// `quiet_map`).
@group(0) @binding(8) var quiet: texture_2d<f32>;


fn home_of(i: u32) -> vec2<f32> {
    for (var k = 0u; k < P.n_outputs; k++) {
        let o = outs[k];
        let w = u32(o.size.x);
        let n = w * u32(o.size.y);
        if (i >= o.offset && i < o.offset + n) {
            let j = i - o.offset;
            return o.origin + vec2<f32>(f32(j % w), f32(j / w)) + 0.5;
        }
    }
    return vec2<f32>(0.0);
}

// Mirrored with opposite sign beyond the walls (see fluid.wgsl `stream`), so
// the interpolated psi is exactly 0 on every wall and the flow runs along it.
fn psi_at(c: vec2<i32>, size: vec2<i32>) -> f32 {
    let m = select(c, -c - 1, c < vec2<i32>(0));
    let q = select(m, 2 * size - m - 1, m >= size);
    var sign = 1.0;
    if (any(q != c)) { sign = -1.0; }
    if (all(q != c)) { sign = 1.0; }  // corner: reflected twice
    return sign * textureLoad(psi, clamp(q, vec2<i32>(0), size - 1), 0).x;
}

// Velocity = curl of the Catmull-Rom interpolated stream function, using the
// interpolant's exact derivatives: divergence is zero everywhere, not just per
// cell, so grains swirl but never pile up. Returns px/s.
fn vel_at(pos: vec2<f32>) -> vec2<f32> {
    let size = vec2<i32>(textureDimensions(psi));
    let cell = vec2<f32>(P.cell_x, P.cell);
    let x = pos / cell - 0.5;
    let i = floor(x);
    let f = x - i;
    let wx = vec4<f32>(f.x * (-0.5 + f.x * (1.0 - 0.5 * f.x)), 1.0 + f.x * f.x * (-2.5 + 1.5 * f.x),
                       f.x * (0.5 + f.x * (2.0 - 1.5 * f.x)), f.x * f.x * (-0.5 + 0.5 * f.x));
    let wy = vec4<f32>(f.y * (-0.5 + f.y * (1.0 - 0.5 * f.y)), 1.0 + f.y * f.y * (-2.5 + 1.5 * f.y),
                       f.y * (0.5 + f.y * (2.0 - 1.5 * f.y)), f.y * f.y * (-0.5 + 0.5 * f.y));
    let dx = vec4<f32>(-0.5 + f.x * (2.0 - 1.5 * f.x), f.x * (-5.0 + 4.5 * f.x),
                       0.5 + f.x * (4.0 - 4.5 * f.x), f.x * (-1.0 + 1.5 * f.x));
    let dy = vec4<f32>(-0.5 + f.y * (2.0 - 1.5 * f.y), f.y * (-5.0 + 4.5 * f.y),
                       0.5 + f.y * (4.0 - 4.5 * f.y), f.y * (-1.0 + 1.5 * f.y));
    var px = 0.0;
    var py = 0.0;
    let base = vec2<i32>(i);
    for (var b = 0; b < 4; b++) {
        for (var a = 0; a < 4; a++) {
            let s = psi_at(base + vec2<i32>(a - 1, b - 1), size);
            px += dx[a] * wy[b] * s;
            py += wx[a] * dy[b] * s;
        }
    }
    // psi is in cells^2/s: curl gives cells/s; scale to px/s. The x/y cell
    // sizes differ slightly, and this scaling keeps the flow divergence-free.
    return vec2<f32>(py * cell.x, -px * cell.y);
}

// grad(phi) at `pos` in px/s: central differences per cell (clamped at the
// walls, so nothing is pushed through them), bilinearly interpolated.
fn phi_at(c: vec2<i32>, size: vec2<i32>) -> f32 {
    return textureLoad(phi, clamp(c, vec2<i32>(0), size - 1), 0).x;
}

fn drift_at(pos: vec2<f32>) -> vec2<f32> {
    let size = vec2<i32>(textureDimensions(phi));
    let cell = vec2<f32>(P.cell_x, P.cell);
    let x = pos / cell - 0.5;
    let i = vec2<i32>(floor(x));
    let f = x - floor(x);
    var g = vec2<f32>(0.0);
    for (var b = 0; b < 2; b++) {
        for (var a = 0; a < 2; a++) {
            let c = i + vec2<i32>(a, b);
            let d = 0.5 * vec2<f32>(phi_at(c + vec2<i32>(1, 0), size) - phi_at(c - vec2<i32>(1, 0), size),
                                    phi_at(c + vec2<i32>(0, 1), size) - phi_at(c - vec2<i32>(0, 1), size));
            g += d * select(1.0 - f.x, f.x, a == 1) * select(1.0 - f.y, f.y, b == 1);
        }
    }
    return g * cell;
}

// `quiet` bilinearly interpolated at `h` (px).
fn quiet_texel(c: vec2<i32>, size: vec2<i32>) -> f32 {
    return textureLoad(quiet, clamp(c, vec2<i32>(0), size - 1), 0).x;
}

fn quiet_at(h: vec2<f32>) -> f32 {
    let size = vec2<i32>(textureDimensions(quiet));
    let x = h / vec2<f32>(P.cell_x, P.cell) - 0.5;
    let i = vec2<i32>(floor(x));
    let f = x - floor(x);
    let top = mix(quiet_texel(i, size), quiet_texel(i + vec2<i32>(1, 0), size), f.x);
    let bottom = mix(quiet_texel(i + vec2<i32>(0, 1), size), quiet_texel(i + vec2<i32>(1, 1), size), f.x);
    return mix(top, bottom, f.y);
}

// Counts a sample of the grains, a different eighth every step, each for
// COUNT_SAMPLE: with every grain counting, the atomics cost several ms per
// step on some GPUs (Intel Arc: 4.7 of 12.5 ms, and much worse while grains
// still sit at home, where neighbouring threads all hit the same cell). A
// cell holds hundreds of grains, so the sample changes nothing visible.
const COUNT_SAMPLE: u32 = 8u;

fn count(pos: vec2<f32>, i: u32) {
    if (P.density <= 0.0 || i % COUNT_SAMPLE != P.seed % COUNT_SAMPLE) { return; }
    let cell = vec2<f32>(P.cell_x, P.cell);
    let size = vec2<u32>(textureDimensions(phi));
    let c = min(vec2<u32>(pos / cell), size - 1u);
    atomicAdd(&counts[c.y * size.x + c.x], COUNT_SAMPLE);
}

// Per-grain randomness from its index (PCG): cheaper than hashing positions.
fn ihash(i: u32, salt: u32) -> f32 {
    var x = i * 747796405u + 2891336453u + salt * 2654435769u;
    x = ((x >> ((x >> 28u) + 4u)) ^ x) * 277803737u;
    x = (x >> 22u) ^ x;
    return f32(x >> 8u) / 16777216.0;
}

@compute @workgroup_size(256)
fn main(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(num_workgroups) nw: vec3<u32>) {
    let i = gid.x + gid.y * nw.x * 256u;
    if (i >= P.n_grains) { return; }
    var s = grains[i];
    var pos = s.xy;
    var v = s.zw;
    let u = P.unit;
    let dt = P.dt;

    // Home positions matter while eroding, in quiet zones, and flying home.
    let releasing = P.homing == 0.0 && P.time < P.release_start + P.release_dur + 0.2;
    let homing = P.homing > 0.0;
    let quiet_zones = P.quiet.w > 0.0;
    var h = vec2<f32>(0.0);
    if (releasing || homing || quiet_zones) {
        h = home_of(i);
    }
    // Erosion: grains break loose in patches, not all at once.
    if (releasing) {
        let n = 0.65 * vnoise(h / (260.0 * u)) + 0.35 * vnoise(h / (60.0 * u));
        let release = P.release_start + P.release_dur * (0.1 + 0.9 * n) + 0.15 * ihash(i, 1u);
        if (P.time < release) {
            grains[i] = vec4<f32>(h, 0.0, 0.0);
            count(h, i);
            return;
        }
    }

    // Grains are tracers of the flow (the sub-grid turbulence is part of psi).
    // Midpoint (RK2): plain Euler spirals outwards and empties vortex cores.
    let v1 = vel_at(pos);
    v = vel_at(pos + v1 * dt * 0.5);
    if (P.density > 0.0 && !homing) {
        v += drift_at(pos);
    }
    // A grain bound to a target keeps riding the flow, plus a spring towards
    // its target: the image ripples with the storm, firmer with firmness.
    var b = atomicLoad(&bound[i]);
    // Eruption: every attractor lets go (recruit.wgsl then drops the stale
    // claims and the images re-form).
    if (b != 0u && P.forcing.w > 0.0) {
        atomicStore(&bound[i], 0u);
        b = 0u;
    }
    if (b != 0u && !homing) {
        let cw = u32(P.canvas.x);
        let tp = vec2<u32>((b - 1u) % cw, (b - 1u) / cw);
        let t = textureLoad(targets, tp, 0);
        if (t.a == 0.0) {
            atomicStore(&bound[i], 0u);
        } else {
            let firmness = (t.a * 255.0 - 1.0) / 254.0;
            var pull = (vec2<f32>(tp) + 0.5 - pos) * mix(2.0, 20.0, firmness);
            // Stream in instead of teleporting.
            let cap = 700.0 * u;
            let len = length(pull);
            if (len > cap) { pull *= cap / len; }
            v += pull;
        }
    }
    // Quiet zones: where a slowly morphing noise field over home positions
    // is strong, the storm is calmer for those grains: it carries them more
    // slowly and a soft spring draws them towards home, so the desktop
    // shows through blurred and rippling in scattered patches that come and
    // go, so the storm never mixes into one soup. Never fully at rest.
    // Density correction refills what they draw away.
    if (quiet_zones && b == 0u && !homing) {
        let calm = quiet_at(h);
        if (calm > 0.0) {
            // Slower flow plus a pull proportional to the distance from home
            // (not a spring: at partial strength a spring's momentum is
            // mostly mixed away each step). They balance a few px from home
            // at calm 1 and ~20 px at 0.5; far grains stream in, capped.
            var pull = (h - pos) * 12.0 * calm;
            let cap = 700.0 * u;
            let len = length(pull);
            if (len > cap) { pull *= cap / len; }
            v = v * (1.0 - 0.8 * calm) + pull;
        }
    }
    if (homing) {
        // Springs home, a little underdamped; the storm fades out as they
        // take over, so grains curve in on its momentum.
        let k = 90.0;
        let spring = s.zw + dt * (k * (h - pos) - 1.6 * sqrt(k) * s.zw);
        v = mix(v, spring, P.homing);
    }
    pos += v * dt;
    if (homing) {
        // The last of the wobble eases out, so every grain is exactly home
        // by `homing_done` and the handoff to the live desktop is exact.
        let settle = smoothstep(P.homing_done - 0.5, P.homing_done - 0.1, P.homing_t);
        pos = mix(pos, h, 0.5 * settle);
        if (P.homing_t >= P.homing_done - 0.1) {
            pos = h;
            v = vec2<f32>(0.0);
        }
    }

    // Walls: reflect, never clamp. Clamping stacked grains on the edge line,
    // draining the band next to it (which gap filling then showed as shards).
    if (pos.x < 0.0) { pos.x = -pos.x; v.x = -v.x * 0.5; }
    if (pos.x > P.canvas.x) { pos.x = 2.0 * P.canvas.x - pos.x; v.x = -v.x * 0.5; }
    if (pos.y < 0.0) { pos.y = -pos.y; v.y = -v.y * 0.5; }
    if (pos.y > P.canvas.y) { pos.y = 2.0 * P.canvas.y - pos.y; v.y = -v.y * 0.5; }
    pos = clamp(pos, vec2<f32>(0.0), P.canvas - 0.001);
    if (P.homing >= 1.0 && length(h - pos) < 0.5 && length(v) < 5.0) {
        pos = h;
        v = vec2<f32>(0.0);
    }
    grains[i] = vec4<f32>(pos, v);
    count(pos, i);

}

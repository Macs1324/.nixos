// Grain update: one grain per screenshot pixel, carried by the fluid.
// A grain is vec4(position px, velocity px/s).

@group(0) @binding(0) var<uniform> P: Params;
@group(0) @binding(1) var<storage, read_write> grains: array<vec4<f32>>;
@group(0) @binding(2) var<storage, read> outs: array<OutRect>;
@group(0) @binding(3) var psi: texture_2d<f32>;

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

    // Home positions matter only while eroding and while flying home.
    let releasing = P.homing == 0.0 && P.time < P.release_start + P.release_dur + 0.2;
    let homing = P.homing > 0.0;
    var h = vec2<f32>(0.0);
    if (releasing || homing) {
        h = home_of(i);
    }
    // Erosion: grains break loose in patches, not all at once.
    if (releasing) {
        let n = 0.65 * vnoise(h / (260.0 * u)) + 0.35 * vnoise(h / (60.0 * u));
        let release = P.release_start + P.release_dur * (0.1 + 0.9 * n) + 0.15 * ihash(i, 1u);
        if (P.time < release) {
            grains[i] = vec4<f32>(h, 0.0, 0.0);
            return;
        }
    }

    // Grains are tracers of the flow (the sub-grid turbulence is part of psi).
    // Midpoint (RK2): plain Euler spirals outwards and empties vortex cores.
    let v1 = vel_at(pos);
    v = vel_at(pos + v1 * dt * 0.5);
    if (homing) {
        // Critically damped springs; the flow fades out as they take over.
        let k = 55.0;
        let spring = s.zw + dt * (k * (h - pos) - 2.0 * sqrt(k) * s.zw);
        v = mix(v, spring, P.homing);
    }
    pos += v * dt;

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
}

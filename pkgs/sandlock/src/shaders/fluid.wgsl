// Stable-fluids passes (after PavelDoGreat's WebGL fluid simulation), one
// entry point per pass. Velocity is in fluid cells per second. Every pass
// binds only the slots it uses; gpu.rs builds a matching layout per pass.

struct Splats {
    geo: array<vec4<f32>, 32>,   // xy centre (cells), zw force (cells/s)
    kind: array<vec4<f32>, 32>,  // x radius (cells), y type: 0 push, 1 vortex, 2 burst
}

@group(0) @binding(0) var<uniform> P: Params;
@group(0) @binding(1) var<uniform> S: Splats;
@group(0) @binding(2) var samp: sampler;
@group(0) @binding(3) var vel_in: texture_2d<f32>;
@group(0) @binding(4) var vel_out: texture_storage_2d<rgba16float, write>;
@group(0) @binding(5) var scal_in: texture_2d<f32>;
@group(0) @binding(6) var scal_aux: texture_2d<f32>;
@group(0) @binding(7) var scal_out: texture_storage_2d<r32float, write>;
// Grains per cell, counted by the grains pass (grains.wgsl `count`).
@group(0) @binding(8) var<storage, read> counts: array<u32>;

fn grid() -> vec2<u32> {
    return textureDimensions(vel_in);
}

fn sgrid() -> vec2<u32> {
    return textureDimensions(scal_in);
}

fn cl(p: vec2<i32>, size: vec2<u32>) -> vec2<i32> {
    return clamp(p, vec2<i32>(0), vec2<i32>(size) - 1);
}

fn vel(p: vec2<i32>) -> vec2<f32> {
    return textureLoad(vel_in, cl(p, grid()), 0).xy;
}

fn scal(p: vec2<i32>) -> f32 {
    return textureLoad(scal_in, cl(p, sgrid()), 0).x;
}

@compute @workgroup_size(16, 16)
fn advect(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = grid();
    if (id.x >= size.x || id.y >= size.y) { return; }
    let s = vec2<f32>(size);
    let uv = (vec2<f32>(id.xy) + 0.5) / s;
    let v = textureSampleLevel(vel_in, samp, uv, 0.0).xy;
    let back = uv - P.dt * v / s;
    let nv = textureSampleLevel(vel_in, samp, back, 0.0).xy / (1.0 + P.dissipation * P.dt);
    textureStore(vel_out, id.xy, vec4<f32>(nv, 0.0, 0.0));
}

@compute @workgroup_size(16, 16)
fn splat(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = grid();
    if (id.x >= size.x || id.y >= size.y) { return; }
    let x = vec2<f32>(id.xy) + 0.5;
    var v = vel(vec2<i32>(id.xy));
    // Continuous wind: the curl of two slowly drifting large-scale noise
    // fields. Divergence-free, so it only bends and carries, and it changes
    // gradually: the flowy backbone of the storm, where gusts are impulses.
    if (P.forcing.x > 0.0) {
        let s = P.forcing.y;
        let e = 1.0 / s;
        let q = x / s;
        let t = P.time;
        let a = vec2<f32>(t * 0.035, t * 0.021);
        let b = vec2<f32>(5.2 - t * 0.017, 1.3 + t * 0.029);
        let wx = (vnoise(q + a + vec2<f32>(e, 0.0)) - vnoise(q + a - vec2<f32>(e, 0.0)))
               + 0.6 * (vnoise(2.1 * q + b + vec2<f32>(2.1 * e, 0.0)) - vnoise(2.1 * q + b - vec2<f32>(2.1 * e, 0.0)));
        let wy = (vnoise(q + a + vec2<f32>(0.0, e)) - vnoise(q + a - vec2<f32>(0.0, e)))
               + 0.6 * (vnoise(2.1 * q + b + vec2<f32>(0.0, 2.1 * e)) - vnoise(2.1 * q + b - vec2<f32>(0.0, 2.1 * e)));
        // (d/dy, -d/dx) of noise scaled by s: unit-ish magnitude per cell.
        v += vec2<f32>(wy, -wx) * 0.5 * s * P.forcing.x * P.dt;
    }
    for (var i = 0u; i < P.splat_count; i++) {
        let d = x - S.geo[i].xy;
        let r = S.kind[i].x;
        let g = exp(-dot(d, d) / (r * r));
        let t = u32(S.kind[i].y);
        if (t == 0u) {
            v += S.geo[i].zw * g;
        } else if (t == 1u) {
            v += vec2<f32>(-d.y, d.x) / r * S.geo[i].z * g;
        } else {
            v += normalize(d + 1e-4) * S.geo[i].z * g;
        }
    }
    textureStore(vel_out, id.xy, vec4<f32>(v, 0.0, 0.0));
}

@compute @workgroup_size(16, 16)
fn curl(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = grid();
    if (id.x >= size.x || id.y >= size.y) { return; }
    let p = vec2<i32>(id.xy);
    let l = vel(p - vec2<i32>(1, 0)).y;
    let r = vel(p + vec2<i32>(1, 0)).y;
    let b = vel(p - vec2<i32>(0, 1)).x;
    let t = vel(p + vec2<i32>(0, 1)).x;
    textureStore(scal_out, id.xy, vec4<f32>(0.5 * (r - l - t + b), 0.0, 0.0, 0.0));
}

// Vorticity confinement: pushes towards stronger curl, which keeps the curls
// within curls that make the WebGL demo look alive. scal_in = curl.
@compute @workgroup_size(16, 16)
fn vorticity(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = grid();
    if (id.x >= size.x || id.y >= size.y) { return; }
    let p = vec2<i32>(id.xy);
    let l = scal(p - vec2<i32>(1, 0));
    let r = scal(p + vec2<i32>(1, 0));
    let b = scal(p - vec2<i32>(0, 1));
    let t = scal(p + vec2<i32>(0, 1));
    let c = scal(p);
    var f = 0.5 * vec2<f32>(abs(t) - abs(b), abs(r) - abs(l));
    f = f / (length(f) + 1e-4) * P.vorticity * c;
    f.y = -f.y;
    let v = clamp(vel(p) + f * P.dt, vec2<f32>(-1000.0), vec2<f32>(1000.0));
    textureStore(vel_out, id.xy, vec4<f32>(v, 0.0, 0.0));
}

@compute @workgroup_size(16, 16)
fn divergence(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = grid();
    if (id.x >= size.x || id.y >= size.y) { return; }
    let p = vec2<i32>(id.xy);
    let c = vel(p);
    // Walls reflect: the neighbour outside mirrors this cell's velocity.
    var l = -c.x;
    var r = -c.x;
    var b = -c.y;
    var t = -c.y;
    if (p.x > 0) { l = vel(p - vec2<i32>(1, 0)).x; }
    if (p.x < i32(size.x) - 1) { r = vel(p + vec2<i32>(1, 0)).x; }
    if (p.y > 0) { b = vel(p - vec2<i32>(0, 1)).y; }
    if (p.y < i32(size.y) - 1) { t = vel(p + vec2<i32>(0, 1)).y; }
    textureStore(scal_out, id.xy, vec4<f32>(0.5 * (r - l + t - b), 0.0, 0.0, 0.0));
}

// Jacobi step for the pressure Poisson equation. scal_in = pressure,
// scal_aux = divergence.
@compute @workgroup_size(16, 16)
fn pressure(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = sgrid();
    if (id.x >= size.x || id.y >= size.y) { return; }
    let p = vec2<i32>(id.xy);
    let s = scal(p - vec2<i32>(1, 0)) + scal(p + vec2<i32>(1, 0)) + scal(p - vec2<i32>(0, 1)) + scal(p + vec2<i32>(0, 1));
    let d = textureLoad(scal_aux, p, 0).x;
    textureStore(scal_out, id.xy, vec4<f32>((s - d) * 0.25, 0.0, 0.0, 0.0));
}

// Density correction: the canvas holds one grain per pixel on average (the
// offscreen canvas has grains too), so a cell with more grains than pixels is
// crowded and one with fewer has thinned out, e.g. where quiet zones or attractors
// pulled grains away. Its excess is the source of a correction potential
// (laplacian(phi) = source, solved by `pressure`) whose gradient the grains
// follow (grains.wgsl `drift_at`): out of crowded cells into thin ones. The
// flow alone never refills an empty region: it only moves it around.
@compute @workgroup_size(16, 16)
fn dsource(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = textureDimensions(scal_out);
    if (id.x >= size.x || id.y >= size.y) { return; }
    let density = f32(counts[id.y * size.x + id.x]) / (P.cell_x * P.cell);
    let s = P.density * (density - 1.0) * (1.0 - P.homing);
    textureStore(scal_out, id.xy, vec4<f32>(s, 0.0, 0.0, 0.0));
}

// Quiet zones (grains.wgsl): how quiet each cell's homes are, 0..calm.
// Per cell rather than per grain: the zones are ~20 cells across, so the
// grains' bilinear lookup of this map matches the noise closely, at a
// fraction of the cost.
@compute @workgroup_size(16, 16)
fn quiet_map(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = textureDimensions(scal_out);
    if (id.x >= size.x || id.y >= size.y) { return; }
    let h = (vec2<f32>(id.xy) + 0.5) * vec2<f32>(P.cell_x, P.cell);
    let n = quiet_noise(h, P.quiet.y, P.quiet.z);
    textureStore(scal_out, id.xy, vec4<f32>(smoothstep(P.quiet.x, P.quiet.x + QUIET_RAMP, n) * P.quiet.w, 0.0, 0.0, 0.0));
}

// Subtract the pressure gradient: the velocity becomes (nearly) incompressible.
@compute @workgroup_size(16, 16)
fn gradient(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = grid();
    if (id.x >= size.x || id.y >= size.y) { return; }
    let p = vec2<i32>(id.xy);
    let g = 0.5 * vec2<f32>(scal(p + vec2<i32>(1, 0)) - scal(p - vec2<i32>(1, 0)),
                            scal(p + vec2<i32>(0, 1)) - scal(p - vec2<i32>(0, 1)));
    textureStore(vel_out, id.xy, vec4<f32>(vel(p) - g, 0.0, 0.0));
}

// Jacobi step for the stream function: laplacian(psi) = -curl. Beyond a wall
// psi continues with the opposite sign, which puts psi = 0 exactly on the wall
// line (the grid ends at the canvas edge): nothing flows through the walls.
// scal_in = psi, scal_aux = curl.
fn psi_at(p: vec2<i32>) -> f32 {
    let size = vec2<i32>(sgrid());
    let q = clamp(p, vec2<i32>(0), size - 1);
    let v = textureLoad(scal_in, q, 0).x;
    return select(v, -v, any(q != p));
}

@compute @workgroup_size(16, 16)
fn stream(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = sgrid();
    if (id.x >= size.x || id.y >= size.y) { return; }
    let p = vec2<i32>(id.xy);
    let s = psi_at(p - vec2<i32>(1, 0)) + psi_at(p + vec2<i32>(1, 0)) + psi_at(p - vec2<i32>(0, 1)) + psi_at(p + vec2<i32>(0, 1));
    textureStore(scal_out, id.xy, vec4<f32>((s + textureLoad(scal_aux, p, 0).x) * 0.25, 0.0, 0.0, 0.0));
}

// Sub-grid turbulence added to the stream function (scal_in = psi, scal_out
// = what the grains read): a moving noise field, ~3 cells per feature, so the
// grid carries it faithfully and grains need no noise of their own. It fades
// to 0 at the walls and during homing.
@compute @workgroup_size(16, 16)
fn turbulence(@builtin(global_invocation_id) id: vec3<u32>) {
    let size = sgrid();
    if (id.x >= size.x || id.y >= size.y) { return; }
    let cell = vec2<f32>(P.cell_x, P.cell);
    let p = (vec2<f32>(id.xy) + 0.5) * cell;
    let scale = 70.0 * P.unit;
    let wall = min(min(p.x, P.canvas.x - p.x), min(p.y, P.canvas.y - p.y));
    let taper = smoothstep(0.0, 1.5 * scale, wall);
    let noise = vnoise(p / scale + vec2<f32>(P.time * 0.3, -P.time * 0.2)) * taper * scale;
    // Grain velocity (px/s) is cell_x * cell_y * curl_px(psi): forcing.z * unit
    // px/s of turbulence.
    let fine = noise * P.forcing.z * P.unit / (cell.x * cell.y) * (1.0 - P.homing);
    textureStore(scal_out, id.xy, vec4<f32>(textureLoad(scal_in, id.xy, 0).x + fine, 0.0, 0.0, 0.0));
}

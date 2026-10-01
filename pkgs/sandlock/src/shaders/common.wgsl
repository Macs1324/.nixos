// Shared by every pass. Canvas coordinates are physical pixels of the whole
// desktop, y down; the fluid grid covers the same area in `cell`-sized cells.

struct Params {
    canvas: vec2<f32>,
    cell: f32,           // canvas px per fluid cell, vertically (see cell_x)
    time: f32,           // seconds since the lock started
    dt: f32,
    homing: f32,         // 0 = storm, 1 = springs pull every grain home
    release_start: f32,  // when the desktop starts eroding
    release_dur: f32,
    forcing: vec4<f32>,  // x wind force (cells/s^2), y wind scale (cells), z fine turbulence (px/s), w 1 = release attractor grains
    vorticity: f32,
    dissipation: f32,
    unit: f32,           // canvas height / 1440: scales px-based constants
    n_grains: u32,
    n_outputs: u32,
    splat_count: u32,
    cell_x: f32,         // horizontally: the grid ends exactly at the canvas edge
    seed: u32,           // changes every step: per-step randomness
    density: f32,        // density correction rate (1/s, 0 = off)
    homing_t: f32,       // seconds since the grains started flying home
    homing_done: f32,    // ... and when every grain must be exactly home
    placed: u32,         // 1 = every pixel holds exactly one grain (place.wgsl)
    quiet: vec4<f32>,    // quiet zones: x noise threshold, y size px, z noise time, w calm (0 = off)
}

// ---- quiet zones (grains.wgsl) ---------------------------------------------------
// 3D Perlin noise over (home position, time): the zones morph in place
// rather than slide. Integer hashing, so storm.rs (`quiet_threshold`)
// computes exactly the same values on the CPU.
//
// Perlin noise is 0 at every lattice point, so with time along a lattice
// axis the whole pattern would fade out and back once per time unit. The
// domain is rotated so time runs diagonally through the lattice: every
// place crosses its lattice points at a different moment, and the zones
// shift continuously.
fn quiet_domain(h: vec2<f32>, t: f32) -> vec3<f32> {
    return vec3<f32>(
        0.891568 * h.x + 0.259444 * h.y + 0.371207 * t,
        0.819648 * h.y - 0.572867 * t,
        -0.452886 * h.x + 0.510750 * h.y + 0.730772 * t,
    );
}

fn perlin_hash(c: vec3<i32>) -> u32 {
    var h = bitcast<u32>(c.x) * 73856093u ^ bitcast<u32>(c.y) * 19349663u ^ bitcast<u32>(c.z) * 83492791u;
    h = (h ^ (h >> 16u)) * 0x7feb352du;
    h = (h ^ (h >> 15u)) * 0x846ca68bu;
    return h ^ (h >> 16u);
}

// Ken Perlin's gradient: one of 12 cube-edge directions, dotted with `f`.
fn perlin_grad(h: u32, f: vec3<f32>) -> f32 {
    let k = h & 15u;
    let u = select(f.y, f.x, k < 8u);
    let v = select(select(f.z, f.x, k == 12u || k == 14u), f.y, k < 4u);
    return select(-u, u, (k & 1u) == 0u) + select(-v, v, (k & 2u) == 0u);
}

fn perlin(p: vec3<f32>) -> f32 {
    let i = vec3<i32>(floor(p));
    let f = p - floor(p);
    let u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    var x: array<f32, 4>;
    for (var k = 0; k < 4; k++) {
        let d = vec3<i32>(0, k & 1, k >> 1);
        let a = perlin_grad(perlin_hash(i + d), f - vec3<f32>(d));
        let b = perlin_grad(perlin_hash(i + d + vec3<i32>(1, 0, 0)), f - vec3<f32>(d) - vec3<f32>(1.0, 0.0, 0.0));
        x[k] = mix(a, b, u.x);
    }
    return mix(mix(x[0], x[1], u.y), mix(x[2], x[3], u.y), u.z);
}

// Noise over which a zone's calm ramps from none to full (storm.rs
// `QUIET_RAMP`): wide, so zones fade in rather than have edges.
const QUIET_RAMP: f32 = 0.3;

// Two octaves at a home position `h` (px) of zones `size` px across, at
// noise time `t`.
fn quiet_noise(h: vec2<f32>, size: f32, t: f32) -> f32 {
    let p = quiet_domain(h / size, t);
    return 0.7 * perlin(p) + 0.3 * perlin(p * 2.03 + vec3<f32>(17.1, 5.3, 11.7));
}

// One output's rectangle in the canvas and its first grain. Grains are laid
// out output by output, row by row: grain `offset + y * w + x` lives at
// `origin + (x, y)` in the screenshot.
struct OutRect {
    origin: vec2<f32>,
    size: vec2<f32>,
    offset: u32,
    _pad0: u32,
    _pad1: u32,
    _pad2: u32,
}

const NONE: u32 = 0xffffffffu;

fn hash(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

fn vnoise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    var f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2<f32>(1.0, 0.0)), f.x),
               mix(hash(i + vec2<f32>(0.0, 1.0)), hash(i + vec2<f32>(1.0, 1.0)), f.x), f.y);
}

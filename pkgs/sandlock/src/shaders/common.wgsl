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
    tide: vec4<f32>,     // tide: x band centre px, y half width px (0 = off), z strength
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

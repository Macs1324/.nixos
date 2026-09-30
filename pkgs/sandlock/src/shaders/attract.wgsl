// Recruiting: every target pixel (inside an attractor's rectangle) claims one
// free grain whose colour is most like its own, from the grains around it.
// Claims are atomic, so a grain is never taken twice; now and then a target
// trades up for a much better match, so the image sharpens over time.
//
// claim[pixel] = grain + 1 (0 = none); bound[grain] = pixel + 1 (0 = free).

struct Rect {
    origin: vec2<u32>,
    size: vec2<u32>,
    emerge: f32,   // seconds until (mostly) formed
    reach: f32,    // px a target looks around
    _pad0: u32,
    _pad1: u32,
}

@group(0) @binding(0) var<uniform> P: Params;
@group(0) @binding(1) var targets: texture_2d<f32>;
@group(0) @binding(2) var<storage, read_write> claim: array<atomic<u32>>;
@group(0) @binding(3) var<storage, read_write> bound: array<atomic<u32>>;
@group(0) @binding(4) var<storage, read> owner: array<u32>;
@group(0) @binding(5) var shot: texture_2d<f32>;
@group(0) @binding(6) var<storage, read> outs: array<OutRect>;
@group(1) @binding(0) var<uniform> R: Rect;

const SAMPLES: u32 = 12u;
const ID_MASK: u32 = 0x7fffffffu;

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

fn colour(grain: u32) -> vec3<f32> {
    return textureLoad(shot, home_of(grain), 0).rgb;
}

// Brightness first, hue second: when a colour isn't around (a blue logo over
// a grey desktop), light parts still get light grains and dark parts dark
// ones, so the image keeps its shading; when the hue is available, it wins.
fn distance(a: vec3<f32>, b: vec3<f32>) -> f32 {
    let d = a - b;
    let l = dot(d, vec3<f32>(0.299, 0.587, 0.114));
    let ca = d.r - d.g;
    let cb = 0.5 * (d.r + d.g) - d.b;
    return 4.0 * l * l + 0.5 * (ca * ca + cb * cb);
}

fn pcg(v: u32) -> u32 {
    let s = v * 747796405u + 2891336453u;
    let w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
    return (w >> 22u) ^ w;
}

fn rand(state: ptr<function, u32>) -> f32 {
    *state = pcg(*state);
    return f32(*state >> 8u) / 16777216.0;
}

@compute @workgroup_size(16, 16)
fn recruit(@builtin(global_invocation_id) id: vec3<u32>) {
    if (id.x >= R.size.x || id.y >= R.size.y) { return; }
    let p = R.origin + id.xy;
    let cw = u32(P.canvas.x);
    let pixel = p.y * cw + p.x;
    let t = textureLoad(targets, p, 0);
    var mine = atomicLoad(&claim[pixel]);

    // Not (or no longer) a target: let its grain go.
    if (t.a == 0.0) {
        if (mine != 0u) {
            atomicCompareExchangeWeak(&bound[mine - 1u], pixel + 1u, 0u);
            atomicStore(&claim[pixel], 0u);
        }
        return;
    }
    // A claim the grain side no longer agrees with (released) is stale.
    if (mine != 0u && atomicLoad(&bound[mine - 1u]) != pixel + 1u) {
        atomicStore(&claim[pixel], 0u);
        mine = 0u;
    }
    // Recruit once the storm has taken hold, and never while flying home.
    if (P.homing > 0.0 || P.time < P.release_start + 0.5 * P.release_dur) { return; }

    var rng = pcg(pixel ^ (P.seed * 0x9e3779b9u));
    // Rate-limited, so the image emerges over `emerge` seconds.
    let rate = 1.0 - exp(-P.dt * 3.0 / R.emerge);
    let roll = rand(&rng);
    if ((mine == 0u && roll >= rate) || (mine != 0u && roll >= rate * 0.25)) { return; }

    let want = t.rgb;
    // Trading up needs a clearly better match (40%), or grains churn.
    var best_d = 1e9;
    if (mine != 0u) { best_d = distance(want, colour(mine - 1u)) * 0.6; }
    var best = 0u;
    for (var k = 0u; k < SAMPLES; k++) {
        let r = R.reach * sqrt(rand(&rng));
        let a = 6.2831853 * rand(&rng);
        let q = vec2<i32>(p) + vec2<i32>(round(vec2<f32>(cos(a), sin(a)) * r));
        if (q.x < 0 || q.y < 0 || q.x >= i32(cw) || q.y >= i32(P.canvas.y)) { continue; }
        let o = owner[u32(q.y) * cw + u32(q.x)] & ID_MASK;
        if (o == 0u || atomicLoad(&bound[o - 1u]) != 0u) { continue; }
        let d = distance(want, colour(o - 1u));
        if (d < best_d) {
            best_d = d;
            best = o;
        }
    }
    if (best != 0u && atomicCompareExchangeWeak(&bound[best - 1u], 0u, pixel + 1u).exchanged) {
        if (mine != 0u) {
            atomicStore(&bound[mine - 1u], 0u);
        }
        atomicStore(&claim[pixel], best);
    }
}

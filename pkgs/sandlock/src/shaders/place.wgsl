// Strict placement for the recompose on unlock: while grains fly home, every
// canvas pixel holds exactly one grain (`owner`, grain + 1) and every grain
// exactly one pixel. There are as many grains as pixels, so the screen is
// always fully covered: no gaps, no grain hidden under another.
//
// Every step, from where the grains are now:
//
//   keep:   each pixel's grain from `scatter` (the one drawn there anyway)
//           keeps it, so everything visible stays exactly where it is;
//   claim:  each grain hidden under another takes a free pixel near it, in
//           rounds of growing radius (nearest first, across all grains);
//   rest:   the very few still without one take whatever pixels are left.
//
// (The claim rounds run over a list of the grains without a pixel, which a
// pass gathers once, sized for an indirect dispatch: a thread per grain in
// every round, most of them with nothing to do, cost several ms.)
//
// So only grains that overlap move, only as far as the nearest free pixel,
// and the holes their crowding left fill with them. (Re-dealing every grain
// along an order instead, rows or a space-filling curve, streaked or
// pixelated the whole picture: it shoves settled grains aside too.) When
// every grain is home, nothing overlaps and nothing moves.

struct Round {
    radius: f32,   // claim: px around the grain to look for a free pixel
    salt: u32,     // claim: per-round randomness
    _pad0: u32,
    _pad1: u32,
}

@group(0) @binding(0) var<uniform> P: Params;
@group(0) @binding(1) var<storage, read> grains: array<vec4<f32>>;
@group(0) @binding(2) var<storage, read_write> owner: array<atomic<u32>>;
@group(0) @binding(3) var<storage, read> outs: array<OutRect>;
// 1 once the grain has a pixel (the attractors' `bound` buffer: nothing
// recruits while grains fly home).
@group(0) @binding(4) var<storage, read_write> placed: array<atomic<u32>>;
// The grains without a pixel for the claims; after them, the pixels still
// free, both in no order (the attractors' `claim` buffer). Counters: free
// pixels, pixels taken from them, grains without a pixel.
@group(0) @binding(5) var<storage, read_write> list: array<u32>;
@group(0) @binding(6) var<storage, read_write> counters: array<atomic<u32>>;
// Workgroups for the claim rounds (dispatch_workgroups_indirect).
@group(0) @binding(7) var<storage, read_write> claim_groups: array<u32>;
@group(1) @binding(0) var<uniform> R: Round;

const ID_MASK: u32 = 0x7fffffffu;
const CLAIM_SAMPLES: u32 = 8u;

fn grain_index(gid: vec3<u32>, nw: vec3<u32>) -> u32 {
    return gid.x + gid.y * nw.x * 256u;
}

fn width() -> u32 {
    return u32(P.canvas.x);
}

fn pixels() -> u32 {
    return width() * u32(P.canvas.y);
}

fn pcg(v: u32) -> u32 {
    let s = v * 747796405u + 2891336453u;
    let w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
    return (w >> 22u) ^ w;
}

// After `scatter` (with `placed` cleared, so no grain has priority): each
// pixel's grain keeps it. Per pixel; there are as many pixels as grains.
@compute @workgroup_size(256)
fn keep(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(num_workgroups) nw: vec3<u32>) {
    let p = grain_index(gid, nw);
    if (p >= pixels()) { return; }
    let o = atomicLoad(&owner[p]) & ID_MASK;
    atomicStore(&owner[p], o);
    if (o != 0u) {
        atomicStore(&placed[o - 1u], 1u);
    }
}

// A grain without a pixel (from `gather`) tries a few random free pixels
// within `R.radius` of where it is.
@compute @workgroup_size(256)
fn claim(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(num_workgroups) nw: vec3<u32>) {
    let k = grain_index(gid, nw);
    if (k >= atomicLoad(&counters[2])) { return; }
    let i = list[k];
    if (atomicLoad(&placed[i]) != 0u) { return; }
    let at = grains[i].xy;
    var rng = pcg(i ^ (R.salt * 0x9e3779b9u) ^ (P.seed * 0x85ebca6bu));
    for (var k = 0u; k < CLAIM_SAMPLES; k++) {
        rng = pcg(rng);
        let r = R.radius * sqrt(f32(rng >> 8u) / 16777216.0);
        rng = pcg(rng);
        let a = 6.2831853 * f32(rng >> 8u) / 16777216.0;
        let q = vec2<i32>(floor(at + vec2<f32>(cos(a), sin(a)) * r));
        if (q.x < 0 || q.y < 0 || q.x >= i32(width()) || q.y >= i32(P.canvas.y)) { continue; }
        let pixel = u32(q.y) * width() + u32(q.x);
        // Most pixels are taken: look before the (costlier) atomic exchange.
        if (atomicLoad(&owner[pixel]) == 0u
            && atomicCompareExchangeWeak(&owner[pixel], 0u, i + 1u).exchanged) {
            atomicStore(&placed[i], 1u);
            return;
        }
    }
}

var<workgroup> group_count: atomic<u32>;
var<workgroup> group_base: u32;

// This thread's slot in a list that counter `c` keeps the length of, if
// `wants` (else 0): the workgroup counts its own first and reserves them all
// at once, so the threads don't all queue on the one counter.
fn reserve(wants: bool, t: u32, c: u32) -> u32 {
    if (t == 0u) { atomicStore(&group_count, 0u); }
    workgroupBarrier();
    var slot = 0u;
    if (wants) { slot = atomicAdd(&group_count, 1u); }
    workgroupBarrier();
    if (t == 0u) { group_base = atomicAdd(&counters[c], atomicLoad(&group_count)); }
    workgroupBarrier();
    return group_base + slot;
}

// Lists the grains without a pixel...
@compute @workgroup_size(256)
fn gather(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(num_workgroups) nw: vec3<u32>,
          @builtin(local_invocation_index) t: u32) {
    let i = grain_index(gid, nw);
    let homeless = i < P.n_grains && atomicLoad(&placed[i]) == 0u;
    let k = reserve(homeless, t, 2u);
    if (homeless) { list[k] = i; }
}

// ... and sizes the claim rounds for them (x at most 65535 per dispatch).
@compute @workgroup_size(1)
fn size_claims() {
    let groups = (atomicLoad(&counters[2]) + 255u) / 256u;
    let x = clamp(groups, 1u, 65535u);
    claim_groups[0] = x;
    claim_groups[1] = (groups + x - 1u) / x;
    claim_groups[2] = 1u;
}

// Lists the pixels still free...
@compute @workgroup_size(256)
fn holes(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(num_workgroups) nw: vec3<u32>,
         @builtin(local_invocation_index) t: u32) {
    let p = grain_index(gid, nw);
    let free = p < pixels() && atomicLoad(&owner[p]) == 0u;
    let k = reserve(free, t, 0u);
    if (free) { list[k] = p; }
}

// ... and every grain still without one takes the next. There are exactly as
// many of each: every pixel without a grain is a grain without a pixel.
@compute @workgroup_size(256)
fn rest(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(num_workgroups) nw: vec3<u32>,
        @builtin(local_invocation_index) t: u32) {
    let i = grain_index(gid, nw);
    let homeless = i < P.n_grains && atomicLoad(&placed[i]) == 0u;
    let k = reserve(homeless, t, 1u);
    if (homeless && k < atomicLoad(&counters[0])) {
        atomicStore(&owner[list[k]], i + 1u);
        atomicStore(&placed[i], 1u);
    }
}

// Every pixel's own grain (the inverse of home_of): the exact end of the
// recompose, whatever rounding did on the way.
@compute @workgroup_size(16, 16)
fn home(@builtin(global_invocation_id) id: vec3<u32>) {
    let w = width();
    if (id.x >= w || id.y >= u32(P.canvas.y)) { return; }
    let p = vec2<f32>(id.xy);
    for (var k = 0u; k < P.n_outputs; k++) {
        let o = outs[k];
        if (all(p >= o.origin) && all(p < o.origin + o.size)) {
            let local = id.xy - vec2<u32>(o.origin);
            atomicStore(&owner[id.y * w + id.x], o.offset + local.y * u32(o.size.x) + local.x + 1u);
            return;
        }
    }
}

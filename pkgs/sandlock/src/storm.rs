//! The storm's choreography: ambient gusts, key vortices, the wrong-password
//! eruption with its lingering entropy, and the springs home on unlock. Pure
//! logic; the caller feeds the resulting splats and params to the GPU.

use crate::config;
use crate::gpu::{Params, Splat};

/// Tiny xorshift RNG: gusts need variety, not statistical quality.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> f32 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        (self.0 >> 40) as f32 / (1u64 << 24) as f32
    }

    fn range(&mut self, lo: f32, hi: f32) -> f32 {
        lo + (hi - lo) * self.next()
    }

    fn sign(&mut self) -> f32 {
        if self.next() < 0.5 {
            -1.0
        } else {
            1.0
        }
    }
}

const RELEASE_DELAY: f32 = 0.15;
/// Password dots shown at most; more characters still count.
const MAX_DOTS: usize = 32;
const HOMING_RAMP: f32 = 0.35;
const SHAKE: f32 = 0.4;
/// Wind force (cells/s²) at `intensity = 1`.
const WIND: f32 = 12.0;
/// After this long, every grain is home and the frame equals the screenshot.
pub(crate) const HOMING_DONE: f32 = 1.4;

#[derive(Clone, Copy, PartialEq)]
pub(crate) enum Phase {
    Storm,
    Checking,
    Homing { since: f32 },
}

pub(crate) struct Dot {
    at: [f32; 2],
    born: f32,
}

pub(crate) struct Storm {
    tuning: config::Storm,
    rng: Rng,
    pub(crate) time: f32,
    pub(crate) phase: Phase,
    entropy: f32,
    next_gust: f32,
    canvas: [f32; 2],
    /// Fluid cell size in px (x, y).
    cell: [f32; 2],
    /// Where the dots sit: centre of the primary output's lower third.
    anchor: [f32; 2],
    spacing: f32,
    dot_radius: f32,
    dots: Vec<Dot>,
    /// Characters typed beyond `MAX_DOTS`, which get no dot.
    undotted: usize,
    pending: Vec<Splat>,
    /// Splats that go off later (the eruption's shockwave).
    scheduled: Vec<(f32, Splat)>,
    /// Release every grain bound to an attractor on the next step.
    shatter: bool,
    /// Latest pointer position (canvas px), and where it was at the last step.
    pointer: Option<[f32; 2]>,
    pointer_prev: Option<[f32; 2]>,
    /// Shake of the dots after a wrong password: (start time).
    shake: Option<f32>,
    /// Quiet-zone noise level above which a home is (starting to be) quiet.
    quiet_threshold: f32,
}

impl Storm {
    /// `primary` is the (origin, size) of the output that shows the dots.
    pub(crate) fn new(
        canvas: [f32; 2],
        cell: [f32; 2],
        primary: ([f32; 2], [f32; 2]),
        seed: u64,
        tuning: config::Storm,
    ) -> Self {
        let (o, s) = primary;
        Self {
            tuning,
            rng: Rng(seed | 1),
            time: 0.0,
            phase: Phase::Storm,
            entropy: 0.0,
            next_gust: RELEASE_DELAY,
            canvas,
            cell,
            anchor: [o[0] + s[0] * 0.5, o[1] + s[1] * 0.78],
            // Discs of sand (attract::Dots) need more room than drawn dots.
            spacing: s[1] * 0.03,
            dot_radius: s[1] * 0.008,
            dots: Vec::new(),
            undotted: 0,
            pending: Vec::new(),
            scheduled: Vec::new(),
            shatter: false,
            pointer: None,
            pointer_prev: None,
            shake: None,
            quiet_threshold: quiet_threshold(tuning.quiet),
        }
    }

    fn cells(&self, px: [f32; 2]) -> [f32; 2] {
        [px[0] / self.cell[0], px[1] / self.cell[1]]
    }

    fn dot_pos(&self, i: usize, n: usize) -> [f32; 2] {
        let offset = (i as f32 - (n as f32 - 1.0) * 0.5) * self.spacing;
        [self.anchor[0] + offset, self.anchor[1]]
    }

    /// Where the password dots go (see `dots`): the row's centre, how wide
    /// it may get (`MAX_DOTS` dots, shaking), and a full dot's radius, in
    /// canvas px.
    pub(crate) fn dots_row(&self) -> ([f32; 2], f32, f32) {
        (self.anchor, (MAX_DOTS as f32 + 1.5) * self.spacing, self.dot_radius)
    }

    pub(crate) fn typed(&mut self) {
        if self.shake.take().is_some() {
            self.cleared();
        }
        if self.dots.len() == MAX_DOTS {
            self.undotted += 1;
            return;
        }
        let n = self.dots.len() + 1;
        let at = self.dot_pos(n - 1, n);
        // Existing dots re-centre as the row grows.
        for i in 0..self.dots.len() {
            self.dots[i].at = self.dot_pos(i, n);
        }
        // No burst of wind: the dot gathering its sand is movement enough.
        self.dots.push(Dot {
            at,
            born: self.time,
        });
    }

    pub(crate) fn erased(&mut self) {
        if self.undotted > 0 {
            self.undotted -= 1;
            return;
        }
        self.dots.pop();
        let n = self.dots.len();
        for i in 0..n {
            self.dots[i].at = self.dot_pos(i, n);
        }
    }

    pub(crate) fn cleared(&mut self) {
        self.dots.clear();
        self.undotted = 0;
    }

    pub(crate) fn submitted(&mut self) {
        self.phase = Phase::Checking;
    }

    /// Wrong password: the sand erupts around the dots, and the storm runs
    /// hotter. The eruption is a ring of counter-spinning vortices, not a
    /// radial blast: a blast compresses grains into a ring and leaves a hole
    /// the incompressible flow never refills, which gap filling shows as
    /// flickering shards. Neighbouring opposite vortices still shoot jets
    /// outwards, so it reads as an explosion.
    pub(crate) fn wrong(&mut self) {
        self.phase = Phase::Storm;
        let e = self.tuning.eruption;
        if e <= 0.0 {
            self.shake = Some(self.time);
            return;
        }
        let centre = self.cells(self.anchor);
        // A shockwave: rings of counter-spinning vortices going off one after
        // another, each wider and stronger, so the eruption spreads outwards.
        // (radius from the dots, vortices, spin, vortex size) in cells.
        const RINGS: [(f32, usize, f32, f32); 4] =
            [(6.0, 8, 450.0, 4.0), (13.0, 12, 420.0, 6.0), (21.0, 14, 380.0, 8.0), (30.0, 16, 320.0, 10.0)];
        for (ring, &(r, n, spin, size)) in RINGS.iter().enumerate() {
            let at_time = self.time + ring as f32 * 0.1;
            let twist = self.rng.range(0.0, std::f32::consts::TAU);
            for k in 0..n {
                let angle = twist + k as f32 / n as f32 * std::f32::consts::TAU + self.rng.range(-0.15, 0.15);
                let at = [centre[0] + r * angle.cos(), centre[1] + r * angle.sin()];
                let spin = if k % 2 == 0 { spin } else { -spin } * e;
                self.scheduled.push((at_time, Splat::Vortex { at, spin, radius: size }));
            }
        }
        self.pending.push(Splat::Vortex {
            at: centre,
            spin: self.rng.sign() * 500.0 * e,
            radius: 8.0,
        });
        self.entropy += 2.5 * e;
        // Attractors let go of every grain; the images re-form afterwards.
        self.shatter = true;
        // The dots shake, then vanish (see `step`).
        self.shake = Some(self.time);
    }

    /// The pointer moved to `at` (canvas px). `jumped`: it just entered a
    /// screen, so the distance from its last position is not a stroke.
    pub(crate) fn pointer(&mut self, at: [f32; 2], jumped: bool) {
        if jumped {
            self.pointer_prev = None;
        }
        self.pointer = Some(at);
    }

    /// Stirs the fluid along the pointer's path since the last step, with its
    /// velocity, like dragging in the WebGL fluid demo.
    fn stir(&mut self, dt: f32, splats: &mut Vec<Splat>) {
        let (Some(now), prev) = (self.pointer, self.pointer_prev) else { return };
        self.pointer_prev = Some(now);
        let Some(prev) = prev else { return };
        let d = [now[0] - prev[0], now[1] - prev[1]];
        let len = d[0].hypot(d[1]);
        if len < 0.5 || self.tuning.mouse <= 0.0 {
            return;
        }
        // Velocity in cells/s, capped so a flick can't blow up the solver.
        let mut v = [d[0] / self.cell[0] / dt, d[1] / self.cell[1] / dt];
        let speed = v[0].hypot(v[1]);
        let cap = 400.0;
        if speed > cap {
            v = [v[0] * cap / speed, v[1] * cap / speed];
        }
        let force = [v[0] * self.tuning.mouse, v[1] * self.tuning.mouse];
        // Along the path, so a fast stroke leaves a trail rather than a dot.
        let steps = ((len / (3.0 * self.cell[0])).ceil() as usize).clamp(1, 4);
        for s in 1..=steps {
            let f = s as f32 / steps as f32;
            let at = self.cells([prev[0] + d[0] * f, prev[1] + d[1] * f]);
            splats.push(Splat::Push { at, force, radius: 3.5 });
        }
    }

    /// Quiet zones for this step (see `Params::quiet`): there from the
    /// start, and less calm while the storm is hot after a wrong password.
    fn quiet(&self, storming: bool) -> [f32; 4] {
        let t = self.tuning;
        if t.quiet <= 0.0 || !storming {
            return [0.0; 4];
        }
        let calm = 1.0 / (1.0 + 2.0 * self.entropy);
        let unit = self.canvas[1] / 1440.0;
        [
            self.quiet_threshold,
            t.quiet_size.max(1.0) * unit,
            self.time / t.quiet_drift.max(0.1),
            calm * t.quiet_calm.clamp(0.0, 1.0),
        ]
    }

    pub(crate) fn correct(&mut self) {
        self.phase = Phase::Homing { since: self.time };
        self.cleared();
    }

    /// Seconds since the grains started flying home, if they have.
    pub(crate) fn homing_for(&self) -> Option<f32> {
        match self.phase {
            Phase::Homing { since } => Some(self.time - since),
            _ => None,
        }
    }

    /// Advances by `dt`, filling `params` and returning this step's splats.
    pub(crate) fn step(&mut self, dt: f32, params: &mut Params) -> Vec<Splat> {
        self.time += dt;
        let homing = self.homing_for().map(|t| (t / HOMING_RAMP).min(1.0));
        let mut splats = std::mem::take(&mut self.pending);
        if homing.is_none() {
            self.stir(dt, &mut splats);
        }
        let now = self.time;
        self.scheduled.retain(|(at, s)| {
            if *at <= now {
                splats.push(*s);
            }
            *at > now
        });

        let t = self.tuning;
        if homing.is_none() && self.time >= RELEASE_DELAY && t.gusts > 0.0 {
            // Gusts: sudden bursts on top of the wind, more frequent with
            // `gusts` and after a wrong password, stronger with `intensity`.
            while self.time >= self.next_gust {
                let at = [
                    self.rng.range(0.0, self.canvas[0]),
                    self.rng.range(0.0, self.canvas[1]),
                ];
                let at = self.cells(at);
                let angle = self.rng.range(0.0, std::f32::consts::TAU);
                let f = self.rng.range(25.0, 60.0) * t.intensity * (1.0 + 0.8 * self.entropy);
                splats.push(Splat::Push {
                    at,
                    force: [f * angle.cos(), f * angle.sin()],
                    radius: self.rng.range(5.0, 12.0),
                });
                if self.rng.next() < 0.5 {
                    splats.push(Splat::Vortex {
                        at,
                        spin: self.rng.sign() * f * 0.9,
                        radius: self.rng.range(4.0, 9.0),
                    });
                }
                self.next_gust += self.rng.range(0.12, 0.35) / ((1.0 + self.entropy) * t.gusts);
            }
        }
        self.entropy *= (-dt / 8.0).exp();
        if self.shake.is_some_and(|t| self.time - t >= SHAKE) {
            self.shake = None;
            self.cleared();
        }

        params.time = self.time;
        params.release_start = RELEASE_DELAY;
        params.homing = homing.unwrap_or(0.0);
        params.homing_t = self.homing_for().unwrap_or(0.0);
        params.homing_done = HOMING_DONE;
        let storming = homing.is_none();
        params.vorticity = if storming {
            12.0 * t.swirl * (1.0 + 0.6 * self.entropy)
        } else {
            3.0
        };
        // Wind strength, wind feature size (~1/3 screen height), fine turbulence.
        let wind = if storming { WIND * t.intensity * (1.0 + 0.8 * self.entropy) } else { 0.0 };
        params.density = if storming { t.density } else { 0.0 };
        params.quiet = self.quiet(storming);
        params.forcing = [wind, 20.0, 55.0 * t.swirl, if std::mem::take(&mut self.shatter) { 1.0 } else { 0.0 }];
        splats
    }

    /// Dots as (x, y, opacity) in canvas px, with pop-in and a wrong-password
    /// shake applied.
    pub(crate) fn dots(&self) -> Vec<[f32; 3]> {
        let pulse = if self.phase == Phase::Checking {
            0.55 + 0.45 * (self.time * 7.0).cos()
        } else {
            1.0
        };
        let shake = self
            .shake
            .map(|t| self.time - t)
            .filter(|t| *t < SHAKE)
            .map(|t| (t * 60.0).sin() * (1.0 - t / SHAKE) * self.spacing * 0.6)
            .unwrap_or(0.0);
        self.dots
            .iter()
            .map(|d| {
                let pop = ((self.time - d.born) / 0.12).clamp(0.0, 1.0);
                [d.at[0] + shake, d.at[1], pop * pulse]
            })
            .collect()
    }
}

// ---- quiet zones --------------------------------------------------------------

/// common.wgsl `QUIET_RAMP`.
const QUIET_RAMP: f32 = 0.3;

/// common.wgsl `perlin_hash`.
fn perlin_hash(c: [i32; 3]) -> u32 {
    let mut h = (c[0] as u32).wrapping_mul(73_856_093) ^ (c[1] as u32).wrapping_mul(19_349_663) ^ (c[2] as u32).wrapping_mul(83_492_791);
    h = (h ^ (h >> 16)).wrapping_mul(0x7feb_352d);
    h = (h ^ (h >> 15)).wrapping_mul(0x846c_a68b);
    h ^ (h >> 16)
}

/// common.wgsl `perlin_grad`.
fn perlin_grad(h: u32, f: [f32; 3]) -> f32 {
    let k = h & 15;
    let u = if k < 8 { f[0] } else { f[1] };
    let v = if k < 4 {
        f[1]
    } else if k == 12 || k == 14 {
        f[0]
    } else {
        f[2]
    };
    (if k & 1 == 0 { u } else { -u }) + (if k & 2 == 0 { v } else { -v })
}

/// common.wgsl `perlin`.
fn perlin(p: [f32; 3]) -> f32 {
    let i = p.map(|v| v.floor() as i32);
    let f = [0, 1, 2].map(|a| p[a] - p[a].floor());
    let u = f.map(|f| f * f * f * (f * (f * 6.0 - 15.0) + 10.0));
    let lerp = |a: f32, b: f32, t: f32| a + (b - a) * t;
    let x = [0, 1, 2, 3].map(|k: i32| {
        let d = [0, k & 1, k >> 1];
        let fd = [0, 1, 2].map(|a| f[a] - d[a] as f32);
        let a = perlin_grad(perlin_hash([i[0] + d[0], i[1] + d[1], i[2] + d[2]]), fd);
        let b = perlin_grad(perlin_hash([i[0] + d[0] + 1, i[1] + d[1], i[2] + d[2]]), [fd[0] - 1.0, fd[1], fd[2]]);
        lerp(a, b, u[0])
    });
    lerp(lerp(x[0], x[1], u[1]), lerp(x[2], x[3], u[1]), u[2])
}

/// common.wgsl `quiet_domain`: time runs diagonally through the lattice.
fn quiet_domain(h: [f32; 2], t: f32) -> [f32; 3] {
    [
        0.891_568 * h[0] + 0.259_444 * h[1] + 0.371_207 * t,
        0.819_648 * h[1] - 0.572_867 * t,
        -0.452_886 * h[0] + 0.510_750 * h[1] + 0.730_772 * t,
    ]
}

/// common.wgsl `quiet_noise`, in noise units (home / size).
fn quiet_noise(p: [f32; 2], t: f32) -> f32 {
    let p = quiet_domain(p, t);
    0.7 * perlin(p) + 0.3 * perlin([p[0] * 2.03 + 17.1, p[1] * 2.03 + 5.3, p[2] * 2.03 + 11.7])
}

/// The noise level to start quieting at so that `share` of the desktop is
/// at least half as calm as its zones get: the noise is not uniform, so its
/// quantile is measured rather than assumed.
fn quiet_threshold(share: f32) -> f32 {
    if share <= 0.0 {
        return 2.0; // never
    }
    let mut samples: Vec<f32> = (0..20_000)
        .map(|k| {
            let k = k as f32;
            // A spread of points and times, away from lattice alignment.
            quiet_noise([(k * 0.618_034).fract() * 97.0, (k * 0.754_878).fract() * 89.0], (k * 0.569_84).fract() * 50.0)
        })
        .collect();
    samples.sort_by(f32::total_cmp);
    let q = samples[(((1.0 - share.min(1.0)) * samples.len() as f32) as usize).min(samples.len() - 1)];
    // Calm ramps over [threshold, threshold + QUIET_RAMP]: centre it on q.
    q - QUIET_RAMP / 2.0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quiet_threshold_gives_the_share() {
        for share in [0.1, 0.2, 0.4] {
            let t = quiet_threshold(share);
            let n = 20_000;
            // Different points than the ones the threshold was measured on.
            let above = (0..n)
                .filter(|&k| {
                    let k = k as f32;
                    quiet_noise([(k * 0.414_214).fract() * 71.0, (k * 0.236_068).fract() * 67.0], (k * 0.302_776).fract() * 40.0)
                        > t + QUIET_RAMP / 2.0
                })
                .count() as f32
                / n as f32;
            assert!((above - share).abs() < 0.03, "share {share}: {above}");
        }
        assert!(quiet_threshold(0.0) > 1.0);
    }

    /// How fast the pattern changes over a patch of desktop, through time.
    fn speeds(noise: impl Fn([f32; 2], f32) -> f32) -> Vec<f32> {
        (0..80)
            .map(|k| {
                let t = k as f32 * 0.05;
                let n = 40 * 40;
                (0..n)
                    .map(|i| {
                        let p = [(i % 40) as f32 * 0.3, (i / 40) as f32 * 0.3];
                        (noise(p, t + 0.01) - noise(p, t)).abs()
                    })
                    .sum::<f32>()
                    / n as f32
            })
            .collect()
    }

    fn swing(v: &[f32]) -> f32 {
        let (lo, hi) = v.iter().fold((f32::MAX, 0.0f32), |(lo, hi), &x| (lo.min(x), hi.max(x)));
        (hi - lo) / hi
    }

    /// The zones shift at a steady pace. With time along a lattice axis the
    /// whole pattern would stall at every lattice plane (Perlin noise changes
    /// slowest there) and lurch in between, once per time unit.
    #[test]
    fn quiet_zones_do_not_pulse() {
        let rotated = swing(&speeds(quiet_noise));
        let axis = swing(&speeds(|p, t| {
            0.7 * perlin([p[0], p[1], t]) + 0.3 * perlin([p[0] * 2.03 + 17.1, p[1] * 2.03 + 5.3, t * 2.03 + 11.7])
        }));
        assert!(rotated < 0.5 * axis, "speed swings {rotated} rotated, {axis} axis-aligned");
    }
}

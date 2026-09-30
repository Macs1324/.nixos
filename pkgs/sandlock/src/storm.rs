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
const HOMING_RAMP: f32 = 0.5;
const SHAKE: f32 = 0.4;
/// Wind force (cells/s²) at `intensity = 1`.
const WIND: f32 = 12.0;
/// After this long, every grain is home and the frame equals the screenshot.
pub(crate) const HOMING_DONE: f32 = 2.4;

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
    pub(crate) dot_radius: f32,
    dots: Vec<Dot>,
    pending: Vec<Splat>,
    /// Shake of the dots after a wrong password: (start time).
    shake: Option<f32>,
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
            spacing: s[1] * 0.022,
            dot_radius: s[1] * 0.0055,
            dots: Vec::new(),
            pending: Vec::new(),
            shake: None,
        }
    }

    fn cells(&self, px: [f32; 2]) -> [f32; 2] {
        [px[0] / self.cell[0], px[1] / self.cell[1]]
    }

    fn dot_pos(&self, i: usize, n: usize) -> [f32; 2] {
        let offset = (i as f32 - (n as f32 - 1.0) * 0.5) * self.spacing;
        [self.anchor[0] + offset, self.anchor[1]]
    }

    pub(crate) fn typed(&mut self) {
        if self.shake.take().is_some() {
            self.dots.clear();
        }
        let n = self.dots.len() + 1;
        let at = self.dot_pos(n - 1, n);
        // Existing dots re-centre as the row grows.
        for i in 0..self.dots.len() {
            self.dots[i].at = self.dot_pos(i, n);
        }
        self.dots.push(Dot {
            at,
            born: self.time,
        });
        let spin = self.rng.sign() * 70.0;
        self.pending.push(Splat::Vortex {
            at: self.cells(at),
            spin,
            radius: 2.5,
        });
    }

    pub(crate) fn erased(&mut self) {
        self.dots.pop();
        let n = self.dots.len();
        for i in 0..n {
            self.dots[i].at = self.dot_pos(i, n);
        }
    }

    pub(crate) fn cleared(&mut self) {
        self.dots.clear();
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
        let centre = self.cells(self.anchor);
        const RING: usize = 8;
        for k in 0..RING {
            let angle = k as f32 / RING as f32 * std::f32::consts::TAU + self.rng.range(-0.2, 0.2);
            let at = [centre[0] + 7.0 * angle.cos(), centre[1] + 7.0 * angle.sin()];
            let spin = if k % 2 == 0 { 180.0 } else { -180.0 };
            self.pending.push(Splat::Vortex {
                at,
                spin,
                radius: 4.0,
            });
        }
        self.pending.push(Splat::Vortex {
            at: centre,
            spin: self.rng.sign() * 220.0,
            radius: 6.0,
        });
        self.entropy += 1.0;
        // The dots shake, then vanish (see `step`).
        self.shake = Some(self.time);
    }

    pub(crate) fn correct(&mut self) {
        self.phase = Phase::Homing { since: self.time };
        self.dots.clear();
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
        self.entropy *= (-dt / 6.0).exp();
        if self.shake.is_some_and(|t| self.time - t >= SHAKE) {
            self.shake = None;
            self.dots.clear();
        }

        params.time = self.time;
        params.release_start = RELEASE_DELAY;
        params.homing = homing.unwrap_or(0.0);
        let storming = homing.is_none();
        params.vorticity = if storming {
            12.0 * t.swirl * (1.0 + 0.6 * self.entropy)
        } else {
            3.0
        };
        // Wind strength, wind feature size (~1/3 screen height), fine turbulence.
        let wind = if storming { WIND * t.intensity * (1.0 + 0.8 * self.entropy) } else { 0.0 };
        params.forcing = [wind, 20.0, 55.0 * t.swirl, 0.0];
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

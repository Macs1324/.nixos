//! Attractors: images whose opaque pixels pull in the most similar grains, so
//! the image emerges from the storm out of the desktop's own pixels.
//!
//! Every attractor renders into a `Target`: a rectangle of the canvas-wide
//! target image (RGB = the colour a pixel wants, A = its firmness, 0 = none).
//! A PNG renders once; a clock re-renders its rectangle when the time it
//! shows changes, and only the pixels that change lose or gain grains.

use std::io::BufReader;

use anyhow::{bail, Context};

use crate::config;
use crate::gpu::Place;

/// A rectangle of target pixels in canvas coordinates, RGBA8 row by row.
pub(crate) struct Target {
    pub(crate) origin: [u32; 2],
    pub(crate) size: [u32; 2],
    pub(crate) rgba: Vec<u8>,
}

/// Decodes any PNG into straight-alpha RGBA8.
pub(crate) fn decode(path: &std::path::Path) -> anyhow::Result<(u32, u32, Vec<u8>)> {
    let file = std::fs::File::open(path).with_context(|| format!("opening {}", path.display()))?;
    let mut decoder = png::Decoder::new(BufReader::new(file));
    decoder.set_transformations(
        png::Transformations::normalize_to_color8() | png::Transformations::ALPHA,
    );
    let mut reader = decoder
        .read_info()
        .with_context(|| format!("reading {}", path.display()))?;
    let size = reader.output_buffer_size().context("PNG too large")?;
    let mut buf = vec![0u8; size];
    let info = reader.next_frame(&mut buf)?;
    let (w, h) = (info.width, info.height);
    let n = (w * h) as usize;
    let rgba = match info.color_type {
        png::ColorType::Rgba => buf[..n * 4].to_vec(),
        png::ColorType::Rgb => buf[..n * 3]
            .as_chunks::<3>().0.iter()
            .flat_map(|p| [p[0], p[1], p[2], 255])
            .collect(),
        png::ColorType::GrayscaleAlpha => buf[..n * 2]
            .as_chunks::<2>().0.iter()
            .flat_map(|p| [p[0], p[0], p[0], p[1]])
            .collect(),
        png::ColorType::Grayscale => buf[..n].iter().flat_map(|&g| [g, g, g, 255]).collect(),
        png::ColorType::Indexed => bail!("{}: palette not expanded", path.display()),
    };
    Ok((w, h, rgba))
}

/// Bilinear resample with premultiplied alpha, so transparent edges don't
/// bleed dark fringes into the colours.
fn resize(w: u32, h: u32, src: &[u8], nw: u32, nh: u32) -> Vec<u8> {
    let at = |x: u32, y: u32| {
        let o = ((y * w + x) * 4) as usize;
        let a = f32::from(src[o + 3]) / 255.0;
        [
            f32::from(src[o]) * a,
            f32::from(src[o + 1]) * a,
            f32::from(src[o + 2]) * a,
            a * 255.0,
        ]
    };
    let mut out = vec![0u8; (nw * nh * 4) as usize];
    for y in 0..nh {
        let fy = ((y as f32 + 0.5) * h as f32 / nh as f32 - 0.5).clamp(0.0, (h - 1) as f32);
        let (y0, ty) = (fy.floor() as u32, fy.fract());
        let y1 = (y0 + 1).min(h - 1);
        for x in 0..nw {
            let fx = ((x as f32 + 0.5) * w as f32 / nw as f32 - 0.5).clamp(0.0, (w - 1) as f32);
            let (x0, tx) = (fx.floor() as u32, fx.fract());
            let x1 = (x0 + 1).min(w - 1);
            let (a, b, c, d) = (at(x0, y0), at(x1, y0), at(x0, y1), at(x1, y1));
            let o = ((y * nw + x) * 4) as usize;
            let alpha =
                (a[3] * (1.0 - tx) + b[3] * tx) * (1.0 - ty) + (c[3] * (1.0 - tx) + d[3] * tx) * ty;
            for k in 0..3 {
                let v = (a[k] * (1.0 - tx) + b[k] * tx) * (1.0 - ty)
                    + (c[k] * (1.0 - tx) + d[k] * tx) * ty;
                out[o + k] = if alpha > 0.0 {
                    (v / (alpha / 255.0)).round().clamp(0.0, 255.0) as u8
                } else {
                    0
                };
            }
            out[o + 3] = alpha.round() as u8;
        }
    }
    out
}

/// An output as attractors see it.
pub(crate) struct Screen {
    pub(crate) name: Option<String>,
    pub(crate) place: Place,
    /// 5th, 50th and 99th percentile luminance of its screenshot: the grains
    /// an attractor on it can draw from.
    pub(crate) levels: [f32; 3],
}

fn luma(r: f32, g: f32, b: f32) -> f32 {
    0.299 * r + 0.587 * g + 0.114 * b
}

/// Luminance percentiles of a BGRA screenshot (sampled: every 7th pixel).
pub(crate) fn levels(bgra: &[u8]) -> [f32; 3] {
    let mut hist = [0u32; 256];
    for px in bgra.as_chunks::<4>().0.iter().step_by(7) {
        let l = luma(f32::from(px[2]), f32::from(px[1]), f32::from(px[0]));
        hist[l.round().clamp(0.0, 255.0) as usize] += 1;
    }
    let total: u32 = hist.iter().sum();
    let at = |q: f32| {
        let mut acc = 0;
        for (i, n) in hist.iter().enumerate() {
            acc += n;
            if acc as f32 >= q * total as f32 {
                return i as f32;
            }
        }
        255.0
    };
    [at(0.05), at(0.5), at(0.99)]
}

/// Stretches the image's own luminance range onto the desktop's, keeping hue,
/// so its light parts recruit lighter grains than its dark parts: the shading
/// survives even where its colours don't exist on screen. The range used is
/// the half of the desktop's away from its median, so no part of the image
/// sinks into the typical background (a bright logo on a dark desktop maps
/// onto the bright half, a dark one onto the dark half).
fn tone_map(rgba: &mut [u8], levels: [f32; 3]) {
    let lumas: Vec<f32> = rgba
        .as_chunks::<4>()
        .0
        .iter()
        .filter(|p| p[3] >= 128)
        .map(|p| luma(f32::from(p[0]), f32::from(p[1]), f32::from(p[2])))
        .collect();
    if lumas.is_empty() {
        return;
    }
    let lo = lumas.iter().copied().fold(f32::MAX, f32::min);
    let hi = lumas.iter().copied().fold(f32::MIN, f32::max);
    let mean = lumas.iter().sum::<f32>() / lumas.len() as f32;
    let [dark, median, bright] = levels;
    // Keep a margin from the median: the storm's typical grain.
    let range = if mean >= median {
        [median + 0.35 * (bright - median), bright]
    } else {
        [median - 0.35 * (median - dark), dark]
    };
    for p in rgba.as_chunks_mut::<4>().0.iter_mut() {
        let l = luma(f32::from(p[0]), f32::from(p[1]), f32::from(p[2]));
        let t = if hi > lo { (l - lo) / (hi - lo) } else { 0.5 };
        let target = range[0] + t * (range[1] - range[0]);
        for c in &mut p[..3] {
            *c = if l > 0.5 {
                (f32::from(*c) * target / l).round().clamp(0.0, 255.0) as u8
            } else {
                target.round() as u8
            };
        }
    }
}

/// The output an attractor sits on: `primary` unless it names one.
fn screen_for<'a>(a: &config::Attractor, screens: &'a [Screen], primary: usize) -> anyhow::Result<&'a Screen> {
    match &a.output {
        None => Ok(&screens[primary]),
        Some(name) => screens
            .iter()
            .find(|s| s.name.as_deref() == Some(name))
            .with_context(|| format!("no output named {name:?}")),
    }
}

/// Size on screen of something `w`x`h` px at scale 1 (`width` overrides the
/// scale), kept inside the output.
fn fit(a: &config::Attractor, w: u32, h: u32, place: Place) -> anyhow::Result<[u32; 2]> {
    let scale = a.width.map_or(a.scale, |width| width / w as f32);
    anyhow::ensure!(
        scale.is_finite() && scale > 0.0,
        "attractor size must be > 0"
    );
    Ok([
        ((w as f32 * scale).round() as u32).clamp(1, place.size[0]),
        ((h as f32 * scale).round() as u32).clamp(1, place.size[1]),
    ])
}

/// Top-left corner that centres `size` at `position` (fractions of the
/// output), kept inside it.
fn origin(a: &config::Attractor, size: [u32; 2], place: Place) -> [u32; 2] {
    let [nw, nh] = size;
    let cx = place.origin[0] as f32 + a.position[0] * place.size[0] as f32;
    let cy = place.origin[1] as f32 + a.position[1] * place.size[1] as f32;
    let x = (cx - nw as f32 / 2.0).round().clamp(
        place.origin[0] as f32,
        (place.origin[0] + place.size[0] - nw) as f32,
    );
    let y = (cy - nh as f32 / 2.0).round().clamp(
        place.origin[1] as f32,
        (place.origin[1] + place.size[1] - nh) as f32,
    );
    [x as u32, y as u32]
}

/// Turns straight-alpha pixels into target pixels: tone-mapped colour, and
/// alpha becomes firmness (opaque-enough pixels are targets).
fn finish(a: &config::Attractor, mut pixels: Vec<u8>, levels: [f32; 3]) -> Vec<u8> {
    if a.tone == config::Tone::Relative {
        tone_map(&mut pixels, levels);
    }
    let firmness = (a.firmness.clamp(0.0, 1.0) * 254.0).round() as u8 + 1;
    pixels
        .as_chunks::<4>().0.iter()
        .flat_map(|p| [p[0], p[1], p[2], if p[3] >= 128 { firmness } else { 0 }])
        .collect()
}

/// Loads every configured attractor onto the simulation, and the password
/// dots; returns the live ones, which the caller updates every frame. A
/// broken attractor is logged and skipped, never fatal.
pub(crate) fn install(
    attractors: &[config::Attractor],
    screens: &[Screen],
    primary: usize,
    dots: Dots,
    gpu: &crate::gpu::Gpu,
    sim: &mut crate::gpu::Sim,
) -> Vec<Live> {
    let mut targets = Vec::new();
    let mut live = Vec::new();
    for a in attractors {
        match load(a, screens, primary) {
            Ok(Loaded::Still(t)) => targets.push((t, a.emerge, a.reach)),
            Ok(Loaded::Live(mut widget)) => match widget.update(&[]) {
                Some(t) => {
                    targets.push((t, a.emerge, a.reach));
                    live.push(widget);
                }
                None => log::error!("{}: nothing to show", a.describe()),
            },
            Err(e) => log::error!("attractor {}: {e:#}", a.describe()),
        }
    }
    // Last, so the dots win wherever they overlap an attractor.
    let mut dots = Live::Dots(dots);
    if let Some(t) = dots.update(&[]) {
        targets.push((t, DOTS.emerge, DOTS.reach * screens[primary].place.size[1] as f32 / 1440.0));
        live.push(dots);
    }
    sim.set_targets(gpu, &targets);
    live
}

/// A loaded attractor: a still image, or a live one that re-renders when
/// what it shows changes.
pub(crate) enum Loaded {
    Still(Target),
    Live(Live),
}

/// An attractor that changes: its rectangle stays, its pixels are
/// re-rendered, and only the pixels that change release or recruit grains.
pub(crate) enum Live {
    Clock(Clock),
    Life(Life),
    Dots(Dots),
}

impl Live {
    /// The new target if what it shows has changed since the last call
    /// (always on the first). `dots` are the password dots (x, y, size
    /// 0..1) in canvas px.
    pub(crate) fn update(&mut self, dots: &[[f32; 3]]) -> Option<Target> {
        match self {
            Live::Clock(c) => c.update(),
            Live::Life(l) => l.update(),
            Live::Dots(d) => d.update(dots),
        }
    }
}

/// A widget's single colour as a target pixel: tone-mapped like an image
/// (`finish`), with the attractor's firmness. Widgets paint with it directly
/// rather than tone-mapping every frame.
fn ink(a: &config::Attractor, levels: [f32; 3]) -> [u8; 4] {
    let [r, g, b] = a.color.map_or([255; 3], |c| c.0);
    let px = finish(a, vec![r, g, b, 255], levels);
    [px[0], px[1], px[2], px[3]]
}

/// Loads an attractor and places it on its output.
pub(crate) fn load(a: &config::Attractor, screens: &[Screen], primary: usize) -> anyhow::Result<Loaded> {
    let screen = screen_for(a, screens, primary)?;
    match (&a.image, a.clock, a.life) {
        (Some(image), None, None) => load_image(a, image, screen).map(Loaded::Still),
        (None, Some(spec), None) => Clock::new(a, spec, screen).map(|c| Loaded::Live(Live::Clock(c))),
        (None, None, Some(spec)) => Life::new(a, spec, screen).map(|l| Loaded::Live(Live::Life(l))),
        _ => bail!("an attractor needs exactly one of `image`, `clock` and `life`"),
    }
}

fn load_image(a: &config::Attractor, image: &std::path::Path, screen: &Screen) -> anyhow::Result<Target> {
    let (w, h, rgba) = decode(image)?;
    anyhow::ensure!(w > 0 && h > 0, "{}: empty image", image.display());
    let place = screen.place;
    let [nw, nh] = fit(a, w, h, place)?;
    let pixels = if (nw, nh) == (w, h) {
        rgba
    } else {
        resize(w, h, &rgba, nw, nh)
    };
    Ok(Target {
        origin: origin(a, [nw, nh], place),
        size: [nw, nh],
        rgba: finish(a, pixels, screen.levels),
    })
}

// ---- clock ------------------------------------------------------------------

/// Height of the clock at scale 1, in screen px.
const CLOCK_HEIGHT: f32 = 100.0;
/// Glyph metrics as fractions of the height: a digit's width, the stroke,
/// the gap between neighbouring segments, and the spacing between glyphs.
const DIGIT_W: f32 = 0.52;
const COLON_W: f32 = 0.16;
const STROKE: f32 = 0.11;
const SEGMENT_GAP: f32 = 0.035;
const SPACING: f32 = 0.14;

/// Segments a..g of each digit (bit 0 = a, the top; clockwise; g = middle).
const DIGITS: [u8; 10] = [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f];

unsafe extern "C" {
    fn localtime_r(time: *const i64, tm: *mut Tm) -> *mut Tm;
    fn tzset();
}

/// glibc's `struct tm`.
#[repr(C)]
struct Tm {
    sec: i32,
    min: i32,
    hour: i32,
    mday: i32,
    mon: i32,
    year: i32,
    wday: i32,
    yday: i32,
    isdst: i32,
    gmtoff: i64,
    zone: *const std::ffi::c_char,
}

/// Local (hour, minute, second) now; None if the clock or zone is broken.
fn local_time() -> Option<(u32, u32, u32)> {
    let secs = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).ok()?.as_secs() as i64;
    // SAFETY: an all-zero `tm` is valid (null zone pointer, never read).
    let mut tm: Tm = unsafe { std::mem::zeroed() };
    // SAFETY: both pointers are valid for the call.
    if unsafe { localtime_r(&secs, &mut tm) }.is_null() {
        return None;
    }
    Some((tm.hour as u32, tm.min as u32, tm.sec as u32))
}

/// The text a clock shows: "HH:MM" or "HH:MM:SS", with a space instead of a
/// leading zero on 12-hour clocks (so the width never changes).
fn clock_text(spec: config::Clock, (hour, min, sec): (u32, u32, u32)) -> String {
    let hours = if spec.twelve_hour {
        format!("{:>2}", (hour + 11) % 12 + 1)
    } else {
        format!("{hour:02}")
    };
    if spec.seconds {
        format!("{hours}:{min:02}:{sec:02}")
    } else {
        format!("{hours}:{min:02}")
    }
}

/// Width of `text` at height 1.
fn text_width(text: &str) -> f32 {
    let glyphs: f32 = text.chars().map(|c| if c == ':' { COLON_W } else { DIGIT_W }).sum();
    glyphs + SPACING * (text.chars().count().saturating_sub(1)) as f32
}

/// Distance from `p` to the segment `a`-`b`.
fn to_segment(p: [f32; 2], a: [f32; 2], b: [f32; 2]) -> f32 {
    let (ab, ap) = ([b[0] - a[0], b[1] - a[1]], [p[0] - a[0], p[1] - a[1]]);
    let len2 = ab[0] * ab[0] + ab[1] * ab[1];
    let t = if len2 > 0.0 { ((ap[0] * ab[0] + ap[1] * ab[1]) / len2).clamp(0.0, 1.0) } else { 0.0 };
    let d = [ap[0] - t * ab[0], ap[1] - t * ab[1]];
    (d[0] * d[0] + d[1] * d[1]).sqrt()
}

/// Whether `p` (in height units, relative to the glyph's top-left) is inked.
fn glyph_covers(c: char, p: [f32; 2]) -> bool {
    let r = STROKE / 2.0;
    if c == ':' {
        let x = COLON_W / 2.0;
        return [0.3, 0.7].iter().any(|&y| to_segment(p, [x, y], [x, y]) <= r * 1.15);
    }
    let Some(mask) = c.to_digit(10).map(|d| DIGITS[d as usize]) else {
        return false; // a space
    };
    let (x0, x1, y0, ym, y1) = (r, DIGIT_W - r, r, 0.5, 1.0 - r);
    let segments = [
        ([x0, y0], [x1, y0]), // a
        ([x1, y0], [x1, ym]), // b
        ([x1, ym], [x1, y1]), // c
        ([x0, y1], [x1, y1]), // d
        ([x0, ym], [x0, y1]), // e
        ([x0, y0], [x0, ym]), // f
        ([x0, ym], [x1, ym]), // g
    ];
    segments.iter().enumerate().any(|(i, &(a, b))| {
        if mask & (1 << i) == 0 {
            return false;
        }
        // Shorten each segment so neighbours stay apart.
        let len = to_segment(b, a, a);
        let g = (r + SEGMENT_GAP).min(len / 2.0) / len;
        let a2 = [a[0] + (b[0] - a[0]) * g, a[1] + (b[1] - a[1]) * g];
        let b2 = [b[0] - (b[0] - a[0]) * g, b[1] - (b[1] - a[1]) * g];
        to_segment(p, a2, b2) <= r
    })
}

/// Renders `text` into a `size` rectangle as straight-alpha RGBA in `ink`.
fn render_text(text: &str, size: [u32; 2], ink: [u8; 3]) -> Vec<u8> {
    let [w, h] = size;
    let unit = h as f32;
    // Centred horizontally if the box is wider than the text.
    let pad = ((w as f32 / unit - text_width(text)) / 2.0).max(0.0);
    let mut starts = Vec::new();
    let mut x = pad;
    for c in text.chars() {
        starts.push((c, x));
        x += if c == ':' { COLON_W } else { DIGIT_W } + SPACING;
    }
    let mut out = vec![0u8; (w * h * 4) as usize];
    for py in 0..h {
        let y = (py as f32 + 0.5) / unit;
        for px in 0..w {
            let x = (px as f32 + 0.5) / unit;
            let inked = starts.iter().any(|&(c, start)| glyph_covers(c, [x - start, y]));
            if inked {
                let o = ((py * w + px) * 4) as usize;
                out[o..o + 4].copy_from_slice(&[ink[0], ink[1], ink[2], 255]);
            }
        }
    }
    out
}

/// A clock attractor. Its rectangle is fixed; `update` re-renders it when the
/// shown time changes, and only the segments that change move grains.
pub(crate) struct Clock {
    attractor: config::Attractor,
    spec: config::Clock,
    origin: [u32; 2],
    size: [u32; 2],
    levels: [f32; 3],
    shown: Option<String>,
}

impl Clock {
    fn new(a: &config::Attractor, spec: config::Clock, screen: &Screen) -> anyhow::Result<Self> {
        // SAFETY: reads TZ and /etc/localtime once, before any thread runs
        // localtime_r (the PAM thread is only spawned later).
        unsafe { tzset() };
        let widest = clock_text(spec, (0, 0, 0));
        let [w, h] = [text_width(&widest) * CLOCK_HEIGHT, CLOCK_HEIGHT];
        let size = fit(a, w.ceil() as u32, h as u32, screen.place)?;
        Ok(Self {
            attractor: a.clone(),
            spec,
            origin: origin(a, size, screen.place),
            size,
            levels: screen.levels,
            shown: None,
        })
    }

    /// The clock's target if the time it shows has changed since the last
    /// call (always on the first).
    pub(crate) fn update(&mut self) -> Option<Target> {
        let text = clock_text(self.spec, local_time()?);
        if self.shown.as_deref() == Some(text.as_str()) {
            return None;
        }
        let ink = self.attractor.color.map_or([255; 3], |c| c.0);
        let rgba = finish(&self.attractor, render_text(&text, self.size, ink), self.levels);
        self.shown = Some(text);
        Some(Target { origin: self.origin, size: self.size, rgba })
    }
}

// ---- Game of Life ----------------------------------------------------------------

/// Tiny xorshift RNG for seeding boards.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> f32 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        (self.0 >> 40) as f32 / (1u64 << 24) as f32
    }
}

/// How many recent generations a new one is compared against: a game that
/// repeats within this many steps (or freezes) is over.
const LIFE_MEMORY: usize = 12;

/// Conway's Game of Life on a board that wraps around at the edges.
pub(crate) struct Life {
    spec: config::Life,
    origin: [u32; 2],
    size: [u32; 2],
    /// Cells across and down, their size in px, and the board's offset
    /// within the rectangle (centred).
    cells: [usize; 2],
    cell: u32,
    margin: [u32; 2],
    alive: Vec<bool>,
    /// Hashes of the last generations, to spot a finished game.
    seen: std::collections::VecDeque<u64>,
    rng: Rng,
    ink: [u8; 4],
    start: std::time::Instant,
    /// Generations shown so far (None = not drawn yet).
    shown: Option<u64>,
    /// The rendered target, reused between generations.
    rgba: Vec<u8>,
}

impl Life {
    fn new(a: &config::Attractor, spec: config::Life, screen: &Screen) -> anyhow::Result<Self> {
        let place = screen.place;
        // At scale 1 the board is its output.
        let size = fit(a, place.size[0], place.size[1], place)?;
        let cell = ((spec.cell * place.size[1] as f32 / 1440.0).round() as u32).max(4);
        let cells = [(size[0] / cell).max(3) as usize, (size[1] / cell).max(3) as usize];
        let margin = [0, 1].map(|k| size[k].saturating_sub(cells[k] as u32 * cell) / 2);
        let seed = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(1, |d| d.as_nanos() as u64)
            | 1;
        let mut life = Self {
            spec,
            origin: origin(a, size, place),
            size,
            cells,
            cell,
            margin,
            alive: vec![false; cells[0] * cells[1]],
            seen: Default::default(),
            rng: Rng(seed),
            ink: ink(a, screen.levels),
            start: std::time::Instant::now(),
            shown: None,
            rgba: Vec::new(),
        };
        life.seed();
        Ok(life)
    }

    /// A new random game.
    fn seed(&mut self) {
        let fill = self.spec.fill;
        for c in &mut self.alive {
            *c = self.rng.next() < fill;
        }
        self.seen.clear();
    }

    fn hash(&self) -> u64 {
        self.alive.iter().fold(0xcbf2_9ce4_8422_2325u64, |h, &c| (h ^ u64::from(c)).wrapping_mul(0x0100_0000_01b3))
    }

    /// One generation (B3/S23), or a new game if this one is over.
    fn step(&mut self) {
        let [w, h] = self.cells;
        let at = |x: usize, y: usize| self.alive[y * w + x];
        let next: Vec<bool> = (0..w * h)
            .map(|i| {
                let (x, y) = (i % w, i / w);
                let mut n = 0;
                for dy in [h - 1, 0, 1] {
                    for dx in [w - 1, 0, 1] {
                        if (dx, dy) != (0, 0) && at((x + dx) % w, (y + dy) % h) {
                            n += 1;
                        }
                    }
                }
                n == 3 || (n == 2 && at(x, y))
            })
            .collect();
        self.alive = next;
        let hash = self.hash();
        let over = !self.alive.contains(&true) || self.seen.contains(&hash);
        self.seen.push_back(hash);
        if self.seen.len() > LIFE_MEMORY {
            self.seen.pop_front();
        }
        if over {
            self.seed();
        }
    }

    /// Paints the board: every live cell a solid square with a gap around it.
    fn render(&mut self) -> Vec<u8> {
        let [w, h] = self.size;
        self.rgba.clear();
        self.rgba.resize((w * h * 4) as usize, 0);
        let gap = (self.cell as f32 * 0.12).round().max(2.0) as u32;
        let live: Vec<usize> = (0..self.alive.len()).filter(|&i| self.alive[i]).collect();
        for i in live {
            let (cx, cy) = ((i % self.cells[0]) as u32, (i / self.cells[0]) as u32);
            let x0 = self.margin[0] + cx * self.cell + gap / 2;
            let y0 = self.margin[1] + cy * self.cell + gap / 2;
            for y in y0..(y0 + self.cell - gap).min(h) {
                let row = ((y * w + x0) * 4) as usize;
                let len = (self.cell - gap).min(w - x0) as usize;
                for px in self.rgba[row..row + len * 4].as_chunks_mut::<4>().0 {
                    *px = self.ink;
                }
            }
        }
        self.rgba.clone()
    }

    fn update(&mut self) -> Option<Target> {
        let generation = (self.start.elapsed().as_secs_f32() / self.spec.period) as u64;
        if self.shown == Some(generation) {
            return None;
        }
        // Catch up without redrawing each step (e.g. after the outputs slept).
        for _ in self.shown.unwrap_or(generation)..generation {
            self.step();
        }
        self.shown = Some(generation);
        Some(Target { origin: self.origin, size: self.size, rgba: self.render() })
    }
}

// ---- password dots ---------------------------------------------------------------

/// The password dots' attractor settings: firm, quick to form (typing wants
/// an answer), and reaching far for light grains on a dark desktop.
const DOTS: DotsTuning = DotsTuning { firmness: 1.0, emerge: 0.25, reach: 260.0 };

struct DotsTuning {
    firmness: f32,
    emerge: f32,
    reach: f32,
}

/// The password dots as an attractor: each dot a disc of sand, sized by
/// its pop-in and pulse, and blown apart with every other attractor by a
/// wrong password's eruption.
pub(crate) struct Dots {
    origin: [u32; 2],
    size: [u32; 2],
    radius: f32,
    ink: [u8; 4],
    /// What was last drawn: (x, y, radius) rounded to half pixels.
    shown: Option<Vec<[i32; 3]>>,
}

impl Dots {
    /// `row` is the dots' centre line (canvas px), `width` as wide as the
    /// row may get, `radius` a full-size dot's; `levels` the primary
    /// output's (see `Screen`).
    pub(crate) fn new(row: [f32; 2], width: f32, radius: f32, canvas: [u32; 2], levels: [f32; 3]) -> Self {
        let a = config::Attractor {
            firmness: DOTS.firmness,
            ..config::Attractor::widget()
        };
        let half = [width / 2.0 + 2.0 * radius, 2.0 * radius];
        let x0 = (row[0] - half[0]).clamp(0.0, canvas[0] as f32) as u32;
        let y0 = (row[1] - half[1]).clamp(0.0, canvas[1] as f32) as u32;
        let x1 = ((row[0] + half[0]).ceil() as u32).min(canvas[0]).max(x0 + 1);
        let y1 = ((row[1] + half[1]).ceil() as u32).min(canvas[1]).max(y0 + 1);
        Self { origin: [x0, y0], size: [x1 - x0, y1 - y0], radius, ink: ink(&a, levels), shown: None }
    }

    fn update(&mut self, dots: &[[f32; 3]]) -> Option<Target> {
        let key: Vec<[i32; 3]> = dots
            .iter()
            .map(|d| [d[0], d[1], d[2] * self.radius].map(|v| (v * 2.0).round() as i32))
            .collect();
        if self.shown.as_ref() == Some(&key) {
            return None;
        }
        let [w, h] = self.size;
        let mut rgba = vec![0u8; (w * h * 4) as usize];
        for d in dots {
            let r = d[2].clamp(0.0, 1.0) * self.radius;
            if r < 0.5 {
                continue;
            }
            let (cx, cy) = (d[0] - self.origin[0] as f32, d[1] - self.origin[1] as f32);
            let ys = (cy - r).floor().max(0.0) as u32..((cy + r).ceil().max(0.0) as u32).min(h);
            for y in ys {
                for x in (cx - r).floor().max(0.0) as u32..((cx + r).ceil().max(0.0) as u32).min(w) {
                    let (dx, dy) = (x as f32 + 0.5 - cx, y as f32 + 0.5 - cy);
                    if dx * dx + dy * dy <= r * r {
                        let o = ((y * w + x) * 4) as usize;
                        rgba[o..o + 4].copy_from_slice(&self.ink);
                    }
                }
            }
        }
        self.shown = Some(key);
        Some(Target { origin: self.origin, size: self.size, rgba })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn life(cells: [usize; 2], alive: &[(usize, usize)]) -> Life {
        let mut l = Life {
            spec: config::Life::default(),
            origin: [0, 0],
            size: [cells[0] as u32 * 10, cells[1] as u32 * 10],
            cells,
            cell: 10,
            margin: [0, 0],
            alive: vec![false; cells[0] * cells[1]],
            seen: Default::default(),
            rng: Rng(7),
            ink: [255; 4],
            start: std::time::Instant::now(),
            shown: None,
            rgba: Vec::new(),
        };
        for &(x, y) in alive {
            l.alive[y * cells[0] + x] = true;
        }
        l
    }

    fn alive(l: &Life) -> Vec<(usize, usize)> {
        (0..l.alive.len()).filter(|&i| l.alive[i]).map(|i| (i % l.cells[0], i / l.cells[0])).collect()
    }

    #[test]
    fn life_blinker_oscillates() {
        let mut l = life([5, 5], &[(1, 2), (2, 2), (3, 2)]);
        l.step();
        assert_eq!(alive(&l), [(2, 1), (2, 2), (2, 3)]);
        l.step();
        assert_eq!(alive(&l), [(1, 2), (2, 2), (3, 2)]);
    }

    #[test]
    fn life_glider_travels_and_wraps() {
        // A glider moves one cell diagonally every 4 generations; on an 8x8
        // board that wraps, it is back where it started after 32. It never
        // repeats within LIFE_MEMORY generations, so it is never reseeded.
        let start = [(1, 0), (2, 1), (0, 2), (1, 2), (2, 2)];
        let mut l = life([8, 8], &start);
        for _ in 0..4 {
            l.step();
        }
        assert_eq!(alive(&l), [(2, 1), (3, 2), (1, 3), (2, 3), (3, 3)]);
        for _ in 4..32 {
            l.step();
        }
        let mut sorted = start.to_vec();
        sorted.sort_by_key(|&(x, y)| (y, x));
        assert_eq!(alive(&l), sorted);
    }

    #[test]
    fn life_reseeds_when_over() {
        // A lone cell dies: a new game starts at once.
        let mut l = life([20, 20], &[(5, 5)]);
        l.step();
        assert!(alive(&l).len() > 40, "{} alive", alive(&l).len());
    }

    #[test]
    fn life_paints_cells_with_gaps() {
        let mut l = life([3, 1], &[(1, 0)]);
        let px = l.render();
        let at = |x: u32, y: u32| px[((y * 30 + x) * 4) as usize];
        assert_eq!(at(15, 5), 255, "inside the cell");
        assert_eq!(at(5, 5), 0, "a dead cell");
        assert_eq!(at(10, 5), 0, "the gap");
    }

    #[test]
    fn dots_grow_and_go() {
        let mut d = Dots { origin: [0, 0], size: [100, 40], radius: 8.0, ink: [255; 4], shown: None };
        let ink = |t: &Target| t.rgba.chunks(4).filter(|p| p[3] != 0).count();
        let full = ink(&d.update(&[[50.0, 20.0, 1.0]]).unwrap());
        assert!((180..=220).contains(&full), "{full}");
        assert!(d.update(&[[50.0, 20.0, 1.0]]).is_none(), "unchanged");
        let half = ink(&d.update(&[[50.0, 20.0, 0.5]]).unwrap());
        assert!(half * 3 < full && half > 0);
        assert_eq!(ink(&d.update(&[]).unwrap()), 0);
    }

    fn clock(seconds: bool, twelve_hour: bool) -> config::Clock {
        config::Clock { seconds, twelve_hour }
    }

    #[test]
    fn clock_text_formats() {
        assert_eq!(clock_text(clock(false, false), (9, 5, 7)), "09:05");
        assert_eq!(clock_text(clock(true, false), (23, 59, 1)), "23:59:01");
        assert_eq!(clock_text(clock(false, true), (0, 0, 0)), "12:00");
        assert_eq!(clock_text(clock(false, true), (13, 4, 0)), " 1:04");
        assert_eq!(clock_text(clock(false, true), (12, 30, 0)), "12:30");
    }

    fn ink(text: &str) -> usize {
        let size = [(text_width(text) * 100.0).ceil() as u32, 100];
        render_text(text, size, [255; 3]).as_chunks::<4>().0.iter().filter(|p| p[3] == 255).count()
    }

    #[test]
    fn digits_use_their_segments() {
        // 8 lights all seven segments, 1 only two; a space nothing.
        assert!(ink("8") > 3 * ink("1"));
        assert!(ink("1") > 0);
        assert_eq!(ink(" "), 0);
        // Every digit renders and 8 is the most ink.
        for d in '0'..='9' {
            assert!(ink(&d.to_string()) > 0 && ink(&d.to_string()) <= ink("8"), "{d}");
        }
    }

    #[test]
    fn segments_stay_apart() {
        // The gap between segments leaves the corners of an 8 empty.
        let size = [(DIGIT_W * 100.0).ceil() as u32, 100];
        let px = render_text("8", size, [255; 3]);
        let at = |x: u32, y: u32| px[((y * size[0] + x) * 4 + 3) as usize];
        assert_eq!(at(size[0] / 2, 5), 255, "top segment");
        assert_eq!(at(5, 5), 0, "top-left corner");
        assert_eq!(at(5, 50), 0, "middle-left joint");
    }
}

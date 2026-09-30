//! Attractors: images whose opaque pixels pull in the most similar grains, so
//! the image emerges from the storm out of the desktop's own pixels.
//!
//! Every attractor renders into a `Target`: a rectangle of the canvas-wide
//! target image (RGB = the colour a pixel wants, A = its firmness, 0 = none).
//! A PNG renders once; a live source such as a clock would re-render its
//! rectangle when it changes, and only the pixels that change lose or gain
//! grains.

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
fn decode(path: &std::path::Path) -> anyhow::Result<(u32, u32, Vec<u8>)> {
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

/// Loads an image attractor and places it on its output (`primary` unless it
/// names one).
pub(crate) fn load(a: &config::Attractor, screens: &[Screen], primary: usize) -> anyhow::Result<Target> {
    let (w, h, rgba) = decode(&a.image)?;
    anyhow::ensure!(w > 0 && h > 0, "{}: empty image", a.image.display());
    let screen = match &a.output {
        None => &screens[primary],
        Some(name) => screens
            .iter()
            .find(|s| s.name.as_deref() == Some(name))
            .with_context(|| format!("no output named {name:?}"))?,
    };
    let place = screen.place;
    let scale = a.width.map_or(a.scale, |width| width / w as f32);
    anyhow::ensure!(
        scale.is_finite() && scale > 0.0,
        "attractor size must be > 0"
    );
    let nw = ((w as f32 * scale).round() as u32).clamp(1, place.size[0]);
    let nh = ((h as f32 * scale).round() as u32).clamp(1, place.size[1]);
    let pixels = if (nw, nh) == (w, h) {
        rgba
    } else {
        resize(w, h, &rgba, nw, nh)
    };

    // Centre at `position` (fractions of the output), kept inside it.
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

    let mut pixels = pixels;
    if a.tone == config::Tone::Relative {
        tone_map(&mut pixels, screen.levels);
    }

    // Alpha becomes firmness: opaque-enough pixels are targets.
    let firmness = (a.firmness.clamp(0.0, 1.0) * 254.0).round() as u8 + 1;
    let rgba = pixels
        .as_chunks::<4>().0.iter()
        .flat_map(|p| [p[0], p[1], p[2], if p[3] >= 128 { firmness } else { 0 }])
        .collect();
    Ok(Target {
        origin: [x as u32, y as u32],
        size: [nw, nh],
        rgba,
    })
}

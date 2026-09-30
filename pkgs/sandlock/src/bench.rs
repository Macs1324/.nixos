//! `sandlock --bench a.png,b.png`: runs the storm headless (no Wayland, no
//! lock) on outputs laid out left to right with those images as their
//! screenshots, rendering offscreen, and reports:
//!
//! - GPU cost: ms per frame (simulation step + rasterize + compose of every
//!   output), run as fast as possible;
//! - how the picture holds up over time: holes, grains near home, and local
//!   colour roughness against the original (soup is rough speckle);
//! - real power: GPU watts, busy % and fan speed at a paced 60 fps, against an
//!   idle baseline (amdgpu sysfs; skipped where it is missing).

use std::path::PathBuf;
use std::time::{Duration, Instant};

use anyhow::Context;

use crate::attract;
use crate::capture::Image;
use crate::config::Config;
use crate::gpu::{Compose, Gpu, Place, Sim};
use crate::storm::{Storm, HOMING_DONE};

const DT: f32 = 1.0 / 60.0;
/// Sim times (s) at which the picture is measured.
const CHECKPOINTS: [f32; 6] = [2.0, 5.0, 10.0, 20.0, 40.0, 60.0];
/// A grain within this many px of its home counts as "home".
const NEAR: i64 = 8;

pub(crate) struct Options {
    pub(crate) images: Vec<PathBuf>,
    /// Simulated seconds of the unpaced run.
    pub(crate) secs: f32,
    /// Real seconds of the paced 60 fps power run (0 = skip).
    pub(crate) paced: f32,
}

impl Default for Options {
    fn default() -> Self {
        Self { images: Vec::new(), secs: 60.0, paced: 20.0 }
    }
}

struct Scene {
    gpu: Gpu,
    sim: Sim,
    storm: Storm,
    live: Vec<attract::Live>,
    outputs: Vec<(Compose, wgpu::Texture, wgpu::TextureView)>,
}

impl Scene {
    /// One displayed frame: a simulation step, then every output drawn.
    fn frame(&mut self) {
        let splats = self.storm.step(DT, &mut self.sim.params);
        self.sim.step(&self.gpu, DT, &splats);
        let dots = self.storm.dots();
        for widget in &mut self.live {
            if let Some(t) = widget.update(&dots) {
                self.sim.update_target(&self.gpu, &t);
            }
        }
        self.sim.rasterize(&self.gpu);
        for (compose, _, target) in &self.outputs {
            compose.draw(&self.gpu, &self.sim, target, 1.0);
        }
    }

    /// `frame`, waiting for the GPU after each phase: how long the
    /// simulation step, the rasterize (scatter + pack) and the compose of
    /// every output take.
    fn frame_phases(&mut self) -> anyhow::Result<[Duration; 3]> {
        let t0 = Instant::now();
        let splats = self.storm.step(DT, &mut self.sim.params);
        self.sim.step(&self.gpu, DT, &splats);
        self.wait()?;
        let t1 = Instant::now();
        self.sim.rasterize(&self.gpu);
        self.wait()?;
        let t2 = Instant::now();
        for (compose, _, target) in &self.outputs {
            compose.draw(&self.gpu, &self.sim, target, 1.0);
        }
        self.wait()?;
        Ok([t1 - t0, t2 - t1, t2.elapsed()])
    }

    fn wait(&self) -> anyhow::Result<()> {
        self.gpu.device.poll(wgpu::PollType::wait_indefinitely())?;
        Ok(())
    }
}

pub(crate) fn run(config: &Config, opts: &Options) -> anyhow::Result<()> {
    // Outputs side by side, top-aligned, like a typical dual-monitor desk.
    let mut images = Vec::new();
    let mut places = Vec::new();
    let mut x = 0;
    for path in &opts.images {
        let (w, h, rgba) = attract::decode(path)?;
        let bgra = rgba.as_chunks::<4>().0.iter().flat_map(|p| [p[2], p[1], p[0], 255]).collect();
        places.push(Place { origin: [x, 0], size: [w, h] });
        images.push(Image { width: w, height: h, bgra });
        x += w;
    }
    let canvas = [x, places.iter().map(|p| p.size[1]).max().context("no images")?];
    println!("canvas {}x{}, outputs {:?}", canvas[0], canvas[1], places.iter().map(|p| p.size).collect::<Vec<_>>());

    // Startup, as the lock pays it before the screen is locked (screenshots
    // aside): `sandlock -f` gives up after 4 s and the fallback locks instead.
    let t0 = Instant::now();
    let gpu = Gpu::new()?;
    let t_gpu = t0.elapsed();
    let shots: Vec<_> = images.iter().map(|i| Some(Image { width: i.width, height: i.height, bgra: i.bgra.clone() })).collect();
    let mut sim = Sim::new(&gpu, canvas, &places, &shots)?;
    drop(shots);
    let primary = (0..places.len())
        .max_by_key(|&i| places[i].size[0] as u64 * places[i].size[1] as u64)
        .unwrap_or(0);
    let screens: Vec<_> = places
        .iter()
        .zip(&images)
        .enumerate()
        .map(|(i, (p, img))| attract::Screen {
            name: Some(format!("BENCH-{}", i + 1)),
            place: *p,
            levels: attract::levels(&img.bgra),
        })
        .collect();
    let t_sim = t0.elapsed() - t_gpu;
    let p = places[primary];
    let storm = Storm::new(
        [canvas[0] as f32, canvas[1] as f32],
        [sim.params.cell_x, sim.params.cell],
        ([p.origin[0] as f32, p.origin[1] as f32], [p.size[0] as f32, p.size[1] as f32]),
        0x9e37_79b9_7f4a_7c15,
        config.storm,
    );
    let (row, width, radius) = storm.dots_row();
    let dots = attract::Dots::new(row, width, radius, canvas, screens[primary].levels);
    let live = attract::install(&config.attractors, &screens, primary, dots, &gpu, &mut sim);
    gpu.device.poll(wgpu::PollType::wait_indefinitely())?;
    println!(
        "startup: GPU {:.0} ms, simulation {:.0} ms, attractors {:.0} ms",
        t_gpu.as_secs_f64() * 1000.0,
        t_sim.as_secs_f64() * 1000.0,
        (t0.elapsed() - t_gpu - t_sim).as_secs_f64() * 1000.0
    );
    let outputs = places
        .iter()
        .map(|&place| {
            let texture = gpu.device.create_texture(&wgpu::TextureDescriptor {
                label: Some("bench output"),
                size: wgpu::Extent3d { width: place.size[0], height: place.size[1], depth_or_array_layers: 1 },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format: wgpu::TextureFormat::Bgra8Unorm,
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::COPY_SRC,
                view_formats: &[],
            });
            let compose = Compose::new(&gpu, &sim, place, wgpu::TextureFormat::Bgra8Unorm, None);
            let view = texture.create_view(&Default::default());
            (compose, texture, view)
        })
        .collect();
    let mut scene = Scene { gpu, sim, storm, live, outputs };
    // SANDLOCK_BENCH_TYPE=<n>: type n characters from 3 s on, one every
    // 0.15 s, to see and time the password dots.
    let typed: u32 = std::env::var("SANDLOCK_BENCH_TYPE").ok().and_then(|n| n.parse().ok()).unwrap_or(0);

    let original = roughness_of_images(&images, &places);
    println!("original roughness {original:.2} (mean |Δluma| between neighbours)");
    println!();
    println!(
        "{:>6}  {:>7}  {:>8}  {:>6}  {:>9}  {:>10}  {:>9}  {:>7}  {:>15}  {:>15}",
        "t (s)", "holes", "at home", "clear", "roughness", "vs orig.", "offscreen", "hidden", "2px edge/inner", "black edge/inner"
    );

    // Unpaced: GPU cost per frame, and the picture at the checkpoints.
    let frames = (opts.secs / DT).round() as usize;
    let mut times = Vec::with_capacity(frames);
    let mut next = CHECKPOINTS.iter().copied().filter(|&t| t <= opts.secs).peekable();
    for f in 1..=frames {
        if f >= 180 && (f - 180) % 9 == 0 && ((f - 180) / 9) < typed as usize {
            scene.storm.typed();
        }
        let start = Instant::now();
        scene.frame();
        scene.wait()?;
        // The first second warms up clocks and caches.
        if f > 60 {
            times.push(start.elapsed());
        }
        if next.peek().is_some_and(|&t| f as f32 * DT >= t - DT / 2.0) {
            let t = next.next().unwrap_or_default();
            let owner = scene.sim.read_owner(&scene.gpu)?;
            let m = measure(&owner, canvas, &images, &places);
            // What is actually on screen, gap filling included.
            let mut shown = vec![f32::NAN; owner.len()];
            for (k, (compose, texture, _)) in scene.outputs.iter().enumerate() {
                let p = compose.place;
                let bgra = read_texture(&scene.gpu, texture, p.size)?;
                if let Some(dir) = std::env::var_os("SANDLOCK_BENCH_DUMP") {
                    dump(&PathBuf::from(dir).join(format!("t{t:02.0}-out{}.png", k + 1)), p.size, &bgra)?;
                }
                for y in 0..p.size[1] {
                    for x in 0..p.size[0] {
                        let o = ((y * p.size[0] + x) * 4) as usize;
                        shown[((p.origin[1] + y) * canvas[0] + p.origin[0] + x) as usize] = luma(&bgra[o..o + 4]);
                    }
                }
            }
            let rough = roughness(&shown, canvas);
            let sp = splats(&scene.sim.read_packed(&scene.gpu)?, canvas, &places);
            println!(
                "{t:>6.0}  {:>6.2}%  {:>7.1}%  {:>5.1}%  {:>9.2}  {:>9.2}x  {:>8.2}%  {:>6.2}%  {:>6.1}%/{:>6.1}%  {:>6.2}%/{:>6.2}%",
                m.holes * 100.0,
                m.home * 100.0,
                m.clear * 100.0,
                rough,
                rough / original.max(1e-6),
                m.offscreen * 100.0,
                m.hidden * 100.0,
                sp.wide[0] * 100.0,
                sp.wide[1] * 100.0,
                sp.black[0] * 100.0,
                sp.black[1] * 100.0
            );
        }
    }
    times.sort();
    if !times.is_empty() {
        let ms = |d: Duration| d.as_secs_f64() * 1000.0;
        let mean = times.iter().map(|&d| ms(d)).sum::<f64>() / times.len() as f64;
        let pct = |q: f64| ms(times[((times.len() - 1) as f64 * q) as usize]);
        println!();
        println!(
            "GPU frame (unpaced, {} frames): mean {mean:.2} ms, p50 {:.2} ms, p95 {:.2} ms = {:.0}% of a 60 fps frame",
            times.len(),
            pct(0.5),
            pct(0.95),
            mean / (1000.0 / 60.0) * 100.0
        );
    }

    // Where the time goes (the waits between phases add a little).
    let mut phases = [Duration::ZERO; 3];
    const SPLIT: u32 = 300;
    for _ in 0..SPLIT {
        for (sum, d) in phases.iter_mut().zip(scene.frame_phases()?) {
            *sum += d;
        }
    }
    let [step, raster, compose] = phases.map(|d| d.as_secs_f64() * 1000.0 / f64::from(SPLIT));
    println!("phases: step {step:.2} ms, rasterize {raster:.2} ms, compose {compose:.2} ms");

    if opts.paced > 0.0 {
        paced(&mut scene, opts.paced)?;
    }
    unlock(&mut scene, &images)
}

/// The correct password: the grains fly home. Saves frames on the way
/// (`SANDLOCK_BENCH_DUMP`) and checks the last frame is the screenshot,
/// exactly, as the handoff to the live desktop needs.
fn unlock(scene: &mut Scene, images: &[Image]) -> anyhow::Result<()> {
    let dir = std::env::var_os("SANDLOCK_BENCH_DUMP").map(PathBuf::from);
    // Every other frame of the primary output with SANDLOCK_BENCH_UNLOCK_ALL
    // (for an animation), else a few stills.
    let all = std::env::var_os("SANDLOCK_BENCH_UNLOCK_ALL").is_some();
    let mut stops = [0.2, 0.45, 0.8, 1.3, 1.9].into_iter().peekable();
    let mut n = 0u32;
    scene.storm.correct();
    while scene.storm.homing_for().is_some_and(|t| t < HOMING_DONE) {
        scene.frame();
        let t = scene.storm.homing_for().unwrap_or(HOMING_DONE);
        n += 1;
        if let Some(dir) = &dir
            && all
        {
            if n.is_multiple_of(2) {
                let (compose, texture, _) = &scene.outputs[0];
                let bgra = read_texture(&scene.gpu, texture, compose.place.size)?;
                dump(&dir.join(format!("frame-{:03}.png", n / 2)), compose.place.size, &bgra)?;
            }
        } else if let Some(dir) = &dir
            && stops.peek().is_some_and(|&s| t >= s)
        {
            stops.next();
            for (k, (compose, texture, _)) in scene.outputs.iter().enumerate() {
                let bgra = read_texture(&scene.gpu, texture, compose.place.size)?;
                dump(&dir.join(format!("unlock-{t:.2}-out{}.png", k + 1)), compose.place.size, &bgra)?;
            }
        }
    }
    scene.wait()?;
    let (mut differ, mut total) = (0u64, 0u64);
    for ((compose, texture, _), img) in scene.outputs.iter().zip(images) {
        let bgra = read_texture(&scene.gpu, texture, compose.place.size)?;
        for (a, b) in bgra.as_chunks::<4>().0.iter().zip(img.bgra.as_chunks::<4>().0) {
            total += 1;
            differ += u64::from(a[..3] != b[..3]);
        }
    }
    println!();
    println!("unlock: after {HOMING_DONE} s, {differ} of {total} pixels differ from the screenshot");
    Ok(())
}

// ---- picture statistics --------------------------------------------------------

struct Measure {
    /// Output pixels no grain landed on (before gap filling).
    holes: f32,
    /// Shown grains within `NEAR` px of home.
    home: f32,
    /// Shown grains on their own home pixel: the desktop exactly as it was.
    clear: f32,
    /// Grains in canvas pixels that belong to no output (invisible).
    offscreen: f32,
    /// Grains on no pixel at all (under another grain).
    hidden: f32,
}

fn luma(bgra: &[u8]) -> f32 {
    0.114 * f32::from(bgra[0]) + 0.587 * f32::from(bgra[1]) + 0.299 * f32::from(bgra[2])
}

/// Home (canvas px) and luma of grain `id`, from the output layout.
fn grain(id: u32, images: &[Image], places: &[Place]) -> Option<([i64; 2], f32)> {
    let mut offset = 0u64;
    for (img, p) in images.iter().zip(places) {
        let n = u64::from(p.size[0]) * u64::from(p.size[1]);
        if u64::from(id) < offset + n {
            let j = u64::from(id) - offset;
            let (x, y) = (j % u64::from(p.size[0]), j / u64::from(p.size[0]));
            let o = ((y * u64::from(img.width) + x) * 4) as usize;
            let home = [i64::from(p.origin[0]) + x as i64, i64::from(p.origin[1]) + y as i64];
            return Some((home, luma(&img.bgra[o..o + 4])));
        }
        offset += n;
    }
    None
}

fn measure(owner: &[u32], canvas: [u32; 2], images: &[Image], places: &[Place]) -> Measure {
    let w = canvas[0] as usize;
    let (mut pixels, mut filled, mut home, mut clear) = (0u64, 0u64, 0u64, 0u64);
    for p in places {
        for y in p.origin[1]..p.origin[1] + p.size[1] {
            for x in p.origin[0]..p.origin[0] + p.size[0] {
                pixels += 1;
                let i = y as usize * w + x as usize;
                let id = owner[i] & 0x7fff_ffff;
                if id == 0 {
                    continue;
                }
                filled += 1;
                // Grains from the offscreen canvas have no screenshot here:
                // on screen, never at home.
                let Some((h, _)) = grain(id - 1, images, places) else { continue };
                let (dx, dy) = (h[0] - i64::from(x), h[1] - i64::from(y));
                home += u64::from(dx * dx + dy * dy <= NEAR * NEAR);
                clear += u64::from(dx == 0 && dy == 0);
            }
        }
    }
    let placed = owner.iter().filter(|&&o| o != 0).count() as u64;
    Measure {
        offscreen: (placed - filled) as f32 / pixels.max(1) as f32,
        hidden: (pixels - placed) as f32 / pixels.max(1) as f32,
        holes: 1.0 - filled as f32 / pixels.max(1) as f32,
        home: home as f32 / filled.max(1) as f32,
        clear: clear as f32 / filled.max(1) as f32,
    }
}

/// Output pixels closer than this to an output edge count as "edge".
const EDGE: u32 = 40;

/// How pixels were splatted (render.wgsl `compose_fs`), each as (near an
/// output edge, interior) shares: no grain within 1 px (a soft 2 px splat),
/// and none within 2 px either (black).
struct Splats {
    wide: [f32; 2],
    black: [f32; 2],
}

fn splat_weight(packed: &[u32], canvas: [u32; 2], x: u32, y: u32, r: i64) -> f32 {
    let (w, h) = (canvas[0] as i64, canvas[1] as i64);
    let mut weight = 0.0f32;
    for dy in -r..=r {
        for dx in -r..=r {
            let (qx, qy) = (i64::from(x) + dx, i64::from(y) + dy);
            if qx < 0 || qy < 0 || qx >= w || qy >= h {
                continue;
            }
            let v = packed[(qy * w + qx) as usize];
            if v == 0 {
                continue;
            }
            let at = [((v >> 4) & 15) as f32 - 1.0, (v & 15) as f32 - 1.0].map(|o| o / 14.0);
            let d = [(dx as f32 + at[0] - 0.5).abs() / r as f32, (dy as f32 + at[1] - 0.5).abs() / r as f32];
            weight += (1.0 - d[0]).max(0.0) * (1.0 - d[1]).max(0.0);
        }
    }
    weight
}

fn splats(packed: &[u32], canvas: [u32; 2], places: &[Place]) -> Splats {
    let (mut n, mut wide, mut black) = ([0u64; 2], [0u64; 2], [0u64; 2]);
    for p in places {
        for y in p.origin[1]..p.origin[1] + p.size[1] {
            for x in p.origin[0]..p.origin[0] + p.size[0] {
                let (lx, ly) = (x - p.origin[0], y - p.origin[1]);
                let edge = lx.min(ly).min(p.size[0] - 1 - lx).min(p.size[1] - 1 - ly) < EDGE;
                let k = usize::from(!edge);
                n[k] += 1;
                if splat_weight(packed, canvas, x, y, 1) <= 1e-4 {
                    wide[k] += 1;
                    black[k] += u64::from(splat_weight(packed, canvas, x, y, 2) <= 1e-4);
                }
            }
        }
    }
    let share = |v: [u64; 2]| [0, 1].map(|k| v[k] as f32 / n[k].max(1) as f32);
    Splats { wide: share(wide), black: share(black) }
}

/// Writes a BGRA8 frame as a PNG (`SANDLOCK_BENCH_DUMP=<dir>`).
fn dump(path: &std::path::Path, size: [u32; 2], bgra: &[u8]) -> anyhow::Result<()> {
    let file = std::fs::File::create(path).with_context(|| format!("creating {}", path.display()))?;
    let mut png = png::Encoder::new(std::io::BufWriter::new(file), size[0], size[1]);
    png.set_color(png::ColorType::Rgb);
    let rgb: Vec<u8> = bgra.as_chunks::<4>().0.iter().flat_map(|p| [p[2], p[1], p[0]]).collect();
    png.write_header()?.write_image_data(&rgb)?;
    Ok(())
}

/// Reads a rendered BGRA8 output back, rows tightly packed.
fn read_texture(gpu: &Gpu, texture: &wgpu::Texture, size: [u32; 2]) -> anyhow::Result<Vec<u8>> {
    let [w, h] = size;
    let row = (w * 4).next_multiple_of(wgpu::COPY_BYTES_PER_ROW_ALIGNMENT);
    let buf = gpu.device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("output readback"),
        size: u64::from(row) * u64::from(h),
        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
        mapped_at_creation: false,
    });
    let mut encoder = gpu.device.create_command_encoder(&Default::default());
    encoder.copy_texture_to_buffer(
        texture.as_image_copy(),
        wgpu::TexelCopyBufferInfo {
            buffer: &buf,
            layout: wgpu::TexelCopyBufferLayout { offset: 0, bytes_per_row: Some(row), rows_per_image: Some(h) },
        },
        wgpu::Extent3d { width: w, height: h, depth_or_array_layers: 1 },
    );
    gpu.queue.submit([encoder.finish()]);
    buf.slice(..).map_async(wgpu::MapMode::Read, |_| {});
    gpu.device.poll(wgpu::PollType::wait_indefinitely())?;
    let data = buf.slice(..).get_mapped_range().map_err(|e| anyhow::anyhow!("mapping output: {e}"))?;
    Ok(data.chunks(row as usize).flat_map(|r| &r[..(w * 4) as usize]).copied().collect())
}

/// Mean |Δ| between right and lower neighbours where both are known.
fn roughness(luma: &[f32], canvas: [u32; 2]) -> f32 {
    let (w, h) = (canvas[0] as usize, canvas[1] as usize);
    let (mut sum, mut n) = (0f64, 0u64);
    for y in 0..h {
        for x in 0..w {
            let a = luma[y * w + x];
            if a.is_nan() {
                continue;
            }
            for (nx, ny) in [(x + 1, y), (x, y + 1)] {
                if nx < w && ny < h {
                    let b = luma[ny * w + nx];
                    if !b.is_nan() {
                        sum += f64::from((a - b).abs());
                        n += 1;
                    }
                }
            }
        }
    }
    (sum / n.max(1) as f64) as f32
}

fn roughness_of_images(images: &[Image], places: &[Place]) -> f32 {
    let canvas = [
        places.iter().map(|p| p.origin[0] + p.size[0]).max().unwrap_or(0),
        places.iter().map(|p| p.origin[1] + p.size[1]).max().unwrap_or(0),
    ];
    let w = canvas[0] as usize;
    let mut shown = vec![f32::NAN; w * canvas[1] as usize];
    for (img, p) in images.iter().zip(places) {
        for y in 0..p.size[1] {
            for x in 0..p.size[0] {
                let o = ((y * img.width + x) * 4) as usize;
                shown[(p.origin[1] + y) as usize * w + (p.origin[0] + x) as usize] = luma(&img.bgra[o..o + 4]);
            }
        }
    }
    roughness(&shown, canvas)
}

// ---- power -------------------------------------------------------------------

/// amdgpu's sysfs files for the first GPU that has them.
struct Sensors {
    power: Option<PathBuf>,
    busy: Option<PathBuf>,
    fan: Option<PathBuf>,
}

impl Sensors {
    fn find() -> Self {
        let mut s = Sensors { power: None, busy: None, fan: None };
        let Ok(cards) = std::fs::read_dir("/sys/class/drm") else { return s };
        for card in cards.flatten() {
            let dev = card.path().join("device");
            if !dev.join("gpu_busy_percent").exists() {
                continue;
            }
            s.busy = Some(dev.join("gpu_busy_percent"));
            if let Ok(hwmons) = std::fs::read_dir(dev.join("hwmon")) {
                for hw in hwmons.flatten() {
                    let hw = hw.path();
                    s.power = ["power1_average", "power1_input"].iter().map(|f| hw.join(f)).find(|p| p.exists());
                    s.fan = Some(hw.join("fan1_input")).filter(|p| p.exists());
                }
            }
            break;
        }
        s
    }

    fn read(path: &Option<PathBuf>) -> Option<f64> {
        std::fs::read_to_string(path.as_ref()?).ok()?.trim().parse().ok()
    }

    /// (watts, busy %, fan rpm)
    fn sample(&self) -> (Option<f64>, Option<f64>, Option<f64>) {
        (Self::read(&self.power).map(|uw| uw / 1e6), Self::read(&self.busy), Self::read(&self.fan))
    }
}

#[derive(Default)]
struct Samples {
    watts: Vec<f64>,
    busy: Vec<f64>,
    fan: Vec<f64>,
}

impl Samples {
    fn add(&mut self, (w, b, f): (Option<f64>, Option<f64>, Option<f64>)) {
        self.watts.extend(w);
        self.busy.extend(b);
        self.fan.extend(f);
    }

    fn report(&self, label: &str) {
        let mean = |v: &[f64]| (!v.is_empty()).then(|| v.iter().sum::<f64>() / v.len() as f64);
        let fmt = |v: Option<f64>, unit: &str| v.map_or("n/a".to_owned(), |v| format!("{v:.1}{unit}"));
        println!(
            "{label:<14} GPU power {:>8}, busy {:>6}, fan {:>9} (last {})",
            fmt(mean(&self.watts), " W"),
            fmt(mean(&self.busy), "%"),
            fmt(mean(&self.fan), " rpm"),
            fmt(self.fan.last().copied(), " rpm"),
        );
    }
}

/// Idle baseline, then the storm at a real 60 fps, sampling the sensors.
fn paced(scene: &mut Scene, secs: f32) -> anyhow::Result<()> {
    let sensors = Sensors::find();
    if sensors.power.is_none() && sensors.busy.is_none() {
        println!("\nno amdgpu sensors found: skipping the power run");
        return Ok(());
    }
    println!();
    let sample_every = Duration::from_millis(250);
    let mut idle = Samples::default();
    let until = Instant::now() + Duration::from_secs_f32(secs / 2.0);
    while Instant::now() < until {
        std::thread::sleep(sample_every);
        idle.add(sensors.sample());
    }
    idle.report("idle");

    let mut running = Samples::default();
    let start = Instant::now();
    let mut next_frame = start;
    let mut next_sample = start + Duration::from_secs(2); // let clocks settle
    while start.elapsed().as_secs_f32() < secs {
        scene.frame();
        scene.wait()?;
        next_frame += Duration::from_secs_f32(DT);
        let now = Instant::now();
        if now >= next_sample {
            running.add(sensors.sample());
            next_sample += sample_every;
        }
        if let Some(left) = next_frame.checked_duration_since(now) {
            std::thread::sleep(left);
        }
    }
    running.report("storm @60 fps");
    Ok(())
}

//! sandlock: a Wayland screen locker. The desktop dissolves into a storm of its
//! own pixels, carried by a fluid simulation; the correct password brings every
//! pixel home and the lock fades into the live desktop.
//!
//! `sandlock` locks the session (ext-session-lock). `sandlock --preview` runs
//! the same storm in a full-screen overlay without locking; Escape quits it.

mod attract;
mod capture;
mod config;
mod daemon;
mod gpu;
mod pam;
mod storm;

use std::ptr::NonNull;
use std::sync::mpsc;
use std::time::{Duration, Instant};

use anyhow::{bail, Context};
use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState, FrameCallbackData},
    output::{OutputHandler, OutputInfo, OutputState},
    reexports::{calloop::EventLoop, calloop_wayland_source::WaylandSource},
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    seat::{
        keyboard::{KeyEvent, KeyboardHandler, Keysym, Modifiers, RawModifiers},
        pointer::{PointerEvent, PointerEventKind, PointerHandler},
        Capability, SeatHandler, SeatState,
    },
    session_lock::{
        SessionLock, SessionLockHandler, SessionLockState, SessionLockSurface,
        SessionLockSurfaceConfigure,
    },
    shell::{
        wlr_layer::{
            Anchor, KeyboardInteractivity, Layer, LayerShell, LayerShellHandler, LayerSurface,
            LayerSurfaceConfigure,
        },
        WaylandSurface,
    },
    shm::{Shm, ShmHandler},
};
use wayland_client::{
    globals::registry_queue_init,
    protocol::{wl_buffer, wl_keyboard, wl_output, wl_pointer, wl_seat, wl_surface},
    Connection, Dispatch, Proxy, QueueHandle,
};
use wayland_protocols::wp::viewporter::client::{
    wp_viewport::WpViewport, wp_viewporter::WpViewporter,
};
use wayland_protocols_wlr::screencopy::v1::client::zwlr_screencopy_manager_v1::ZwlrScreencopyManagerV1;

use capture::{Capture, CaptureState};
use gpu::{Gpu, OutputGfx, Place, Sim};
use storm::{Phase, Storm, HOMING_DONE};

const PAM_SERVICE: &str = "sandlock";
const SIM_DT: f32 = 1.0 / 60.0;
/// The storm looks no different above 60 fps; rendering faster only heats
/// the GPU.
const FRAME_INTERVAL: Duration = Duration::from_micros(16_667);
const FADE: f32 = 0.35;

enum Key {
    Char(String),
    Backspace,
    Enter,
    Escape,
}

enum Role {
    Lock(SessionLockSurface),
    Layer(LayerSurface),
}

impl Role {
    fn wl_surface(&self) -> &wl_surface::WlSurface {
        match self {
            Role::Lock(s) => s.wl_surface(),
            Role::Layer(s) => s.wl_surface(),
        }
    }
}

/// A full-screen surface on one output: lock surface, preview overlay, or the
/// unlock handoff overlay.
struct Screen {
    output: usize,
    role: Role,
    _viewport: Option<WpViewport>,
    configured: bool,
    gfx: Option<OutputGfx>,
    /// A frame callback is outstanding: the compositor has not asked for the
    /// next frame yet (e.g. the output is asleep), so don't render.
    waiting: Option<Instant>,
    /// When the next frame is due (frame-rate cap).
    due: Instant,
    /// Surface size in logical px (from configure): maps pointer positions.
    logical: [u32; 2],
}

impl Screen {
    /// Whether the compositor wants a frame and the frame-rate cap allows one.
    fn due(&self, now: Instant) -> bool {
        // A lost callback must not freeze the screen forever.
        let waiting = self.waiting.is_some_and(|t| now - t < Duration::from_secs(1));
        self.gfx.is_some() && !waiting && now >= self.due
    }

    /// Draws a frame (after `Sim::rasterize`) and asks for the next callback.
    fn draw(&mut self, now: Instant, qh: &QueueHandle<App>, gpu: &Gpu, sim: &Sim, overlay: &Overlay) {
        let Some(gfx) = &mut self.gfx else { return };
        // Keep a steady cadence, but don't try to catch up after a stall.
        self.due = (self.due + FRAME_INTERVAL).max(now + FRAME_INTERVAL / 2);
        let surface = self.role.wl_surface();
        surface.frame(qh, FrameCallbackData(surface.clone()));
        self.waiting = Some(now);
        let dots = if Some(self.output) == overlay.dots_on { overlay.dots } else { &[] };
        gfx.render(gpu, sim, overlay.alpha, dots, overlay.dot_radius);
    }
}

/// What is drawn over the grains: fade and password dots.
struct Overlay<'a> {
    alpha: f32,
    dots: &'a [[f32; 3]],
    dots_on: Option<usize>,
    dot_radius: f32,
}

impl Overlay<'_> {
    const PLAIN: Overlay<'static> = Overlay { alpha: 1.0, dots: &[], dots_on: None, dot_radius: 0.0 };
}

/// Draws every screen that is due, rasterising the grains once for all of
/// them; returns whether anything was drawn.
fn draw_due(screens: &mut [Screen], qh: &QueueHandle<App>, gpu: &Gpu, sim: &Sim, overlay: &Overlay) -> bool {
    let now = Instant::now();
    if !screens.iter().any(|s| s.due(now)) {
        return false;
    }
    sim.rasterize(gpu);
    for screen in screens.iter_mut().filter(|s| s.due(now)) {
        screen.draw(now, qh, gpu, sim, overlay);
    }
    true
}

struct Output {
    wl: wl_output::WlOutput,
    info: OutputInfo,
}

struct App {
    conn: Connection,
    registry_state: RegistryState,
    output_state: OutputState,
    compositor: CompositorState,
    seat_state: SeatState,
    shm: Shm,
    lock_state: SessionLockState,
    layer_shell: Option<LayerShell>,
    viewporter: Option<WpViewporter>,
    screencopy: Option<ZwlrScreencopyManagerV1>,
    keyboard: Option<wl_keyboard::WlKeyboard>,
    pointer: Option<wl_pointer::WlPointer>,
    /// Pointer positions (canvas px) since the last loop; `true` = it just
    /// entered a screen.
    pointer_moves: Vec<([f32; 2], bool)>,
    /// Each output's rectangle in the canvas, for pointer positions.
    places: Vec<Place>,

    captures: Vec<Capture>,
    lock: Option<SessionLock>,
    locked: bool,
    lock_refused: bool,
    screens: Vec<Screen>,
    keys: Vec<Key>,
    closed: bool,
}

fn main() -> anyhow::Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    let (mut preview, mut daemonize) = (false, false);
    let mut config_path = config::default_path();
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--preview" => preview = true,
            "-f" | "--daemonize" => daemonize = true,
            "--config" => config_path = Some(args.next().context("--config needs a path")?.into()),
            other => bail!("unknown argument {other:?} (usage: sandlock [-f] [--preview] [--config <file>])"),
        }
    }
    // A broken config must not stop the lock: fall back to defaults.
    let config = match config_path.as_deref().map(config::load).transpose() {
        Ok(c) => c.unwrap_or_default(),
        Err(e) => {
            log::error!("{e:#}; using defaults");
            config::Config::default()
        }
    };
    let Some(_instance) = daemon::single_instance()? else {
        log::info!("sandlock is already running");
        return Ok(());
    };
    // Fork before anything spawns a thread; the parent returns once locked.
    let mut ready = if daemonize && !preview {
        daemon::daemonize()?
    } else {
        daemon::Ready::none()
    };

    let conn = Connection::connect_to_env().context("connecting to Wayland")?;
    let (globals, event_queue) = registry_queue_init::<App>(&conn)?;
    let qh = event_queue.handle();
    let mut event_loop: EventLoop<App> = EventLoop::try_new()?;
    WaylandSource::new(conn.clone(), event_queue)
        .insert(event_loop.handle())
        .map_err(|e| anyhow::anyhow!("inserting Wayland source: {e}"))?;

    let mut app = App {
        conn: conn.clone(),
        registry_state: RegistryState::new(&globals),
        output_state: OutputState::new(&globals, &qh),
        compositor: CompositorState::bind(&globals, &qh).context("wl_compositor")?,
        seat_state: SeatState::new(&globals, &qh),
        shm: Shm::bind(&globals, &qh).context("wl_shm")?,
        lock_state: SessionLockState::new(&globals, &qh),
        layer_shell: LayerShell::bind(&globals, &qh).ok(),
        viewporter: globals.bind(&qh, 1..=1, ()).ok(),
        screencopy: globals.bind(&qh, 1..=3, ()).ok(),
        keyboard: None,
        pointer: None,
        pointer_moves: Vec::new(),
        places: Vec::new(),
        captures: Vec::new(),
        lock: None,
        locked: false,
        lock_refused: false,
        screens: Vec::new(),
        keys: Vec::new(),
        closed: false,
    };
    if preview && app.layer_shell.is_none() {
        bail!("--preview needs wlr-layer-shell");
    }

    // Let output geometry arrive.
    for _ in 0..3 {
        event_loop.dispatch(Duration::from_millis(20), &mut app)?;
    }
    let outputs: Vec<Output> = app
        .output_state
        .outputs()
        .filter_map(|wl| {
            let info = app.output_state.info(&wl)?;
            Some(Output { wl, info })
        })
        .collect();
    if outputs.is_empty() {
        bail!("no outputs");
    }

    // Screenshots first: once locked, the outputs only show the lock.
    let images = capture_all(&mut app, &mut event_loop, &outputs, &qh)?;
    let places = layout(&outputs, &images);
    app.places = places.clone();
    let canvas = places.iter().fold([0u32; 2], |c, p| {
        [
            c[0].max(p.origin[0] + p.size[0]),
            c[1].max(p.origin[1] + p.size[1]),
        ]
    });
    log::info!("canvas {}x{}, outputs {places:?}", canvas[0], canvas[1]);

    // GPU setup before locking, so the first locked frame is ready at once.
    let gpu = Gpu::new()?;
    let mut sim = Sim::new(&gpu, canvas, &places, &images)?;

    let primary = (0..places.len())
        .max_by_key(|&i| places[i].size[0] as u64 * places[i].size[1] as u64)
        .unwrap_or(0);
    // Attractors: a broken image is logged and skipped, never fatal.
    let named: Vec<_> = outputs
        .iter()
        .zip(&places)
        .zip(&images)
        .map(|((o, p), img)| attract::Screen {
            name: o.info.name.clone(),
            place: *p,
            levels: img.as_ref().map_or([20.0, 60.0, 200.0], |i| attract::levels(&i.bgra)),
        })
        .collect();
    let targets: Vec<_> = config
        .attractors
        .iter()
        .filter_map(|a| match attract::load(a, &named, primary) {
            Ok(t) => Some((t, a.emerge, a.reach)),
            Err(e) => {
                log::error!("attractor {}: {e:#}", a.image.display());
                None
            }
        })
        .collect();
    if !targets.is_empty() {
        sim.set_targets(&gpu, &targets);
    }
    drop(images);

    let p = places[primary];
    let seed = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos() as u64)
        .unwrap_or(0)
        ^ u64::from(std::process::id());
    let mut storm = Storm::new(
        [canvas[0] as f32, canvas[1] as f32],
        [sim.params.cell_x, sim.params.cell],
        (
            [p.origin[0] as f32, p.origin[1] as f32],
            [p.size[0] as f32, p.size[1] as f32],
        ),
        seed ^ 0x9e37_79b9_7f4a_7c15,
        config.storm,
    );

    // Lock (or open the preview overlays) and wait for every surface.
    if preview {
        for (i, out) in outputs.iter().enumerate() {
            let screen =
                app.layer_screen(&qh, i, &out.wl, KeyboardInteractivity::Exclusive, &out.info)?;
            app.screens.push(screen);
        }
    } else {
        let lock = app
            .lock_state
            .lock(&qh)
            .context("ext-session-lock unavailable")?;
        for (i, out) in outputs.iter().enumerate() {
            let surface = app.compositor.create_surface(&qh);
            let viewport = app.viewport(&surface, &out.info, &qh);
            let lock_surface = lock.create_lock_surface(surface, &out.wl, &qh);
            app.screens.push(Screen {
                output: i,
                role: Role::Lock(lock_surface),
                _viewport: viewport,
                configured: false,
                gfx: None,
                waiting: None,
                due: Instant::now(),
                logical: [0, 0],
            });
        }
        app.lock = Some(lock);
    }
    let deadline = Instant::now() + Duration::from_secs(5);
    while !app.screens.iter().all(|s| s.configured) && !app.lock_refused {
        event_loop.dispatch(Duration::from_millis(10), &mut app)?;
        if Instant::now() > deadline {
            bail!("surfaces were never configured");
        }
    }
    if app.lock_refused {
        bail!("the compositor refused the lock (another locker running?)");
    }
    let display =
        NonNull::new(conn.backend().display_ptr().cast()).context("no wl_display pointer")?;
    for screen in &mut app.screens {
        screen.gfx = Some(make_gfx(
            &gpu,
            &sim,
            display,
            screen,
            places[screen.output],
            preview,
        )?);
    }

    // ---- the storm -----------------------------------------------------------
    let (auth_tx, auth_rx) = mpsc::channel::<bool>();
    let mut password: Vec<u8> = Vec::new();
    let mut last = Instant::now();
    let mut backlog = 0.0f32;
    let mut frames = 0u32;
    let mut stats_since = Instant::now();
    let mut last_shown = Instant::now();
    loop {
        // Short waits keep input responsive whether or not frames are due.
        event_loop.dispatch(Duration::from_millis(2), &mut app)?;
        if app.closed {
            bail!("a surface was closed by the compositor");
        }

        for key in std::mem::take(&mut app.keys) {
            if storm.phase != Phase::Storm {
                continue;
            }
            match key {
                Key::Char(s) => {
                    password.extend_from_slice(s.as_bytes());
                    storm.typed();
                }
                Key::Backspace => {
                    // Drop one whole UTF-8 character.
                    while let Some(b) = password.pop() {
                        if b & 0xc0 != 0x80 {
                            break;
                        }
                    }
                    storm.erased();
                }
                Key::Escape if preview => return Ok(()),
                Key::Escape => {
                    wipe(&mut password);
                    storm.cleared();
                }
                Key::Enter if password.is_empty() => {}
                Key::Enter => {
                    storm.submitted();
                    let secret = std::mem::take(&mut password);
                    let tx = auth_tx.clone();
                    let service = pam_service();
                    std::thread::spawn(move || {
                        let mut secret = secret;
                        let ok = pam::authenticate(&service, &secret).unwrap_or_else(|e| {
                            log::error!("PAM: {e:#}");
                            false
                        });
                        wipe(&mut secret);
                        let _ = tx.send(ok);
                    });
                }
            }
        }
        for (at, entered) in std::mem::take(&mut app.pointer_moves) {
            log::trace!("pointer at {at:?}{}", if entered { " (entered)" } else { "" });
            storm.pointer(at, entered);
        }
        if let Ok(ok) = auth_rx.try_recv() {
            if ok {
                storm.correct()
            } else {
                storm.wrong()
            }
        }

        // Fixed-step simulation, catching up with real time. While no screen
        // has been drawn for a while (outputs asleep), the storm pauses
        // instead of keeping the GPU busy; homing always finishes.
        let now = Instant::now();
        let visible = now - last_shown < Duration::from_millis(500) || storm.homing_for().is_some();
        backlog = if visible {
            (backlog + (now - last).as_secs_f32()).min(SIM_DT * 6.0)
        } else {
            0.0
        };
        last = now;
        while backlog >= SIM_DT {
            let splats = storm.step(SIM_DT, &mut sim.params);
            sim.step(&gpu, SIM_DT, &splats);
            backlog -= SIM_DT;
        }

        let dots = storm.dots();
        let overlay = Overlay {
            alpha: 1.0,
            dots: &dots,
            dots_on: Some(primary),
            dot_radius: storm.dot_radius,
        };
        let drew = draw_due(&mut app.screens, &qh, &gpu, &sim, &overlay);
        if drew {
            last_shown = now;
            frames += 1;
            if app.locked {
                ready.signal();
            }
        }
        if stats_since.elapsed() >= Duration::from_secs(2) {
            let secs = stats_since.elapsed().as_secs_f32();
            log::debug!("{:.1} fps", frames as f32 / secs);
            #[cfg(debug_assertions)]
            if std::env::var_os("SANDLOCK_STATS").is_some() {
                let (edge, inner) = sim.coverage(&gpu, 60)?;
                log::info!(
                    "t={:.0}s: empty px near walls {:.1}%, interior {:.1}%",
                    storm.time,
                    edge * 100.0,
                    inner * 100.0
                );
            }
            frames = 0;
            stats_since = Instant::now();
        }

        if storm.homing_for().is_some_and(|t| t >= HOMING_DONE) {
            break;
        }
    }

    // ---- handoff: the reassembled desktop fades into the live one ------------
    if !preview {
        handoff(
            &mut app,
            &mut event_loop,
            &qh,
            &gpu,
            &sim,
            display,
            &outputs,
            &places,
        )?;
    }
    fade(&mut app, &mut event_loop, &qh, &gpu, &sim)?;
    Ok(())
}

/// The PAM stack to check passwords against. Debug builds may borrow another
/// service (`SANDLOCK_PAM_SERVICE`) for testing before the system provides
/// `sandlock`; release builds always use `sandlock`.
fn pam_service() -> String {
    #[cfg(debug_assertions)]
    if let Ok(service) = std::env::var("SANDLOCK_PAM_SERVICE") {
        return service;
    }
    PAM_SERVICE.to_owned()
}

fn wipe(bytes: &mut Vec<u8>) {
    bytes
        .iter_mut()
        .for_each(|b| unsafe { std::ptr::write_volatile(b, 0) });
    bytes.clear();
}

/// Captures every output; failures leave that output black.
fn capture_all(
    app: &mut App,
    event_loop: &mut EventLoop<App>,
    outputs: &[Output],
    qh: &QueueHandle<App>,
) -> anyhow::Result<Vec<Option<capture::Image>>> {
    let Some(manager) = app.screencopy.clone() else {
        log::warn!("no wlr-screencopy: the storm starts from a black screen");
        return Ok(outputs.iter().map(|_| None).collect());
    };
    app.captures = outputs
        .iter()
        .enumerate()
        .map(|(i, o)| Capture::start(&manager, &o.wl, i, qh))
        .collect();
    let deadline = Instant::now() + Duration::from_secs(2);
    while !app.captures.iter().all(Capture::is_done) && Instant::now() < deadline {
        event_loop.dispatch(Duration::from_millis(10), app)?;
    }
    Ok(app.captures.iter_mut().map(Capture::take_image).collect())
}

/// Places every output in one physical-pixel canvas. Logical positions are
/// scaled by each output's own buffer scale; mixed scales may overlap or leave
/// gaps, which only costs some wasted canvas.
fn layout(outputs: &[Output], images: &[Option<capture::Image>]) -> Vec<Place> {
    let mut places: Vec<([i64; 2], [u32; 2])> = outputs
        .iter()
        .zip(images)
        .map(|(o, img)| {
            let (lw, lh) = o.info.logical_size.unwrap_or((1, 1));
            let (lx, ly) = o.info.logical_position.unwrap_or((0, 0));
            let size = match img {
                Some(img) => [img.width, img.height],
                None => {
                    let mode = o.info.modes.iter().find(|m| m.current);
                    mode.map(|m| [m.dimensions.0 as u32, m.dimensions.1 as u32])
                        .unwrap_or([lw.max(1) as u32, lh.max(1) as u32])
                }
            };
            let scale = size[0] as f64 / lw.max(1) as f64;
            (
                [
                    (lx as f64 * scale).round() as i64,
                    (ly as f64 * scale).round() as i64,
                ],
                size,
            )
        })
        .collect();
    let min_x = places.iter().map(|p| p.0[0]).min().unwrap_or(0);
    let min_y = places.iter().map(|p| p.0[1]).min().unwrap_or(0);
    places
        .iter_mut()
        .map(|(o, size)| Place {
            origin: [(o[0] - min_x) as u32, (o[1] - min_y) as u32],
            size: *size,
        })
        .collect()
}

fn make_gfx(
    gpu: &Gpu,
    sim: &Sim,
    display: NonNull<std::ffi::c_void>,
    screen: &Screen,
    place: Place,
    transparent: bool,
) -> anyhow::Result<OutputGfx> {
    let ptr =
        NonNull::new(screen.role.wl_surface().id().as_ptr().cast()).context("null wl_surface")?;
    // SAFETY: the display and surface live as long as `screen`, which outlives
    // its gfx (dropped together).
    let surface = unsafe { gpu.surface(display, ptr)? };
    OutputGfx::new(gpu, sim, surface, place, transparent)
}

/// Shows the reassembled desktop in overlays above the lock, unlocks, and
/// leaves the overlays for `fade`.
#[allow(clippy::too_many_arguments)]
fn handoff(
    app: &mut App,
    event_loop: &mut EventLoop<App>,
    qh: &QueueHandle<App>,
    gpu: &Gpu,
    sim: &Sim,
    display: NonNull<std::ffi::c_void>,
    outputs: &[Output],
    places: &[Place],
) -> anyhow::Result<()> {
    let mut overlays = Vec::new();
    if app.layer_shell.is_some() {
        for (i, out) in outputs.iter().enumerate() {
            overlays.push(app.layer_screen(qh, i, &out.wl, KeyboardInteractivity::None, &out.info)?);
        }
        let deadline = Instant::now() + Duration::from_secs(1);
        while !overlays.iter().all(|s: &Screen| s.configured) && Instant::now() < deadline {
            // Overlay configures arrive through the same handler as screens.
            std::mem::swap(&mut app.screens, &mut overlays);
            event_loop.dispatch(Duration::from_millis(10), app)?;
            std::mem::swap(&mut app.screens, &mut overlays);
        }
        overlays.retain(|s| s.configured);
        sim.rasterize(gpu);
        for overlay in &mut overlays {
            let mut gfx = make_gfx(gpu, sim, display, overlay, places[overlay.output], true)?;
            gfx.render(gpu, sim, 1.0, &[], 0.0);
            overlay.gfx = Some(gfx);
        }
        app.conn.roundtrip()?;
    }
    if let Some(lock) = app.lock.take() {
        lock.unlock();
    }
    app.conn.roundtrip()?;
    // Lock surfaces go; the overlays take over for the fade.
    app.screens = overlays;
    Ok(())
}

fn fade(
    app: &mut App,
    event_loop: &mut EventLoop<App>,
    qh: &QueueHandle<App>,
    gpu: &Gpu,
    sim: &Sim,
) -> anyhow::Result<()> {
    let start = Instant::now();
    loop {
        event_loop.dispatch(Duration::from_millis(2), app)?;
        let t = start.elapsed().as_secs_f32() / FADE;
        if t >= 1.0 {
            break;
        }
        let alpha = 1.0 - t * t * (3.0 - 2.0 * t);
        let overlay = Overlay { alpha, ..Overlay::PLAIN };
        draw_due(&mut app.screens, qh, gpu, sim, &overlay);
    }
    app.screens.clear();
    app.conn.roundtrip()?;
    Ok(())
}

impl App {
    fn viewport(
        &self,
        surface: &wl_surface::WlSurface,
        info: &OutputInfo,
        qh: &QueueHandle<Self>,
    ) -> Option<WpViewport> {
        // Buffers are physical pixels; the viewport maps them onto the
        // logical size, which also covers fractional scales.
        let viewporter = self.viewporter.as_ref()?;
        let (w, h) = info.logical_size?;
        let viewport = viewporter.get_viewport(surface, qh, ());
        viewport.set_destination(w, h);
        Some(viewport)
    }

    fn layer_screen(
        &self,
        qh: &QueueHandle<Self>,
        output: usize,
        wl_output: &wl_output::WlOutput,
        keyboard: KeyboardInteractivity,
        info: &OutputInfo,
    ) -> anyhow::Result<Screen> {
        let surface = self.compositor.create_surface(qh);
        let viewport = self.viewport(&surface, info, qh);
        let shell = self.layer_shell.as_ref().context("wlr-layer-shell unavailable")?;
        let layer = shell.create_layer_surface(
            qh,
            surface,
            Layer::Overlay,
            Some("sandlock"),
            Some(wl_output),
        );
        layer.set_anchor(Anchor::all());
        layer.set_exclusive_zone(-1);
        layer.set_keyboard_interactivity(keyboard);
        layer.commit();
        Ok(Screen {
            output,
            role: Role::Layer(layer),
            _viewport: viewport,
            configured: false,
            gfx: None,
            waiting: None,
            due: Instant::now(),
            logical: [0, 0],
        })
    }

    fn mark_configured(&mut self, surface: &wl_surface::WlSurface, size: (u32, u32)) {
        for screen in &mut self.screens {
            if screen.role.wl_surface() == surface {
                screen.configured = true;
                screen.logical = [size.0, size.1];
            }
        }
    }
}

// ---- Wayland handlers ------------------------------------------------------------

impl CaptureState for App {
    fn capture(&mut self, index: usize) -> (Option<&mut Capture>, &Shm) {
        (self.captures.get_mut(index), &self.shm)
    }
}

impl SessionLockHandler for App {
    fn locked(&mut self, _: &Connection, _: &QueueHandle<Self>, _: SessionLock) {
        self.locked = true;
        log::info!("session locked");
    }

    fn finished(&mut self, _: &Connection, _: &QueueHandle<Self>, _: SessionLock) {
        self.lock_refused = true;
    }

    fn configure(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        surface: SessionLockSurface,
        configure: SessionLockSurfaceConfigure,
        _: u32,
    ) {
        self.mark_configured(surface.wl_surface(), configure.new_size);
    }
}

impl LayerShellHandler for App {
    fn closed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &LayerSurface) {
        self.closed = true;
    }

    fn configure(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        layer: &LayerSurface,
        configure: LayerSurfaceConfigure,
        _: u32,
    ) {
        self.mark_configured(layer.wl_surface(), configure.new_size);
    }
}

impl PointerHandler for App {
    fn pointer_frame(&mut self, _: &Connection, _: &QueueHandle<Self>, pointer: &wl_pointer::WlPointer, events: &[PointerEvent]) {
        for event in events {
            let Some(screen) = self.screens.iter().find(|s| s.role.wl_surface() == &event.surface) else {
                continue;
            };
            let entered = match event.kind {
                PointerEventKind::Enter { serial } => {
                    // No cursor over the lock: the grains show the pointer.
                    pointer.set_cursor(serial, None, 0, 0);
                    true
                }
                PointerEventKind::Motion { .. } => false,
                _ => continue,
            };
            let Some(place) = self.places.get(screen.output) else { continue };
            let [lw, lh] = screen.logical;
            if lw == 0 || lh == 0 {
                continue;
            }
            let x = place.origin[0] as f32 + event.position.0 as f32 * place.size[0] as f32 / lw as f32;
            let y = place.origin[1] as f32 + event.position.1 as f32 * place.size[1] as f32 / lh as f32;
            self.pointer_moves.push(([x, y], entered));
        }
    }
}

impl KeyboardHandler for App {
    fn enter(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: &wl_surface::WlSurface,
        _: u32,
        _: &[u32],
        _: &[Keysym],
    ) {
        log::debug!("keyboard focus entered");
    }

    fn leave(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: &wl_surface::WlSurface,
        _: u32,
    ) {
    }

    fn press_key(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        event: KeyEvent,
    ) {
        let key = match event.keysym {
            Keysym::Return | Keysym::KP_Enter => Key::Enter,
            Keysym::BackSpace => Key::Backspace,
            Keysym::Escape => Key::Escape,
            _ => match event.utf8 {
                Some(s) if !s.is_empty() && !s.chars().any(char::is_control) => Key::Char(s),
                _ => return,
            },
        };
        log::debug!(
            "key: {}",
            match &key {
                Key::Char(s) => format!("text ({} bytes)", s.len()),
                Key::Backspace => "backspace".into(),
                Key::Enter => "enter".into(),
                Key::Escape => "escape".into(),
            }
        );
        self.keys.push(key);
    }

    fn repeat_key(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        _: KeyEvent,
    ) {
    }

    fn release_key(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        _: KeyEvent,
    ) {
    }

    fn update_modifiers(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        _: Modifiers,
        _: RawModifiers,
        _: u32,
    ) {
    }
}

impl SeatHandler for App {
    fn seat_state(&mut self) -> &mut SeatState {
        &mut self.seat_state
    }

    fn new_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat) {}

    fn new_capability(
        &mut self,
        _: &Connection,
        qh: &QueueHandle<Self>,
        seat: wl_seat::WlSeat,
        capability: Capability,
    ) {
        log::debug!("seat capability {capability:?}");
        if capability == Capability::Keyboard && self.keyboard.is_none() {
            match self.seat_state.get_keyboard(qh, &seat, None) {
                Ok(k) => self.keyboard = Some(k),
                Err(e) => log::error!("keyboard: {e}"),
            }
        }
        if capability == Capability::Pointer && self.pointer.is_none() {
            match self.seat_state.get_pointer(qh, &seat) {
                Ok(p) => self.pointer = Some(p),
                Err(e) => log::error!("pointer: {e}"),
            }
        }
    }

    fn remove_capability(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: wl_seat::WlSeat,
        capability: Capability,
    ) {
        if capability == Capability::Keyboard
            && let Some(k) = self.keyboard.take()
        {
            k.release();
        }
        if capability == Capability::Pointer
            && let Some(p) = self.pointer.take()
        {
            p.release();
        }
    }

    fn remove_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat) {}
}

impl CompositorHandler for App {
    fn scale_factor_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: i32,
    ) {
    }

    fn transform_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: wl_output::Transform,
    ) {
    }

    fn frame(&mut self, _: &Connection, _: &QueueHandle<Self>, surface: &wl_surface::WlSurface, _: u32) {
        for screen in &mut self.screens {
            if screen.role.wl_surface() == surface {
                screen.waiting = None;
            }
        }
    }

    fn surface_enter(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
    }

    fn surface_leave(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
    }
}

impl OutputHandler for App {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }

    fn new_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}

    fn update_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}

    fn output_destroyed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
}

impl ShmHandler for App {
    fn shm_state(&mut self) -> &mut Shm {
        &mut self.shm
    }
}

impl ProvidesRegistryState for App {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    registry_handlers![OutputState, SeatState];
}

// Globals and objects without events.
impl Dispatch<WpViewporter, ()> for App {
    fn event(
        _: &mut Self,
        _: &WpViewporter,
        _: <WpViewporter as Proxy>::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<WpViewport, ()> for App {
    fn event(
        _: &mut Self,
        _: &WpViewport,
        _: <WpViewport as Proxy>::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ZwlrScreencopyManagerV1, ()> for App {
    fn event(
        _: &mut Self,
        _: &ZwlrScreencopyManagerV1,
        _: <ZwlrScreencopyManagerV1 as Proxy>::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<wl_buffer::WlBuffer, ()> for App {
    fn event(
        _: &mut Self,
        _: &wl_buffer::WlBuffer,
        _: wl_buffer::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

smithay_client_toolkit::delegate_registry!(App);
smithay_client_toolkit::delegate_dispatch2!(App);

//! GPU side: the fluid + grain simulation and per-output rendering.

use std::borrow::Cow;
use std::ptr::NonNull;

use anyhow::{bail, Context};
use bytemuck::{Pod, Zeroable};
use raw_window_handle::{
    RawDisplayHandle, RawWindowHandle, WaylandDisplayHandle, WaylandWindowHandle,
};

use crate::capture::Image;

const COMMON: &str = include_str!("shaders/common.wgsl");
const FLUID: &str = include_str!("shaders/fluid.wgsl");
const GRAINS: &str = include_str!("shaders/grains.wgsl");
const RENDER: &str = include_str!("shaders/render.wgsl");
const ATTRACT: &str = include_str!("shaders/attract.wgsl");
/// Dynamic-offset stride for per-attractor uniforms.
const RECT_SLOT: u64 = 256;

/// Fluid cells across the canvas height: the prototype's tuning assumes this.
const GRID_ROWS: f32 = 61.0;
const SOLVER_ITERS: usize = 40; // even: results land back in slot 0; warm-started
const MAX_SPLATS: usize = 32;
const MAX_DOTS: usize = 64;

#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
pub(crate) struct Params {
    pub(crate) canvas: [f32; 2],
    pub(crate) cell: f32,
    pub(crate) time: f32,
    pub(crate) dt: f32,
    pub(crate) homing: f32,
    pub(crate) release_start: f32,
    pub(crate) release_dur: f32,
    /// Wind force (cells/s²), wind scale (cells), fine turbulence (px/s).
    pub(crate) forcing: [f32; 4],
    pub(crate) vorticity: f32,
    pub(crate) dissipation: f32,
    pub(crate) unit: f32,
    pub(crate) n_grains: u32,
    pub(crate) n_outputs: u32,
    pub(crate) splat_count: u32,
    pub(crate) cell_x: f32,
    pub(crate) seed: u32,
    /// Tide: band centre (px), half width (px, 0 = off), strength, unused.
    pub(crate) tide: [f32; 4],
}

#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
struct Splats {
    geo: [[f32; 4]; MAX_SPLATS],
    kind: [[f32; 4]; MAX_SPLATS],
}

#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
struct OutRect {
    origin: [f32; 2],
    size: [f32; 2],
    offset: u32,
    _pad: [u32; 3],
}

#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
struct View {
    origin: [f32; 2],
    size: [f32; 2],
    alpha: f32,
    srgb_surface: u32,
    dot_count: u32,
    dot_radius: f32,
    n_outputs: u32,
    canvas_w: u32,
    canvas_h: u32,
    _pad: u32,
    dots: [[f32; 4]; MAX_DOTS],
}

/// A force splatted into the fluid, in fluid cells.
#[derive(Clone, Copy)]
pub(crate) enum Splat {
    Push {
        at: [f32; 2],
        force: [f32; 2],
        radius: f32,
    },
    Vortex {
        at: [f32; 2],
        spin: f32,
        radius: f32,
    },
}

/// Where an output's pixels sit in the canvas (physical px).
#[derive(Clone, Copy, Debug)]
pub(crate) struct Place {
    pub(crate) origin: [u32; 2],
    pub(crate) size: [u32; 2],
}

pub(crate) struct Gpu {
    pub(crate) instance: wgpu::Instance,
    pub(crate) adapter: wgpu::Adapter,
    pub(crate) device: wgpu::Device,
    pub(crate) queue: wgpu::Queue,
}

impl Gpu {
    pub(crate) fn new() -> anyhow::Result<Self> {
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
            backends: wgpu::Backends::VULKAN,
            ..wgpu::InstanceDescriptor::new_without_display_handle()
        });
        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::HighPerformance,
            ..Default::default()
        }))
        .context("no Vulkan adapter")?;
        log::info!("GPU: {:?}", adapter.get_info().name);
        // Grain buffers are large (16 bytes per screen pixel): take the
        // adapter's real limits instead of the conservative defaults.
        let (device, queue) = pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor {
            label: Some("sandlock"),
            required_limits: adapter.limits(),
            ..Default::default()
        }))
        .context("requesting GPU device")?;
        // wgpu panics on uncaptured errors by default, and a crash while
        // locked leaves the session locked with nobody to unlock it (e.g. a
        // device lost across suspend). Log instead: frames may stop, but
        // typing the password still unlocks.
        device.on_uncaptured_error(std::sync::Arc::new(|e| log::error!("GPU: {e}")));
        device.set_device_lost_callback(|reason, why| log::error!("GPU device lost ({reason:?}): {why}"));
        Ok(Self {
            instance,
            adapter,
            device,
            queue,
        })
    }

    /// # Safety
    /// `display` and `surface` must be live Wayland objects that outlive the
    /// returned surface.
    pub(crate) unsafe fn surface(
        &self,
        display: NonNull<std::ffi::c_void>,
        surface: NonNull<std::ffi::c_void>,
    ) -> anyhow::Result<wgpu::Surface<'static>> {
        let target = wgpu::SurfaceTargetUnsafe::RawHandle {
            raw_display_handle: Some(RawDisplayHandle::Wayland(WaylandDisplayHandle::new(
                display,
            ))),
            raw_window_handle: RawWindowHandle::Wayland(WaylandWindowHandle::new(surface)),
        };
        // SAFETY: forwarded to the caller.
        Ok(unsafe { self.instance.create_surface_unsafe(target) }?)
    }
}

/// The canvas no output covers, as rectangles: the cells of the grid that
/// every output edge cuts the canvas into, where no output is.
fn offscreen(canvas: [u32; 2], places: &[Place]) -> Vec<Place> {
    let cuts = |axis: usize, end: u32| {
        let mut v: Vec<u32> = places
            .iter()
            .flat_map(|p| [p.origin[axis], p.origin[axis] + p.size[axis]])
            .chain([0, end])
            .filter(|&c| c <= end)
            .collect();
        v.sort_unstable();
        v.dedup();
        v
    };
    let (xs, ys) = (cuts(0, canvas[0]), cuts(1, canvas[1]));
    let mut rects = Vec::new();
    for y in ys.windows(2) {
        for x in xs.windows(2) {
            let covered = places.iter().any(|p| {
                (p.origin[0]..p.origin[0] + p.size[0]).contains(&x[0])
                    && (p.origin[1]..p.origin[1] + p.size[1]).contains(&y[0])
            });
            if !covered {
                rects.push(Place { origin: [x[0], y[0]], size: [x[1] - x[0], y[1] - y[0]] });
            }
        }
    }
    rects
}

/// BGRA pixels for an offscreen rectangle: each pixel takes the colour of
/// its mirror image across the edge of the nearest output (black where that
/// output has no screenshot).
fn mirrored(r: Place, places: &[Place], images: &[Option<Image>]) -> Vec<u8> {
    let mut out = vec![0u8; (r.size[0] * r.size[1] * 4) as usize];
    for y in 0..r.size[1] {
        for x in 0..r.size[0] {
            let p = [i64::from(r.origin[0] + x), i64::from(r.origin[1] + y)];
            // Nearest output, and the nearest point in it.
            let nearest = places.iter().zip(images).min_by_key(|(o, _)| {
                let q = clamp_into(p, o);
                (q[0] - p[0]).pow(2) + (q[1] - p[1]).pow(2)
            });
            let Some((o, Some(img))) = nearest else { continue };
            // Reflect across the edge line (between the last pixel inside
            // and the first outside), not across the last pixel.
            let q = clamp_into(p, o);
            let m = clamp_into([0, 1].map(|a| 2 * q[a] - p[a] + (p[a] - q[a]).signum()), o);
            let (ix, iy) = ((m[0] - i64::from(o.origin[0])) as u32, (m[1] - i64::from(o.origin[1])) as u32);
            if ix < img.width && iy < img.height {
                let src = ((iy * img.width + ix) * 4) as usize;
                let dst = ((y * r.size[0] + x) * 4) as usize;
                out[dst..dst + 4].copy_from_slice(&img.bgra[src..src + 4]);
            }
        }
    }
    out
}

fn clamp_into(p: [i64; 2], o: &Place) -> [i64; 2] {
    [0, 1].map(|a| p[a].clamp(i64::from(o.origin[a]), i64::from(o.origin[a] + o.size[a]) - 1))
}

// ---- bind group layout helpers ----------------------------------------------

fn entry(
    binding: u32,
    visibility: wgpu::ShaderStages,
    ty: wgpu::BindingType,
) -> wgpu::BindGroupLayoutEntry {
    wgpu::BindGroupLayoutEntry {
        binding,
        visibility,
        ty,
        count: None,
    }
}

fn uniform() -> wgpu::BindingType {
    wgpu::BindingType::Buffer {
        ty: wgpu::BufferBindingType::Uniform,
        has_dynamic_offset: false,
        min_binding_size: None,
    }
}

fn storage(read_only: bool) -> wgpu::BindingType {
    wgpu::BindingType::Buffer {
        ty: wgpu::BufferBindingType::Storage { read_only },
        has_dynamic_offset: false,
        min_binding_size: None,
    }
}

fn texture(sample_type: wgpu::TextureSampleType) -> wgpu::BindingType {
    wgpu::BindingType::Texture {
        sample_type,
        view_dimension: wgpu::TextureViewDimension::D2,
        multisampled: false,
    }
}

fn storage_texture(format: wgpu::TextureFormat) -> wgpu::BindingType {
    wgpu::BindingType::StorageTexture {
        access: wgpu::StorageTextureAccess::WriteOnly,
        format,
        view_dimension: wgpu::TextureViewDimension::D2,
    }
}

const UNFILTERED: wgpu::TextureSampleType = wgpu::TextureSampleType::Float { filterable: false };

/// The type of each binding slot in fluid.wgsl.
fn fluid_binding(binding: u32) -> wgpu::BindingType {
    match binding {
        0 | 1 => uniform(),
        2 => wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
        3 => texture(wgpu::TextureSampleType::Float { filterable: true }),
        4 => storage_texture(wgpu::TextureFormat::Rgba16Float),
        5 | 6 => texture(UNFILTERED),
        _ => storage_texture(wgpu::TextureFormat::R32Float),
    }
}

fn module(device: &wgpu::Device, label: &str, body: &str) -> wgpu::ShaderModule {
    device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: Some(label),
        source: wgpu::ShaderSource::Wgsl(Cow::Owned(format!("{COMMON}\n{body}"))),
    })
}

fn compute(
    device: &wgpu::Device,
    module: &wgpu::ShaderModule,
    entry_point: &str,
    layouts: &[&wgpu::BindGroupLayout],
) -> wgpu::ComputePipeline {
    let layouts: Vec<Option<&wgpu::BindGroupLayout>> = layouts.iter().copied().map(Some).collect();
    let layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
        label: Some(entry_point),
        bind_group_layouts: &layouts,
        immediate_size: 0,
    });
    device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
        label: Some(entry_point),
        layout: Some(&layout),
        module,
        entry_point: Some(entry_point),
        compilation_options: Default::default(),
        cache: None,
    })
}

fn grid_texture(
    device: &wgpu::Device,
    size: [u32; 2],
    format: wgpu::TextureFormat,
) -> wgpu::TextureView {
    device
        .create_texture(&wgpu::TextureDescriptor {
            label: Some("fluid"),
            size: wgpu::Extent3d {
                width: size[0],
                height: size[1],
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::STORAGE_BINDING,
            view_formats: &[],
        })
        .create_view(&Default::default())
}

/// One fluid pass: its pipeline and the bind group it runs with.
struct Pass {
    pipeline: wgpu::ComputePipeline,
    group: wgpu::BindGroup,
}

// ---- simulation --------------------------------------------------------------

pub(crate) struct Sim {
    pub(crate) params: Params,
    grid: [u32; 2],
    params_buf: wgpu::Buffer,
    splats_buf: wgpu::Buffer,
    /// Owned here; the passes reach it through their bind groups.
    _grains: wgpu::Buffer,
    pub(crate) n_outputs: u32,
    advect: Pass,
    splat: Pass,
    curl: Pass,
    vorticity: Pass,
    divergence: Pass,
    pressure: [Pass; 2],
    gradient: Pass,
    stream: [Pass; 2],
    turbulence: Pass,
    grains_pass: Pass,
    grain_groups: [u32; 2],
    /// Which grain sits on each canvas pixel (id + 1, 0 = none), rebuilt
    /// every frame by `rasterize`.
    pub(crate) owner: wgpu::Buffer,
    scatter: Pass,
    /// Each pixel's owner packed with its colour and sub-pixel position
    /// (render.wgsl `pack`): what the outputs splat.
    pub(crate) packed: wgpu::Buffer,
    pack: Pass,
    render_module: wgpu::ShaderModule,
    pub(crate) canvas: [u32; 2],
    targets_tex: wgpu::Texture,
    /// Owned here; the passes reach them through their bind groups.
    _claim: wgpu::Buffer,
    _bound: wgpu::Buffer,
    recruit: Pass,
    rect_layout: wgpu::BindGroupLayout,
    /// One recruit dispatch per attractor rectangle.
    rects: Vec<[u32; 4]>,
    rect_group: Option<wgpu::BindGroup>,
}

/// Per-attractor recruit settings (attract.wgsl `Rect`).
#[repr(C)]
#[derive(Clone, Copy, Pod, Zeroable)]
struct RectUniform {
    origin: [u32; 2],
    size: [u32; 2],
    emerge: f32,
    reach: f32,
    _pad: [u32; 2],
}

impl Sim {
    /// `places` and `images` are per output, in the same order.
    pub(crate) fn new(
        gpu: &Gpu,
        canvas: [u32; 2],
        places: &[Place],
        images: &[Option<Image>],
    ) -> anyhow::Result<Self> {
        let device = &gpu.device;
        let max = device.limits().max_texture_dimension_2d;
        if canvas[0] > max || canvas[1] > max {
            bail!(
                "desktop {}x{} exceeds the GPU's {max}px texture limit",
                canvas[0],
                canvas[1]
            );
        }

        // Screenshot atlas, one region per output.
        let shot_tex = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("screenshot"),
            size: wgpu::Extent3d {
                width: canvas[0],
                height: canvas[1],
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Bgra8Unorm,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });
        for (place, image) in places.iter().zip(images) {
            let Some(image) = image else { continue };
            let w = image.width.min(place.size[0]);
            let h = image.height.min(place.size[1]);
            gpu.queue.write_texture(
                wgpu::TexelCopyTextureInfo {
                    texture: &shot_tex,
                    mip_level: 0,
                    origin: wgpu::Origin3d {
                        x: place.origin[0],
                        y: place.origin[1],
                        z: 0,
                    },
                    aspect: wgpu::TextureAspect::All,
                },
                &image.bgra,
                wgpu::TexelCopyBufferLayout {
                    offset: 0,
                    bytes_per_row: Some(image.width * 4),
                    rows_per_image: Some(image.height),
                },
                wgpu::Extent3d {
                    width: w,
                    height: h,
                    depth_or_array_layers: 1,
                },
            );
        }
        // Canvas no output covers (e.g. below a smaller monitor) gets grains
        // too, coloured like the nearest output mirrored across its edge:
        // left empty, the storm would stir that emptiness into the screens
        // as black streaks. Nobody sees these grains at home.
        let hidden = offscreen(canvas, places);
        for r in &hidden {
            let bgra = mirrored(*r, places, images);
            gpu.queue.write_texture(
                wgpu::TexelCopyTextureInfo {
                    texture: &shot_tex,
                    mip_level: 0,
                    origin: wgpu::Origin3d { x: r.origin[0], y: r.origin[1], z: 0 },
                    aspect: wgpu::TextureAspect::All,
                },
                &bgra,
                wgpu::TexelCopyBufferLayout {
                    offset: 0,
                    bytes_per_row: Some(r.size[0] * 4),
                    rows_per_image: Some(r.size[1]),
                },
                wgpu::Extent3d { width: r.size[0], height: r.size[1], depth_or_array_layers: 1 },
            );
        }
        let shot = shot_tex.create_view(&Default::default());

        // Grains in home order: the outputs, then the offscreen rectangles.
        let mut rects = Vec::with_capacity(places.len() + hidden.len());
        let mut n_grains: u64 = 0;
        for place in places.iter().chain(&hidden) {
            rects.push(OutRect {
                origin: [place.origin[0] as f32, place.origin[1] as f32],
                size: [place.size[0] as f32, place.size[1] as f32],
                offset: n_grains as u32,
                _pad: [0; 3],
            });
            n_grains += u64::from(place.size[0]) * u64::from(place.size[1]);
        }
        let grain_bytes = n_grains * 16;
        if grain_bytes > device.limits().max_storage_buffer_binding_size {
            bail!("{n_grains} grains exceed the GPU's storage buffer limit");
        }

        use wgpu::util::DeviceExt;
        let outs_buf = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("outputs"),
            contents: bytemuck::cast_slice(&rects),
            usage: wgpu::BufferUsages::STORAGE,
        });
        // Zeroed; the first step writes every grain's home position.
        let grains = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("grains"),
            size: grain_bytes,
            usage: wgpu::BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        // Cells are square to within a few percent: the column count is
        // rounded so the grid ends exactly at the canvas edge (the walls).
        let cell = canvas[1] as f32 / GRID_ROWS;
        let grid = [((canvas[0] as f32 / cell).round() as u32).max(1), GRID_ROWS as u32];
        let cell_x = canvas[0] as f32 / grid[0] as f32;
        let params = Params {
            canvas: [canvas[0] as f32, canvas[1] as f32],
            cell,
            time: 0.0,
            dt: 0.0,
            homing: 0.0,
            release_start: 0.0,
            release_dur: 1.8,
            forcing: [0.0; 4],
            vorticity: 0.0,
            dissipation: 0.3,
            unit: canvas[1] as f32 / 1440.0,
            n_grains: n_grains as u32,
            n_outputs: rects.len() as u32,
            splat_count: 0,
            cell_x,
            seed: 0,
            tide: [0.0; 4],
        };
        let params_buf = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("params"),
            size: size_of::<Params>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        let splats_buf = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("splats"),
            size: size_of::<Splats>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        // Fluid state: velocity lives in vel[0], pressure in p[0], stream
        // function in psi[0] at the end of every step.
        let vel = [
            grid_texture(device, grid, wgpu::TextureFormat::Rgba16Float),
            grid_texture(device, grid, wgpu::TextureFormat::Rgba16Float),
        ];
        let scalar = || grid_texture(device, grid, wgpu::TextureFormat::R32Float);
        let curl = scalar();
        let div = scalar();
        let p = [scalar(), scalar()];
        let psi = [scalar(), scalar()];
        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("velocity"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            ..Default::default()
        });

        let fluid = module(device, "fluid", FLUID);
        enum Res<'a> {
            Params,
            Splats,
            Sampler,
            View(&'a wgpu::TextureView),
        }
        let pass = |name: &str, slots: &[(u32, Res)]| -> Pass {
            let entries: Vec<_> = slots
                .iter()
                .map(|(b, _)| entry(*b, wgpu::ShaderStages::COMPUTE, fluid_binding(*b)))
                .collect();
            let layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some(name),
                entries: &entries,
            });
            let resources: Vec<_> = slots
                .iter()
                .map(|(b, r)| wgpu::BindGroupEntry {
                    binding: *b,
                    resource: match r {
                        Res::Params => params_buf.as_entire_binding(),
                        Res::Splats => splats_buf.as_entire_binding(),
                        Res::Sampler => wgpu::BindingResource::Sampler(&sampler),
                        Res::View(v) => wgpu::BindingResource::TextureView(v),
                    },
                })
                .collect();
            let group = device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some(name),
                layout: &layout,
                entries: &resources,
            });
            Pass {
                pipeline: compute(device, &fluid, name, &[&layout]),
                group,
            }
        };

        let advect = pass(
            "advect",
            &[
                (0, Res::Params),
                (2, Res::Sampler),
                (3, Res::View(&vel[0])),
                (4, Res::View(&vel[1])),
            ],
        );
        let splat = pass(
            "splat",
            &[
                (0, Res::Params),
                (1, Res::Splats),
                (3, Res::View(&vel[1])),
                (4, Res::View(&vel[0])),
            ],
        );
        let curl_pass = pass("curl", &[(3, Res::View(&vel[0])), (7, Res::View(&curl))]);
        let vorticity = pass(
            "vorticity",
            &[
                (0, Res::Params),
                (3, Res::View(&vel[0])),
                (4, Res::View(&vel[1])),
                (5, Res::View(&curl)),
            ],
        );
        let divergence = pass(
            "divergence",
            &[(3, Res::View(&vel[1])), (7, Res::View(&div))],
        );
        let pressure = [
            pass(
                "pressure",
                &[
                    (5, Res::View(&p[0])),
                    (6, Res::View(&div)),
                    (7, Res::View(&p[1])),
                ],
            ),
            pass(
                "pressure",
                &[
                    (5, Res::View(&p[1])),
                    (6, Res::View(&div)),
                    (7, Res::View(&p[0])),
                ],
            ),
        ];
        let gradient = pass(
            "gradient",
            &[
                (3, Res::View(&vel[1])),
                (4, Res::View(&vel[0])),
                (5, Res::View(&p[0])),
            ],
        );
        let stream = [
            pass(
                "stream",
                &[
                    (5, Res::View(&psi[0])),
                    (6, Res::View(&curl)),
                    (7, Res::View(&psi[1])),
                ],
            ),
            pass(
                "stream",
                &[
                    (5, Res::View(&psi[1])),
                    (6, Res::View(&curl)),
                    (7, Res::View(&psi[0])),
                ],
            ),
        ];
        let turbulence = pass(
            "turbulence",
            &[(0, Res::Params), (5, Res::View(&psi[0])), (7, Res::View(&psi[1]))],
        );
        // Attractors: the target image (rgb colour, a firmness), and the
        // claims between target pixels and grains (see attract.wgsl).
        let targets_tex = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("targets"),
            size: wgpu::Extent3d { width: canvas[0], height: canvas[1], depth_or_array_layers: 1 },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Rgba8Unorm,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });
        let targets = targets_tex.create_view(&Default::default());
        let claim = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("claim"),
            size: u64::from(canvas[0]) * u64::from(canvas[1]) * 4,
            usage: wgpu::BufferUsages::STORAGE,
            mapped_at_creation: false,
        });
        let bound = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("bound"),
            size: n_grains * 4,
            usage: wgpu::BufferUsages::STORAGE,
            mapped_at_creation: false,
        });

        let cs = wgpu::ShaderStages::COMPUTE;
        let bind = |binding, resource| wgpu::BindGroupEntry { binding, resource };
        let tv = wgpu::BindingResource::TextureView;

        let grains_module = module(device, "grains", GRAINS);
        let grains_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("grains"),
            entries: &[
                entry(0, cs, uniform()),
                entry(1, cs, storage(false)),
                entry(2, cs, storage(true)),
                entry(3, cs, texture(UNFILTERED)),
                entry(4, cs, storage(false)),
                entry(5, cs, texture(UNFILTERED)),
            ],
        });
        let grains_pass = Pass {
            pipeline: compute(device, &grains_module, "main", &[&grains_layout]),
            group: device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("grains"),
                layout: &grains_layout,
                entries: &[
                    bind(0, params_buf.as_entire_binding()),
                    bind(1, grains.as_entire_binding()),
                    bind(2, outs_buf.as_entire_binding()),
                    // psi + turbulence (see `turbulence`).
                    bind(3, tv(&psi[1])),
                    bind(4, bound.as_entire_binding()),
                    bind(5, tv(&targets)),
                ],
            }),
        };
        let groups = n_grains.div_ceil(256) as u32;
        let gx = groups.clamp(1, 65535);
        let grain_groups = [gx, groups.div_ceil(gx).max(1)];

        let owner = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("owner"),
            size: u64::from(canvas[0]) * u64::from(canvas[1]) * 4,
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::COPY_SRC,
            mapped_at_creation: false,
        });
        let render_module = module(device, "render", RENDER);
        let scatter_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("scatter"),
            entries: &[
                entry(0, cs, uniform()),
                entry(1, cs, storage(true)),
                entry(2, cs, storage(false)),
                entry(3, cs, storage(true)),
            ],
        });
        let scatter = Pass {
            pipeline: compute(device, &render_module, "scatter", &[&scatter_layout]),
            group: device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("scatter"),
                layout: &scatter_layout,
                entries: &[
                    bind(0, params_buf.as_entire_binding()),
                    bind(1, grains.as_entire_binding()),
                    bind(2, owner.as_entire_binding()),
                    bind(3, bound.as_entire_binding()),
                ],
            }),
        };
        let packed = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("packed"),
            size: u64::from(canvas[0]) * u64::from(canvas[1]) * 4,
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_SRC,
            mapped_at_creation: false,
        });
        let pack_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("pack"),
            entries: &[
                entry(0, cs, uniform()),
                entry(1, cs, storage(true)),
                entry(2, cs, storage(false)),
                entry(4, cs, storage(true)),
                entry(5, cs, texture(UNFILTERED)),
                entry(6, cs, storage(false)),
            ],
        });
        let pack = Pass {
            pipeline: compute(device, &render_module, "pack", &[&pack_layout]),
            group: device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("pack"),
                layout: &pack_layout,
                entries: &[
                    bind(0, params_buf.as_entire_binding()),
                    bind(1, grains.as_entire_binding()),
                    bind(2, owner.as_entire_binding()),
                    bind(4, outs_buf.as_entire_binding()),
                    bind(5, tv(&shot)),
                    bind(6, packed.as_entire_binding()),
                ],
            }),
        };

        let attract_module = module(device, "attract", ATTRACT);
        let recruit_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("recruit"),
            entries: &[
                entry(0, cs, uniform()),
                entry(1, cs, texture(UNFILTERED)),
                entry(2, cs, storage(false)),
                entry(3, cs, storage(false)),
                entry(4, cs, storage(true)),
                entry(5, cs, texture(UNFILTERED)),
                entry(6, cs, storage(true)),
            ],
        });
        let rect_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("attractor rect"),
            entries: &[entry(
                0,
                cs,
                wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Uniform,
                    has_dynamic_offset: true,
                    min_binding_size: wgpu::BufferSize::new(size_of::<RectUniform>() as u64),
                },
            )],
        });
        let recruit = Pass {
            pipeline: compute(device, &attract_module, "recruit", &[&recruit_layout, &rect_layout]),
            group: device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("recruit"),
                layout: &recruit_layout,
                entries: &[
                    bind(0, params_buf.as_entire_binding()),
                    bind(1, tv(&targets)),
                    bind(2, claim.as_entire_binding()),
                    bind(3, bound.as_entire_binding()),
                    bind(4, owner.as_entire_binding()),
                    bind(5, tv(&shot)),
                    bind(6, outs_buf.as_entire_binding()),
                ],
            }),
        };

        let mut sim = Self {
            params,
            grid,
            params_buf,
            splats_buf,
            _grains: grains,
            n_outputs: places.len() as u32,
            advect,
            splat,
            curl: curl_pass,
            vorticity,
            divergence,
            pressure,
            gradient,
            stream,
            turbulence,
            grains_pass,
            grain_groups,
            owner,
            scatter,
            packed,
            pack,
            render_module,
            canvas,
            targets_tex,
            _claim: claim,
            _bound: bound,
            recruit,
            rect_layout,
            rects: Vec::new(),
            rect_group: None,
        };
        // Place every grain at home before the first frame is drawn.
        sim.step(gpu, 0.0, &[]);
        Ok(sim)
    }

    /// Installs attractor targets: (target, emerge seconds, reach px). Later
    /// targets overwrite earlier ones where they overlap.
    pub(crate) fn set_targets(&mut self, gpu: &Gpu, targets: &[(crate::attract::Target, f32, f32)]) {
        let mut slots = vec![0u8; targets.len().max(1) * RECT_SLOT as usize];
        self.rects.clear();
        for (k, (t, emerge, reach)) in targets.iter().enumerate() {
            self.update_target(gpu, t);
            let rect = RectUniform {
                origin: t.origin,
                size: t.size,
                emerge: *emerge,
                reach: *reach * self.params.unit,
                _pad: [0; 2],
            };
            slots[k * RECT_SLOT as usize..][..size_of::<RectUniform>()].copy_from_slice(bytemuck::bytes_of(&rect));
            self.rects.push([t.origin[0], t.origin[1], t.size[0], t.size[1]]);
        }
        use wgpu::util::DeviceExt;
        let buf = gpu.device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("attractor rects"),
            contents: &slots,
            usage: wgpu::BufferUsages::UNIFORM,
        });
        self.rect_group = Some(gpu.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("attractor rects"),
            layout: &self.rect_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::Buffer(wgpu::BufferBinding {
                    buffer: &buf,
                    offset: 0,
                    size: wgpu::BufferSize::new(size_of::<RectUniform>() as u64),
                }),
            }],
        }));
    }

    /// Rewrites one installed target's pixels (same rectangle as installed by
    /// `set_targets`): recruiting then frees the grains of pixels that stopped
    /// being targets and finds grains for new ones.
    pub(crate) fn update_target(&self, gpu: &Gpu, t: &crate::attract::Target) {
        gpu.queue.write_texture(
            wgpu::TexelCopyTextureInfo {
                texture: &self.targets_tex,
                mip_level: 0,
                origin: wgpu::Origin3d { x: t.origin[0], y: t.origin[1], z: 0 },
                aspect: wgpu::TextureAspect::All,
            },
            &t.rgba,
            wgpu::TexelCopyBufferLayout {
                offset: 0,
                bytes_per_row: Some(t.size[0] * 4),
                rows_per_image: Some(t.size[1]),
            },
            wgpu::Extent3d { width: t.size[0], height: t.size[1], depth_or_array_layers: 1 },
        );
    }

    /// Rebuilds the owner and packed buffers from the current grain
    /// positions: one pass each for all outputs, run once per frame before
    /// they compose.
    pub(crate) fn rasterize(&self, gpu: &Gpu) {
        let mut encoder = gpu.device.create_command_encoder(&Default::default());
        encoder.clear_buffer(&self.owner, 0, None);
        {
            let mut cpass = encoder.begin_compute_pass(&Default::default());
            cpass.set_pipeline(&self.scatter.pipeline);
            cpass.set_bind_group(0, &self.scatter.group, &[]);
            cpass.dispatch_workgroups(self.grain_groups[0], self.grain_groups[1], 1);
            cpass.set_pipeline(&self.pack.pipeline);
            cpass.set_bind_group(0, &self.pack.group, &[]);
            // Per pixel: the owner is read in order and every pixel written,
            // so no clear is needed. (Per grain, writing only the winners,
            // measured slower: 2.7 vs 1.9 ms for the whole rasterize.)
            cpass.dispatch_workgroups(self.canvas[0].div_ceil(16), self.canvas[1].div_ceil(16), 1);
        }
        gpu.queue.submit([encoder.finish()]);
    }

    /// Reads the owner buffer back (grain id + 1 per canvas pixel, top bits
    /// = priority). Blocks on the GPU: for statistics only.
    pub(crate) fn read_owner(&self, gpu: &Gpu) -> anyhow::Result<Vec<u32>> {
        let [w, h] = self.canvas;
        read_back(gpu, &self.owner, u64::from(w) * u64::from(h) * 4)
    }

    /// Reads the packed buffer back (see render.wgsl `pack`). Blocks on the
    /// GPU: for statistics only.
    pub(crate) fn read_packed(&self, gpu: &Gpu) -> anyhow::Result<Vec<u32>> {
        let [w, h] = self.canvas;
        read_back(gpu, &self.packed, u64::from(w) * u64::from(h) * 4)
    }

    /// Debug statistic: share of canvas pixels with no grain (before gap
    /// filling) within `band` px of a wall, and elsewhere. Blocks on the GPU.
    #[cfg(debug_assertions)]
    pub(crate) fn coverage(&self, gpu: &Gpu, band: u32) -> anyhow::Result<(f32, f32)> {
        let [w, h] = self.canvas;
        let ids = self.read_owner(gpu)?;
        let (mut edge, mut edge_n, mut inner, mut inner_n) = (0u64, 0u64, 0u64, 0u64);
        for y in 0..h {
            for x in 0..w {
                let empty = u64::from(ids[(y * w + x) as usize] == 0);
                if x < band || y < band || x + band >= w || y + band >= h {
                    edge_n += 1;
                    edge += empty;
                } else {
                    inner_n += 1;
                    inner += empty;
                }
            }
        }
        Ok((edge as f32 / edge_n.max(1) as f32, inner as f32 / inner_n.max(1) as f32))
    }

    /// Advances the simulation by `dt` with the given forces. `self.params`
    /// carries time, homing, forcing and vorticity, set by the caller.
    pub(crate) fn step(&mut self, gpu: &Gpu, dt: f32, splats: &[Splat]) {
        let mut data = Splats::zeroed();
        let splats = &splats[..splats.len().min(MAX_SPLATS)];
        for (i, s) in splats.iter().enumerate() {
            (data.geo[i], data.kind[i]) = match *s {
                Splat::Push { at, force, radius } => {
                    ([at[0], at[1], force[0], force[1]], [radius, 0.0, 0.0, 0.0])
                }
                Splat::Vortex { at, spin, radius } => {
                    ([at[0], at[1], spin, 0.0], [radius, 1.0, 0.0, 0.0])
                }
            };
        }
        self.params.dt = dt;
        self.params.splat_count = splats.len() as u32;
        self.params.seed = self.params.seed.wrapping_add(1);
        gpu.queue
            .write_buffer(&self.params_buf, 0, bytemuck::bytes_of(&self.params));
        gpu.queue
            .write_buffer(&self.splats_buf, 0, bytemuck::bytes_of(&data));

        let mut encoder = gpu.device.create_command_encoder(&Default::default());
        {
            let mut cpass = encoder.begin_compute_pass(&Default::default());
            let gx = self.grid[0].div_ceil(16);
            let gy = self.grid[1].div_ceil(16);
            let mut run = |p: &Pass| {
                cpass.set_pipeline(&p.pipeline);
                cpass.set_bind_group(0, &p.group, &[]);
                cpass.dispatch_workgroups(gx, gy, 1);
            };
            if dt > 0.0 {
                run(&self.advect);
                run(&self.splat);
                run(&self.curl);
                run(&self.vorticity);
                run(&self.divergence);
                // Warm-started from the previous step (no decay), so
                // large-scale compression converges over successive steps.
                for i in 0..SOLVER_ITERS {
                    run(&self.pressure[i % 2]);
                }
                run(&self.gradient);
                // Stream function of the final velocity: its curl is exactly
                // incompressible even where psi is only approximate.
                run(&self.curl);
                for i in 0..SOLVER_ITERS {
                    run(&self.stream[i % 2]);
                }
            }
            // Always, so the first step (dt = 0) also fills what grains read.
            run(&self.turbulence);
            if let Some(rect_group) = &self.rect_group {
                cpass.set_pipeline(&self.recruit.pipeline);
                cpass.set_bind_group(0, &self.recruit.group, &[]);
                for (k, r) in self.rects.iter().enumerate() {
                    cpass.set_bind_group(1, rect_group, &[(k as u64 * RECT_SLOT) as u32]);
                    cpass.dispatch_workgroups(r[2].div_ceil(16), r[3].div_ceil(16), 1);
                }
            }
            cpass.set_pipeline(&self.grains_pass.pipeline);
            cpass.set_bind_group(0, &self.grains_pass.group, &[]);
            cpass.dispatch_workgroups(self.grain_groups[0], self.grain_groups[1], 1);
        }
        gpu.queue.submit([encoder.finish()]);
    }
}

/// Copies the first `size` bytes of `src` to the CPU. Blocks on the GPU: for
/// statistics only.
fn read_back(gpu: &Gpu, src: &wgpu::Buffer, size: u64) -> anyhow::Result<Vec<u32>> {
    let buf = gpu.device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("readback"),
        size,
        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
        mapped_at_creation: false,
    });
    let mut encoder = gpu.device.create_command_encoder(&Default::default());
    encoder.copy_buffer_to_buffer(src, 0, &buf, 0, size);
    gpu.queue.submit([encoder.finish()]);
    buf.slice(..).map_async(wgpu::MapMode::Read, |_| {});
    gpu.device.poll(wgpu::PollType::wait_indefinitely())?;
    let data = buf
        .slice(..)
        .get_mapped_range()
        .map_err(|e| anyhow::anyhow!("mapping readback buffer: {e}"))?;
    Ok(bytemuck::cast_slice(&data).to_vec())
}

// ---- per-output rendering -------------------------------------------------------

/// The compose pipeline for one output: draws the grains, the fade and the
/// password dots into any render target of `format`.
pub(crate) struct Compose {
    pub(crate) place: Place,
    srgb: bool,
    view_buf: wgpu::Buffer,
    pipeline: wgpu::RenderPipeline,
    group: wgpu::BindGroup,
}

impl Compose {
    pub(crate) fn new(gpu: &Gpu, sim: &Sim, place: Place, format: wgpu::TextureFormat, blend: Option<wgpu::BlendState>) -> Self {
        let device = &gpu.device;
        let view_buf = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("view"),
            size: size_of::<View>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        let fs = wgpu::ShaderStages::FRAGMENT;
        let layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("compose"),
            entries: &[entry(0, fs, uniform()), entry(2, fs, storage(true))],
        });
        let group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("compose"),
            layout: &layout,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: view_buf.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 2, resource: sim.packed.as_entire_binding() },
            ],
        });
        // The module's group 0 belongs to the scatter pass; compose uses group 1.
        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("compose"),
            bind_group_layouts: &[None, Some(&layout)],
            immediate_size: 0,
        });
        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("compose"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &sim.render_module,
                entry_point: Some("compose_vs"),
                compilation_options: Default::default(),
                buffers: &[],
            },
            primitive: Default::default(),
            depth_stencil: None,
            multisample: Default::default(),
            fragment: Some(wgpu::FragmentState {
                module: &sim.render_module,
                entry_point: Some("compose_fs"),
                compilation_options: Default::default(),
                targets: &[Some(wgpu::ColorTargetState {
                    format,
                    blend,
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            multiview_mask: None,
            cache: None,
        });
        Self { place, srgb: format.is_srgb(), view_buf, pipeline, group }
    }

    /// Draws one frame from the owner buffer (`Sim::rasterize` first) into
    /// `target`. `dots` are (x, y, opacity) in canvas px.
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn draw(
        &self,
        gpu: &Gpu,
        sim: &Sim,
        target: &wgpu::TextureView,
        alpha: f32,
        dots: &[[f32; 3]],
        dot_radius: f32,
    ) {
        let mut view = View::zeroed();
        view.origin = [self.place.origin[0] as f32, self.place.origin[1] as f32];
        view.size = [self.place.size[0] as f32, self.place.size[1] as f32];
        view.alpha = alpha;
        view.srgb_surface = u32::from(self.srgb);
        view.dot_radius = dot_radius;
        view.n_outputs = sim.n_outputs;
        [view.canvas_w, view.canvas_h] = sim.canvas;
        let dots = &dots[..dots.len().min(MAX_DOTS)];
        view.dot_count = dots.len() as u32;
        for (slot, d) in view.dots.iter_mut().zip(dots) {
            *slot = [d[0], d[1], d[2], 0.0];
        }
        gpu.queue.write_buffer(&self.view_buf, 0, bytemuck::bytes_of(&view));

        let mut encoder = gpu.device.create_command_encoder(&Default::default());
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("compose"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: target,
                    depth_slice: None,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::TRANSPARENT),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });
            pass.set_pipeline(&self.pipeline);
            pass.set_bind_group(1, &self.group, &[]);
            pass.draw(0..3, 0..1);
        }
        gpu.queue.submit([encoder.finish()]);
    }
}

/// An output's Wayland surface and its compose pipeline.
pub(crate) struct OutputGfx {
    surface: wgpu::Surface<'static>,
    config: wgpu::SurfaceConfiguration,
    compose: Compose,
}

impl OutputGfx {
    pub(crate) fn new(
        gpu: &Gpu,
        sim: &Sim,
        surface: wgpu::Surface<'static>,
        place: Place,
        transparent: bool,
    ) -> anyhow::Result<Self> {
        let device = &gpu.device;
        let [w, h] = place.size;
        let caps = surface.get_capabilities(&gpu.adapter);
        // Prefer a non-sRGB format so screenshot bytes reach the screen as-is.
        let format = caps
            .formats
            .iter()
            .copied()
            .find(|f| !f.is_srgb())
            .or_else(|| caps.formats.first().copied())
            .context("surface has no formats")?;
        let alpha_mode = if transparent && caps.alpha_modes.contains(&wgpu::CompositeAlphaMode::PreMultiplied) {
            wgpu::CompositeAlphaMode::PreMultiplied
        } else {
            wgpu::CompositeAlphaMode::Opaque
        };
        let mut config = surface
            .get_default_config(&gpu.adapter, w, h)
            .context("surface not supported by the adapter")?;
        config.format = format;
        config.alpha_mode = alpha_mode;
        // Rendering is paced by frame callbacks; Mailbox keeps a present from
        // ever blocking the input loop (Fifo may, e.g. on a sleeping monitor).
        config.present_mode = if caps.present_modes.contains(&wgpu::PresentMode::Mailbox) {
            wgpu::PresentMode::Mailbox
        } else {
            wgpu::PresentMode::Fifo
        };
        config.desired_maximum_frame_latency = 1;
        log::debug!("surface {format:?}, {:?}, {alpha_mode:?}", config.present_mode);
        surface.configure(device, &config);
        let blend = (alpha_mode == wgpu::CompositeAlphaMode::PreMultiplied).then_some(wgpu::BlendState::REPLACE);
        let compose = Compose::new(gpu, sim, place, format, blend);
        Ok(Self { surface, config, compose })
    }

    /// Draws one frame (`Sim::rasterize` first) and presents it.
    pub(crate) fn render(&mut self, gpu: &Gpu, sim: &Sim, alpha: f32, dots: &[[f32; 3]], dot_radius: f32) {
        let frame = match self.surface.get_current_texture() {
            wgpu::CurrentSurfaceTexture::Success(f) | wgpu::CurrentSurfaceTexture::Suboptimal(f) => f,
            wgpu::CurrentSurfaceTexture::Outdated | wgpu::CurrentSurfaceTexture::Lost => {
                self.surface.configure(&gpu.device, &self.config);
                return;
            }
            _ => return,
        };
        let target = frame.texture.create_view(&Default::default());
        self.compose.draw(gpu, sim, &target, alpha, dots, dot_radius);
        gpu.queue.present(frame);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn offscreen_is_what_no_output_covers() {
        // 2560x1440 next to 1920x1080, top-aligned: one strip under the
        // smaller monitor.
        let places = [
            Place { origin: [0, 0], size: [2560, 1440] },
            Place { origin: [2560, 0], size: [1920, 1080] },
        ];
        let r = offscreen([4480, 1440], &places);
        assert_eq!(r.len(), 1);
        assert_eq!((r[0].origin, r[0].size), ([2560, 1080], [1920, 360]));
        assert!(offscreen([2560, 1440], &places[..1]).is_empty());
    }

    #[test]
    fn offscreen_mirrors_the_nearest_output() {
        let places = [Place { origin: [0, 0], size: [4, 2] }];
        // Rows: 0..7 in blue.
        let bgra = (0..8u8).flat_map(|v| [v, 0, 0, 255]).collect();
        let images = [Some(Image { width: 4, height: 2, bgra })];
        // Two rows below: the first mirrors row 1, the second row 0.
        let px = mirrored(Place { origin: [0, 2], size: [4, 2] }, &places, &images);
        let blue: Vec<u8> = px.chunks(4).map(|p| p[0]).collect();
        assert_eq!(blue, [4, 5, 6, 7, 0, 1, 2, 3]);
    }

    /// Every shader module parses and validates, as `module` builds it.
    #[test]
    fn shaders_validate() {
        for (name, body) in [("fluid", FLUID), ("grains", GRAINS), ("render", RENDER), ("attract", ATTRACT)] {
            let source = format!("{COMMON}\n{body}");
            let module = naga::front::wgsl::parse_str(&source)
                .unwrap_or_else(|e| panic!("{name}: {}", e.emit_to_string(&source)));
            naga::valid::Validator::new(naga::valid::ValidationFlags::all(), naga::valid::Capabilities::all())
                .validate(&module)
                .unwrap_or_else(|e| panic!("{name}: {}", e.emit_to_string(&source)));
        }
    }
}

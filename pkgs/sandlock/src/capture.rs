//! One-shot screenshots of every output through wlr-screencopy.

use smithay_client_toolkit::dispatch2::Dispatch2;
use smithay_client_toolkit::shm::{raw::RawPool, Shm};
use wayland_client::protocol::{wl_buffer, wl_output, wl_shm};
use wayland_client::{Connection, Dispatch, Proxy, QueueHandle, WEnum};
use wayland_protocols_wlr::screencopy::v1::client::{
    zwlr_screencopy_frame_v1::{self, ZwlrScreencopyFrameV1},
    zwlr_screencopy_manager_v1::ZwlrScreencopyManagerV1,
};

/// A captured output, always stored as top-down BGRA (`Bgra8Unorm` order).
pub(crate) struct Image {
    pub(crate) width: u32,
    pub(crate) height: u32,
    pub(crate) bgra: Vec<u8>,
}

enum Phase {
    /// Waiting for the compositor to describe the buffer it wants.
    Negotiating {
        shm: Option<(wl_shm::Format, u32, u32, u32)>,
    },
    Copying {
        pool: RawPool,
        buffer: wl_buffer::WlBuffer,
        format: wl_shm::Format,
        width: u32,
        height: u32,
        stride: u32,
        y_invert: bool,
    },
    Done(Option<Image>),
}

pub(crate) struct Capture {
    frame: ZwlrScreencopyFrameV1,
    phase: Phase,
}

impl Capture {
    pub(crate) fn start<D>(
        manager: &ZwlrScreencopyManagerV1,
        output: &wl_output::WlOutput,
        index: usize,
        qh: &QueueHandle<D>,
    ) -> Self
    where
        D: Dispatch<ZwlrScreencopyFrameV1, FrameData> + 'static,
    {
        // overlay_cursor = 0: the pointer is not part of the storm.
        let frame = manager.capture_output(0, output, qh, FrameData(index));
        Self {
            frame,
            phase: Phase::Negotiating { shm: None },
        }
    }

    pub(crate) fn is_done(&self) -> bool {
        matches!(self.phase, Phase::Done(_))
    }

    pub(crate) fn take_image(&mut self) -> Option<Image> {
        match &mut self.phase {
            Phase::Done(image) => image.take(),
            _ => None,
        }
    }

    fn fail(&mut self, why: &str) {
        log::warn!("screen capture failed: {why}");
        self.phase = Phase::Done(None);
    }

    /// Allocates the shm buffer the compositor asked for and requests the copy.
    fn copy<D>(&mut self, shm: &Shm, qh: &QueueHandle<D>)
    where
        D: Dispatch<wl_buffer::WlBuffer, ()> + 'static,
    {
        let Phase::Negotiating {
            shm: Some((format, width, height, stride)),
        } = self.phase
        else {
            return self.fail("compositor offered no shm buffer");
        };
        let size = stride as usize * height as usize;
        let mut pool = match RawPool::new(size, shm) {
            Ok(pool) => pool,
            Err(err) => return self.fail(&format!("shm pool: {err}")),
        };
        let buffer = pool.create_buffer(
            0,
            width as i32,
            height as i32,
            stride as i32,
            format,
            (),
            qh,
        );
        self.frame.copy(&buffer);
        self.phase = Phase::Copying {
            pool,
            buffer,
            format,
            width,
            height,
            stride,
            y_invert: false,
        };
    }

    fn finish(&mut self) {
        let Phase::Copying {
            pool,
            buffer,
            format,
            width,
            height,
            stride,
            y_invert,
        } = &mut self.phase
        else {
            return self.fail("ready before copy");
        };
        let (width, height, stride) = (*width, *height, *stride as usize);
        let swap_rb = match format {
            wl_shm::Format::Argb8888 | wl_shm::Format::Xrgb8888 => false,
            wl_shm::Format::Abgr8888 | wl_shm::Format::Xbgr8888 => true,
            other => {
                let why = format!("unsupported format {other:?}");
                return self.fail(&why);
            }
        };
        let src = pool.mmap();
        let row = width as usize * 4;
        let mut bgra = vec![0u8; row * height as usize];
        for y in 0..height as usize {
            let from = if *y_invert {
                height as usize - 1 - y
            } else {
                y
            };
            let line = &src[from * stride..from * stride + row];
            let out = &mut bgra[y * row..(y + 1) * row];
            out.copy_from_slice(line);
            if swap_rb {
                out.as_chunks_mut::<4>().0.iter_mut().for_each(|px| px.swap(0, 2));
            }
        }
        buffer.destroy();
        self.frame.destroy();
        self.phase = Phase::Done(Some(Image {
            width,
            height,
            bgra,
        }));
    }
}

/// Implemented by the app state: gives the frame handler access to the
/// capture for an output and to shm for allocating its buffer.
pub(crate) trait CaptureState: Sized {
    /// The capture for output `index`, and shm (borrowed alongside it).
    fn capture(&mut self, index: usize) -> (Option<&mut Capture>, &Shm);
}

/// User data of a screencopy frame: the index of the output it captures.
pub(crate) struct FrameData(pub(crate) usize);

impl<D> Dispatch2<ZwlrScreencopyFrameV1, D> for FrameData
where
    D: Dispatch<wl_buffer::WlBuffer, ()> + CaptureState + 'static,
{
    fn event(
        &self,
        state: &mut D,
        _frame: &ZwlrScreencopyFrameV1,
        event: zwlr_screencopy_frame_v1::Event,
        _conn: &Connection,
        qh: &QueueHandle<D>,
    ) {
        use zwlr_screencopy_frame_v1::Event;
        let (Some(capture), shm) = state.capture(self.0) else {
            return;
        };
        match event {
            Event::Buffer {
                format: WEnum::Value(format),
                width,
                height,
                stride,
            } => {
                if let Phase::Negotiating { shm } = &mut capture.phase {
                    *shm = Some((format, width, height, stride));
                }
                // Version 1 and 2 never send buffer_done: copy right away.
                if capture.frame.version() < 3 {
                    capture.copy(shm, qh);
                }
            }
            Event::BufferDone => capture.copy(shm, qh),
            Event::Flags { flags } => {
                if let (Phase::Copying { y_invert, .. }, WEnum::Value(flags)) =
                    (&mut capture.phase, flags)
                {
                    *y_invert = flags.contains(zwlr_screencopy_frame_v1::Flags::YInvert);
                }
            }
            Event::Ready { .. } => capture.finish(),
            Event::Failed => capture.fail("compositor reported failure"),
            _ => {}
        }
    }
}

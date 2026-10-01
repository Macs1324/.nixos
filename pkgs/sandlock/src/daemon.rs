//! Process plumbing: one sandlock at a time, and `-f` (fork once locked) so
//! callers such as a before-sleep hook can wait for the lock to be in place.

use std::ffi::{c_int, c_short};
use std::fs::File;
use std::io::{Read, Seek, Write};
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::time::{Duration, Instant};

const LOCK_EX: c_int = 2;
const LOCK_NB: c_int = 4;
const POLLIN: c_short = 1;

/// How long `-f` waits, all told (for another instance, then for its own
/// lock), before giving up, so the caller's fallback still gets to lock
/// before logind's suspend delay (InhibitDelayMaxSec, 5 s by default) runs
/// out.
pub(crate) const LOCK_TIMEOUT: Duration = Duration::from_secs(4);

#[repr(C)]
struct PollFd {
    fd: c_int,
    events: c_short,
    revents: c_short,
}

unsafe extern "C" {
    fn flock(fd: c_int, operation: c_int) -> c_int;
    fn pipe(fds: *mut c_int) -> c_int;
    fn fork() -> c_int;
    fn setsid() -> c_int;
    fn poll(fds: *mut PollFd, nfds: u64, timeout: c_int) -> c_int;
    fn _exit(status: c_int) -> !;
}

/// Held for the process lifetime; dropping it releases the instance lock.
/// The file's content says whether the session is locked ("L") or not
/// (empty), for other instances waiting on this one.
pub(crate) struct Instance(File);

impl Instance {
    fn set(&mut self, locked: bool) {
        let result = self.0.set_len(0).and_then(|()| {
            self.0.rewind()?;
            if locked { self.0.write_all(b"L") } else { Ok(()) }
        });
        if let Err(e) = result {
            log::warn!("instance file: {e}");
        }
    }

    pub(crate) fn mark_locked(&mut self) {
        self.set(true);
    }

    pub(crate) fn mark_unlocked(&mut self) {
        self.set(false);
    }
}

/// Outcome of trying to become the one running sandlock.
pub(crate) enum Start {
    /// This process owns the lock and should run.
    Run(Instance),
    /// Another sandlock holds the session locked.
    AlreadyLocked,
    /// Another sandlock is running but has not locked (it is starting up,
    /// fading out, or previewing).
    Busy,
}

/// Becomes the single sandlock instance. With a `wait` deadline, a running
/// instance that has not locked yet is given until then to lock (or exit, in
/// which case this process takes over) before `Busy` is returned.
pub(crate) fn single_instance(wait: Option<Instant>) -> anyhow::Result<Start> {
    // Not /tmp: another user could create the file there first and hold it.
    let dir = std::env::var_os("XDG_RUNTIME_DIR")
        .ok_or_else(|| anyhow::anyhow!("XDG_RUNTIME_DIR is not set"))?;
    let path = std::path::Path::new(&dir).join("sandlock.lock");
    let mut file = File::options()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .open(&path)?;
    loop {
        // SAFETY: plain syscall on an fd we own.
        if unsafe { flock(file.as_raw_fd(), LOCK_EX | LOCK_NB) } == 0 {
            let mut instance = Instance(file);
            // A previous instance may have died while locked.
            instance.mark_unlocked();
            return Ok(Start::Run(instance));
        }
        let mut state = [0u8; 1];
        let locked = file.rewind().and_then(|()| file.read(&mut state)).is_ok_and(|n| n == 1 && state[0] == b'L');
        if locked {
            return Ok(Start::AlreadyLocked);
        }
        if wait.is_none_or(|deadline| Instant::now() >= deadline) {
            return Ok(Start::Busy);
        }
        std::thread::sleep(Duration::from_millis(50));
    }
}

/// Tells the waiting parent (if any) that the session is locked.
pub(crate) struct Ready(Option<File>);

impl Ready {
    pub(crate) fn none() -> Self {
        Self(None)
    }

    pub(crate) fn signal(&mut self) {
        if let Some(mut pipe) = self.0.take() {
            let _ = pipe.write_all(b"L");
        }
    }
}

/// Forks. The parent waits until the child reports the lock is in place, then
/// exits 0; if the child dies first, or has not locked by `deadline`, it
/// exits 1, so `sandlock -f || fallback` never leaves a machine unlocked.
/// Must run before any thread is spawned.
pub(crate) fn daemonize(deadline: Instant) -> anyhow::Result<Ready> {
    let mut fds = [0 as c_int; 2];
    // SAFETY: `fds` has room for the two descriptors.
    if unsafe { pipe(fds.as_mut_ptr()) } != 0 {
        anyhow::bail!("pipe: {}", std::io::Error::last_os_error());
    }
    // SAFETY: fresh descriptors from pipe(2), owned from here on.
    let (read, write) = unsafe { (OwnedFd::from_raw_fd(fds[0]), OwnedFd::from_raw_fd(fds[1])) };
    // SAFETY: called while the process is still single-threaded.
    match unsafe { fork() } {
        -1 => anyhow::bail!("fork: {}", std::io::Error::last_os_error()),
        0 => {
            drop(read);
            // SAFETY: detach from the caller's session; failure is harmless.
            unsafe { setsid() };
            Ok(Ready(Some(File::from(write))))
        }
        _ => {
            drop(write);
            let mut pipe = File::from(read);
            let locked = loop {
                let left = deadline.saturating_duration_since(Instant::now());
                let mut fd = PollFd { fd: pipe.as_raw_fd(), events: POLLIN, revents: 0 };
                // SAFETY: one valid pollfd.
                match unsafe { poll(&mut fd, 1, left.as_millis() as c_int) } {
                    0 => {
                        log::error!("not locked after {LOCK_TIMEOUT:?}; giving up");
                        break false;
                    }
                    n if n < 0 && std::io::Error::last_os_error().kind() == std::io::ErrorKind::Interrupted => {}
                    _ => {
                        let mut byte = [0u8; 1];
                        break pipe.read(&mut byte).is_ok_and(|n| n == 1);
                    }
                }
            };
            // SAFETY: the parent only waited on the pipe; exit without
            // running destructors shared with the child.
            unsafe { _exit(if locked { 0 } else { 1 }) }
        }
    }
}

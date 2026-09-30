//! Process plumbing: one sandlock at a time, and `-f` (fork once locked) so
//! callers such as a before-sleep hook can wait for the lock to be in place.

use std::ffi::c_int;
use std::fs::File;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};

const LOCK_EX: c_int = 2;
const LOCK_NB: c_int = 4;

unsafe extern "C" {
    fn flock(fd: c_int, operation: c_int) -> c_int;
    fn pipe(fds: *mut c_int) -> c_int;
    fn fork() -> c_int;
    fn setsid() -> c_int;
    fn _exit(status: c_int) -> !;
}

/// Held for the process lifetime; dropping it releases the instance lock.
pub(crate) struct Instance(#[allow(dead_code)] File);

/// Returns `None` if another sandlock already holds the lock.
pub(crate) fn single_instance() -> anyhow::Result<Option<Instance>> {
    let dir = std::env::var_os("XDG_RUNTIME_DIR").unwrap_or_else(|| "/tmp".into());
    let path = std::path::Path::new(&dir).join("sandlock.lock");
    let file = File::options()
        .create(true)
        .truncate(false)
        .write(true)
        .open(&path)?;
    // SAFETY: plain syscall on an fd we own.
    if unsafe { flock(file.as_raw_fd(), LOCK_EX | LOCK_NB) } != 0 {
        return Ok(None);
    }
    Ok(Some(Instance(file)))
}

/// Tells the waiting parent (if any) that the session is locked.
pub(crate) struct Ready(Option<File>);

impl Ready {
    pub(crate) fn none() -> Self {
        Self(None)
    }

    pub(crate) fn signal(&mut self) {
        if let Some(mut pipe) = self.0.take() {
            use std::io::Write;
            let _ = pipe.write_all(b"L");
        }
    }
}

/// Forks. The parent waits until the child reports the lock is in place, then
/// exits 0; if the child dies first it exits 1, so `sandlock -f || fallback`
/// never leaves a machine unlocked. Must run before any thread is spawned.
pub(crate) fn daemonize() -> anyhow::Result<Ready> {
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
            use std::io::Read;
            let mut byte = [0u8; 1];
            let locked = File::from(read).read(&mut byte).is_ok_and(|n| n == 1);
            // SAFETY: the parent only waited on the pipe; exit without
            // running destructors shared with the child.
            unsafe { _exit(if locked { 0 } else { 1 }) }
        }
    }
}

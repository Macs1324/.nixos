//! Minimal libpam binding: authenticate the current user with a password.
//!
//! Only the five functions sandlock needs are declared, which keeps pam-sys
//! (and its bindgen/libclang build step) out of the build.

use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::ptr;

const PAM_SUCCESS: c_int = 0;
const PAM_BUF_ERR: c_int = 5;
const PAM_CONV_ERR: c_int = 19;
const PAM_PROMPT_ECHO_OFF: c_int = 1;
const PAM_PROMPT_ECHO_ON: c_int = 2;

#[repr(C)]
struct PamMessage {
    msg_style: c_int,
    msg: *const c_char,
}

#[repr(C)]
struct PamResponse {
    resp: *mut c_char,
    resp_retcode: c_int,
}

type ConvFn = unsafe extern "C" fn(
    num_msg: c_int,
    msg: *mut *const PamMessage,
    resp: *mut *mut PamResponse,
    appdata: *mut c_void,
) -> c_int;

#[repr(C)]
struct PamConv {
    conv: ConvFn,
    appdata_ptr: *mut c_void,
}

#[repr(C)]
struct Passwd {
    pw_name: *mut c_char,
    // Remaining fields are never read.
}

unsafe extern "C" {
    fn pam_start(
        service: *const c_char,
        user: *const c_char,
        conv: *const PamConv,
        pamh: *mut *mut c_void,
    ) -> c_int;
    #[cfg(debug_assertions)]
    fn pam_start_confdir(
        service: *const c_char,
        user: *const c_char,
        conv: *const PamConv,
        confdir: *const c_char,
        pamh: *mut *mut c_void,
    ) -> c_int;
    fn pam_authenticate(pamh: *mut c_void, flags: c_int) -> c_int;
    fn pam_acct_mgmt(pamh: *mut c_void, flags: c_int) -> c_int;
    fn pam_end(pamh: *mut c_void, status: c_int) -> c_int;
    fn pam_strerror(pamh: *mut c_void, errnum: c_int) -> *const c_char;

    // libc: responses must be malloc'd because PAM frees them.
    fn calloc(n: usize, size: usize) -> *mut c_void;
    fn strdup(s: *const c_char) -> *mut c_char;
    fn getuid() -> u32;
    fn getpwuid(uid: u32) -> *const Passwd;
}

/// Answers every hidden or visible prompt with the password; informational
/// messages get an empty reply.
unsafe extern "C" fn conversation(
    num_msg: c_int,
    msg: *mut *const PamMessage,
    resp: *mut *mut PamResponse,
    appdata: *mut c_void,
) -> c_int {
    if num_msg <= 0 || msg.is_null() || resp.is_null() || appdata.is_null() {
        return PAM_CONV_ERR;
    }
    let count = num_msg as usize;
    // SAFETY: PAM owns the returned array and frees it (and each resp) itself.
    let replies = unsafe { calloc(count, size_of::<PamResponse>()) } as *mut PamResponse;
    if replies.is_null() {
        return PAM_BUF_ERR;
    }
    let password = appdata as *const c_char;
    for i in 0..count {
        // SAFETY: Linux-PAM passes `msg` as a pointer to an array of pointers.
        let style = unsafe { (**msg.add(i)).msg_style };
        let reply = unsafe { &mut *replies.add(i) };
        reply.resp_retcode = 0;
        reply.resp = match style {
            PAM_PROMPT_ECHO_OFF | PAM_PROMPT_ECHO_ON => unsafe { strdup(password) },
            _ => ptr::null_mut(),
        };
    }
    unsafe { *resp = replies };
    PAM_SUCCESS
}

/// Name of the user running sandlock, from the password database (not $USER,
/// which the environment could set to anything).
fn current_user() -> anyhow::Result<CString> {
    // SAFETY: getpwuid returns a pointer into static storage or null.
    let pw = unsafe { getpwuid(getuid()) };
    if pw.is_null() {
        anyhow::bail!("no passwd entry for the current uid");
    }
    let name = unsafe { CStr::from_ptr((*pw).pw_name) };
    Ok(name.to_owned())
}

/// `pam_start`, or in debug builds `pam_start_confdir` when
/// `SANDLOCK_PAM_CONFDIR` points at a test stack.
unsafe fn start(service: &CStr, user: &CStr, conv: &PamConv, handle: &mut *mut c_void) -> c_int {
    #[cfg(debug_assertions)]
    if let Some(dir) = std::env::var_os("SANDLOCK_PAM_CONFDIR") {
        use std::os::unix::ffi::OsStrExt;
        if let Ok(dir) = CString::new(dir.as_bytes()) {
            // SAFETY: forwarded from the caller; `dir` outlives the call.
            return unsafe { pam_start_confdir(service.as_ptr(), user.as_ptr(), conv, dir.as_ptr(), handle) };
        }
    }
    // SAFETY: forwarded from the caller.
    unsafe { pam_start(service.as_ptr(), user.as_ptr(), conv, handle) }
}

/// Checks `password` for the current user against the `service` PAM stack.
/// Blocking: PAM may sleep on failure, so call it off the render thread.
pub(crate) fn authenticate(service: &str, password: &[u8]) -> anyhow::Result<bool> {
    let service = CString::new(service)?;
    let user = current_user()?;
    let mut secret = password.to_vec();
    secret.push(0);
    let conv = PamConv {
        conv: conversation,
        appdata_ptr: secret.as_mut_ptr().cast(),
    };

    let mut handle: *mut c_void = ptr::null_mut();
    // SAFETY: all pointers are valid for the duration of the PAM transaction;
    // `secret` and `conv` outlive `pam_end` below.
    let ok = unsafe {
        let status = start(&service, &user, &conv, &mut handle);
        if status != PAM_SUCCESS {
            anyhow::bail!("pam_start failed ({status})");
        }
        let mut status = pam_authenticate(handle, 0);
        if status == PAM_SUCCESS {
            status = pam_acct_mgmt(handle, 0);
        }
        if status != PAM_SUCCESS {
            let why = CStr::from_ptr(pam_strerror(handle, status)).to_string_lossy();
            log::info!("authentication failed: {why}");
        }
        pam_end(handle, status);
        status == PAM_SUCCESS
    };

    secret
        .iter_mut()
        .for_each(|b| unsafe { ptr::write_volatile(b, 0) });
    Ok(ok)
}

#[cfg(test)]
mod tests {
    use super::authenticate;
    use std::path::PathBuf;

    /// A PAM stack in a temp dir whose only check is a script comparing the
    /// password it receives on stdin (pam_exec expose_authtok) to `expected`.
    fn stack(expected: &str) -> PathBuf {
        let pam_lib = std::env::var("SANDLOCK_TEST_PAM_LIB").unwrap_or_default();
        let dir = std::env::temp_dir().join(format!("sandlock-pam-{}-{}", std::process::id(), expected.len()));
        std::fs::create_dir_all(&dir).unwrap();
        let script = dir.join("check.sh");
        std::fs::write(
            &script,
            // pam_exec runs commands with an empty environment: no PATH.
            format!(
                "#!/bin/sh\nexport PATH={}\ngot=$(tr -d '\\000')\nprintf '%s' \"$got\" > {}/got\n[ \"$got\" = '{expected}' ]\n",
                std::env::var("PATH").unwrap_or_default(),
                dir.display()
            ),
        )
        .unwrap();
        std::fs::set_permissions(&script, std::os::unix::fs::PermissionsExt::from_mode(0o755)).unwrap();
        std::fs::write(
            dir.join("sandlock"),
            format!(
                "auth required {pam_lib}/pam_exec.so expose_authtok quiet {}\naccount required {pam_lib}/pam_permit.so\n",
                script.display()
            ),
        )
        .unwrap();
        dir
    }

    /// Needs `SANDLOCK_TEST_PAM_LIB` (the dir holding pam_exec.so), so it is
    /// skipped in the Nix build sandbox.
    #[test]
    fn conversation_delivers_the_password() {
        if std::env::var_os("SANDLOCK_TEST_PAM_LIB").is_none() {
            eprintln!("skipped: SANDLOCK_TEST_PAM_LIB not set");
            return;
        }
        let dir = stack("Test123!åäö@#x");
        // SAFETY (test only): single-threaded use of the process environment.
        unsafe { std::env::set_var("SANDLOCK_PAM_CONFDIR", &dir) };
        let ok = authenticate("sandlock", "Test123!åäö@#x".as_bytes()).unwrap();
        let got = std::fs::read_to_string(dir.join("got")).unwrap_or_default();
        assert_eq!(got, "Test123!åäö@#x");
        assert!(ok);
        assert!(!authenticate("sandlock", b"wrong").unwrap());
    }
}

// src/pam.rs declares the handful of libpam functions it uses by hand, which
// avoids pam-sys and its bindgen/libclang build dependency.
fn main() {
    println!("cargo:rustc-link-lib=pam");
}

---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
---

# Rust

- `cargo clippy --all-targets` must be clean; treat warnings as findings.
- No `unwrap()` / `expect()` on values that can fail at runtime outside tests and `main`; propagate with `?` and the crate's error type.
- Keep `pub` surface minimal; prefer `pub(crate)`.
- New dependencies need a stated reason and a check that a std or already-present crate cannot do it.

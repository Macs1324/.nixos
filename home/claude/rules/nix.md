---
paths:
  - "**/*.nix"
  - "**/flake.lock"
---

# Nix files

- Format with `alejandra`; it runs automatically after every edit.
- Verify with `nix eval` on the changed attribute or `just build` before claiming a change works. Never `just switch` / `just home` unprompted.
- Do not run `nix flake update` or change `flake.lock` unless asked.
- Match the file's existing style for `with pkgs;`, `lib.` prefixes, and `inherit`.
- Never write a secret into a `.nix` file; it would land in the world-readable store.

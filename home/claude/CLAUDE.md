# Global instructions

## Environment
- NixOS. There is no global `npm i -g`, `pip install`, or `apt`. For a one-off tool use `nix shell nixpkgs#<pkg> -c <cmd>` or `nix run nixpkgs#<pkg>`; for a project, look for a `flake.nix` / `shell.nix` and use `nix develop -c <cmd>`.
- Claude Code itself is configured from `~/.nixos/home/claude/`. `~/.claude/settings.json`, agents, commands and rules are read-only symlinks into the Nix store: change them there and run `just home`, never edit them in place.
- Prefer `jq` for JSON in shell.

## How to work
- Read before you write. Find the existing pattern, then match it.
- Verify before you claim. "Done" means the build, tests, or `nix eval` passed and you saw it. If you skipped verification, say so.
- Smallest diff that solves the problem. No drive-by refactors, no speculative abstractions, no new dependencies without saying why.
- Report failures verbatim. Paste the actual error, not a paraphrase.
- Do not push, force-push, or rewrite shared history unless explicitly asked.

## Delegation
Specialised agents are available: `scout`, `architect`, `implementer`, `verifier`, `reviewer`, `security-reviewer`, `researcher`, `nix-engineer`. Use them when a task has separable phases or would otherwise flood the main context with file dumps. `/feature`, `/fix`, `/review`, and `/ship` encode the standard pipelines. For trivial changes, just do the work.

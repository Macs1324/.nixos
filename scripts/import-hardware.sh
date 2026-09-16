#!/usr/bin/env bash
set -euo pipefail

# Generate this machine's hardware configuration into hosts/<host>/ and stage
# it, so the flake can evaluate and build that host. Review the diff before
# committing; nothing is committed here.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
host=${1:-${NIXOS_HOST:-$(hostname)}}
case "$host" in
  workdesktop|worklaptop|homedesktop) ;;
  *)
    echo "Choose a host: workdesktop, worklaptop, or homedesktop (got: $host)." >&2
    exit 2
    ;;
esac

target="hosts/$host/hardware-configuration.nix"
generated=$(mktemp)
trap 'rm -f "$generated"' EXIT
# The temp file is deliberately written as the invoking user, not root.
# shellcheck disable=SC2024
sudo nixos-generate-config --show-hardware-config > "$generated"

if [[ -f "$target" ]] && cmp -s "$generated" "$target"; then
  echo "$target is already up to date."
  exit 0
fi
if [[ -f "$target" ]]; then
  echo "Updating $target; previous version stays in Git history." >&2
  diff -u "$target" "$generated" || true
fi
install -m 0644 "$generated" "$target"
git add -- "$target"
echo "Wrote and staged $target. Review with 'git diff --cached', then build with: just build $host"

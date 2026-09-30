#!/usr/bin/env bash
set -euo pipefail

# Run from the repository even when invoked from another directory.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
action=${1:-build}
host=${2:-${NIXOS_HOST:-$(hostname)}}
case "$host" in
  workdesktop|worklaptop|homedesktop) ;;
  *)
    echo "Choose a host: workdesktop, worklaptop, or homedesktop (got: $host)." >&2
    echo "Use NIXOS_HOST=workdesktop just, or: just $action workdesktop" >&2
    exit 2
    ;;
esac
system=".#nixosConfigurations.$host.config.system.build.toplevel"
home=".#homeConfigurations.macs@$host.activationPackage"

# nh comes from programs.nh, so the first switch after enabling it (or a
# machine without it) runs it from the registry's pinned nixpkgs instead.
if command -v nh >/dev/null; then
  nh=(nh)
else
  nh=(nix run nixpkgs#nh --)
fi

require_hardware() {
  if [[ ! -f "hosts/$host/hardware-configuration.nix" ]]; then
    echo "hosts/$host/hardware-configuration.nix is missing; run this on $host first:" >&2
    echo "  just hardware $host" >&2
    exit 3
  fi
}

case "$action" in
  build)
    require_hardware
    nix build --no-link "$system" "$home"
    ;;
  switch)
    require_hardware
    # Validate and build both halves before activating either one.
    nix build --no-link "$system" "$home"
    # nh elevates itself for the system switch and prints a package diff.
    "${nh[@]}" os switch . --hostname "$host"
    # Back up unmanaged files that Home Manager takes over instead of aborting.
    "${nh[@]}" home switch . --configuration "macs@$host" --backup-extension hm-backup
    ;;
  home)
    "${nh[@]}" home switch . --configuration "macs@$host" --backup-extension hm-backup
    ;;
  *)
    echo "Unknown action: $action (expected build, switch, or home)." >&2
    exit 2
    ;;
esac

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

case "$action" in
  build)
    nix build --impure --no-link "$system" "$home"
    ;;
  switch)
    # Validate and build both halves before activating either one.
    nix build --impure --no-link "$system" "$home"
    sudo nixos-rebuild switch --impure --flake ".#$host"
    home-manager switch --flake ".#macs@$host"
    ;;
  home)
    home-manager switch --flake ".#macs@$host"
    ;;
  *)
    echo "Unknown action: $action (expected build, switch, or home)." >&2
    exit 2
    ;;
esac

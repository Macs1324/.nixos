set positional-arguments

default: switch

fmt:
    alejandra .

# Selection: explicit host, then NIXOS_HOST, then the current hostname.
build host="":
    bash scripts/rebuild.sh build "$1"

switch host="":
    bash scripts/rebuild.sh switch "$1"

home host="":
    bash scripts/rebuild.sh home "$1"

# Generate and stage this machine's hardware file under hosts/<host>/.
hardware host="":
    bash scripts/import-hardware.sh "$1"

# Update the lock file for review; activation and commits are separate actions.
update:
    nix flake update

# Nix resolves the current system for the test packages; no hardcoded platform.
check:
    alejandra --check .
    shellcheck scripts/rebuild.sh scripts/import-hardware.sh
    bash -n scripts/rebuild.sh scripts/import-hardware.sh
    nix build --no-link .#monitor-model .#helper-tests
    nix flake check --no-build

clean:
    sudo nix-collect-garbage -d
    nix-collect-garbage -d

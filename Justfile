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

# Update the lock file for review; activation and commits are separate actions.
update:
    nix flake update

check:
    alejandra --check .
    shellcheck scripts/rebuild.sh
    bash -n scripts/rebuild.sh
    nix build --no-link .#checks.x86_64-linux.monitor-model .#checks.x86_64-linux.helper-tests
    nix flake check --impure --no-build

clean:
    sudo nix-collect-garbage -d
    nix-collect-garbage -d

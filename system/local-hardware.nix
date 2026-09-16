{...}: {
  # Deliberately local: disk UUIDs and detected hardware stay on each machine.
  # Rebuild/evaluate NixOS outputs with --impure to allow this import.
  imports = [
    (
      if builtins.pathExists /etc/nixos/hardware-configuration.nix
      then /etc/nixos/hardware-configuration.nix
      else throw "Local hardware configuration is unavailable. Run Nix with --impure on the target machine and ensure /etc/nixos/hardware-configuration.nix exists."
    )
  ];
}

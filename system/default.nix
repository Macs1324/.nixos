{...}: {
  imports = [
    ./base.nix
    ./hardware.nix
    ./desktop.nix
    ./theme.nix
    ./packages.nix
  ];
  nixpkgs.config = import ../lib/nixpkgs-config.nix;
}

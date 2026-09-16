{...}: {
  imports = [
    ./base.nix
    ./hardware.nix
    ./desktop.nix
    ./theme.nix
    ./packages.nix
  ];
  nixpkgs.config = import ../lib/nixpkgs-config.nix;
  nixpkgs.overlays = [
    (import ../lib/overlays/davinci-resolve-hash.nix)
  ];
}

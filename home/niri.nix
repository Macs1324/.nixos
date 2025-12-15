{
  config,
  pkgs,
  pc,
  niri,
  ...
}: {
  nixpkgs.overlays = [niri.overlays.niri];

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
    settings = {
    };
  };
}

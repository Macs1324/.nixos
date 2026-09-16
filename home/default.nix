{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./monitors.nix
    ./theme.nix
    ./programs.nix
    ./terminals.nix
    ./shell.nix
    ./environment.nix
    ./notifications.nix
    ./hyprland.nix
    ./niri.nix
    ./gnome.nix
    ./wlogout.nix
    ./nvim
    ./ai.nix
  ];
  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
  home.username = "macs";
  home.homeDirectory = "/home/macs";
  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
  home.packages = [
    inputs.hyprland-qtutils.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.brightnessctl
  ];
}

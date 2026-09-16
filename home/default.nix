{pkgs, ...}: {
  imports = [
    ../modules/apps.nix
    ./monitors.nix
    ./theme.nix
    ./programs.nix
    ./terminals.nix
    ./shell.nix
    ./environment.nix
    ./notifications.nix
    ./hyprland.nix
    ./niri.nix
    ./wlogout.nix
    ./secrets.nix
    ./nvim
    ./ai.nix
  ];
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };
  home.username = "macs";
  home.homeDirectory = "/home/macs";
  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
  home.packages = [
    pkgs.hyprland-qtutils
    pkgs.brightnessctl
  ];
}

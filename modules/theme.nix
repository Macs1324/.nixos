# Stylix settings shared by NixOS and Home Manager. The two are evaluated
# separately, so both import this and derive the same palette from the same image.
{
  config,
  lib,
  pkgs,
  ...
}: let
  displays = import ../lib/monitors.nix {inherit lib pkgs;} config.desktop.monitors;
in {
  imports = [./monitors.nix];

  stylix = {
    enable = true;
    autoEnable = true;
    # The palette is generated from the leftmost monitor's wallpaper.
    image = displays.themeWallpaper;
    polarity = "dark";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes.terminal = 14;
    };

    # Without an icon theme GTK apps (Thunar especially) fall back to
    # hicolor and show blank or generic icons.
    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };

    cursor = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };

    opacity.terminal = 0.78;
  };
}

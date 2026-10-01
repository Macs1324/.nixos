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
    # Stylix's generator only samples accents from the image, so a wallpaper
    # with few hues gives repeated, near-monochrome accents. Keep its neutrals
    # and give every accent slot its own hue (lib/palette.py).
    base16Scheme =
      lib.importJSON (import ../lib/palette.nix {inherit pkgs;} {
        inherit (config.stylix) image polarity;
        generated = config.stylix.generated.json;
      })
      // {
        author = "Stylix";
        scheme = "Stylix";
        slug = "stylix";
      };

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

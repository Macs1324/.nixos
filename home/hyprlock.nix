{config, ...}: let
  colors = config.lib.stylix.colors;
in {
  # Stylix colors the background and input field; the blurred screenshot stays
  # instead of the wallpaper.
  stylix.targets.hyprlock.image.enable = false;

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        grace = 0;
        no_fade_in = false;
        no_fade_out = false;
      };

      background = {
        monitor = "";
        path = "screenshot";
        blur_passes = 3;
        blur_size = 7;
        noise = 0.0117;
        contrast = 0.8916;
        brightness = 0.8172;
        vibrancy = 0.1696;
        vibrancy_darkness = 0.0;
      };

      label = [
        {
          monitor = "";
          text = "brb :)";
          color = "rgba(${colors.base05}e6)";
          font_size = 100;
          font_family = config.stylix.fonts.monospace.name;
          position = "0, 80";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = {
        monitor = "";
        size = "300, 50";
        outline_thickness = 2;
        dots_size = 0.2;
        dots_spacing = 0.35;
        dots_center = true;
        fade_on_empty = true;
        placeholder_text = "";
        hide_input = false;
        position = "0, -100";
        halign = "center";
        valign = "center";
      };
    };
  };
}

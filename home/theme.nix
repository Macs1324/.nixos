{...}: {
  imports = [../modules/theme.nix];

  # Noctalia draws per-monitor wallpapers (home/monitors.nix) in both sessions,
  # so Stylix only supplies its palette: no hyprpaper, no Noctalia default path.
  stylix.targets.hyprland.hyprpaper.enable = false;
  stylix.targets.noctalia.image.enable = false;
  # Standalone Home Manager does not auto-enable this, but the system is NixOS.
  stylix.targets.qt.enable = true;
  stylix.targets.firefox.profileNames = ["default"];
  stylix.targets.zen-browser.profileNames = ["default"];

  home.pointerCursor = {
    gtk.enable = true;
    # Generates HYPRCURSOR_THEME/HYPRCURSOR_SIZE instead of hand-written env lines.
    hyprcursor = {
      enable = true;
      size = 24;
    };
  };
}

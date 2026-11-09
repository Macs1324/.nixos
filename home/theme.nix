{lib, ...}: {
  imports = [../modules/theme.nix];

  # Noctalia draws per-monitor wallpapers (home/monitors.nix) in both sessions,
  # so Stylix only supplies its palette: no hyprpaper, no Noctalia default path.
  stylix.targets.hyprland.hyprpaper.enable = false;
  stylix.targets.noctalia.image.enable = false;
  # Push wallpaper, palette and font to Noctalia Greeter whenever they change
  # (passwordless for this user, see system/desktop.nix).
  programs.noctalia.settings.shell.greeter_sync.auto_sync = true;
  # Standalone Home Manager does not auto-enable this, but the system is NixOS.
  stylix.targets.qt.enable = true;
  stylix.targets.firefox.profileNames = ["default"];
  stylix.targets.zen-browser.profileNames = ["default"];
  # rofi is not used; the target only trips Stylix's own `programs.rofi.font` rename warning.
  stylix.targets.rofi.enable = false;
  # Stylix still writes the OpenCode 1 tui.json, which OpenCode 2 ignores. The
  # theme selection already lives in the app-owned cli.json (migrated by OpenCode);
  # Stylix keeps supplying the theme file itself.
  programs.opencode.tui = lib.mkForce {};

  home.pointerCursor = {
    gtk.enable = true;
    # Generates HYPRCURSOR_THEME/HYPRCURSOR_SIZE instead of hand-written env lines.
    hyprcursor = {
      enable = true;
      size = 24;
    };
  };
}

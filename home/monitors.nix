{
  config,
  lib,
  pkgs,
  ...
}: let
  python = pkgs.python3.withPackages (ps: [ps.tomlkit]);
  connectors = pkgs.writeText "monitor-connectors.json" (builtins.toJSON (builtins.attrNames config.desktop.monitors));
  displays = import ../lib/monitors.nix {inherit lib;} config.desktop.monitors;
in {
  imports = [../modules/monitors.nix];

  options.desktop.wallpapers.resetOverridesOnSwitch = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Restore declared wallpapers on activation by removing only their Noctalia UI overrides.";
  };

  config = {
    home.activation.restoreMonitorWallpapers =
      lib.mkIf config.desktop.wallpapers.resetOverridesOnSwitch
      (lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${python}/bin/python ${../scripts/reset-wallpaper-overrides.py} ${connectors} ${lib.escapeShellArg config.xdg.stateHome}
      '');

    programs.niri.settings.outputs = displays.niriOutputs;
    wayland.windowManager.hyprland.settings = {
      monitor = displays.hyprlandMonitors;
      workspace_rule = displays.hyprlandWorkspaces;
    };

    # Noctalia renders the wallpaper in both Wayland sessions, including Niri's
    # overview backdrop. No second wallpaper daemon is needed.
    programs.noctalia = {
      enable = true;
      settings.wallpaper = displays.noctaliaWallpaper;
    };

    dconf.settings = lib.mkIf (displays.defaultWallpaper != null) {
      "org/gnome/desktop/background" = {
        picture-uri = "file://${displays.defaultWallpaper}";
        picture-uri-dark = "file://${displays.defaultWallpaper}";
      };
      "org/gnome/desktop/screensaver".picture-uri = "file://${displays.defaultWallpaper}";
    };
  };
}

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
      # Lock screen widgets sit at output-local coordinates, so each output gets
      # its own label; the login box stays at its default spot near the bottom.
      settings.lockscreen_widgets = {
        enabled = true;
        widget = lib.mapAttrs' (name: center:
          lib.nameValuePair "brb-${name}" (center
            // {
              type = "label";
              output = name;
              # A set box scales the text to fit it.
              box_width = 420.0;
              box_height = 140.0;
              rotation = 0.0;
              settings = {
                title = "brb :)";
                background = false;
                font_family = config.stylix.fonts.monospace.name;
              };
            }))
        displays.logicalCenters;
      };
    };
  };
}

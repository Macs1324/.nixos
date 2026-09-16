{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  positiveNumber = types.addCheck types.number (value: value > 0);
  monitors = lib.attrValues config.desktop.monitors;
in {
  options.desktop.monitors = mkOption {
    description = "Monitor inventory keyed by exact connector name, shared by desktop consumers.";
    default = {};
    type = types.attrsOf (types.submodule {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable this output.";
        };
        primary = mkOption {
          type = types.bool;
          default = false;
          description = "Use this output's wallpaper for consumers with only one background.";
        };
        mode = mkOption {
          description = "Physical pixel dimensions and optional refresh rate in Hz; null uses the preferred mode.";
          default = null;
          type = types.nullOr (types.submodule {
            options = {
              width = mkOption {type = types.ints.positive;};
              height = mkOption {type = types.ints.positive;};
              refresh = mkOption {
                type = types.nullOr positiveNumber;
                default = null;
              };
            };
          });
        };
        scale = mkOption {
          type = positiveNumber;
          default = 1.0;
          description = "Physical pixels per logical pixel.";
        };
        position = mkOption {
          description = "Position in logical pixels after scaling and rotation; null lets the compositor place it.";
          default = null;
          type = types.nullOr (types.submodule {
            options = {
              x = mkOption {type = types.int;};
              y = mkOption {type = types.int;};
            };
          });
        };
        rotation = mkOption {
          type = types.enum [0 90 180 270];
          default = 0;
          description = "Counter-clockwise rotation in degrees (Wayland output transform).";
        };
        flipped = mkOption {
          type = types.bool;
          default = false;
          description = "Apply the flipped Wayland output transform.";
        };
        wallpaper = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Wallpaper image; null inherits the primary output's image.";
        };
        hyprlandWorkspaces = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Hyprland workspace assignments; Niri's dynamic workspace model is independent.";
        };
      };
    });
  };

  config.assertions = [
    {
      assertion = builtins.length (builtins.filter (monitor: monitor.enable && monitor.primary) monitors) == 1;
      message = "desktop.monitors must have exactly one enabled primary output.";
    }
    {
      assertion = lib.all (monitor: !monitor.primary || (monitor.enable && monitor.wallpaper != null)) monitors;
      message = "The primary output must be enabled and have a wallpaper.";
    }
  ];
}

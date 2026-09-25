{
  lib,
  pkgs,
}: let
  evaluate = monitors:
    (lib.evalModules {
      modules = [
        ../modules/monitors.nix
        {
          options.assertions = lib.mkOption {
            default = [];
            type = lib.types.listOf lib.types.attrs;
          };
          config.desktop.monitors = monitors;
        }
      ];
    }).config;
  translate = monitors: import ../lib/monitors.nix {inherit lib;} (evaluate monitors).desktop.monitors;
  valid = monitors: lib.all (a: a.assertion) (evaluate monitors).assertions;
  wallpaper = ../assets/wallpapers/deep-sea.jpg;
  other = ../assets/wallpapers/mecha-wings.png;
  fixture = {
    DP-1 = {
      primary = true;
      inherit wallpaper;
      mode = {
        width = 2560;
        height = 1440;
        refresh = 59.95;
      };
      scale = 1.5;
      rotation = 90;
      flipped = true;
      position = {
        x = -960;
        y = 0;
      };
      hyprlandWorkspaces = ["2"];
    };
    HDMI-A-1 = {};
    DP-3 = {
      enable = false;
      hyprlandWorkspaces = ["9"];
    };
  };
  output = translate fixture;
  tests = lib.runTests {
    testMode = {
      expr = (builtins.head output.hyprlandMonitors).mode;
      expected = "2560x1440@59.950000";
    };
    testIntegerRefresh = {
      expr =
        builtins.isFloat
        (translate {
          DP-1 = {
            primary = true;
            inherit wallpaper;
            mode = {
              width = 1920;
              height = 1080;
              refresh = 60;
            };
          };
        }).niriOutputs.DP-1.mode.refresh;
      expected = true;
    };
    testNiriMode = {
      expr = output.niriOutputs.DP-1.mode.refresh;
      expected = 59.95;
    };
    testScale = {
      expr = output.niriOutputs.DP-1.scale;
      expected = 1.5;
    };
    testTransform = {
      expr = (builtins.head output.hyprlandMonitors).transform;
      expected = 5;
    };
    testPosition = {
      expr = (builtins.head output.hyprlandMonitors).position;
      expected = "-960x0";
    };
    testPreferredMode = {
      expr = (builtins.elemAt output.hyprlandMonitors 2).mode;
      expected = "preferred";
    };
    testDisabled = {
      expr = output.niriOutputs.DP-3;
      expected = {enable = false;};
    };
    testDisabledWallpaper = {
      expr = output.noctaliaWallpaper.monitors ? DP-3;
      expected = false;
    };
    testLogicalCenters = {
      expr = output.logicalCenters;
      expected = {
        DP-1 = {
          cx = 480.0;
          cy = 2560.0 / 1.5 / 2.0;
        };
      };
    };
    testWallpaperFallback = {
      expr = output.wallpapers.HDMI-A-1;
      expected = wallpaper;
    };
    testThemeWallpaperLeftmost = {
      expr =
        (translate {
          DP-1 = {
            primary = true;
            inherit wallpaper;
            position = {
              x = 0;
              y = 0;
            };
          };
          HDMI-A-1 = {
            wallpaper = other;
            position = {
              x = -1920;
              y = 0;
            };
          };
        }).themeWallpaper;
      expected = other;
    };
    testThemeWallpaperPrimaryFallback = {
      expr =
        (translate {
          DP-1 = {
            primary = true;
            inherit wallpaper;
          };
          HDMI-A-1.wallpaper = other;
        }).themeWallpaper;
      expected = wallpaper;
    };
    testWorkspace = {
      expr = output.hyprlandWorkspaces;
      expected = [
        {
          workspace = "2";
          monitor = "DP-1";
        }
      ];
    };
    testValid = {
      expr = valid fixture;
      expected = true;
    };
    testMissingPrimary = {
      expr = valid {DP-1 = {inherit wallpaper;};};
      expected = false;
    };
    testDuplicatePrimary = {
      expr = valid (fixture
        // {
          HDMI-A-1 = {
            primary = true;
            inherit wallpaper;
          };
        });
      expected = false;
    };
    testDisabledPrimary = {
      expr = valid {
        DP-1 = {
          primary = true;
          enable = false;
          inherit wallpaper;
        };
      };
      expected = false;
    };
    testMissingWallpaper = {
      expr = valid {DP-1.primary = true;};
      expected = false;
    };
    testInvalidScale = {
      expr =
        (builtins.tryEval (builtins.deepSeq
          (evaluate {
            DP-1 = {
              primary = true;
              inherit wallpaper;
              scale = 0;
            };
          }).desktop.monitors
          true)).success;
      expected = false;
    };
  };
in
  assert lib.assertMsg (tests == []) (builtins.toJSON tests);
    pkgs.writeText "monitor-model-tests" "Monitor translation and validation tests passed.\n"

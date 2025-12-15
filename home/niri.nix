{
  config,
  pkgs,
  pc,
  niri,
  ...
}:
{
  nixpkgs.overlays = [ niri.overlays.niri ];

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
    settings = {
      # Input configuration
      input = {
        keyboard = {
          xkb = {
            # layout = "us,ru";
            # options = "grp:win_space_toggle,compose:ralt,ctrl:nocaps";
          };
          numlock = true;
        };

        touchpad = {
          tap = true;
          natural-scroll = true;
          # dwt = true;
          # dwtp = true;
          # accel-speed = 0.2;
          # accel-profile = "flat";
        };

        mouse = {
          # natural-scroll = true;
          # accel-speed = 0.2;
          # accel-profile = "flat";
        };

        # Uncomment to enable focus-follows-mouse
        focus-follows-mouse = {
          enable = true;
          max-scroll-amount = "0%";
        };

        # Uncomment to enable mouse warping to focused window
        warp-mouse-to-focus.enable = true;
      };

      # Output configuration
      # Uncomment and adjust for your specific displays
      outputs."DP-1" = {
        mode = {
          width = 3440;
          height = 1440;
          refresh = 165.00;
        };
        scale = 1.0;
        transform = {
          rotation = 0;
          flipped = false;
        };
        position = {
          x = 0;
          y = 0;
        };
      };

      outputs."HDMI-A-2" = {
        mode = {
          width = 3840;
          height = 2160;
          refresh = 59.98;
        };
        scale = 1.5;
        transform = {
          rotation = 0;
          flipped = false;
        };
        position = {
          x = 3440;
          y = 0;
        };
      };

      # Layout settings
      layout = {
        gaps = 16;
        center-focused-column = "never";

        preset-column-widths = [
          { proportion = 0.33333; }
          { proportion = 0.5; }
          { proportion = 0.66667; }
        ];

        default-column-width = {
          proportion = 0.5;
        };

        focus-ring = {
          enable = true;
          width = 2;
          active.color = "#7fc8ff";
          inactive.color = "#505050";
        };

        border = {
          enable = false;
          width = 4;
          active.color = "#ffc87f";
          inactive.color = "#505050";
          urgent.color = "#9b0000";
        };

        shadow = {
          enable = false;
          softness = 30.0;
          spread = 5.0;
          offset = {
            x = 0.0;
            y = 5.0;
          };
          color = "#0007";
        };

        struts = {
          left = 0.0;
          right = 0.0;
          top = 0.0;
          bottom = 0.0;
        };
      };

      # Spawn programs at startup
      spawn-at-startup = [
        { argv = [ "waybar" ]; }
      ];

      # Hotkey overlay settings
      hotkey-overlay = {
        skip-at-startup = false;
      };

      # Ask clients to omit CSD if possible
      prefer-no-csd = true;

      # Screenshot path
      screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

      # Animation settings
      animations = {
        enable = true;
        # slowdown = 3.0;
      };

      # Window rules
      window-rules = [
        # Fix WezTerm initial configure bug
        {
          matches = [
            {
              app-id = "^org\\.wezfurlong\\.wezterm$";
            }
          ];
          default-column-width = { };
        }

        # Firefox picture-in-picture as floating
        {
          matches = [
            {
              app-id = "firefox$";
              title = "^Picture-in-Picture$";
            }
          ];
          open-floating = true;
        }

        # Example: block password managers from screen capture (commented out)
        # {
        #   matches = [
        #     { app-id = "^org\\.keepassxc\\.KeePassXC$"; }
        #     { app-id = "^org\\.gnome\\.World\\.Secrets$"; }
        #   ];
        #   block-out-from = "screen-capture";
        # }

        # Example: enable rounded corners for all windows (commented out)
        # {
        #   matches = [{}];
        #   geometry-corner-radius = {
        #     top-left = 12.0;
        #     top-right = 12.0;
        #     bottom-left = 12.0;
        #     bottom-right = 12.0;
        #   };
        #   clip-to-geometry = true;
        # }
      ];

      # Keybindings
      binds = {
        # Show hotkey overlay
        "Mod+Shift+Slash" = {
          action.show-hotkey-overlay = [ ];
        };

        # Program launchers
        "Mod+Q" = {
          action.spawn = "kitty";
          hotkey-overlay.title = "Open a Terminal: kitty";
        };
        "Mod+O" = {
          action.spawn-sh = "wofi --show drun";
          hotkey-overlay.title = "Application menu";
        };
        "Ctrl+Alt+L" = {
          action.spawn = "hyprlock";
          hotkey-overlay.title = "Lock the Screen: hyprlock";
        };

        # # Screen reader toggle
        # "Super+Alt+S" = {
        #   action.spawn-sh = "pkill orca || exec orca";
        #   allow-when-locked = true;
        #   hotkey-overlay.hidden = true;
        # };

        # Volume controls
        "XF86AudioRaiseVolume" = {
          action.spawn-sh = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+";
          allow-when-locked = true;
        };
        "XF86AudioLowerVolume" = {
          action.spawn-sh = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-";
          allow-when-locked = true;
        };
        "XF86AudioMute" = {
          action.spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          allow-when-locked = true;
        };
        "XF86AudioMicMute" = {
          action.spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
          allow-when-locked = true;
        };

        # Brightness controls
        "XF86MonBrightnessUp" = {
          action.spawn = [
            "brightnessctl"
            "--class=backlight"
            "set"
            "+10%"
          ];
          allow-when-locked = true;
        };
        "XF86MonBrightnessDown" = {
          action.spawn = [
            "brightnessctl"
            "--class=backlight"
            "set"
            "10%-"
          ];
          allow-when-locked = true;
        };

        # Overview
        "Mod+Escape" = {
          action.toggle-overview = [ ];
          repeat = false;
        };

        # Close window
        "Mod+C" = {
          action.close-window = [ ];
          repeat = false;
        };

        # Focus movement
        "Mod+Left".action.focus-column-left = [ ];
        "Mod+Down".action.focus-window-down = [ ];
        "Mod+Up".action.focus-window-up = [ ];
        "Mod+Right".action.focus-column-right = [ ];
        "Mod+H".action.focus-column-left = [ ];
        "Mod+J".action.focus-window-down = [ ];
        "Mod+K".action.focus-window-up = [ ];
        "Mod+L".action.focus-column-right = [ ];

        # Move window
        "Mod+Ctrl+Left".action.move-column-left = [ ];
        "Mod+Ctrl+Down".action.move-window-down = [ ];
        "Mod+Ctrl+Up".action.move-window-up = [ ];
        "Mod+Ctrl+Right".action.move-column-right = [ ];
        "Mod+Ctrl+H".action.move-column-left = [ ];
        "Mod+Ctrl+J".action.move-window-down = [ ];
        "Mod+Ctrl+K".action.move-window-up = [ ];
        "Mod+Ctrl+L".action.move-column-right = [ ];

        # Focus first/last column
        "Mod+0".action.focus-column-first = [ ];
        "Mod+Shift+4".action.focus-column-last = [ ];
        "Mod+Ctrl+Home".action.move-column-to-first = [ ];
        "Mod+Ctrl+End".action.move-column-to-last = [ ];

        # Monitor focus
        "Mod+Shift+Left".action.focus-monitor-left = [ ];
        "Mod+Shift+Down".action.focus-monitor-down = [ ];
        "Mod+Shift+Up".action.focus-monitor-up = [ ];
        "Mod+Shift+Right".action.focus-monitor-right = [ ];
        "Mod+Shift+H".action.focus-monitor-left = [ ];
        "Mod+Shift+J".action.focus-monitor-down = [ ];
        "Mod+Shift+K".action.focus-monitor-up = [ ];
        "Mod+Shift+L".action.focus-monitor-right = [ ];

        # Move column to monitor
        "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = [ ];
        "Mod+Shift+Ctrl+Down".action.move-column-to-monitor-down = [ ];
        "Mod+Shift+Ctrl+Up".action.move-column-to-monitor-up = [ ];
        "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = [ ];
        "Mod+Shift+Ctrl+H".action.move-column-to-monitor-left = [ ];
        "Mod+Shift+Ctrl+J".action.move-column-to-monitor-down = [ ];
        "Mod+Shift+Ctrl+K".action.move-column-to-monitor-up = [ ];
        "Mod+Shift+Ctrl+L".action.move-column-to-monitor-right = [ ];

        # Workspace focus
        "Mod+Page_Down".action.focus-workspace-down = [ ];
        "Mod+Page_Up".action.focus-workspace-up = [ ];
        "Mod+U".action.focus-workspace-down = [ ];
        "Mod+I".action.focus-workspace-up = [ ];

        # Move column to workspace
        "Mod+Ctrl+Page_Down".action.move-column-to-workspace-down = [ ];
        "Mod+Ctrl+Page_Up".action.move-column-to-workspace-up = [ ];
        "Mod+Ctrl+U".action.move-column-to-workspace-down = [ ];
        "Mod+Ctrl+I".action.move-column-to-workspace-up = [ ];

        # Move workspace
        "Mod+Shift+Page_Down".action.move-workspace-down = [ ];
        "Mod+Shift+Page_Up".action.move-workspace-up = [ ];
        "Mod+Shift+U".action.move-workspace-down = [ ];
        "Mod+Shift+I".action.move-workspace-up = [ ];

        # Mouse wheel workspace switching
        "Mod+WheelScrollDown" = {
          action.focus-workspace-down = [ ];
          cooldown-ms = 150;
        };
        "Mod+WheelScrollUp" = {
          action.focus-workspace-up = [ ];
          cooldown-ms = 150;
        };
        "Mod+Ctrl+WheelScrollDown" = {
          action.move-column-to-workspace-down = [ ];
          cooldown-ms = 150;
        };
        "Mod+Ctrl+WheelScrollUp" = {
          action.move-column-to-workspace-up = [ ];
          cooldown-ms = 150;
        };

        # Mouse wheel column focus
        "Mod+WheelScrollRight".action.focus-column-right = [ ];
        "Mod+WheelScrollLeft".action.focus-column-left = [ ];
        "Mod+Ctrl+WheelScrollRight".action.move-column-right = [ ];
        "Mod+Ctrl+WheelScrollLeft".action.move-column-left = [ ];

        # Shift+wheel for horizontal scrolling
        "Mod+Shift+WheelScrollDown".action.focus-column-right = [ ];
        "Mod+Shift+WheelScrollUp".action.focus-column-left = [ ];
        "Mod+Ctrl+Shift+WheelScrollDown".action.move-column-right = [ ];
        "Mod+Ctrl+Shift+WheelScrollUp".action.move-column-left = [ ];

        # Workspace switching by index
        "Mod+1".action.focus-workspace = 1;
        "Mod+2".action.focus-workspace = 2;
        "Mod+3".action.focus-workspace = 3;
        "Mod+4".action.focus-workspace = 4;
        "Mod+5".action.focus-workspace = 5;
        "Mod+6".action.focus-workspace = 6;
        "Mod+7".action.focus-workspace = 7;
        "Mod+8".action.focus-workspace = 8;
        "Mod+9".action.focus-workspace = 9;

        # Move column to workspace by index
        "Mod+Ctrl+1".action.move-column-to-workspace = 1;
        "Mod+Ctrl+2".action.move-column-to-workspace = 2;
        "Mod+Ctrl+3".action.move-column-to-workspace = 3;
        "Mod+Ctrl+4".action.move-column-to-workspace = 4;
        "Mod+Ctrl+5".action.move-column-to-workspace = 5;
        "Mod+Ctrl+6".action.move-column-to-workspace = 6;
        "Mod+Ctrl+7".action.move-column-to-workspace = 7;
        "Mod+Ctrl+8".action.move-column-to-workspace = 8;
        "Mod+Ctrl+9".action.move-column-to-workspace = 9;

        # Consume/expel windows
        "Mod+BracketLeft".action.consume-or-expel-window-left = [ ];
        "Mod+BracketRight".action.consume-or-expel-window-right = [ ];
        "Mod+Comma".action.consume-window-into-column = [ ];
        "Mod+Period".action.expel-window-from-column = [ ];

        # Column/window sizing
        "Mod+R".action.switch-preset-column-width = [ ];
        "Mod+Shift+R".action.switch-preset-window-height = [ ];
        "Mod+Ctrl+R".action.reset-window-height = [ ];
        "Mod+S".action.maximize-column = [ ];
        "Mod+Shift+S".action.fullscreen-window = [ ];
        "Mod+Ctrl+S".action.expand-column-to-available-width = [ ];
        "Mod+T".action.center-column = [ ];
        "Mod+Ctrl+T".action.center-visible-columns = [ ];

        # Fine width adjustments
        "Mod+Minus".action.set-column-width = "-10%";
        "Mod+Equal".action.set-column-width = "+10%";
        "Mod+Shift+Minus".action.set-window-height = "-10%";
        "Mod+Shift+Equal".action.set-window-height = "+10%";

        # Floating windows
        "Mod+F".action.toggle-window-floating = [ ];
        "Mod+Shift+F".action.switch-focus-between-floating-and-tiling = [ ];

        # Toggle tabbed display
        "Mod+W".action.toggle-column-tabbed-display = [ ];

        # Screenshots
        "Mod+P".action.screenshot = [ ];
        "Mod+Ctrl+P".action.screenshot-screen = [ ];
        "Mod+Alt+P".action.screenshot-window = [ ];

        # # Toggle keyboard shortcuts inhibitor
        # "Mod+Escape" = {
        #   action.toggle-keyboard-shortcuts-inhibit = [];
        #   allow-inhibiting = false;
        # };

        # Quit
        "Mod+Shift+E".action.quit = [ ];
        "Ctrl+Alt+Delete".action.quit = [ ];

        # Power off monitors
        # "Mod+Shift+P".action.power-off-monitors = [];
      };
    };
  };
}

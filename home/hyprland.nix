{
  hyprland,
  hyprland-plugins,
  config,
  pkgs,
  pc,
  ...
}: {
  programs.wofi = {
    enable = true;
    settings = {
      allow_markup = true;
      gtk_dark = true;
      allow_images = true;
    };

    style = ''
      * {
          font-family: monospace;
      }
      #window {
          border-bottom-radius: 15px;
      }

      #img {
          padding: 10px;
          border-radius: 10px;
      }
      #input {
          font-size: 2rem;
      }
    '';
  };
  wayland = {
    windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      plugins = [
      ];
      xwayland.enable = true;
      settings = {
        general = {
          gaps_in = 3;
          gaps_out = 5;
        };
        decoration = {
          rounding = 0;
          inactive_opacity = 0.85;
        };
        misc = {
          disable_splash_rendering = true;
          force_default_wallpaper = 1;
          disable_hyprland_logo = true;
          animate_manual_resizes = true;
          animate_mouse_windowdragging = true;
        };
        exec-once = [
          "waybar"
          "hyprpaper"
          "exec-once = clipse -listen"
        ];
        dwindle = {
          pseudotile = true;
          smart_split = true;
          preserve_split = true;
        };
        settings = {
          "$mod" = "SUPER";
          "$term" = "ghostty";
          "env" = [
            "HYPRCURSOR_THEME,phinger-cursors-light"
            "HYPRCURSOR_SIZE,32"
          ];
          monitor =
            if pc == "workdesktop"
            then [
              "DP-2, 3440x1440@165.00, 0x0, 1"
              "DP-1, 2560x1440@143.86, 3440x0, 1"
            ]
            else
              []
              ++ (
                if pc == "homedesktop"
                then [
                  "DP-2, 2560x1440@170.00, 0x0, 1"
                  "HDMI-A-2, 1920x1080@60.00, 2560x0, 1"
                ]
                else []
              );
          workspace =
            [
              "special:notes, on-created-empty:rnote"
            ]
            ++ (
              if pc == "workdesktop"
              then [
                "1, monitor:DP-2"
                "2, monitor:DP-1"
              ]
              else []
            );
          windowrulev2 = [
            "float,class:(clipse)"
            "size 622 652,class:(clipse)"
          ];
          bind =
            [
              # Commands
              "$mod, Q, exec, $term"
              "$mod, O, exec, wofi --show drun"
              "$mod, C, killactive"
              "$mod, P, pseudo"
              "$mod, V, layoutmsg, togglesplit"
              "$mod SHIFT, S, exec, grim -g \"$(slurp)\" - | wl-copy"
              "$mod SHIFT, V, layoutmsg, swapsplit"
              "CTRL ALT, L, exec, hyprlock"
              "$mod, A, togglespecialworkspace, notes"
              "$mod CTRL, V, exec, $term --class clipse -e clipse"
              "${
                if pc == "workdesktop" || pc == "worklaptop"
                then "$mod, N, exec, cd ~/Code/uxstream/ && neovide --fork ."
                else "$mod, N, exec, notify-send 'cannot open uxstream workspace'"
              }"

              # Manage view
              "$mod, S, fullscreen"
              "$mod, F, togglefloating"
              # Move focus
              "$mod, h, movefocus, l"
              "$mod, j, movefocus, d"
              "$mod, k, movefocus, u"
              "$mod, l, movefocus, r"
              # Move windows
              "$mod SHIFT, h, movewindow, l"
              "$mod SHIFT, j, movewindow, d"
              "$mod SHIFT, k, movewindow, u"
              "$mod SHIFT, l, movewindow, r"
              # Resize windows
              "$mod CTRL, h, resizeactive, -50 0"
              "$mod CTRL, j, resizeactive, 0 50"
              "$mod CTRL, k, resizeactive, 0 -50"
              "$mod CTRL, l, resizeactive, 50 0"
            ]
            ++ (
              # workspaces
              # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
              builtins.concatLists (builtins.genList
                (
                  x: let
                    ws = let
                      c = (x + 1) / 10;
                    in
                      builtins.toString (x + 1 - (c * 10));
                  in [
                    "$mod, ${ws}, workspace, ${toString (x + 1)}"
                    "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
                  ]
                )
                10)
            );
          bindm = [
            # mouse movements
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
            "$mod ALT, mouse:272, resizewindow"
          ];
          bezier = [
            "overshot,0.05,0.9,0.1,1.1"
            "ease,0.33, 1, 0.68, 1"
          ];
          animation = [
            "workspaces,1,2.5,ease,slidefadevert"
            "windows,1,3.0,overshot,gnomed"
          ];
        };
      };
    };
  };
  services.hyprpaper =
    if pc == "workdesktop"
    then let
      wallpaper = "~/.nixos/assets/wallpapers/workdesktop";
    in {
      enable = true;
      settings = {
        ipc = "on";
        splash = false;
        preload = ["${wallpaper}-1.png" "${wallpaper}-2.jpg"];
        wallpaper = [
          "DP-2,${wallpaper}-1.png"
          "DP-1,${wallpaper}-2.jpg"
        ];
      };
    }
    else if pc == "homedesktop"
    then let
      wallpaper = "~/.nixos/assets/wallpapers/homedesktop";
    in {
      enable = true;
      settings = {
        ipc = "on";
        splash = "false";
        preload = ["${wallpaper}-1.jpg" "${wallpaper}-2.jpg"];
        wallpaper = [
          "DP-2,${wallpaper}-1.jpg"
          "HDMI-A-2,${wallpaper}-2.jpg"
        ];
      };
    }
    else let
      wallpaper_path = "~/.nixos/assets/wallpapers/${pc}.png";
      display =
        if pc == "worklaptop"
        then "eDP-1"
        else "DP-2";
    in {
      enable = true;
      settings = {
        ipc = "on";
        splash = false;
        # splash_offset = 2.0;

        preload = [wallpaper_path];

        wallpaper = [
          "${display},${wallpaper_path}"
        ];
      };
    };
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        grace = 5;
        no_fade_in = true;
        no_fade_out = true;
      };

      background = {
        monitor = "";
        path = "screenshot";
        color = "rgb(40, 44, 52)"; # Default background color

        blur_size = 4;
        blur_passes = 3;
        noise = 0.0117;
        contrast = 1.3;
        brightness = 0.8;
        vibrancy = 0.21;
        vibrancy_darkness = 0.0;
      };

      input-field = [
        {
          monitor = "";
          size = "250, 50";
          outline_thickness = 3;
          dots_size = 0.2; # Scale of input-field height, 0.2 - 0.8
          dots_spacing = 0.64; # Scale of dots' absolute size, 0.0 - 1.0
          dots_center = true;
          outer_color = "rgb(98, 114, 164)"; # Default accent color
          inner_color = "rgb(40, 44, 52)"; # Default background color
          font_color = "rgb(248, 248, 242)"; # Default foreground color
          fade_on_empty = true;
          placeholder_text = "Password..."; # Text rendered in the input box when it's empty.
          position = "0, 80";
          halign = "center";
          valign = "bottom";
        }
      ];

      label = [
        # Current time
        {
          monitor = "";
          # text = ''cmd[update:1000] echo "<b><big> $(date +"%H:%M:%S") </big></b>"'';
          text = "brb :)";
          color = "rgb(248, 248, 242)"; # Default foreground color
          font_size = 64;
          font_family = "Sans"; # Default font
          position = "0, 16";
          halign = "center";
          valign = "center";
        }
        # User label
        {
          monitor = "";
          # text = ''Hey <span text_transform="capitalize" size="larger">$USER</span>'';
          text = "";
          color = "rgb(248, 248, 242)"; # Default foreground color
          font_size = 24; # Default font size
          font_family = "Sans"; # Default font
          position = "0, 0";
          halign = "center";
          valign = "center";
        }
        # Type to unlock
        {
          monitor = "";
          text = "Type to unlock!";
          color = "rgb(248, 248, 242)"; # Default foreground color
          font_size = 24; # Default font size
          font_family = "Sans"; # Default font
          position = "0, 30";
          halign = "center";
          valign = "bottom";
        }
      ];
    };
  };
}

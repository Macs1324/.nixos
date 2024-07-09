{
  config,
  pkgs,
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
      settings = {
        settings = {
          "$mod" = "SUPER";
          "$term" = "alacritty";
          bind =
            [
              "$mod, Q, exec, $term"
              "$mod, O, exec, wofi --show drun"
              "$mod, C, killactive"
            ]
            ++ (
              # workspaces
              # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
              builtins.concatLists (builtins.genList (
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
            "workspaces,1,4,ease,slidevert"
            "windows,1,4.5,overshot,slide"
          ];
        };
      };
    };
  };
}

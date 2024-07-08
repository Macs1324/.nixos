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
      image_size = 48;
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
          bind =
            [
              "$mod, Q, exec, kitty"
              "$mod, O, exec, wofi --show drun"
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
        };
      };
    };
  };
}

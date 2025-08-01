{
  config,
  pkgs,
  ...
}: {
  programs.wlogout = {
    enable = true;
    layout = [
      {
        label = "lock";
        action = "sleep .5 && hyprlock";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "hyprctl dispatch exit";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "hibernate";
        action = "systemctl hibernate";
        text = "Hibernate";
        keybind = "h";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
    ];

    style = ''
      /* Global reset */
      * {
        background-image: none;
      }

      /* Window - modern dark background with subtle transparency */
      window {
        background-color: rgba(46, 52, 64, 0.95);
        font-family: "Inter", "Hack Nerd Font Mono", monospace;
      }

      /* Button base - elegant cards with subtle borders */
      button {
        background-color: rgba(67, 76, 94, 0.8);
        color: #${config.lib.stylix.colors.base05};
        border: 2px solid rgba(129, 161, 193, 0.2);
        border-radius: 16px;
        padding: 24px;
        margin: 12px;
        min-width: 140px;
        min-height: 140px;
        font-size: 11pt;
        font-weight: 500;
        background-repeat: no-repeat;
        background-position: center center;
        background-size: 48px 48px;
      }

      /* Hover state - subtle highlight with Nord blue accent */
      button:hover {
        background-color: rgba(129, 161, 193, 0.15);
        border-color: rgba(129, 161, 193, 0.6);
        color: #${config.lib.stylix.colors.base07};
      }

      /* Focus state for keyboard navigation */
      button:focus {
        background-color: rgba(129, 161, 193, 0.12);
        border-color: rgba(129, 161, 193, 0.8);
        color: #${config.lib.stylix.colors.base07};
      }

      /* Individual button icons using GTK image() function */
      #lock {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
      }

      #logout {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
      }

      #suspend {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/suspend.png"));
      }

      #hibernate {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/hibernate.png"));
      }

      /* Shutdown - red accent for dangerous action */
      #shutdown {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
        border-color: rgba(191, 97, 106, 0.3);
      }

      #shutdown:hover {
        background-color: rgba(191, 97, 106, 0.15);
        border-color: rgba(191, 97, 106, 0.7);
        color: #${config.lib.stylix.colors.base07};
      }

      #shutdown:focus {
        background-color: rgba(191, 97, 106, 0.12);
        border-color: rgba(191, 97, 106, 0.8);
        color: #${config.lib.stylix.colors.base07};
      }

      /* Reboot - orange accent for caution */
      #reboot {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
        border-color: rgba(208, 135, 112, 0.3);
      }

      #reboot:hover {
        background-color: rgba(208, 135, 112, 0.15);
        border-color: rgba(208, 135, 112, 0.7);
        color: #${config.lib.stylix.colors.base07};
      }

      #reboot:focus {
        background-color: rgba(208, 135, 112, 0.12);
        border-color: rgba(208, 135, 112, 0.8);
        color: #${config.lib.stylix.colors.base07};
      }
    '';
  };
}

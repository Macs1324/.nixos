{
  hyprland,
  hyprland-plugins,
  config,
  pkgs,
  pc,
  ...
}: {
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "left";
        width = 40;
        margin = "5 0 5 5";
        spacing = 4;

        modules-left = ["custom/launcher"];
        modules-center = ["hyprland/workspaces"];
        modules-right = [
          "pulseaudio"
          "cpu"
          "memory"
          "temperature"
          "battery"
          "tray"
          "clock"
          "custom/power"
        ];

        "custom/launcher" = {
          "format" = "󱄅";
          "tooltip" = false;
          "on-click" = "wofi --show drun";
        };

        "hyprland/workspaces" = {
          "format" = "{icon}";
          "format-icons" = {
            "1" = "א";
            "2" = "ב";
            "3" = "ג";
            "4" = "ד";
            "5" = "ה";
            "6" = "ו";
            "7" = "ז";
            "8" = "ח";
            "9" = "ט";
            "10" = "י";
          };
          "on-click" = "activate";
          "show-special" = false;
          "all-outputs" = false;
        };

        "pulseaudio" = {
          "format" = "{icon}";
          "format-muted" = "󰝟";
          "format-icons" = {
            "headphone" = "󰋋";
            "hands-free" = "󰋋";
            "headset" = "󰋋";
            "phone" = "";
            "portable" = "";
            "car" = "";
            "default" = ["󰕿" "󰖀" "󰕾"];
          };
          "tooltip-format" = "{volume}% {desc}";
          "on-click" = "pavucontrol";
          "on-scroll-up" = "pamixer -i 5";
          "on-scroll-down" = "pamixer -d 5";
        };

        "cpu" = {
          "format" = "󰻠";
          "tooltip-format" = "CPU: {usage}%";
          "interval" = 2;
        };

        "memory" = {
          "format" = "󰍛";
          "tooltip-format" = "RAM: {percentage}%\n{used:0.1f}G/{total:0.1f}G";
          "interval" = 2;
        };

        "temperature" = {
          "hwmon-path" = "/sys/class/hwmon/hwmon2/temp1_input";
          "format" = "󰔏";
          "tooltip-format" = "Temp: {temperatureC}°C";
          "critical-threshold" = 80;
          "format-critical" = "󰸁";
        };

        "battery" = {
          "states" = {
            "warning" = 30;
            "critical" = 15;
          };
          "format" = "{icon}";
          "format-charging" = "󰂄";
          "format-plugged" = "󰂄";
          "format-icons" = ["󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
          "tooltip-format" = "Battery: {capacity}%";
        };

        "tray" = {
          "icon-size" = 16;
          "spacing" = 5;
        };

        "clock" = {
          "format" = "{:%H\n%M}";
          "tooltip-format" = "{:%A %d %B %Y}";
          "on-click" = "gnome-calendar";
        };

        "custom/power" = {
          "format" = "󰐥";
          "tooltip" = "Power menu";
          "on-click" = "wlogout";
        };
      };
    };

    style = let
      colors = config.lib.stylix.colors;
    in ''
      * {
        font-family: monospace;
        font-size: 12px;
        min-height: 0;
      }

      window#waybar {
        background: alpha(#${colors.base00}, 0.9);
        border-radius: 15px;
        color: #${colors.base05};
        transition-property: background-color;
        transition-duration: 0.3s;
      }

      #workspaces button {
        all: unset;
        padding: 12px 0;
        margin: 2px 0;
        border-radius: 8px;
        background: transparent;
        color: #${colors.base07};
        border: 2px solid transparent;
        font-size: 20px;
        font-weight: bold;
        transition: all 0.3s ease;
      }

      #workspaces button:hover {
        background: alpha(#${colors.base07}, 0.1);
        color: #${colors.base07};
      }

      window#waybar #workspaces button.active {
        background: transparent;
        color: #${colors.base07};
        border: 2px solid #${colors.base0D};
        font-weight: bold;
      }

      window#waybar #workspaces button.focused {
        background: transparent;
        color: #${colors.base07};
        border: 2px solid #${colors.base0D};
        font-weight: bold;
      }

      window#waybar #workspaces button.persistent {
        background: transparent;
        color: #${colors.base07};
        border: 2px solid #${colors.base0D};
        font-weight: bold;
      }

      window#waybar #workspaces button.current_output {
        background: transparent;
        color: #${colors.base07};
        border: 2px solid #${colors.base0D};
        font-weight: bold;
      }

      #workspaces button.urgent {
        background: #${colors.base08};
        color: #${colors.base05};
        animation: blink 0.5s linear infinite alternate;
      }

      @keyframes blink {
        to {
          background: alpha(#${colors.base08}, 0.5);
        }
      }

      #custom-launcher:hover {
        background: alpha(#${colors.base0E}, 0.2);
        border-radius: 8px;
      }

      #custom-power:hover {
        background: alpha(#${colors.base08}, 0.2);
        border-radius: 8px;
      }

      #pulseaudio,
      #cpu,
      #memory,
      #temperature,
      #battery,
      #tray,
      #clock,
      #custom-power {
        padding: 8px 0;
        margin: 1px 0;
        background: transparent;
        color: #${colors.base05};
        font-size: 16px;
        transition: all 0.3s ease;
      }

      #custom-launcher:hover,
      #pulseaudio:hover,
      #cpu:hover,
      #memory:hover,
      #temperature:hover,
      #battery:hover,
      #clock:hover,
      #custom-power:hover {
        background: alpha(#${colors.base03}, 0.8);
      }

      #custom-launcher {
        background: transparent;
        color: #${colors.base0E};
        font-size: 24px;
        padding: 12px 0;
      }

      #pulseaudio.muted {
        color: #${colors.base08};
      }

      #cpu.warning {
        color: #${colors.base0A};
      }

      #cpu.critical {
        color: #${colors.base08};
      }

      #memory.warning {
        color: #${colors.base0A};
      }

      #memory.critical {
        color: #${colors.base08};
      }

      #temperature.critical {
        color: #${colors.base08};
        animation: blink 0.5s linear infinite alternate;
      }

      #battery.charging {
        color: #${colors.base0B};
      }

      #battery.warning:not(.charging) {
        color: #${colors.base0A};
      }

      #battery.critical:not(.charging) {
        color: #${colors.base08};
        animation: blink 0.5s linear infinite alternate;
      }

      #clock {
        font-weight: bold;
        font-size: 14px;
      }

      #custom-power {
        background: transparent;
        color: #${colors.base08};
        font-size: 20px;
        padding: 10px 0;
      }

      #tray menu {
        background: alpha(#${colors.base00}, 0.95);
        border-radius: 8px;
        border: 1px solid alpha(#${colors.base03}, 0.3);
      }
    '';
  };
}

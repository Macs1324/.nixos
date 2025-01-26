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
        width = 30;

        modules-left = ["hyprland/workspaces"];
        modules-right = ["clock"];

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
            "active" = "";
            "default" = "";
          };
        };
      };
    };
  };
}

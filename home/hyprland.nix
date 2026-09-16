{
  pkgs,
  inputs,
  ...
}: {
  imports = [./wofi.nix ./hyprlock.nix];
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
    settings.config = {
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
      dwindle = {
        smart_split = true;
        preserve_split = true;
      };
    };
    # Native Lua keeps dispatcher arguments and ordering explicit. Host-specific
    # monitors and workspace rules come from the shared monitor adapter.
    extraConfig = builtins.readFile ./hyprland.lua;
  };
}

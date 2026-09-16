{lib, ...}: {
  imports = [../../home];
  desktop.monitors = import ./monitors.nix;
  wayland.windowManager.hyprland.settings = {
    bind = [
      {
        _args = [
          "SUPER + N"
          (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("cd ~/Code/uxstream/ && neovide --fork .")'')
        ];
      }
    ];
  };
}

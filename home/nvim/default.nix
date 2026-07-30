{
  config,
  pkgs,
  ...
}: let
  # Import all modules from the modules directory
  moduleDir = ./modules;
  moduleFiles = builtins.readDir moduleDir;
  nixFiles = builtins.filter (name: builtins.match ".*\\.nix$" name != null) (
    builtins.attrNames moduleFiles
  );

  # Import each module and merge them
  modules = map (file: import (moduleDir + "/${file}") {inherit pkgs config;}) nixFiles;

  # Merge all modules into one configuration
  mergedConfig =
    builtins.foldl'
    (acc: module: {
      plugins = acc.plugins // (module.plugins or {});
      extraConfigLua = acc.extraConfigLua + (module.extraConfigLua or "");
      keymaps = acc.keymaps ++ (module.keymaps or []);
      opts = acc.opts // (module.opts or {});
    })
    {
      plugins = {};
      extraConfigLua = "";
      keymaps = [];
      opts = {};
    }
    modules;
in {
  programs.nixvim = {
    enable = true;
    globals.mapleader = " ";
    # Neovide reads opacity during its initial UI setup. Keep this as an early
    # global instead of setting it from the later extraConfigLua block.
    globals.neovide_opacity = 0.8;

    # Enable nord colorscheme
    colorschemes.nord.enable = true;

    clipboard = {
      providers.wl-copy.enable = true; # for Wayland
      register = "unnamedplus";
    };

    # Merge in all module configurations
    plugins = mergedConfig.plugins;
    extraConfigLua = mergedConfig.extraConfigLua;
    keymaps = mergedConfig.keymaps;
    opts = mergedConfig.opts;

    extraLuaPackages = ps: [ps.magick];
    extraPackages = [pkgs.imagemagick];
  };

  # Settings that must be known before Neovim starts belong in Neovide's own
  # config. Runtime and keybinding settings live in modules/neovide.nix.
  xdg.configFile."neovide/config.toml".text = ''
    fork = true
    frame = "full"
    idle = true
    startup-message-capture = true
    tabs = false
    title-hidden = false
    vsync = true
    wayland-app-id = "neovide"

    [font]
    normal = ["JetBrainsMono Nerd Font"]
    size = 14.0
  '';
}

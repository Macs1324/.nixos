{
  config,
  pkgs,
  pc,
  ...
}: let
  # Import all modules from the modules directory
  moduleDir = ./modules;
  moduleFiles = builtins.readDir moduleDir;
  nixFiles = builtins.filter (name: builtins.match ".*\\.nix$" name != null) (builtins.attrNames moduleFiles);

  # Import each module and merge them
  modules = map (file: import (moduleDir + "/${file}") {inherit pkgs config;}) nixFiles;

  # Merge all modules into one configuration
  mergedConfig =
    builtins.foldl' (acc: module: {
      plugins = acc.plugins // (module.plugins or {});
      extraConfigLua = acc.extraConfigLua + (module.extraConfigLua or "");
      keymaps = acc.keymaps ++ (module.keymaps or []);
      opts = acc.opts // (module.opts or {});
    }) {
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

    colorschemes.nord = {
      enable = true;
      autoLoad = true;
      settings = {
        disable_background = true;
        cursorline_transparent = true;
      };
    };
    clipboard = {
      providers.wl-copy.enable = true; # for Wayland
      register = "unnamedplus";
    };

    # Merge in all module configurations
    plugins = mergedConfig.plugins;
    extraConfigLua = mergedConfig.extraConfigLua;
    keymaps = mergedConfig.keymaps;
    opts = mergedConfig.opts;
  };
}

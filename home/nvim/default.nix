{pkgs, ...}: {
  programs.nixvim = {
    imports = [
      ./modules/completion.nix
      ./modules/file-explorer.nix
      ./modules/finder.nix
      ./modules/git.nix
      ./modules/lsp.nix
      ./modules/markdown.nix
      ./modules/navigation.nix
      ./modules/neovide.nix
      ./modules/rust.nix
      ./modules/treesitter.nix
      ./modules/ui.nix
      ./modules/ux.nix
    ];
    enable = true;
    nixpkgs.useGlobalPackages = true;
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

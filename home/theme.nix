{pkgs, ...}: {
  stylix.enable = true;
  stylix.autoEnable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";

  stylix.fonts = {
    monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };
    sizes.terminal = 14;
  };

  stylix.opacity.terminal = 0.78;

  stylix.targets.nixvim.enable = false;
  stylix.targets.zen-browser.enable = false;
  stylix.targets.hyprlock.enable = false;
  stylix.targets.firefox.profileNames = ["default"];

  home.pointerCursor = {
    enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    # Generates HYPRCURSOR_THEME/HYPRCURSOR_SIZE instead of hand-written env lines.
    hyprcursor = {
      enable = true;
      size = 24;
    };
  };
}

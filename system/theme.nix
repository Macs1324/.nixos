{pkgs, ...}: {
  imports = [../modules/theme.nix];

  stylix.targets.kmscon.enable = false;
  # This target overlays gtksourceview, which changes the hash of everything
  # built on it (Inkscape and friends) and forces source builds on every palette
  # change. Home Manager's gtksourceview target installs the same style per user.
  stylix.targets.gtksourceview.enable = false;

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.ubuntu-mono
    nerd-fonts.jetbrains-mono
    meslo-lgs-nf
    inter
  ];
}

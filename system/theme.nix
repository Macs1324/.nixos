{pkgs, ...}: {
  stylix.enable = true;
  stylix.autoEnable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
  stylix.targets.kmscon.enable = false;

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.ubuntu-mono
    nerd-fonts.jetbrains-mono
    meslo-lgs-nf
    inter
  ];
}

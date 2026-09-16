{pkgs, ...}: {
  imports = [./development.nix];
  environment.systemPackages = with pkgs; [android-studio sqlitebrowser];
}

{
  config,
  lib,
  pkgs,
  ...
}: {
  nixpkgs.config.allowUnfree = true;
  programs.adb.enable = true;
  environment.systemPackages = with pkgs; [
    gpt4all-cuda
    android-studio
  ];
}

{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../system
    ../../system/work.nix
    ../../system/games.nix
  ];
  networking.hostName = "homedesktop";

  boot.initrd.kernelModules = ["amdgpu"];
  hardware.graphics = {
    enable32Bit = true;
    extraPackages = [pkgs.rocmPackages.clr.icd];
  };
  systemd.tmpfiles.rules = ["L+ /opt/rocm/hip - - - - ${pkgs.rocmPackages.clr}"];
}

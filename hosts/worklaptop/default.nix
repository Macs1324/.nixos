{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../system
    ../../system/work.nix
  ];
  networking.hostName = "worklaptop";
  environment.systemPackages = [pkgs.discord];
}

{pkgs, ...}: {
  imports = [
    ../../system
    ../../system/work.nix
  ];
  networking.hostName = "worklaptop";
  environment.systemPackages = [pkgs.discord];
}

{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../system
    ../../system/work.nix
    ../../system/laptop.nix
  ];
  networking.hostName = "worklaptop";
  desktop.monitors = import ./monitors.nix;

  # Iris Xe (Raptor Lake-P): without the iHD driver VA-API fails to initialise
  # and every video is decoded on the CPU.
  hardware.graphics.extraPackages = [
    pkgs.intel-media-driver
    pkgs.vpl-gpu-rt
  ];
}

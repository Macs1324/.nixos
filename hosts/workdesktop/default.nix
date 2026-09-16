{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../system
    ../../system/work.nix
  ];
  networking.hostName = "workdesktop";
  desktop.monitors = import ./monitors.nix;

  # Arc B60: retain the kernel and force-probe workaround from this machine.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = ["xe.force_probe=e211"];
  boot.initrd.kernelModules = ["xe"];
  hardware.graphics = {
    enable32Bit = true;
    extraPackages = with pkgs; [intel-media-driver intel-compute-runtime vpl-gpu-rt];
    extraPackages32 = [pkgs.pkgsi686Linux.intel-media-driver];
  };
  # Let Mesa/Vulkan discover the available GPUs and both ABI driver sets.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
  environment.systemPackages = with pkgs; [intel-gpu-tools];
}

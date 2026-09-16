{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../system
    ../../system/work.nix
  ];
  networking.hostName = "worklaptop";
  desktop.monitors = import ./monitors.nix;
}

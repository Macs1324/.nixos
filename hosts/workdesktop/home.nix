{...}: {
  imports = [../../home];
  desktop.monitors = import ./monitors.nix;
  programs.ssh.includes = ["config-autogen"];
}

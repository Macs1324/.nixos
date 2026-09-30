{...}: {
  imports = [../../home];
  desktop.monitors = import ./monitors.nix;
  programs.ssh.includes = ["config-autogen"];

  # The company logo emerges from the lock screen's storm on both monitors.
  programs.sandlock.settings.attractor = let
    logo = output: width: {
      image = ../../assets/uxstream-logo.png;
      inherit output width;
      position = [0.5 0.35];
    };
  in [
    (logo "DP-1" 1400)
    (logo "HDMI-A-2" 1050)
  ];
}

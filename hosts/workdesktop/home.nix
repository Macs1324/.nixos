{config, ...}: {
  imports = [../../home];
  desktop.monitors = import ./monitors.nix;
  programs.ssh.includes = ["config-autogen"];

  # The company logo emerges from the lock screen's storm on the main monitor;
  # the right one plays Conway's Game of Life with the NixOS snowflake drawn
  # over it (later attractors win where they overlap).
  programs.sandlock.settings.attractor = [
    {
      image = ../../assets/uxstream-logo.png;
      output = "DP-1";
      width = 1400;
      position = [0.5 0.35];
    }
    {
      life = {};
      output = "HDMI-A-2";
      color = config.lib.stylix.colors.withHashtag.base09;
      # Generations change every 1.5 s: form fast, hold firm.
      emerge = 0.6;
      firmness = 0.7;
    }
    {
      image = ../../assets/logo.png;
      output = "HDMI-A-2";
      width = 600;
      position = [0.5 0.5];
    }
  ];
}

{config, ...}: {
  imports = [
    ../../home
    ../../home/discord.nix
    ../../home/spotify.nix
  ];
  desktop.monitors = import ./monitors.nix;
  ai.claude.profile = "personal";

  # Beside the clock (home/sandlock.nix): the NixOS snowflake emerges above
  # it, centred on the main monitor, and Conway's Game of Life plays out
  # across the pixel-art one, its cells made of the desktop's own grains.
  programs.sandlock.settings.attractor = [
    {
      image = ../../assets/logo.png;
      output = "DP-2";
      # Centred across, above the clock (the default position).
      width = 340;
      # Its surroundings are mostly near-black: reach far for light grains,
      # and ask for the logo's own blues rather than the dark desktop's range.
      reach = 500;
      tone = "absolute";
    }
    {
      life = {};
      output = "HDMI-A-2";
      # This palette's accents are nearly all the clock's colour; base09
      # is the one that differs.
      color = config.lib.stylix.colors.withHashtag.base09;
      # Generations change every 1.5 s: form fast, hold firm.
      emerge = 0.6;
      firmness = 0.7;
    }
  ];
}

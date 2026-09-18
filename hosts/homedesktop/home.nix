{...}: {
  imports = [
    ../../home
    ../../home/discord.nix
    ../../home/spotify.nix
  ];
  desktop.monitors = import ./monitors.nix;
  ai.claude.profile = "personal";
}

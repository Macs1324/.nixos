{...}: {
  imports = [
    ../../home
    ../../home/discord.nix
  ];
  desktop.monitors = import ./monitors.nix;
}

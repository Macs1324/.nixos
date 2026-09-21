{...}: {
  imports = [
    ../../home
    ../../home/discord.nix
    ../../home/laptop.nix
  ];
  desktop.monitors = import ./monitors.nix;
}

{
  pkgs,
  noctalia,
  ...
}: {
  # install package
  environment.systemPackages = with pkgs; [
    noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    # ... maybe other stuff
  ];
}

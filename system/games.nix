{pkgs, ...}: {
  programs.steam.enable = true;
  hardware.xpadneo.enable = true;
  boot.extraModprobeConfig = "options bluetooth disable_ertm=Y";
  environment.systemPackages = with pkgs; [
    discord
    webcord
    prismlauncher
    spotify
    davinci-resolve
  ];
}

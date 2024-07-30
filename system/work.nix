{
  config,
  lib,
  pkgs,
  pc,
  ...
}: {
  nixpkgs.config.allowUnfree = true;
  programs.adb.enable = true;
  environment.systemPackages = with pkgs;
    [
      android-studio
      redis
    ]
    ++ (
      if pc == "workdesktop"
      then [
        gpt4all-cuda
      ]
      else []
    );

  services.redis.servers."uxstream" = {
    enable = true;
    port = 6379;
  };

  networking = {
    interfaces.wlp0s20f3.ipv4.addresses = [
      {
        address = "192.168.1.32";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.1.1";
    nameservers = ["8.8.8.8"];
  };
}

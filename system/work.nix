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
      sqlitebrowser
    ]
    ++ (
      {
        "workdesktop" = [
        ];
        "worklaptop" = [
          discord
        ];
        "homedesktop" = [
        ];
      }
      .${
        pc
      }
    );

  services.redis.servers."uxstream" = {
    enable = true;
    port = 6379;
  };
}

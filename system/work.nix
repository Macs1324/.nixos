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
      {
        "workdesktop" = [
          gpt4all-cuda
        ];
        "worklaptop" = [
          discord
        ];
      }
      .${pc}
    );

  services.redis.servers."uxstream" = {
    enable = true;
    port = 6379;
  };
}

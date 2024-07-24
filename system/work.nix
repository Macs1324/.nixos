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

  services.redis.servers."uxstream".enable = true;
}

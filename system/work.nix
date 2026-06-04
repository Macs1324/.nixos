{
  config,
  lib,
  pkgs,
  pc,
  ...
}: {
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs;
    [
      android-studio
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
}

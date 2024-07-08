{config, lib, pkgs, ...}:
{
    nixpkgs.config.allowUnfree = true;
    programs.steam.enable = true;
}

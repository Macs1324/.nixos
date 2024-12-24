{
  description = "Macs1324 flake config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    hyprland-qtutils.url = "github:hyprwm/hyprland-qtutils";
    hyprcursor-phinger.url = "github:jappie3/hyprcursor-phinger";
    zen-browser.url = "github:MarceColl/zen-browser-flake";
  };

  outputs = {
    self,
    hyprland,
    hyprland-plugins,
    hyprland-qtutils,
    nixpkgs,
    home-manager,
    hyprcursor-phinger,
    zen-browser,
    ...
  }: let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    pkgs = nixpkgs.legacyPackages.${system};

    pcs = {
      worklaptop = "worklaptop";
      workdesktop = "workdesktop";
      homedesktop = "homedesktop";
    };
    pc = lib.strings.removeSuffix "\n" "${builtins.readFile ./pc}";
  in {
    nixosConfigurations = {
      nixos = lib.nixosSystem {
        inherit system;
        modules = [./configuration.nix];
        specialArgs = {
          inherit pc zen-browser;
        };
      };
    };
    homeConfigurations = {
      macs = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [./home.nix];
        extraSpecialArgs = {
          inherit pc hyprland hyprland-plugins hyprcursor-phinger hyprland-qtutils;
        };
      };
    };
  };
}

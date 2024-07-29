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
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
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
          inherit pc;
        };
      };
    };
    homeConfigurations = {
      macs = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [./home.nix];
        extraSpecialArgs = {
          inherit pc;
        };
      };
    };
  };
}

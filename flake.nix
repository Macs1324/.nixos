{
  description = "Macs1324 flake config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-qtutils.url = "github:hyprwm/hyprland-qtutils";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      # If using a stable channel you can use `url = "github:nix-community/nixvim/nixos-<version>"`
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    hyprland,
    hyprland-qtutils,
    nixpkgs,
    home-manager,
    zen-browser,
    stylix,
    nixvim,
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
        modules = [
          stylix.nixosModules.stylix
          ./configuration.nix
        ];
        specialArgs = {
          inherit pc zen-browser hyprland;
        };
      };
    };
    homeConfigurations = {
      macs = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          stylix.homeModules.stylix
          nixvim.homeModules.nixvim
          ./home.nix
        ];
        extraSpecialArgs = {
          inherit
            pc
            hyprland
            hyprland-qtutils
            stylix
            ;
        };
      };
    };
  };
}

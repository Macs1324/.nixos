{
  description = "Macs1324 flake config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-qtutils.url = "github:hyprwm/hyprland-qtutils";

    niri.url = "github:sodiboo/niri-flake";
    niri.inputs.nixpkgs.follows = "nixpkgs";

    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

  outputs = inputs @ {
    nixpkgs,
    home-manager,
    ...
  }: let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    hosts = ["workdesktop" "worklaptop" "homedesktop"];
    pkgs = import nixpkgs {
      inherit system;
      config = import ./lib/nixpkgs-config.nix;
    };
  in {
    nixosConfigurations = lib.genAttrs hosts (host:
      lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules = [
          inputs.stylix.nixosModules.stylix
          inputs.niri.nixosModules.niri
          (./hosts + "/${host}")
        ];
      });

    homeConfigurations = lib.genAttrs (map (host: "macs@${host}") hosts) (name: let
      host = lib.removePrefix "macs@" name;
    in
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {inherit inputs;};
        modules = [
          inputs.stylix.homeModules.stylix
          inputs.nixvim.homeModules.nixvim
          inputs.zen-browser.homeModules.default
          inputs.niri.homeModules.niri
          inputs.noctalia.homeModules.default
          (./hosts + "/${host}/home.nix")
        ];
      });

    # Flake checking normally ignores custom homeConfigurations outputs.
    checks.${system} =
      lib.genAttrs (map (host: "home-${host}") hosts) (name:
        inputs.self.homeConfigurations."macs@${lib.removePrefix "home-" name}".activationPackage)
      // {
        monitor-model = import ./tests/monitors.nix {inherit lib pkgs;};
        helper-tests =
          pkgs.runCommand "workstation-helper-tests" {
            nativeBuildInputs = [
              (pkgs.python3.withPackages (ps: [ps.tomlkit]))
              pkgs.bash
              pkgs.just
            ];
          } ''
            cp -r ${./scripts} scripts
            cp -r ${./tests} tests
            cp ${./Justfile} Justfile
            python -B -m unittest discover -s tests
            touch $out
          '';
      };

    formatter.${system} = pkgs.alejandra;
  };
}

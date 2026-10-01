{
  description = "Macs1324 flake config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # The three below deliberately do NOT follow nixpkgs. Their binary caches only
    # hold builds made against each flake's own nixpkgs pin, so a `follows` line
    # changes the derivation hash and turns every cache hit into a local compile.
    # The cost is carrying a few extra nixpkgs revisions in the store; the benefit
    # is not building a compositor by hand. See system/base.nix for the caches.
    hyprland.url = "github:hyprwm/Hyprland";

    niri.url = "github:sodiboo/niri-flake";

    # The `cachix` branch always points at the newest commit CI has finished
    # caching, unlike `main`, which can run ahead of it.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Weekly prebuilt nix-index database, used by comma and command-not-found.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # GRUB themes with a NixOS module (boot.loader.grub2-theme).
    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tracks Claude Code releases within hours; nixpkgs lags by days.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
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
    # A host only becomes buildable once its machine has imported its hardware
    # file with `just hardware <host>`; see scripts/import-hardware.sh.
    hardwareFile = host: ./hosts + "/${host}/hardware-configuration.nix";
    readyHosts = builtins.filter (host: builtins.pathExists (hardwareFile host)) hosts;
    pkgs = import nixpkgs {
      inherit system;
      config = import ./lib/nixpkgs-config.nix;
    };
    tests = {
      monitor-model = import ./tests/monitors.nix {inherit lib pkgs;};
      wallpaper-conversion = import ./tests/wallpaper.nix {inherit pkgs;};
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
    sandlock = pkgs.callPackage ./pkgs/sandlock/package.nix {};
  in {
    nixosConfigurations = lib.genAttrs readyHosts (host:
      lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules = [
          inputs.stylix.nixosModules.stylix
          inputs.niri.nixosModules.niri
          inputs.grub2-themes.nixosModules.default
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
          inputs.spicetify-nix.homeManagerModules.default
          inputs.nix-index-database.homeModules.nix-index
          (./hosts + "/${host}/home.nix")
        ];
      });

    # Exposed as packages so `nix build .#monitor-model` resolves the system itself.
    packages.${system} = tests // {inherit sandlock;};

    # `nix develop .#sandlock` for iterating on the lock screen with cargo.
    devShells.${system}.sandlock = pkgs.mkShell {
      inputsFrom = [sandlock];
      packages = with pkgs; [cargo rustc clippy rustfmt rust-analyzer];
      LD_LIBRARY_PATH = lib.makeLibraryPath (with pkgs; [vulkan-loader libGL wayland libxkbcommon]);
      # Lets `cargo test` run the PAM conversation test (skipped without it).
      SANDLOCK_TEST_PAM_LIB = "${pkgs.linux-pam}/lib/security";
    };

    # Flake checking normally ignores custom homeConfigurations outputs.
    checks.${system} =
      lib.genAttrs (map (host: "home-${host}") hosts) (name:
        inputs.self.homeConfigurations."macs@${lib.removePrefix "home-" name}".activationPackage)
      // tests;

    formatter.${system} = pkgs.alejandra;
  };
}

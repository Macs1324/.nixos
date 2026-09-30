{
  pkgs,
  inputs,
  ...
}: let
  # Boot splash from adi1090x's theme pack; preview them all at
  # github.com/adi1090x/plymouth-themes and change this name to swap.
  plymouthTheme = "hexagon_dots";
  # The pack's scripts centre the animation once, on the first monitor's size
  # (`GetWidth(0)`). Plymouth starts on the firmware framebuffer (simpledrm)
  # and only later swaps in xe's real monitors, and it lays every monitor out
  # centred in one canvas as big as the largest. So the position is stale and
  # measured on the wrong screen: re-centre on the canvas (`GetWidth()`) every
  # frame, which is the centre of each monitor.
  plymouthThemes = (pkgs.adi1090x-plymouth-themes.override {selected_themes = [plymouthTheme];}).overrideAttrs (old: {
    # installPhase is overridden without runHook, so postInstall would never run.
    postFixup =
      (old.postFixup or "")
      + ''
        substituteInPlace $out/share/plymouth/themes/${plymouthTheme}/${plymouthTheme}.script \
          --replace-fail 'Window.GetWidth(0)' 'Window.GetWidth()' \
          --replace-fail 'Window.GetHeight(0)' 'Window.GetHeight()' \
          --replace-fail 'Plymouth.SetRefreshFunction (refresh_callback);' '
        fun centred_refresh_callback ()
          {
            flyingman_sprite.SetX(Window.GetX() + (Window.GetWidth() / 2 - flyingman_image[0].GetWidth() / 2));
            flyingman_sprite.SetY(Window.GetY() + (Window.GetHeight() / 2 - flyingman_image[0].GetHeight() / 2));
            refresh_callback();
          }
        Plymouth.SetRefreshFunction (centred_refresh_callback);'
      '';
  });
in {
  # Bootloader.
  boot.loader.timeout = null;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.useOSProber = true;
  # /boot is 511M and each generation costs ~75M of kernel + initrd. Without a
  # cap it fills up, and the bootloader install then fails *while copying the
  # new initrd*, before it gets to prune the old ones -- so it cannot recover on
  # its own. Raising this above ~5 needs a bigger ESP.
  boot.loader.grub.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # Stylix's own splash is off in system/theme.nix. The systemd initrd lets
  # Plymouth start early instead of after the stage-1 log spam.
  boot.plymouth = {
    enable = true;
    theme = plymouthTheme;
    themePackages = [plymouthThemes];
  };
  boot.initrd.systemd.enable = true;
  boot.consoleLogLevel = 3;
  boot.kernelParams = ["quiet" "udev.log_level=3" "systemd.show_status=auto"];

  networking.networkmanager.enable = true;
  # Set your time zone.
  time.timeZone = "Europe/Stockholm";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "sv_SE.UTF-8";
    LC_IDENTIFICATION = "sv_SE.UTF-8";
    LC_MEASUREMENT = "sv_SE.UTF-8";
    LC_MONETARY = "sv_SE.UTF-8";
    LC_NAME = "sv_SE.UTF-8";
    LC_NUMERIC = "sv_SE.UTF-8";
    LC_PAPER = "sv_SE.UTF-8";
    LC_TELEPHONE = "sv_SE.UTF-8";
    LC_TIME = "sv_SE.UTF-8";
  };

  users.groups.uinput = {};
  users.groups.plugdev = {};
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.macs = {
    isNormalUser = true;
    description = "Max Blank";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
      "uinput"
      "video"
      "render"
      "plugdev"
      "seat"
    ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  programs.zsh.enable = true;
  services.envfs.enable = true;
  programs.nix-ld.enable = true;
  services.pcscd.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = ["root" "@wheel"];

      # niri's cache is not listed here: its NixOS module adds niri.cachix.org
      # itself via `niri-flake.cache.enable` (on by default).
      # These only pay off while the matching flake input does not follow our
      # nixpkgs -- see the note in flake.nix.
      substituters = [
        "https://hyprland.cachix.org"
        "https://noctalia.cachix.org"
      ];
      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };

    # Deduplicate the store; generation pruning is `programs.nh.clean` below.
    optimise.automatic = true;

    # `nix shell nixpkgs#foo` and legacy `<nixpkgs>` resolve to this flake's pinned nixpkgs.
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = ["nixpkgs=flake:nixpkgs"];
  };

  # Weekly prune of old generations, always keeping at least as many as the
  # grub configurationLimit above. nh.clean and nix.gc cannot both be enabled.
  programs.nh = {
    enable = true;
    flake = "/home/macs/.nixos";
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 14d --keep 5";
    };
  };

  # The channel-based database is absent on flake systems; comma and
  # nix-index-database (home/programs.nix) provide command-not-found instead.
  programs.command-not-found.enable = false;

  system.stateVersion = "24.05";
}

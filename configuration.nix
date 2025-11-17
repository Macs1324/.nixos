# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  pc,
  zen-browser,
  hyprland,
  stylix,
  pcs,
  theme,
  ...
}: {
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ]
    ++ {
      "homedesktop" = [
        ./system/games.nix
        ./system/work.nix
      ];
      "workdesktop" = [./system/work.nix];
      "worklaptop" = [./system/work.nix];
    }
  .${
      pc
    };

  boot.kernelPackages = pkgs.linuxPackages_testing;
  boot.kernelParams =
    if pc == "workdesktop"
    then [
      # "i915.force_probe=!e211"
      "xe.force_probe=e211"
    ]
    else [];
  # Bootloader.
  boot.loader.timeout = null;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.theme = pkgs.lib.mkForce pkgs.minimal-grub-theme;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixmacs"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
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

  hardware.enableRedistributableFirmware = true;
  hardware.uinput.enable = true;
  hardware.opentabletdriver.enable = true;
  hardware.firmware = with pkgs; [linux-firmware];
  hardware.enableAllFirmware = true;

  # Enable OpenGL
  hardware.graphics =
    if pc == "homedesktop"
    then {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        rocmPackages.clr.icd
      ];
    }
    else if pc == "workdesktop"
    then {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        # VA-API (Video Acceleration API)
        intel-media-driver # iHD driver for newer Intel GPUs
        intel-vaapi-driver # i965 driver for older Intel GPUs (fallback)

        # Vulkan
        intel-compute-runtime # OpenCL and Level Zero
        vpl-gpu-rt # Video Processing Library

        # Mesa drivers
        mesa # Includes iris, crocus, etc.
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        intel-media-driver
        intel-vaapi-driver
        mesa
      ];
    }
    else {
      enable = true;
    };

  environment.sessionVariables =
    {
      "workdesktop" = {
        # VA-API driver selection (iHD for newer Intel, i965 for older)
        LIBVA_DRIVER_NAME = "iHD";

        # Force Mesa to use the correct GPU (card0 = Arc B60)
        MESA_LOADER_DRIVER_OVERRIDE = "iris";

        # Vulkan ICD selection
        VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";

        # Enable hardware video decoding
        VDPAU_DRIVER = "va_gl";
      };
      "worklaptop" = {};
      "homedesktop" = {};
    }
    .${
      pc
    };

  services.xserver.videoDrivers =
    if pc == "workdesktop"
    then [
      # Use modesetting for modern Wayland support with xe driver
      # DO NOT use "intel" - it's the old DDX driver, not compatible with xe/Arc B60
      "modesetting"
    ]
    else ["modesetting"];

  # Increase the amount of inotify watchers
  # Note that inotify watches consume 1kB on 64-bit machines.
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 1048576; # default:  8192
    "fs.inotify.max_user_instances" = 1024; # default:   128
    "fs.inotify.max_queued_events" = 32768; # default: 16384
  };
  boot.initrd.kernelModules =
    if pc == "homedesktop"
    then ["amdgpu"]
    else if pc == "workdesktop"
    then [
      # "i915"
      "xe"
    ]
    else [];

  systemd.tmpfiles.rules =
    if pc == "homedesktop"
    then [
      "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
    ]
    else [];

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  # services.xserver.enable = true;
  # services.xserver = {
  #   xkb.layout = "us";
  #   xkb.variant = "";
  # };

  # Enable the KDE Plasma Desktop Environment.
  # services.desktopManager.plasma6.enable = true;
  # services.displayManager.sddm.enable = true;
  # services.displayManager.sddm.wayland.enable = true;

  # services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  # Configure keymap in X11

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    wireplumber.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
  services.postgresql = {
    enable = true;
    ensureDatabases = ["clockout"];
    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser  auth-method
      local all       all     trust
    '';
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
      "docker"
      "plugdev"
      "seat"
    ];
    packages = with pkgs; [
      kdePackages.kate
      #  thunderbird
    ];
  };

  stylix.enable = true;
  stylix.autoEnable = true;
  stylix.base16Scheme = theme;

  programs.java.enable = true;
  programs.firejail.enable = true;
  programs.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };
  programs.zsh.enable = true;
  services.envfs.enable = true;
  programs.nix-ld.enable = true;
  programs.ssh = {
    extraConfig = ''
      Host uxs-sup
        HostName 94.254.42.77
        User uxstream
        Port 44022
      Host uxs-platonum-demo
        HostName 192.168.1.56
        user uxstream
        Port 22
    '';
  };
  virtualisation.docker.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Basic utilities
    wget
    gh
    pavucontrol
    pamixer
    rnote # note app
    zip
    unzip
    bitwarden-desktop
    gnome-calendar
    bzip2
    obs-studio
    vlc
    hyprpaper
    flatpak
    plantuml
    mermaid-cli
    networkmanagerapplet
    pandoc
    libreoffice
    pciutils
    unigine-superposition

    intel-vaapi-driver
    libva
    libva-utils # Provides vainfo for checking VA-API
    intel-gpu-tools # Provides intel_gpu_top
    vulkan-tools # Provides vulkaninfo
    mesa-demos # Provides glxinfo

    inxi

    # Libraries and dependencies
    libnotify
    pulseaudio
    wl-clipboard
    wlogout
    grim
    slurp
    clipse
    libadwaita
    linuxHeaders
    clinfo
    imagemagick

    # Programming languages
    nodejs
    bun
    rustup
    python3
    zig
    gcc
    go
    sqlite

    # Editors
    vim
    neovide
    code-cursor

    # CLI Tools
    alejandra
    prettier
    ripgrep
    fd
    zsh-powerlevel10k
    shellcheck
    bacon
    ffmpeg
    gst_all_1.gstreamer
    xh
    htop
    jq
    gnumake
    podman
    podman-compose
    viu
    just

    # Browsers
    google-chrome
    brave

    # Creative tools
    blender
    inkscape-with-extensions
    godot_4
    godot_4-export-templates-bin
    krita
    gimp
    audacity

    # LaTeX
    (pkgs.texlive.combine {
      inherit
        (pkgs.texlive)
        scheme-medium
        dvisvgm
        dvipng # for preview and export as html
        wrapfig
        amsmath
        moresize
        fontawesome5
        geometry
        raleway
        ulem
        hyperref
        capt-of
        ;
      #(setq org-latex-compiler "lualatex")
      #(setq org-preview-latex-default-process 'dvisvgm)
    })

    # Gaming
    lutris

    # Dev tools
    pgadmin4
    insomnia
    git-lfs
    gource
  ];

  environment.variables = {
    # Set the default editor for the system
    EDITOR = "nvim";
    VISUAL = "nvim";
    GIT_EDITOR = "nvim";
    SHELL = "zsh";

    core = "$HOME/Code/corecf";
    keymaker = "$HOME/Code/corecf/services/keymaker";
    supervisor = "$HOME/Code/uxstream/services/supervisor/supervisor";
    portal = "$HOME/Code/corecf/web/portal";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.ubuntu-mono
    nerd-fonts.jetbrains-mono
    meslo-lgs-nf
    inter
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;
  services.seatd.enable = true;
  services.udev = {
    enable = true;
    extraRules = ''
      # Rules for Oryx web flashing and live training
      KERNEL=="hidraw*", ATTRS{idVendor}=="16c0", MODE="0664", GROUP="plugdev"
      KERNEL=="hidraw*", ATTRS{idVendor}=="3297", MODE="0664", GROUP="plugdev"

      # Legacy rules for live training over webusb (Not needed for firmware v21+)
        # Rule for all ZSA keyboards
        SUBSYSTEM=="usb", ATTR{idVendor}=="3297", GROUP="plugdev"
        # Rule for the Moonlander
        SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", GROUP="plugdev"
        # Rule for the Ergodox EZ
        SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="1307", GROUP="plugdev"
        # Rule for the Planck EZ
        SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="6060", GROUP="plugdev"

      # Wally Flashing rules for the Ergodox EZ
      ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", ENV{ID_MM_DEVICE_IGNORE}="1"
      ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789A]?", ENV{MTP_NO_PROBE}="1"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789ABCD]?", MODE:="0666"
      KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", MODE:="0666"

      # Keymapp / Wally Flashing rules for the Moonlander and Planck EZ
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE:="0666", SYMLINK+="stm32_dfu"
      # Keymapp Flashing rules for the Voyager
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu"
    '';
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}

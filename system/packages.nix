{pkgs, ...}: {
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Basic utilities
    wget
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
    proton-vpn
    plantuml
    asciidoc-full
    mermaid-cli
    networkmanagerapplet
    pandoc
    libreoffice
    pciutils
    distrobox
    wl-mirror
    gpu-screen-recorder
    gnupg
    pinentry-qt
    git-crypt
    tmux

    libva
    libva-utils # Provides vainfo for checking VA-API
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
    cmake
    podman-compose
    viu
    just
    fastfetch

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
    (pkgs.texliveSmall.withPackages (
      ps:
        with ps; [
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
          datetime2
          tcolorbox
          #(setq org-latex-compiler "lualatex")
          #(setq org-preview-latex-default-process 'dvisvgm)
        ]
    ))
  ];
}

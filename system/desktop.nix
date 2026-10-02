{
  config,
  pkgs,
  inputs,
  ...
}: {
  # Noctalia Greeter on greetd. Its look (wallpaper, palette, font) is pushed
  # from the shell by `shell.greeter_sync` (home/theme.nix), not set here.
  services.displayManager.noctalia-greeter = {
    enable = true;
    cursorTheme = {inherit (config.stylix.cursor) package name;};
    settings.cursor.size = config.stylix.cursor.size;
    # The sync helper only ever writes appearance settings, so it runs without
    # a password prompt for this user.
    passwordlessSyncUsers = ["macs"];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      cups-browsed
    ];
  };
  services.ipp-usb.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    wireplumber.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  services.flatpak.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gnome.evolution-data-server.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin # "Extract here" / "Create archive" (via xarchiver)
      thunar-volman # auto-mount USB drives and phones
      thunar-media-tags-plugin
    ];
  };
  # Trash, mounting and network locations in Thunar's sidebar.
  services.gvfs.enable = true;
  # Thumbnails for images, PDFs and (with ffmpegthumbnailer) videos.
  services.tumbler.enable = true;

  programs.firejail.enable = true;
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config = {
      common.default = ["gtk"];
      hyprland.default = [
        "hyprland"
        "gtk"
      ];
      niri.default = [
        "gnome"
        "gtk"
      ];
      niri."org.freedesktop.impl.portal.Access" = "gtk";
      niri."org.freedesktop.impl.portal.FileChooser" = "gtk";
      niri."org.freedesktop.impl.portal.Notification" = "gtk";
      niri."org.freedesktop.impl.portal.Secret" = "gnome-keyring";
    };
  };

  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  services.seatd.enable = true;
  security.pam.services.hyprlock = {};
  # sandlock (inputs.sandlock) checks passwords against this stack.
  security.pam.services.sandlock = {};
  environment.systemPackages = [
    inputs.sandlock.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.xwayland-satellite
    pkgs.xarchiver
    pkgs.ffmpegthumbnailer
  ];
}

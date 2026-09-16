{
  pkgs,
  inputs,
  ...
}: {
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = [(pkgs.sddm-astronaut.override {embeddedTheme = "pixel_sakura";})];
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

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gnome.evolution-data-server.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
  programs.thunar.enable = true;

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
  environment.systemPackages = [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.xwayland-satellite
  ];
}

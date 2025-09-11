{
  config,
  pkgs,
  lib,
  pc,
  ...
}: {
  # GNOME configuration aligned with Hyprland aesthetics
  # Maintains consistent Nord theme and minimal design philosophy

  dconf.settings = {
    # Shell and desktop settings
    "org/gnome/shell" = {
      enabled-extensions = [
        "user-theme@gnome-shell-extensions.gcampax.github.com"
      ];
      favorite-apps = [
        "org.gnome.Nautilus.desktop"
        "kitty.desktop"
        "firefox.desktop"
        "code-cursor.desktop"
        "org.gnome.Settings.desktop"
      ];
    };

    # Interface settings - consistent with Hyprland's minimal approach
    "org/gnome/desktop/interface" = {
      gtk-theme = "Adwaita-dark";
      icon-theme = "Papirus-Dark";
      cursor-theme = "Bibata-Modern-Ice";
      cursor-size = 24;
      font-name = "Inter 11";
      document-font-name = "Inter 11";
      monospace-font-name = "JetBrains Mono 12";
      show-battery-percentage = true;
      enable-animations = true;
      enable-hot-corners = false;
    };

    # Window manager behavior - inspired by Hyprland's tiling approach
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "close,minimize,maximize:";
      focus-mode = "sloppy"; # Similar to Hyprland's focus behavior
      mouse-button-modifier = "<Super>";
      num-workspaces = 10;
      workspace-names = ["א" "ב" "ג" "ד" "ה" "ו" "ז" "ח" "ט" "י"];
    };

    "org/gnome/desktop/wm/keybindings" = {
      # Consistent with Hyprland keybindings where possible
      close = ["<Super>c"];
      toggle-fullscreen = ["<Super>s"];
      toggle-maximized = ["<Super>f"];

      # Workspace navigation (matching Hyprland)
      switch-to-workspace-1 = ["<Super>1"];
      switch-to-workspace-2 = ["<Super>2"];
      switch-to-workspace-3 = ["<Super>3"];
      switch-to-workspace-4 = ["<Super>4"];
      switch-to-workspace-5 = ["<Super>5"];
      switch-to-workspace-6 = ["<Super>6"];
      switch-to-workspace-7 = ["<Super>7"];
      switch-to-workspace-8 = ["<Super>8"];
      switch-to-workspace-9 = ["<Super>9"];
      switch-to-workspace-10 = ["<Super>0"];

      # Move window to workspace
      move-to-workspace-1 = ["<Super><Shift>1"];
      move-to-workspace-2 = ["<Super><Shift>2"];
      move-to-workspace-3 = ["<Super><Shift>3"];
      move-to-workspace-4 = ["<Super><Shift>4"];
      move-to-workspace-5 = ["<Super><Shift>5"];
      move-to-workspace-6 = ["<Super><Shift>6"];
      move-to-workspace-7 = ["<Super><Shift>7"];
      move-to-workspace-8 = ["<Super><Shift>8"];
      move-to-workspace-9 = ["<Super><Shift>9"];
      move-to-workspace-10 = ["<Super><Shift>0"];

      # Window navigation
      switch-windows = ["<Alt>Tab"];
      switch-applications = ["<Super>Tab"];
    };

    # Custom keybindings matching Hyprland
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>q";
      command = "kitty";
      name = "Terminal";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Super>o";
      command = "gnome-search-tool";
      name = "Application Launcher";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Super><Shift>s";
      command = "gnome-screenshot -a -c";
      name = "Screenshot Selection";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
      binding = "<Super>n";
      command = "neovide";
      name = "Neovide";
    };

    # Workspace behavior
    "org/gnome/mutter" = {
      workspaces-only-on-primary = false;
      dynamic-workspaces = false;
      center-new-windows = true;
    };

    # Desktop background and screensaver - matching Hyprland wallpapers
    "org/gnome/desktop/background" =
      if pc == "workdesktop"
      then {
        picture-uri = "file:///home/macs/.nixos/assets/wallpapers/workdesktop-1.png";
        picture-uri-dark = "file:///home/macs/.nixos/assets/wallpapers/workdesktop-1.png";
        picture-options = "zoom";
      }
      else if pc == "homedesktop"
      then {
        picture-uri = "file:///home/macs/.nixos/assets/wallpapers/homedesktop-1.jpg";
        picture-uri-dark = "file:///home/macs/.nixos/assets/wallpapers/homedesktop-1.jpg";
        picture-options = "zoom";
      }
      else {
        picture-uri = "file:///home/macs/.nixos/assets/wallpapers/${pc}.jpg";
        picture-uri-dark = "file:///home/macs/.nixos/assets/wallpapers/${pc}.jpg";
        picture-options = "zoom";
      };

    "org/gnome/desktop/screensaver" =
      if pc == "workdesktop"
      then {
        picture-uri = "file:///home/macs/.nixos/assets/wallpapers/workdesktop-1.png";
        lock-enabled = true;
        lock-delay = lib.hm.gvariant.mkUint32 300;
      }
      else if pc == "homedesktop"
      then {
        picture-uri = "file:///home/macs/.nixos/assets/wallpapers/homedesktop-1.jpg";
        lock-enabled = true;
        lock-delay = lib.hm.gvariant.mkUint32 300;
      }
      else {
        picture-uri = "file:///home/macs/.nixos/assets/wallpapers/${pc}.jpg";
        lock-enabled = true;
        lock-delay = lib.hm.gvariant.mkUint32 300;
      };

    # Power settings
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-timeout = 3600;
      sleep-inactive-battery-timeout = 1800;
    };

    # File manager settings
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
      show-hidden-files = false;
      show-image-thumbnails = "always";
    };

    "org/gnome/nautilus/list-view" = {
      use-tree-view = true;
      default-zoom-level = "small";
    };

    # Terminal settings (GNOME Terminal as fallback)
    "org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
      background-color = "rgb(46,52,64)";
      foreground-color = "rgb(216,222,233)";
      palette = [
        "rgb(46,52,64)" # base00 - dark
        "rgb(191,97,106)" # base08 - red
        "rgb(163,190,140)" # base0B - green
        "rgb(235,203,139)" # base0A - yellow
        "rgb(129,161,193)" # base0D - blue
        "rgb(180,142,173)" # base0E - magenta
        "rgb(136,192,208)" # base0C - cyan
        "rgb(216,222,233)" # base05 - light
        "rgb(76,86,106)" # base03 - bright dark
        "rgb(191,97,106)" # base08 - bright red
        "rgb(163,190,140)" # base0B - bright green
        "rgb(235,203,139)" # base0A - bright yellow
        "rgb(129,161,193)" # base0D - bright blue
        "rgb(180,142,173)" # base0E - bright magenta
        "rgb(136,192,208)" # base0C - bright cyan
        "rgb(236,239,244)" # base07 - white
      ];
      use-theme-colors = false;
      use-theme-transparency = false;
      background-transparency-percent = 85;
      use-transparent-background = true;
      font = "JetBrains Mono 12";
      use-system-font = false;
    };

    # Sound and notification settings
    "org/gnome/desktop/sound" = {
      theme-name = "freedesktop";
      event-sounds = true;
      input-feedback-sounds = false;
    };

    "org/gnome/desktop/notifications" = {
      application-children = ["firefox" "kitty" "code-cursor"];
      show-banners = true;
      show-in-lock-screen = false;
    };
  };

  # Install GNOME extensions and themes
  home.packages = with pkgs; [
    # Minimal extensions
    gnomeExtensions.user-themes

    # Themes consistent with Hyprland aesthetic
    adwaita-qt
    papirus-icon-theme

    # Tools
    gnome-tweaks
    dconf-editor
  ];

  # Override GTK settings to ensure consistency with Nord theme
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    font = {
      name = "Inter";
      size = 11;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-decoration-layout = "close,minimize,maximize:";
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-decoration-layout = "close,minimize,maximize:";
    };
  };

  # Qt theming to match GTK
  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };
}

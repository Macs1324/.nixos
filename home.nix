{
  config,
  pkgs,
  hyprcursor-phinger,
  hyprland-qtutils,
  ...
}: {
  imports = [
    ./home/hyprland.nix
    ./home/eww.nix
    hyprcursor-phinger.homeManagerModules.hyprcursor-phinger
  ];
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "macs";
  home.homeDirectory = "/home/macs";

  programs.git = {
    enable = true;
    userName = "Macs1324";
    userEmail = "max.blank410@gmail.com";
  };
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };
  programs.kitty = {
    enable = true;
    theme = "Catppuccin-Mocha";
    settings = {
      font_family = "Hack Nerd Font Mono";
      bold_font = "Hack Nerd Font Mono";
      italic_font = "Hack Nerd Font Mono Italic";
      bold_italic_font = "Hack Nerd Font Mono Italic";
      font_size = "11.0";

      enable_audio_bell = false;
      url_style = "single";

      macos_option_as_alt = "left";

      background_opacity = "0.4";
    };
    keybindings = {
      "cmd+c" = "copy_to_clipboard";
      "cmd+v" = "paste_from_clipboard";
      "shift+insert" = "paste_from_clipboard";
      "ctrl+shift+." = "next_tab";
      "ctrl+shift+," = "previous_tab";
      "ctrl+shift+right" = "move_tab_forward";
      "ctrl+shift+left" = "move_tab_backward";
      "ctrl+shift+'" = "set_tab_title";
    };
  };
  programs.alacritty = {
    enable = true;
    settings = {
      terminal.shell.program = "zsh";

      window = {
        dimensions = {
          lines = 3;
          columns = 200;
        };
        opacity = 0.4;
      };
      font = {
        normal = {
          family = "Hack Nerd Font Mono";
          style = "Regular";
        };
      };
      keyboard.bindings = [
        {
          key = "K";
          mods = "Control";
          chars = "\\u000c";
        }
      ];
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "Materia-dark";
      package = pkgs.materia-theme;
    };
  };

  programs.hyprcursor-phinger.enable = true;
  home.pointerCursor = {
    name = "phinger-cursors-light";
    package = pkgs.phinger-cursors;
    size = 32;
    gtk.enable = true;
  };
  programs.direnv = {
    enable = true;
    enableBashIntegration = true; # see note on other shells below
    nix-direnv.enable = true;
  };
  programs.waybar.enable = true;
  programs.ncspot.enable = true;
  # programs.cava.enable = true;

  programs.bash = {
    enable = true;
    bashrcExtra = ''
      export PATH=$PATH:~/.config/emacs/bin
    '';
  };
  services.dunst = {
    enable = true;
    settings = {
      global = {
        width = 300;
        height = 300;
        offset = "30x50";
        origin = "top-right";
        transparency = 10;
        frame_color = "#eceff1";
        font = "Droid Sans 9";
      };

      urgency_normal = {
        background = "#37474f";
        foreground = "#eceff1";
        timeout = 10;
      };
    };
  };

  home.packages = [
    hyprland-qtutils.packages."${pkgs.system}".default
  ];

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

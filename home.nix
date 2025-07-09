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
    ./home/waybar.nix
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
  # programs.ncspot.enable = true;
  # programs.cava.enable = true;

  programs.ghostty = {
    enable = true;
    settings = {
      theme = "rose-pine";
      font-size = 14;
      background-opacity = 0.78;
      gtk-single-instance = true;
    };

    themes = {
      rose-pine = {
        background = "191724";
        cursor-color = "e0def4";
        cursor-text = "191724";
        foreground = "e0def4";
        palette = [
          "0=#26233a"
          "1=#eb6f92"
          "2=#31748f"
          "3=#f6c177"
          "4=#9ccfd8"
          "5=#c4a7e7"
          "6=#ebbcba"
          "7=#e0def4"
          "8=#6e6a86"
          "9=#eb6f92"
          "10=#31748f"
          "11=#f6c177"
          "12=#9ccfd8"
          "13=#c4a7e7"
          "14=#ebbcba"
          "15=#e0def4"
        ];
        selection-background = "403d52";
        selection-foreground = "e0def4";
      };
    };
  };

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

  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.cargo/bin"
  ];

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

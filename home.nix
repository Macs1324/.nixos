{
  config,
  pkgs,
  hyprland-qtutils,
  stylix,
  theme,
  zen-browser,
  ...
}: {
  imports = [
    ./home/hyprland.nix
    ./home/gnome.nix
    ./home/eww.nix
    ./home/waybar.nix
    ./home/wlogout.nix
    ./home/nvim
  ];
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "macs";
  home.homeDirectory = "/home/macs";

  stylix.enable = true;
  stylix.autoEnable = true;
  stylix.base16Scheme = theme;

  stylix.fonts = {
    monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };
    sizes.terminal = 14;
  };

  stylix.opacity.terminal = 0.78;

  stylix.targets.nixvim = {
    enable = true;
    transparentBackground.main = true;
    transparentBackground.numberLine = true;
    transparentBackground.signColumn = true;
  };
  stylix.targets.zen-browser.profileNames = ["default"];
  stylix.targets.firefox.profileNames = ["default"];

  programs.firefox = {
    enable = true;
  };

  programs.zen-browser = {
    enable = true;
    profiles = {
      default = {};
    };
  };

  programs.bat = {
    enable = true;
  };

  programs.emacs = {
    enable = true;
  };

  programs.zed-editor = {
    enable = true;
  };

  programs.lazygit = {
    enable = true;
  };

  programs.cava = {
    enable = true;
  };

  programs.btop = {
    enable = true;
  };

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

  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
  };
  programs.direnv = {
    enable = true;
    enableBashIntegration = true; # see note on other shells below
    nix-direnv.enable = true;
  };
  # programs.ncspot.enable = true;

  programs.kitty = {
    enable = true;
    settings = {
      single_instance = "yes";
      enable_audio_bell = "no";
      visual_bell_duration = "0.0";
      window_padding_width = "4";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      tab_title_template = "{title}{' :{}:'.format(num_windows) if num_windows > 1 else ''}";
      allow_remote_control = "yes";
      listen_on = "unix:/tmp/kitty";
      dynamic_background_opacity = "yes";
      confirm_os_window_close = "0";
    };
    keybindings = {
      "ctrl+shift+equal" = "change_font_size all +2.0";
      "ctrl+shift+minus" = "change_font_size all -2.0";
      "ctrl+shift+backspace" = "change_font_size all 0";
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 14;

      # Use Stylix colors for Nord theming
      background = config.lib.stylix.colors.withHashtag.base00;
      foreground = config.lib.stylix.colors.withHashtag.base05;

      # Nord color palette using Stylix base16 colors
      palette = [
        "0=${config.lib.stylix.colors.withHashtag.base00}" # black
        "1=${config.lib.stylix.colors.withHashtag.base08}" # red
        "2=${config.lib.stylix.colors.withHashtag.base0B}" # green
        "3=${config.lib.stylix.colors.withHashtag.base0A}" # yellow
        "4=${config.lib.stylix.colors.withHashtag.base0D}" # blue
        "5=${config.lib.stylix.colors.withHashtag.base0E}" # magenta
        "6=${config.lib.stylix.colors.withHashtag.base0C}" # cyan
        "7=${config.lib.stylix.colors.withHashtag.base05}" # white
        "8=${config.lib.stylix.colors.withHashtag.base03}" # bright black
        "9=${config.lib.stylix.colors.withHashtag.base08}" # bright red
        "10=${config.lib.stylix.colors.withHashtag.base0B}" # bright green
        "11=${config.lib.stylix.colors.withHashtag.base0A}" # bright yellow
        "12=${config.lib.stylix.colors.withHashtag.base0D}" # bright blue
        "13=${config.lib.stylix.colors.withHashtag.base0E}" # bright magenta
        "14=${config.lib.stylix.colors.withHashtag.base0C}" # bright cyan
        "15=${config.lib.stylix.colors.withHashtag.base07}" # bright white
      ];

      # Window settings
      window-padding-x = 4;
      window-padding-y = 4;
      background-opacity = 0.78;
      confirm-close-surface = false;

      # Image display support (for nvim image.nvim plugin)
      image-storage-limit = 1073741824; # 1GB for images

      # Keybindings
      keybind = [
        "ctrl+shift+equal=increase_font_size:2"
        "ctrl+shift+minus=decrease_font_size:2"
        "ctrl+shift+backspace=reset_font_size"
      ];
    };
  };

  # Fastfetch - Deactivated in favor of pfetch (can be re-enabled anytime)
  programs.fastfetch = {
    enable = false;
    settings = {
      logo = {
        type = "kitty";
        source = "~/.nixos/assets/logo.png";
        width = 48;
        height = 19;
      };
      modules = [
        "title"
        "separator"
        "os"
        {
          type = "host";
          format = "{/2}{-}{/}{2}{?3} {3}{?}";
        }
        "kernel"
        "uptime"
        {
          type = "battery";
          format = "{/4}{-}{/}{4}{?5} [{5}]{?}";
        }
        "break"
        "packages"
        "shell"
        "display"
        "terminal"
        "break"
        "cpu"
        {
          type = "gpu";
          key = "GPU";
        }
        "memory"
        "break"
        "colors"
      ];
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      pfetch
      alias nd="nix develop"
      alias nv="neovide --fork"
    '';
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [
        "git"
        "npm"
        "history"
        "node"
        "rust"
        "deno"
      ];
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
        monitor = 0;
        follow = "none";

        # Geometry
        width = "(250, 400)";
        height = 300;
        origin = "top-right";
        offset = "20x20";
        corner_radius = 12;

        # Progress bar
        progress_bar = true;
        progress_bar_height = 8;
        progress_bar_frame_width = 1;
        progress_bar_min_width = 150;
        progress_bar_max_width = 300;
        progress_bar_corner_radius = 4;

        # Icon settings
        icon_corner_radius = 8;
        indicate_hidden = "yes";
        transparency = 0;
        separator_height = 2;
        padding = 12;
        horizontal_padding = 16;
        text_icon_padding = 8;
        frame_width = 2;
        gap_size = 6;

        # Text
        line_height = 0;
        markup = "full";
        format = "<b>%s</b>\\n%b";
        alignment = "left";
        vertical_alignment = "center";
        show_age_threshold = 60;
        ellipsize = "middle";
        ignore_newline = "no";
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = "yes";

        # Icons
        enable_recursive_icon_lookup = true;
        icon_position = "left";
        min_icon_size = 24;
        max_icon_size = 48;

        # History
        sticky_history = "yes";
        history_length = 20;

        # Misc/Advanced
        dmenu = "wofi -dmenu -p dunst:";
        browser = "firefox";
        always_run_script = true;
        title = "Dunst";
        class = "Dunst";
        force_xinerama = false;

        # Mouse actions
        mouse_left_click = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };

      experimental = {
        per_monitor_dpi = false;
      };

      urgency_low = {
        timeout = 8;
        default_icon = "dialog-information";
      };

      urgency_normal = {
        timeout = 10;
        default_icon = "dialog-information";
      };

      urgency_critical = {
        timeout = 0;
        default_icon = "dialog-error";
      };
    };
  };

  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.cargo/bin"
  ];

  home.packages = [
    hyprland-qtutils.packages."${pkgs.system}".default
    pkgs.pfetch
  ];

  # Pfetch configuration
  home.sessionVariables = {
    PF_INFO = "ascii title os kernel uptime pkgs memory";
    PF_ASCII = "nixos";
    PF_SEP = "  ";
  };

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

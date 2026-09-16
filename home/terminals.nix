{
  config,
  pkgs,
  ...
}: {
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
          chars = builtins.fromJSON ''"\u000c"'';
        }
      ];
    };
  };

  programs.kitty = {
    enable = true;
    settings = {
      single_instance = "yes";

      # Neovide-like motion: animate cursor jumps and fade the blink smoothly.
      cursor_trail = "1";
      cursor_trail_decay = "0.08 0.22";
      cursor_trail_start_threshold = "1";
      cursor_blink_interval = "0.5 ease-in-out";

      # Keep the pointer out of the way while typing and retain precise,
      # sub-line touchpad scrolling in Kitty's scrollback buffer.
      mouse_hide_wait = "-1.0";
      pixel_scroll = "yes";
      wheel_scroll_multiplier = "2.0";

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
}

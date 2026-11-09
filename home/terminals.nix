{
  config,
  lib,
  pkgs,
  ...
}: let
  tmux = lib.getExe config.programs.tmux.package;
  # Pick up a detached session if there is one (so closing a window doesn't
  # leak sessions), otherwise start a new one.
  kittyTmux = pkgs.writeShellScript "kitty-tmux" ''
    read -r session < <(${tmux} list-sessions -f '#{==:#{session_attached},0}' -F '#{session_id}' 2>/dev/null)
    if [[ -n $session ]]; then
      exec ${tmux} attach-session -t "$session"
    fi
    exec ${tmux} new-session
  '';
in {
  programs.alacritty = {
    enable = true;
    settings = {
      terminal.shell.program = "nu";

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
      shell = "${kittyTmux}";
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
      # tmux can't request the kitty keyboard protocol, so send Shift+Enter as
      # CSI u while tmux is focused (it sets the window title to "tmux ...").
      "--when-focus-on title:^tmux shift+enter" = "send_text all \\e[13;2u";
    };
  };

  # Font, colors, and opacity come from the Stylix ghostty target.
  programs.ghostty = {
    enable = true;
    settings = {
      command = "nu";
      window-padding-x = 4;
      window-padding-y = 4;
      confirm-close-surface = false;

      # Image display support (for nvim image.nvim plugin)
      image-storage-limit = 1073741824; # 1GB for images

      keybind = [
        "ctrl+shift+equal=increase_font_size:2"
        "ctrl+shift+minus=decrease_font_size:2"
        "ctrl+shift+backspace=reset_font_size"
      ];
    };
  };
}

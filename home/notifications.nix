{pkgs, ...}: {
  services.dunst = {
    # Noctalia owns the notification bus in both Wayland sessions.
    enable = false;
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
}

{...}: {
  programs.wofi = {
    enable = true;
    settings = {
      allow_markup = true;
      allow_images = true;
      insensitive = true;
      hide_scroll = true;
      prompt = "Search";
      width = 600;
      height = 400;
      location = "center";
      columns = 1;
      term = "kitty";
      gtk_dark = true;
      dynamic_lines = true;
      matching = "contains";
      key_expand = "Tab";
      key_exit = "Escape";
    };

    style = ''
      /* Reset and base styling */
      * {
        all: unset;
        font-family: monospace;
        font-size: 14px;
        transition: all 0.2s ease-in-out;
      }

      /* Main window */
      window {
        background: alpha(@theme_base_color, 0.95);
        border: 2px solid @theme_selected_bg_color;
        border-radius: 15px;
        padding: 10px;
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
      }

      /* Input field */
      #input {
        background: alpha(@theme_selected_bg_color, 0.1);
        border: 2px solid transparent;
        border-radius: 10px;
        padding: 12px 16px;
        margin: 8px;
        font-size: 16px;
        color: @theme_text_color;
      }

      #input:focus {
        border-color: @theme_selected_bg_color;
        background: alpha(@theme_selected_bg_color, 0.2);
      }

      /* Outer box containing the scroll area */
      #outer-box {
        padding: 8px;
      }

      /* Inner box with results */
      #inner-box {
        border-radius: 8px;
      }

      /* Scroll area */
      #scroll {
        margin: 4px 0;
      }

      /* Individual entries */
      #entry {
        background: transparent;
        border-radius: 8px;
        padding: 12px 16px;
        margin: 2px 4px;
        color: @theme_text_color;
      }

      #entry:hover {
        background: alpha(@theme_selected_bg_color, 0.2);
      }

      #entry:selected {
        background: @theme_selected_bg_color;
        color: @theme_selected_fg_color;
      }

      /* Text in entries */
      #text {
        padding: 2px 8px;
      }

      #entry:selected #text {
        color: @theme_selected_fg_color;
        font-weight: bold;
      }

      /* Icons */
      #img {
        background: transparent;
        border-radius: 6px;
        padding: 4px;
        margin-right: 8px;
      }

      #entry:selected #img {
        background: alpha(@theme_selected_fg_color, 0.1);
      }

      /* No results message */
      #no-results {
        color: alpha(@theme_text_color, 0.6);
        font-style: italic;
        padding: 20px;
        text-align: center;
      }
    '';
  };
}

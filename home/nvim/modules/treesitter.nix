{
  pkgs,
  config,
  ...
}: {
  plugins = {
    treesitter = {
      enable = true;
      settings = {
        highlight = {
          enable = true;
          disable = [
            "latex"
            "markdown"
          ];
        };
        auto_install = true;
        indent_enable = true;
        folding = true;
        autoLoad = true;
        incremental_selection.enable = true;
      };
    };
    treesitter-context = {
      enable = true;
      settings = {
        max_lines = 4;
        min_window_height = 40;
      };
    };
    ts-autotag.enable = true;
    # tpope's indent fixes
    sleuth.enable = true;
  };
}

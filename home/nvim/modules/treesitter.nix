{
  pkgs,
  config,
  ...
}: {
  plugins = {
    treesitter = {
      enable = true;

      # Explicitly declare grammars instead of auto_install
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        bash
        c
        cpp
        css
        html
        javascript
        json
        lua
        markdown
        markdown_inline
        nix
        python
        rust
        svelte
        tsx
        typescript
        vim
        yaml
      ];

      settings = {
        highlight = {
          enable = true;
          disable = [
            "latex"
            "markdown"
          ];
        };
        indent = {
          enable = true;
        };
        incremental_selection = {
          enable = true;
        };
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

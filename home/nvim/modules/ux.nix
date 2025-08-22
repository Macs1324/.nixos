{
  pkgs,
  config,
  ...
}: {
  opts = {
    ignorecase = true;
    smartcase = true;

    # Tab indentation settings
    expandtab = false; # Use tabs instead of spaces
    tabstop = 4; # Width of a tab character
    shiftwidth = 4; # Indentation width for >> and <<
    softtabstop = 4; # Number of columns for tab/backspace in insert mode
    smartindent = true; # Smart indentation
    autoindent = true; # Copy indent from current line when starting new line

    # Wrapping settings
    wrap = false; # Disable line wrapping by default
  };

  plugins = {
    indent-blankline = {
      enable = true;
      autoLoad = true;
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<Esc>";
      action = "<cmd>lua if vim.v.hlsearch == 1 then vim.cmd('noh') end<cr>";
      options = {
        silent = true;
        desc = "Clear search highlighting if active";
      };
    }
    {
      mode = "n";
      key = "<leader>uw";
      action = "<cmd>set wrap!<cr>";
      options = {
        silent = true;
        desc = "Toggle line wrapping";
      };
    }
  ];
}

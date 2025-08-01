{
  pkgs,
  config,
  ...
}: {
  opts = {
    ignorecase = true;
    smartcase = true;
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
  ];
}

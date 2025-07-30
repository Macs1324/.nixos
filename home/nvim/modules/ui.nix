{
  pkgs,
  config,
  ...
}: {
  plugins = {
    lualine = {
      enable = true;
      settings = {
        options = {
          theme = "nord";
          section_separators = {
            left = "";
            right = "";
          };
        };
      };
    };

    which-key = {
      enable = true;
      settings = {
        spec = [
          {
            __unkeyed-1 = "<leader>u";
            group = "UI";
            desc = "UI operations";
          }
        ];
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>ut";
      action = "<cmd>colorscheme<cr>";
      options.desc = "Toggle colorscheme";
    }
  ];

  extraConfigLua = ''
    -- UI specific lua config
    vim.opt.termguicolors = true
  '';
}

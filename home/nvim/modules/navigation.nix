{pkgs, ...}: {
  opts = {
    number = true;
    relativenumber = true;
  };

  keymaps = [
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
      options.desc = "Move to left window";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
      options.desc = "Move to bottom window";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
      options.desc = "Move to top window";
    }

    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
      options.desc = "Move to right window";
    }
    {
      mode = "n";
      key = "<C-Left>";
      action.__raw = ''
        function()
          if vim.fn.winnr() == vim.fn.winnr('h') then
            vim.cmd('vertical resize -2')
          else
            vim.cmd('vertical resize +2')
          end
        end
      '';
      options.desc = "Expand window towards left";
    }
    {
      mode = "n";
      key = "<C-Right>";
      action.__raw = ''
        function()
          if vim.fn.winnr() == vim.fn.winnr('l') then
            vim.cmd('vertical resize -2')
          else
            vim.cmd('vertical resize +2')
          end
        end
      '';
      options.desc = "Expand window towards right";
    }
    {
      mode = "n";
      key = "<C-Up>";
      action.__raw = ''
        function()
          if vim.fn.winnr() == vim.fn.winnr('k') then
            vim.cmd('resize -2')
          else
            vim.cmd('resize +2')
          end
        end
      '';
      options.desc = "Expand window towards top";
    }
    {
      mode = "n";
      key = "<C-Down>";
      action.__raw = ''
        function()
          if vim.fn.winnr() == vim.fn.winnr('j') then
            vim.cmd('resize -2')
          else
            vim.cmd('resize +2')
          end
        end
      '';
      options.desc = "Expand window towards bottom";
    }
    {
      mode = "n";
      key = "\\";
      action = "<c-w>s";
      options.desc = "Horizontal split";
    }
    {
      mode = "n";
      key = "|";
      action = "<c-w>v";
      options.desc = "Vertical split";
    }

    # Tab navigation
    {
      mode = "n";
      key = "<leader>c";
      action = "<cmd>bdelete<cr>";
      options.desc = "Close current tab";
    }
    {
      mode = "n";
      key = "<S-h>";
      action = "<cmd>bprevious<cr>";
      options.desc = "Previous tab";
    }
    {
      mode = "n";
      key = "<S-l>";
      action = "<cmd>bnext<cr>";
      options.desc = "Next tab";
    }
  ];
}

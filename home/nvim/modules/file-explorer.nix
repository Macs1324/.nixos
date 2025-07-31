{
  pkgs,
  config,
  ...
}: {
  keymaps = [
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>NvimTreeToggle<cr>";
      options.desc = "Toggle NvimTree";
    }
  ];

  plugins.web-devicons.enable = true;

  plugins.nvim-tree = {
    enable = true;

    onAttach = {
      __raw = ''
        function(bufnr)
          local api = require "nvim-tree.api"

          local function opts(desc)
            return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
          end

          -- Use l to enter directory or open file
          vim.keymap.set('n', 'l', api.node.open.edit, opts('Open'))
          vim.keymap.set('n', '<cr>', api.node.open.edit, opts('Open'))
          -- Use h to close directory
          vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts('Close Directory'))
          -- Use z to collapse all directories
          vim.keymap.set('n', 'z', api.tree.collapse_all, opts('Collapse All'))
        end
      '';
    };

    openOnSetup = true;
    disableNetrw = true;
    hijackNetrw = true;
    hijackCursor = true;
    hijackUnnamedBufferWhenOpening = true;
    syncRootWithCwd = true;

    updateFocusedFile.enable = true;

    sortBy = "case_sensitive";

    filters = {
      custom = ["__pycache__"];
      exclude = [];
    };

    git = {
      enable = true;
      ignore = true;
    };

    view = {
      side = "right";
      width = 30;
      number = true;
      relativenumber = true;
      preserveWindowProportions = true;
    };

    renderer = {
      rootFolderLabel = false;
      indentWidth = 2;
      highlightGit = true;
      indentMarkers.enable = true;

      icons.glyphs = {
        default = "󰈚";
        symlink = "";
        folder = {
          default = "";
          empty = "";
          emptyOpen = "";
          open = "";
          symlink = "";
          symlinkOpen = "";
          arrowOpen = "";
          arrowClosed = "";
        };
        git = {
          unstaged = "✗";
          staged = "✓";
          unmerged = "";
          renamed = "➜";
          untracked = "★";
          deleted = "";
          ignored = "◌";
        };
      };
    };
  };
}

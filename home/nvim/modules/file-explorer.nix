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

    openOnSetup = true;
    settings = {
      disable_netrw = true;
      hijack_netrw = true;
      hijack_cursor = true;
      hijack_unnamed_buffer_when_opening = true;
      sync_root_with_cwd = true;
      update_focused_file.enable = true;
      sort_by = "case_sensitive";

      filters = {
        custom = ["__pycache__"];
        exclude = [];
        dotfiles = true;
        git_ignored = true;
      };
      git = {
        enable = true;
        ignore = false;
      };
      view = {
        side = "right";
        width = 30;
        number = true;
        relativenumber = true;
        preserve_window_proportions = true;
      };
      renderer = {
        root_folder_label = false;
        indent_width = 2;
        highlight_git = true;
        indent_markers.enable = true;

        icons.glyphs = {
          default = "󰈚";
          symlink = "";
          folder = {
            default = "";
            empty = "";
            empty_open = "";
            open = "";
            symlink = "";
            symlink_open = "";
            arrow_open = "";
            arrow_closed = "";
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

      on_attach = {
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
            -- Use a to add file
            vim.keymap.set('n', 'a', api.fs.create, opts('Create File/Directory'))
            -- Vim-style file management
            vim.keymap.set('n', 'y', api.fs.copy.node, opts('Copy'))
            vim.keymap.set('n', 'x', api.fs.cut, opts('Cut'))
            vim.keymap.set('n', 'p', api.fs.paste, opts('Paste'))
            vim.keymap.set('n', 'r', api.fs.rename, opts('Rename'))
            vim.keymap.set('n', 'd', api.fs.remove, opts('Delete'))
            -- Use Shift+H to toggle hidden files and git ignored files
            vim.keymap.set('n', 'H', function()
              api.tree.toggle_hidden_filter()
              api.tree.toggle_gitignore_filter()
            end, opts('Toggle Hidden & Git Ignored Files'))
          end
        '';
      };
    };
  };
}

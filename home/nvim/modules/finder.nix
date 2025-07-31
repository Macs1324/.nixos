{pkgs, ...}: {
  plugins.telescope = {
    enable = true;
    extensions = {
      fzf-native = {
        enable = true;
        settings = {
          fuzzy = true;
          override_generic_sorter = true;
          override_file_sorter = true;
          case_mode = "smart_case";
        };
      };
      undo.enable = true;
    };
    settings = {
      defaults = {
        prompt_prefix = " ";
        selection_caret = " ";
        path_display = ["truncate"];
        file_ignore_patterns = [
          "^.git/"
          "^.mypy_cache/"
          "^__pycache__/"
          "^output/"
          "^data/"
          "%.ipynb"
        ];
        layout_config = {
          bottom_pane = {
            height = 25;
            preview_cutoff = 120;
            prompt_position = "top";
          };
          center = {
            height = 0.4;
            preview_cutoff = 40;
            prompt_position = "top";
            width = 0.5;
          };
          cursor = {
            height = 0.9;
            preview_cutoff = 40;
            width = 0.8;
          };
          horizontal = {
            height = 0.9;
            preview_cutoff = 120;
            prompt_position = "bottom";
            width = 0.8;
          };
          vertical = {
            height = 0.9;
            preview_cutoff = 40;
            prompt_position = "bottom";
            width = 0.8;
          };
        };
      };
      pickers = {
        find_files = {
          hidden = true;
        };
        live_grep = {
          additional_args = ["--hidden"];
        };
        grep_string = {
          additional_args = ["--hidden"];
        };
      };
    };
  };

  # Additional plugins for enhanced functionality
  plugins = {
    project-nvim = {
      enable = true;
      enableTelescope = true;
    };
    todo-comments = {
      enable = true;
    };
  };

  keymaps = [
    # General Telescope
    {
      mode = "n";
      key = "<leader>sP";
      action = "<cmd>Telescope<cr>";
      options.desc = "Telescope";
    }
    {
      mode = "n";
      key = "<leader>ss";
      action = "<cmd>Telescope find_files<cr>";
      options.desc = "Smart Find";
    }

    # Search
    {
      mode = "n";
      key = "<leader>s:";
      action = "<cmd>Telescope command_history<cr>";
      options.desc = "Command History";
    }
    {
      mode = "n";
      key = "<leader>s,";
      action = "<cmd>Telescope buffers<cr>";
      options.desc = "Buffers";
    }
    {
      mode = "n";
      key = "<leader>sh";
      action = "<cmd>Telescope help_tags<cr>";
      options.desc = "Help Pages";
    }
    {
      mode = "n";
      key = "<leader>sk";
      action = "<cmd>Telescope keymaps<cr>";
      options.desc = "Keymaps";
    }
    {
      mode = "n";
      key = "<leader>su";
      action = "<cmd>Telescope undo<cr>";
      options.desc = "Undo Tree";
    }
    {
      mode = "n";
      key = "<leader>st";
      action = "<cmd>TodoTelescope<cr>";
      options.desc = "Todo Comments";
    }
    {
      mode = "n";
      key = "<leader>sT";
      action.__raw = ''
        function()
          require('todo-comments').telescope({
            keywords = {"TODO", "FIX", "FIXME"}
          })
        end
      '';
      options.desc = "Todo (TODO/FIX/FIXME)";
    }

    # File/Find
    {
      mode = "n";
      key = "<leader>ff";
      action = "<cmd>Telescope find_files<cr>";
      options.desc = "Find Files";
    }
    {
      mode = "n";
      key = "<leader>fF";
      action = "<cmd>Telescope find_files hidden=true<cr>";
      options.desc = "Find All Files";
    }
    {
      mode = "n";
      key = "<leader>fw";
      action = "<cmd>Telescope live_grep<cr>";
      options.desc = "Live Grep";
    }
    {
      mode = "n";
      key = "<leader>fr";
      action = "<cmd>Telescope oldfiles<cr>";
      options.desc = "Recent Files";
    }
    {
      mode = "n";
      key = "<leader>fp";
      action = "<cmd>Telescope projects<cr>";
      options.desc = "Projects";
    }

    # Git (using Telescope's built-in git pickers)
    {
      mode = "n";
      key = "<leader>gL";
      action = "<cmd>Telescope git_commits<cr>";
      options.desc = "Git Commits";
    }
    {
      mode = "n";
      key = "<leader>gb";
      action = "<cmd>Telescope git_branches<cr>";
      options.desc = "Git Branches";
    }
    {
      mode = "n";
      key = "<leader>gs";
      action = "<cmd>Telescope git_status<cr>";
      options.desc = "Git Status";
    }
    {
      mode = "n";
      key = "<leader>gS";
      action = "<cmd>Telescope git_stash<cr>";
      options.desc = "Git Stash";
    }

    # LSP integration
    {
      mode = "n";
      key = "<leader>lr";
      action = "<cmd>Telescope lsp_references<cr>";
      options.desc = "LSP References";
    }
    {
      mode = "n";
      key = "<leader>ld";
      action = "<cmd>Telescope lsp_definitions<cr>";
      options.desc = "LSP Definitions";
    }
    {
      mode = "n";
      key = "<leader>lD";
      action = "<cmd>Telescope lsp_type_definitions<cr>";
      options.desc = "LSP Type Definitions";
    }
    {
      mode = "n";
      key = "<leader>li";
      action = "<cmd>Telescope lsp_implementations<cr>";
      options.desc = "LSP Implementations";
    }
    {
      mode = "n";
      key = "<leader>ls";
      action = "<cmd>Telescope lsp_document_symbols<cr>";
      options.desc = "Document Symbols";
    }
    {
      mode = "n";
      key = "<leader>lS";
      action = "<cmd>Telescope lsp_workspace_symbols<cr>";
      options.desc = "Workspace Symbols";
    }

    # Additional useful pickers
    {
      mode = "n";
      key = "<leader>sm";
      action = "<cmd>Telescope marks<cr>";
      options.desc = "Marks";
    }
    {
      mode = "n";
      key = "<leader>sj";
      action = "<cmd>Telescope jumplist<cr>";
      options.desc = "Jump List";
    }
    {
      mode = "n";
      key = "<leader>sr";
      action = "<cmd>Telescope registers<cr>";
      options.desc = "Registers";
    }
    {
      mode = "n";
      key = "<leader>sc";
      action = "<cmd>Telescope colorscheme<cr>";
      options.desc = "Colorschemes";
    }

    # Search in current buffer
    {
      mode = "n";
      key = "<leader>/";
      action = "<cmd>Telescope current_buffer_fuzzy_find<cr>";
      options.desc = "Search in Buffer";
    }

    # Grep word under cursor
    {
      mode = "n";
      key = "<leader>sw";
      action = "<cmd>Telescope grep_string<cr>";
      options.desc = "Grep Word Under Cursor";
    }
  ];
}

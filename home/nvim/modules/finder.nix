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
      action.__raw = ''
        function()
          require('telescope.builtin').find_files({
            prompt_title = 'Find Projects',
            cwd = vim.fn.expand('~'),
            find_command = {'fd', '--type', 'd', '--max-depth', '3', '-E', '.git', '-E', 'node_modules'},
            attach_mappings = function(prompt_bufnr, map)
              local actions = require('telescope.actions')
              local action_state = require('telescope.actions.state')

              map('i', '<CR>', function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                vim.cmd('cd ' .. selection.path)
                require('telescope.builtin').find_files({ cwd = selection.path })
              end)

              return true
            end,
          })
        end
      '';
      options.desc = "Find Projects";
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
      key = "<leader>fR";
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

    # Grep word under cursor
    {
      mode = "n";
      key = "<leader>sw";
      action = "<cmd>Telescope grep_string<cr>";
      options.desc = "Grep Word Under Cursor";
    }
  ];

  extraConfigLua = ''
    -- Simple project detection based on common project markers
    local function find_project_root()
      local markers = {'.git', 'package.json', 'Cargo.toml', 'go.mod', 'pyproject.toml', 'flake.nix'}
      local current = vim.fn.expand('%:p:h')

      while current ~= '/' do
        for _, marker in ipairs(markers) do
          if vim.fn.filereadable(current .. '/' .. marker) == 1 or
             vim.fn.isdirectory(current .. '/' .. marker) == 1 then
            return current
          end
        end
        current = vim.fn.fnamemodify(current, ':h')
      end

      return vim.fn.getcwd()
    end

    -- Auto-change to project root when opening files
    vim.api.nvim_create_autocmd('BufEnter', {
      pattern = "*",
      callback = function()
        if vim.bo.buftype == "" then
          local root = find_project_root()
          if root ~= vim.fn.getcwd() then
            vim.cmd('cd ' .. root)
          end
        end
      end,
    })
  '';
}

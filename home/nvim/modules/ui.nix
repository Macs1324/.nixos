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
          # Keep the colored mode block, let the rest of the bar show through.
          theme.__raw = ''
            (function()
              local theme = vim.deepcopy(require("lualine.themes.auto"))
              for _, mode in pairs(theme) do
                mode.b.bg = "None"
                mode.c.bg = "None"
              end
              return theme
            end)()
          '';
          section_separators = {
            left = "";
            right = "";
          };
        };
      };
    };

    notify = {
      enable = true;
      settings = {
        fps = 60;
        icons = {
          debug = "";
          error = "";
          info = "";
          trace = "✎";
          warn = "";
        };
        level = "info";
        max_height = 10;
        max_width = 80;
        minimum_width = 50;
        # on_close = {
        #   __raw = "function() print('Window closed') end";
        # };
        # on_open = {
        #   __raw = "function() print('Window opened') end";
        # };
        render = "default";
        stages = "fade_in_slide_out";
        timeout = 5000;
        top_down = false;
      };
    };

    nui.enable = true;
    noice = {
      enable = true;
      settings.presets = {
        command_palette = true;
        inc_rename = true;
        lsp_doc_border = true;
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
          {
            __unkeyed-1 = "<leader>l";
            group = "LSP";
            desc = "Language Server Protocol";
          }
          {
            __unkeyed-1 = "<leader>s";
            group = "Search";
            desc = "Search operations";
          }
          {
            __unkeyed-1 = "<leader>f";
            group = "Find";
            desc = "Find files and content";
          }
          {
            __unkeyed-1 = "<leader>g";
            group = "Git";
            desc = "Git operations";
          }
          {
            __unkeyed-1 = "<leader>t";
            group = "Toggle";
            desc = "Toggle settings";
          }
        ];
      };
    };

    mini-tabline = {
      enable = true;
    };

    mini = {
      enable = true;

      modules = {
        indentscope = {
          enable = true;
        };
        ai = {
          n_lines = 50;
          search_method = "cover_or_next";
        };
        comment = {
          mappings = {
            comment = "<leader>/";
            comment_line = "<leader>/";
            comment_visual = "<leader>/";
            textobject = "<leader>/";
          };
        };
        diff = {
          view = {
            style = "sign";
          };
        };
        starter = {
          content_hooks = {
            "__unkeyed-1.adding_bullet" = {
              __raw = "require('mini.starter').gen_hook.adding_bullet()";
            };
            "__unkeyed-2.indexing" = {
              __raw = "require('mini.starter').gen_hook.indexing('all', { 'Builtin actions' })";
            };
            "__unkeyed-3.padding" = {
              __raw = "require('mini.starter').gen_hook.aligning('center', 'center')";
            };
          };
          evaluate_single = true;
          header = ''
            ██████╗  █████╗ ███████╗███████╗██████╗ ██╗   ██╗██╗███╗   ███╗
            ██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██║   ██║██║████╗ ████║
            ██████╔╝███████║███████╗█████╗  ██║  ██║██║   ██║██║██╔████╔██║
            ██╔══██╗██╔══██║╚════██║██╔══╝  ██║  ██║╚██╗ ██╔╝██║██║╚██╔╝██║
            ██████╔╝██║  ██║███████║███████╗██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
            ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
          '';
          items = {
            "__unkeyed-1.buildtin_actions" = {
              __raw = "require('mini.starter').sections.builtin_actions()";
            };
            "__unkeyed-2.recent_files_current_directory" = {
              __raw = "require('mini.starter').sections.recent_files(10, false)";
            };
            "__unkeyed-3.recent_files" = {
              __raw = "require('mini.starter').sections.recent_files(10, true)";
            };
            "__unkeyed-4.sessions" = {
              __raw = "require('mini.starter').sections.sessions(5, true)";
            };
          };
        };
        surround = {
          mappings = {
            add = "gsa";
            delete = "gsd";
            find = "gsf";
            find_left = "gsF";
            highlight = "gsh";
            replace = "gsr";
            update_n_lines = "gsn";
          };
        };
      };
    };
    virt-column = {
      enable = true;
      autoLoad = true;
      settings = {
        char = "┃";
        enabled = true;
        exclude = {
          buftypes = [
            "nofile"
            "quickfix"
            "terminal"
            "prompt"
          ];
          filetypes = [
            "lspinfo"
            "packer"
            "checkhealth"
            "help"
            "man"
            "TelescopePrompt"
            "TelescopeResults"
          ];
        };
        highlight = "NonText";
        virtcolumn = "";
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

  opts = {
    cursorline = true;
    colorcolumn = "80";
  };

  extraConfigLua = ''
    -- UI specific lua config
    vim.opt.termguicolors = true

    -- mini.base16 (the Stylix colorscheme) gives the gutter, statusline and
    -- tabline an opaque base01/base02 background. Drop it so they match the
    -- transparent editor area, keeping each group's foreground.
    local function clear_ui_backgrounds()
      local groups = {
        "LineNr", "LineNrAbove", "LineNrBelow", "CursorLineNr",
        "CursorLine", "CursorLineSign", "CursorLineFold",
        "SignColumn", "FoldColumn",
        "StatusLine", "StatusLineNC", "WinBar", "WinBarNC",
        "TabLine", "TabLineFill", "TabLineSel",
        "MiniTablineCurrent", "MiniTablineVisible", "MiniTablineHidden",
        "MiniTablineTrunc",
        "MiniDiffSignAdd", "MiniDiffSignChange", "MiniDiffSignDelete",
        "GitSignsAdd", "GitSignsChange", "GitSignsDelete", "GitSignsUntracked",
      }
      for _, name in ipairs(groups) do
        local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
        hl.bg, hl.ctermbg = nil, nil
        vim.api.nvim_set_hl(0, name, hl)
      end
      -- Without a CursorLine background, the bold number marks the current line.
      local nr = vim.api.nvim_get_hl(0, { name = "CursorLineNr", link = false })
      nr.bold = true
      vim.api.nvim_set_hl(0, "CursorLineNr", nr)
      -- Same for the current tab: use TabLineSel's accent as its text color.
      local tab = vim.api.nvim_get_hl(0, { name = "MiniTablineCurrent", link = false })
      tab.fg = vim.api.nvim_get_hl(0, { name = "TabLineSel", link = false }).fg
      vim.api.nvim_set_hl(0, "MiniTablineCurrent", tab)
      -- Modified buffers are drawn inverted; show the accent as text instead.
      for _, name in ipairs({
        "MiniTablineModifiedCurrent",
        "MiniTablineModifiedVisible",
        "MiniTablineModifiedHidden",
      }) do
        local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
        if hl.bg then
          hl.fg, hl.bg, hl.ctermbg = hl.bg, nil, nil
          vim.api.nvim_set_hl(0, name, hl)
        end
      end
    end
    clear_ui_backgrounds()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = clear_ui_backgrounds })
  '';
}

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
        top_down = true;
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
  '';
}

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

    nui.enable = true;
    noice = {
      enable = true;
      settings.presets = {
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

    mini = {
      enable = true;

      modules = {
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

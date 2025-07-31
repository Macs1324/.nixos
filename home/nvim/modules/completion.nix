{
  pkgs,
  config,
  ...
}: {
  plugins = {
    # Core completion engine
    cmp = {
      enable = true;
      autoEnableSources = false;

      settings = {
        # Performance settings
        performance = {
          debounce = 60;
          throttle = 30;
          max_view_entries = 200;
          fetching_timeout = 200;
        };

        # Completion behavior
        completion = {
          completeopt = "menu,menuone,noselect";
          keyword_length = 1;
        };

        # Snippet expansion
        snippet = {
          expand.__raw = ''
            function(args)
              require('luasnip').lsp_expand(args.body)
            end
          '';
        };

        # Window styling
        window = {
          completion = {
            border = "rounded";
            winhighlight = "Normal:CmpPmenu,CursorLine:CmpSel,Search:None";
            scrollbar = false;
          };
          documentation = {
            border = "rounded";
            winhighlight = "Normal:CmpDoc";
            max_height = 15;
            max_width = 60;
          };
        };

        # Formatting
        formatting = {
          expandable_indicator = true;
          fields = ["kind" "abbr" "menu"];
          format.__raw = ''
            function(entry, vim_item)
              local kind_icons = {
                Text = "󰉿",
                Method = "󰆧",
                Function = "󰊕",
                Constructor = "",
                Field = "󰜢",
                Variable = "󰀫",
                Class = "󰠱",
                Interface = "",
                Module = "",
                Property = "󰜢",
                Unit = "󰑭",
                Value = "󰎠",
                Enum = "",
                Keyword = "󰌋",
                Snippet = "",
                Color = "󰏘",
                File = "󰈙",
                Reference = "󰈇",
                Folder = "󰉋",
                EnumMember = "",
                Constant = "󰏿",
                Struct = "󰙅",
                Event = "",
                Operator = "󰆕",
                TypeParameter = ""
              }

              vim_item.kind = string.format('%s %s', kind_icons[vim_item.kind] or "", vim_item.kind)

              vim_item.menu = ({
                nvim_lsp = "[LSP]",
                nvim_lua = "[Lua]",
                luasnip = "[Snip]",
                buffer = "[Buf]",
                path = "[Path]",
                cmdline = "[Cmd]",
                git = "[Git]",
                emoji = "[Emoji]",
                calc = "[Calc]",
                treesitter = "[TS]"
              })[entry.source.name] or "[?]"

              local label = vim_item.abbr
              local truncated_label = vim.fn.strchars(label) > 25 and vim.fn.strcharpart(label, 0, 22) .. "..." or label
              vim_item.abbr = truncated_label

              return vim_item
            end
          '';
        };

        # Source configuration
        sources = [
          {
            name = "nvim_lsp";
            priority = 1000;
            group_index = 1;
            max_item_count = 20;
          }
          {
            name = "luasnip";
            priority = 800;
            group_index = 1;
            max_item_count = 5;
          }
          {
            name = "buffer";
            priority = 500;
            group_index = 2;
            max_item_count = 10;
          }
          {
            name = "path";
            priority = 400;
            group_index = 2;
            max_item_count = 10;
          }
          {
            name = "treesitter";
            priority = 300;
            group_index = 3;
            max_item_count = 8;
          }
        ];

        # Sorting
        sorting = {
          priority_weight = 2;
          comparators = [
            "require('cmp').config.compare.offset"
            "require('cmp').config.compare.exact"
            "require('cmp').config.compare.score"
            "require('cmp').config.compare.recently_used"
            "require('cmp').config.compare.locality"
            "require('cmp').config.compare.kind"
            "require('cmp').config.compare.sort_text"
            "require('cmp').config.compare.length"
            "require('cmp').config.compare.order"
          ];
        };

        # Key mappings
        mapping = {
          "<C-p>".__raw = "cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert })";
          "<C-n>".__raw = "cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert })";
          "<Up>".__raw = "cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert })";
          "<Down>".__raw = "cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert })";
          "<C-u>".__raw = "cmp.mapping.scroll_docs(-4)";
          "<C-d>".__raw = "cmp.mapping.scroll_docs(4)";
          "<C-Space>".__raw = "cmp.mapping.complete()";
          "<C-e>".__raw = "cmp.mapping.abort()";
          "<CR>".__raw = ''
            cmp.mapping({
              i = function(fallback)
                if cmp.visible() and cmp.get_active_entry() then
                  cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
                else
                  fallback()
                end
              end,
              s = cmp.mapping.confirm({ select = true }),
              c = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
            })
          '';
          "<Tab>".__raw = ''
            cmp.mapping(function(fallback)
              local luasnip = require('luasnip')
              if cmp.visible() then
                cmp.select_next_item()
              elseif luasnip.locally_jumpable(1) then
                luasnip.jump(1)
              else
                fallback()
              end
            end, { "i", "s" })
          '';
          "<S-Tab>".__raw = ''
            cmp.mapping(function(fallback)
              local luasnip = require('luasnip')
              if cmp.visible() then
                cmp.select_prev_item()
              elseif luasnip.locally_jumpable(-1) then
                luasnip.jump(-1)
              else
                fallback()
              end
            end, { "i", "s" })
          '';
        };
      };
    };

    # Snippet engine
    luasnip = {
      enable = true;
      settings = {
        enable_autosnippets = true;
        store_selection_keys = "<Tab>";
        update_events = "TextChanged,TextChangedI";
        delete_check_events = "TextChanged";
        history = true;
        region_check_events = "CursorMoved";
      };
    };

    # Core completion sources
    cmp-nvim-lsp.enable = true;
    cmp-buffer.enable = true;
    cmp-path.enable = true;
    cmp_luasnip.enable = true;
    cmp-treesitter.enable = true;
    friendly-snippets.enable = true;

    # Autopairs integration
    nvim-autopairs = {
      enable = true;
      settings = {
        check_ts = true;
        disable_filetype = ["TelescopePrompt"];
        disable_in_macro = true;
        disable_in_visualblock = false;
        disable_in_replace_mode = true;
        enable_moveright = true;
        enable_afterquote = true;
        enable_check_bracket_line = false;
        enable_bracket_in_quote = true;
        break_undo = true;
        check_comma = true;
        map_cr = true;
        map_bs = true;
      };
    };
  };

  # Key mappings
  keymaps = [
    {
      mode = "i";
      key = "<C-j>";
      action.__raw = "function() require('luasnip').jump(1) end";
      options = {
        desc = "Next snippet placeholder";
        silent = true;
      };
    }
    {
      mode = "i";
      key = "<C-k>";
      action.__raw = "function() require('luasnip').jump(-1) end";
      options = {
        desc = "Previous snippet placeholder";
        silent = true;
      };
    }
    {
      mode = "s";
      key = "<C-j>";
      action.__raw = "function() require('luasnip').jump(1) end";
      options = {
        desc = "Next snippet placeholder";
        silent = true;
      };
    }
    {
      mode = "s";
      key = "<C-k>";
      action.__raw = "function() require('luasnip').jump(-1) end";
      options = {
        desc = "Previous snippet placeholder";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>tc";
      action.__raw = "function() require('cmp').setup.buffer({ enabled = not require('cmp').get_config().enabled }) end";
      options = {
        desc = "Toggle completion";
        silent = true;
      };
    }
  ];

  extraConfigLua = ''
    -- Completion configuration
    local cmp = require('cmp')
    local luasnip = require('luasnip')

    -- Load friendly-snippets
    require("luasnip.loaders.from_vscode").lazy_load()
    require("luasnip.loaders.from_snipmate").lazy_load()

    -- Autopairs integration
    local cmp_autopairs = require('nvim-autopairs.completion.cmp')
    cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())

    -- Highlight groups for completion
    vim.api.nvim_set_hl(0, 'CmpPmenu', { bg = '#1e1e2e', fg = '#cdd6f4' })
    vim.api.nvim_set_hl(0, 'CmpSel', { bg = '#313244', fg = '#cdd6f4', bold = true })
    vim.api.nvim_set_hl(0, 'CmpDoc', { bg = '#181825', fg = '#cdd6f4' })

    -- Performance optimizations
    vim.opt.completeopt = 'menu,menuone,noselect'
    vim.opt.shortmess:append('c')
    vim.opt.updatetime = 300
    vim.opt.timeoutlen = 500
  '';
}

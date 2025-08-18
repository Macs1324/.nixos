{
  pkgs,
  config,
  ...
}: {
  plugins = {
    lsp = {
      enable = true;
      servers = {
        nil_ls.enable = true; # Nix LSP
        lua_ls.enable = true;
        svelte.enable = true; # Svelte LSP
        ts_ls.enable = true; # TS/JS
        marksman.enable = true;
        biome.enable = true;
      };
    };
    lsp-format = {
      enable = true;
      autoLoad = true;
      settings = {
        go = {
          exclude = [
            "gopls"
          ];
          force = true;
          order = [
            "gopls"
            "efm"
          ];
          sync = true;
        };
        typescript = {
          tab_width = {
            __raw = ''
              function()
                return vim.opt.shiftwidth:get()
              end'';
          };
        };
        yaml = {
          tab_width = 2;
        };
      };
    };
    none-ls = {
      enable = true;
      autoLoad = true;
      enableLspFormat = true;
      sources.formatting.prettierd = {
        enable = true;
        disableTsServerFormatter = true;
        settings = {
          extra_args = [
            "--use-tabs"
            "--tab-width=4"
            "--print-width=80"
          ];
        };
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "gd";
      action = "<cmd>lua vim.lsp.buf.definition()<cr>";
      options.desc = "Go to definition";
    }
    {
      mode = "n";
      key = "<leader>lr";
      action = "<cmd>lua vim.lsp.buf.references()<cr>";
      options.desc = "LSP References";
    }
  ];

  extraConfigLua = ''
    -- LSP specific configuration
    vim.diagnostic.config({
      virtual_text = false,
      signs = true,
      underline = true,
      update_in_insert = false,
    })

    -- Format on save
    vim.api.nvim_create_autocmd("BufWritePre", {
      callback = function()
        vim.lsp.buf.format()
      end,
    })
  '';
}

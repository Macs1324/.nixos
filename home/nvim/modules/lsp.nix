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
        marksman.enable = true; # Markdown
        biome.enable = true; # JS/TS formatter
        tailwindcss.enable = true;
        cucumber_language_server.enable = true;
        cucumber_language_server.package = null;
      };
    };
    none-ls = {
      enable = true;
      autoLoad = true;
      enableLspFormat = false;
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
    {
      mode = "n";
      key = "<leader>tf";
      action = "<cmd>ToggleAutoFormat<cr>";
      options.desc = "Toggle auto format";
    }
    {
      mode = "n";
      key = "<leader>le";
      action = "<cmd>lua vim.diagnostic.open_float()<cr>";
      options.desc = "Show line diagnostics";
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

    -- Auto format toggle
    vim.g.auto_format = true

    -- Format on save (only if auto_format is enabled)
    vim.api.nvim_create_autocmd("BufWritePre", {
      callback = function()
        if vim.g.auto_format then
          vim.lsp.buf.format()
        end
      end,
    })

    -- Toggle auto format function
    local function toggle_auto_format()
      vim.g.auto_format = not vim.g.auto_format
      local status = vim.g.auto_format and "enabled" or "disabled"
      print("Auto format " .. status)
    end

    -- Create user command for toggling
    vim.api.nvim_create_user_command("ToggleAutoFormat", toggle_auto_format, {})
  '';
}

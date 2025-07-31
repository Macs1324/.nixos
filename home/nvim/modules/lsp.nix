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
  '';
}

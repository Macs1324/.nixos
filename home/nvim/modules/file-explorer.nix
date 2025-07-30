{
  pkgs,
  config,
  ...
}: {
  plugins = {
    web-devicons.enable = true;
    nvim-tree = {
      enable = true;
      autoClose = true;
      view = {
        width = 30;
        side = "left";
      };
      renderer = {
        groupEmpty = true;
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>NvimTreeToggle<cr>";
      options.desc = "Toggle file explorer";
    }
    {
      mode = "n";
      key = "<leader>ef";
      action = "<cmd>NvimTreeFocus<cr>";
      options.desc = "Focus file explorer";
    }
  ];
}

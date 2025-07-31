{pkgs, ...}: {
  opts = {
    number = true;
    relativenumber = true;
  };

  keymaps = [
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
      options.desc = "Move to left window";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
      options.desc = "Move to bottom window";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
      options.desc = "Move to top window";
    }
    {
      mode = "n";
      key = "<c-l>";
      action = "<c-w>l";
      options.desc = "move to right window";
    }
    {
      mode = "n";
      key = "\\";
      action = "<c-w>s";
      options.desc = "Horizontal split";
    }
    {
      mode = "n";
      key = "|";
      action = "<c-w>v";
      options.desc = "Vertical split";
    }
  ];
}

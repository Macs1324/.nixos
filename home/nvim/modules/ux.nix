{
  pkgs,
  config,
  ...
}: {
  opts = {};

  plugins = {
    indent-blankline = {
      enable = true;
      autoLoad = true;
    };
  };

  keymaps = [
  ];
}

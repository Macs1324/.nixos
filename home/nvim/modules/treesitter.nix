{
  pkgs,
  config,
  ...
}: {
  plugins.treesitter = {
    enable = true;
    folding = true;
    settings.highlight = {
      enable = true;
    };
  };
}

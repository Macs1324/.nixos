{...}: {
  stylix.targets.vesktop.enable = false;

  programs.vesktop = {
    enable = true;
    vencord = {
      # Merge Home Manager settings into a file Vesktop can write.
      mutableSettings = true;
      settings.enabledThemes = [];
    };
  };
}

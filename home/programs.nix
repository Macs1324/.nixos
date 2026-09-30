{pkgs, ...}: {
  programs.firefox = {
    enable = true;
    # Preserve the pre-26.05 profile location until it is migrated explicitly.
    configPath = ".mozilla/firefox";
  };

  programs.zen-browser = {
    enable = true;
    profiles = {
      default = {};
    };
  };

  programs.bat = {
    enable = true;
  };

  programs.emacs = {
    enable = true;
  };

  programs.zed-editor = {
    enable = true;
  };

  programs.lazygit = {
    enable = true;
    settings.git.diffRenderers = [{command = "delta --paging=never";}];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      # The theme Stylix generates for bat, so diffs follow the wallpaper palette.
      syntax-theme = "base16-stylix";
    };
  };

  # Prebuilt nix-index database: `, cmd` runs anything from nixpkgs, and an
  # unknown command names the package that provides it.
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  programs.cava = {
    enable = true;
  };

  programs.tmux = {
    enable = true;
  };

  programs.btop = {
    enable = true;
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "Macs1324";
      email = "max.blank410@gmail.com";
    };
  };
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };
}

{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./home/hyprland.nix
    ./home/eww.nix
  ];
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "macs";
  home.homeDirectory = "/home/macs";

  programs.git = {
    enable = true;
    userName = "Macs1324";
    userEmail = "max.blank410@gmail.com";
  };
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        dimensions = {
          lines = 3;
          columns = 200;
        };
        opacity = 0.4;
      };
      keyboard.bindings = [
        {
          key = "K";
          mods = "Control";
          chars = "\\u000c";
        }
      ];
    };
  };

  programs.bash = {
    enable = true;
    bashrcExtra = ''
      export PATH=$PATH:~/.config/emacs/bin
    '';
  };
  services.dunst = {
    enable = true;
    settings = {
      global = {
        width = 300;
        height = 300;
        offset = "30x50";
        origin = "top-right";
        transparency = 10;
        frame_color = "#eceff1";
        font = "Droid Sans 9";
      };

      urgency_normal = {
        background = "#37474f";
        foreground = "#eceff1";
        timeout = 10;
      };
    };
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

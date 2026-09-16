{pkgs, ...}: {
  programs.direnv = {
    enable = true;
    enableBashIntegration = true; # see note on other shells below
    nix-direnv.enable = true;
  };
  # programs.ncspot.enable = true;

  # Fastfetch - Deactivated in favor of pfetch (can be re-enabled anytime)
  programs.fastfetch = {
    enable = false;
    settings = {
      logo = {
        type = "kitty";
        source = "~/.nixos/assets/logo.png";
        width = 48;
        height = 19;
      };
      modules = [
        "title"
        "separator"
        "os"
        {
          type = "host";
          format = "{/2}{-}{/}{2}{?3} {3}{?}";
        }
        "kernel"
        "uptime"
        {
          type = "battery";
          format = "{/4}{-}{/}{4}{?5} [{5}]{?}";
        }
        "break"
        "packages"
        "shell"
        "display"
        "terminal"
        "break"
        "cpu"
        {
          type = "gpu";
          key = "GPU";
        }
        "memory"
        "break"
        "colors"
      ];
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      pfetch
      alias nd="nix develop -c $SHELL"
      alias nv="neovide --fork"
    '';
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [
        "git"
        "npm"
        "history"
        "node"
        "rust"
        "deno"
      ];
    };
  };

  programs.bash = {
    enable = true;
    bashrcExtra = ''
      export PATH=$PATH:~/.config/emacs/bin
    '';
  };
  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.cargo/bin"
    "$HOME/.local/bin"
  ];

  home.packages = [pkgs.pfetch];
  # Pfetch configuration
  home.sessionVariables = {
    PF_INFO = "ascii title os kernel uptime pkgs memory";
    PF_ASCII = "nixos";
    PF_SEP = "  ";
  };
}

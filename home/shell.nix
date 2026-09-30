{pkgs, ...}: {
  programs.direnv = {
    enable = true;
    enableBashIntegration = true; # see note on other shells below
    nix-direnv.enable = true;
  };
  # programs.ncspot.enable = true;

  # A small image greeting on every interactive shell. The logo uses the kitty
  # graphics protocol, so other terminals (and tmux) get the small ASCII logo.
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "kitty";
        source = "${../assets/logo.png}";
        width = 20;
        height = 9;
        padding.top = 1;
      };
      display.separator = "  ";
      modules = [
        "title"
        "os"
        "kernel"
        "uptime"
        "packages"
        "wm"
        "memory"
        "colors"
      ];
    };
  };

  programs.starship.enable = true;
  programs.zoxide.enable = true;
  programs.fzf = {
    enable = true;
    # Atuin owns Ctrl-R; fzf keeps Ctrl-T and Alt-C.
    historyWidget.command = "";
  };
  programs.eza = {
    enable = true;
    icons = "auto";
    git = true;
  };
  programs.atuin = {
    enable = true;
    # Ctrl-R opens Atuin; the up arrow keeps plain zsh history stepping.
    flags = ["--disable-up-arrow"];
  };
  programs.yazi = {
    enable = true;
    # `y` opens yazi and cds to where you quit it (the new upstream default).
    shellWrapperName = "y";
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      if [[ ( $TERM == xterm-kitty || $TERM == xterm-ghostty ) && -z $TMUX ]]; then
        fastfetch
      else
        fastfetch --logo nixos --logo-type small
      fi
      alias nd="nix develop -c $SHELL"
      alias nv="neovide --fork"
    '';
    oh-my-zsh = {
      enable = true;
      # No theme: Starship draws the prompt.
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
}

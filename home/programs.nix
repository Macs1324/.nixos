{
  config,
  lib,
  pkgs,
  ...
}: {
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
    terminal = "tmux-256color";
    mouse = true;
    # The login shell is bash, and its hand-off to nu (nushell.nix) only fires
    # at SHLVL 1, which a tmux pane never is.
    shell = lib.getExe config.programs.nushell.package;
    extraConfig = ''
      # Truecolor and modified keys (Shift+Enter etc.) from the outer terminal.
      # Ghostty speaks modifyOtherKeys; kitty doesn't, so it sends CSI u itself
      # (see the shift+enter map in terminals.nix).
      set -as terminal-features 'xterm*:RGB:extkeys'
      # Undercurl/coloured underlines and OSC 8 links; kitty supports both.
      set -as terminal-features 'xterm*:usstyle:hyperlinks'
      # Forward focus in/out to panes (nvim FocusGained/autoread).
      set -g focus-events on
      # Claude Code drops to 256 colours under $TMUX unless told truecolor
      # passes through, which the RGB feature above makes true.
      set-environment -g CLAUDE_CODE_TMUX_TRUECOLOR 1
      set -s extended-keys on
      set -s extended-keys-format csi-u

      # Let kitty graphics (kitten icat, fastfetch) reach the outer terminal.
      set -g allow-passthrough on

      # kitty keys its tmux-only bindings off this title prefix.
      set -g set-titles on
      set -g set-titles-string 'tmux #S:#W'
    '';
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

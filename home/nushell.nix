# Trial setup: zsh stays the login and terminal shell, so run `nu` to try this.
# Starship, zoxide, fzf, Atuin, direnv and yazi hook in through their default
# Home Manager shell integration. eza's stays off so `ls` keeps returning tables.
{...}: {
  programs.nushell = {
    enable = true;
    # Pick up home.sessionVariables and sessionPath when not started from zsh.
    loadSessionVariables = true;
    settings.show_banner = false;
    shellAliases = {
      nd = "nix develop -c nu";
      nv = "neovide --fork";
    };
    extraConfig = ''
      if ($env.TERM? in [xterm-kitty xterm-ghostty]) and ($env.TMUX? | is-empty) {
        fastfetch
      } else {
        fastfetch --logo nixos --logo-type small
      }
    '';
  };

  # Completions for external commands, which Nushell lacks out of the box.
  programs.carapace = {
    enable = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
  };
}

# Nushell is the interactive shell everywhere, while the login shell stays bash
# (system/base.nix) and zsh stays available as a fallback.
# Starship, zoxide, fzf, Atuin, direnv and yazi hook in through their default
# Home Manager shell integration. eza's stays off so `ls` keeps returning tables.
{
  config,
  lib,
  ...
}: {
  programs.nushell = {
    enable = true;
    # Pick up home.sessionVariables and sessionPath when not started from bash.
    loadSessionVariables = true;
    settings.show_banner = false;
    shellAliases = {
      nd = "nix develop -c nu";
      nv = "neovide --fork";
    };
    extraConfig = ''
      # Inside tmux, TERM is tmux's own; ask it which terminal the client runs in.
      let in_tmux = not ($env.TMUX? | is-empty)
      let outer_term = if $in_tmux { tmux display-message -p '#{client_termname}' } else { $env.TERM? }
      if $outer_term in [xterm-kitty xterm-ghostty] {
        # tmux eats raw kitty graphics; `kitten icat` uses unicode placeholders there.
        if $in_tmux { fastfetch --logo-type kitty-icat } else { fastfetch }
      } else {
        fastfetch --logo nixos --logo-type small
      }
    '';
  };

  # TTY and SSH logins land in bash, which has set up the environment by now.
  # Running `bash` by hand stays in bash: its parent is nu or SHLVL is above 1.
  programs.bash.initExtra = ''
    if [[ $(</proc/$PPID/comm) != nu && $SHLVL == 1 && -z ''${BASH_EXECUTION_STRING-} ]]; then
      exec ${lib.getExe config.programs.nushell.package}
    fi
  '';

  # Completions for external commands, which Nushell lacks out of the box.
  programs.carapace = {
    enable = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
  };
}

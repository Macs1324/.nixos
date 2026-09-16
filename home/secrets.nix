{
  config,
  lib,
  ...
}: let
  # git-crypt encrypted files; plaintext only when the checkout is unlocked.
  sshSecrets = ../secrets/ssh;
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # config.local keeps any hand-maintained hosts on a machine; config.d holds
    # the decrypted fragments from this repository. OpenSSH ignores a missing include.
    includes = [
      "config.local"
      "config.d/*.conf"
    ];
  };

  # Copy each decrypted SSH fragment into ~/.ssh/config.d. Files that are still
  # ciphertext are skipped with a warning instead of breaking every ssh call.
  home.activation.installSshSecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
    target=${lib.escapeShellArg config.home.homeDirectory}/.ssh/config.d
    run mkdir -p "$target"
    for source in ${sshSecrets}/*.conf; do
      name=$(basename "$source")
      if [[ "$(head -c 9 "$source" | tr -d '\0')" == GITCRYPT ]]; then
        warnEcho "secrets/ssh/$name is still git-crypt encrypted; run 'git-crypt unlock' and switch again"
        run rm -f "$target/$name"
      else
        run install -m 0600 "$source" "$target/$name"
      fi
    done
  '';
}

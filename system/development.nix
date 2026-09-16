{
  pkgs,
  lib,
  ...
}: {
  # Increase the amount of inotify watchers
  # Note that inotify watches consume 1kB on 64-bit machines.
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 1048576; # default:  8192
    "fs.inotify.max_user_instances" = 1024; # default:   128
    "fs.inotify.max_queued_events" = 32768; # default: 16384
  };
  services.postgresql = {
    enable = true;
    ensureDatabases = ["clockout"];
    authentication = lib.mkOverride 10 ''
      #type database  DBuser  auth-method
      local all       all     trust
    '';
  };

  programs.java.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };
  environment.systemPackages = with pkgs; [
    # Programming languages
    nodejs
    bun
    rustup
    python3
    zig
    gcc
    go
    sqlite

    # Dev tools
    pgadmin4
    git-lfs
    gource
  ];
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.sandlock;
  toml = pkgs.formats.toml {};
  sandlock = lib.getExe (pkgs.callPackage ../pkgs/sandlock/package.nix {});
  noctalia = lib.getExe config.programs.noctalia.package;
  # `sandlock -f` returns only once the session is locked. If it cannot lock
  # for any reason, Noctalia's own lock takes over, so nothing (least of all a
  # before-sleep hook) ever leaves the machine unlocked.
  lock = "${sandlock} -f || ${noctalia} msg session lock";
in {
  options.programs.sandlock = {
    settings = lib.mkOption {
      inherit (toml) type;
      default = {};
      example = {
        storm = {
          intensity = 0.5;
          gusts = 0.1;
          swirl = 0.35;
        };
      };
      description = "sandlock's config.toml; see pkgs/sandlock/src/config.rs for every key.";
    };
    lockCommand = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = lock;
      description = "Locks the session with sandlock, falling back to Noctalia.";
    };
  };

  config = {
    # The time emerges from the storm below the centre of the largest output
    # (hosts add their own attractors to this list), in the palette's primary
    # accent (Noctalia's `mPrimary`): what stands out most against the
    # palette's surfaces, which is most of what is on screen.
    programs.sandlock.settings.attractor = [
      {
        clock = {};
        color = config.lib.stylix.colors.withHashtag.base0D;
        position = [0.5 0.72];
        scale = 2.4;
      }
    ];

    xdg.configFile."sandlock/config.toml" = lib.mkIf (cfg.settings != {}) {
      source = toml.generate "sandlock-config.toml" cfg.settings;
    };

    # The lock keybind (niri and Hyprland).
    desktop.apps.lock = lock;

    # sandlock locks before suspend instead of Noctalia; swayidle's
    # before-sleep hook holds the suspend until `sandlock -f` has locked.
    programs.noctalia.settings.lockscreen.lock_before_suspend = false;
    services.swayidle = {
      enable = true;
      events = {
        before-sleep = lock;
        lock = lock; # loginctl lock-session
      };
    };
  };
}

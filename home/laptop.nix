{...}: {
  # Lid close and `systemctl suspend` lock through sandlock's before-sleep hook
  # (home/sandlock.nix). Noctalia's idle behaviours ship disabled, so an
  # unattended laptop would otherwise stay unlocked and lit.
  programs.noctalia.settings.idle.behavior = {
    # Sooner than on desktops; locks with sandlock (home/sandlock.nix).
    lock.timeout = 300;
    screen-off = {
      timeout = 330;
      action = "screen_off";
    };
    # Only on battery: a long build on the charger should not be put to sleep.
    suspend = {
      timeout = 900;
      action = "command";
      # The before-sleep hook locks first.
      command = "grep -qx 0 /sys/class/power_supply/A*/online && systemctl suspend";
    };
  };

  # Palm rejection: ignore the touchpad while typing.
  programs.niri.settings.input.touchpad.dwt = true;
}

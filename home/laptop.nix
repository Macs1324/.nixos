{...}: {
  # Noctalia already locks on lid close and `systemctl suspend`
  # (lockscreen.lock_before_suspend defaults to true); its idle behaviours ship
  # disabled, so an unattended laptop would otherwise stay unlocked and lit.
  programs.noctalia.settings.idle.behavior = {
    lock = {
      timeout = 300;
      action = "lock";
    };
    screen-off = {
      timeout = 330;
      action = "screen_off";
    };
    # Only on battery: a long build on the charger should not be put to sleep.
    suspend = {
      timeout = 900;
      action = "command";
      command = "grep -qx 0 /sys/class/power_supply/A*/online && noctalia msg session lock-and-suspend";
    };
  };

  # Palm rejection: ignore the touchpad while typing.
  programs.niri.settings.input.touchpad.dwt = true;
}

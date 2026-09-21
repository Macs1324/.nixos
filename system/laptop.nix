{...}: let
  # Holding a lithium pack at 100% on a machine that is mostly docked is what
  # ages it fastest. Raise this (or write the sysfs file by hand) before a trip.
  chargeLimit = 80;
in {
  # Intel's thermal daemon throttles gradually ahead of the firmware's hard trip
  # points, which matters for a 45W H-series part in a thin chassis. It coexists
  # with power-profiles-daemon (system/desktop.nix); TLP and auto-cpufreq do not.
  services.thermald.enable = true;

  # BIOS, SSD and Thunderbolt firmware through LVFS: `fwupdmgr update`.
  services.fwupd.enable = true;

  networking.networkmanager.wifi.powersave = true;

  # logind's default for a short press is poweroff, which a lid-adjacent button
  # makes easy to hit by accident. niri already intercepts the key; this covers
  # Hyprland, SDDM and the TTYs.
  services.logind.settings.Login = {
    HandlePowerKey = "suspend";
    HandlePowerKeyLongPress = "poweroff";
  };

  # A service rather than a udev ATTR rule: the threshold attribute is attached
  # by the vendor WMI driver, which can load after the battery's add event.
  systemd.services.battery-charge-limit = {
    description = "Cap battery charge at ${toString chargeLimit}%";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for threshold in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
        if [ -w "$threshold" ]; then
          echo ${toString chargeLimit} > "$threshold"
        fi
      done
    '';
  };
}

# Consume the normalized desktop.monitors option from modules/monitors.nix.
# Keep compositor-specific details here, outside the machine inventories.
{lib}: monitors: let
  enabled = lib.filterAttrs (_: monitor: monitor.enable) monitors;
  primary = lib.findFirst (monitor: monitor.primary) null (lib.attrValues enabled);
  defaultWallpaper =
    if primary == null
    then null
    else primary.wallpaper;
  wallpaperFor = monitor:
    if monitor.wallpaper != null
    then monitor.wallpaper
    else defaultWallpaper;
  # Leftmost placed output (top edge breaks ties); the primary output stands in
  # when no output has an explicit position.
  placed = builtins.filter (monitor: monitor.position != null) (lib.attrValues enabled);
  leftmost =
    if placed == []
    then primary
    else
      builtins.head (lib.sort (a: b:
        a.position.x < b.position.x || (a.position.x == b.position.x && a.position.y < b.position.y))
      placed);
  modeString = mode:
    if mode == null
    then "preferred"
    else
      "${toString mode.width}x${toString mode.height}"
      + lib.optionalString (mode.refresh != null) "@${toString mode.refresh}";
in {
  inherit defaultWallpaper;
  themeWallpaper =
    if leftmost == null
    then null
    else wallpaperFor leftmost;
  names = builtins.attrNames enabled;
  wallpapers = lib.mapAttrs (_: wallpaperFor) enabled;

  niriOutputs = lib.mapAttrs (_: monitor:
    {inherit (monitor) enable;}
    // lib.optionalAttrs monitor.enable {
      inherit (monitor) scale position;
      # niri-flake requires a float even for whole-number refresh rates.
      mode =
        if monitor.mode == null
        then null
        else
          monitor.mode
          // {
            refresh =
              if monitor.mode.refresh == null
              then null
              else monitor.mode.refresh * 1.0;
          };
      transform = {inherit (monitor) rotation flipped;};
    })
  monitors;

  hyprlandMonitors = lib.mapAttrsToList (name: monitor:
    {
      output = name;
      disabled = !monitor.enable;
    }
    // lib.optionalAttrs monitor.enable {
      mode = modeString monitor.mode;
      inherit (monitor) scale;
      position =
        if monitor.position == null
        then "auto"
        else "${toString monitor.position.x}x${toString monitor.position.y}";
      transform =
        builtins.div monitor.rotation 90
        + (
          if monitor.flipped
          then 4
          else 0
        );
    })
  monitors;

  hyprlandWorkspaces = lib.concatLists (lib.mapAttrsToList (name: monitor:
    map (workspace: {
      inherit workspace;
      monitor = name;
    })
    monitor.hyprlandWorkspaces)
  enabled);

  noctaliaWallpaper = {
    enabled = true;
    automation.enabled = false;
    default.path = toString defaultWallpaper;
    monitors = lib.mapAttrs (_: monitor: {path = toString (wallpaperFor monitor);}) enabled;
  };
}

# Consume the normalized desktop.monitors option from modules/monitors.nix.
# Keep compositor-specific details here, outside the machine inventories.
#
# With `pkgs`, every wallpaper is converted for the output it is on
# (lib/wallpaper.nix: an upright sRGB PNG at its exact size); without, the
# images are passed through as declared (the evaluation-only tests).
{
  lib,
  pkgs ? null,
}: monitors: let
  enabled = lib.filterAttrs (_: monitor: monitor.enable) monitors;
  # name/value pairs, so outputs found by a property keep their names.
  outputs = lib.mapAttrsToList lib.nameValuePair enabled;
  primary = lib.findFirst (output: output.value.primary) null outputs;
  # The output's physical size as it is seen (rotation applied), if declared.
  seenSize = monitor:
    if monitor.mode == null
    then null
    else if monitor.rotation == 90 || monitor.rotation == 270
    then [monitor.mode.height monitor.mode.width]
    else [monitor.mode.width monitor.mode.height];
  prepare = name: monitor: image:
    if pkgs == null || image == null
    then image
    else
      import ./wallpaper.nix {inherit pkgs;} {
        inherit name image;
        size = seenSize monitor;
      };
  wallpaperFor = name: monitor:
    prepare name monitor (
      if monitor.wallpaper != null
      then monitor.wallpaper
      else primary.value.wallpaper or null
    );
  # The primary output's wallpaper, for outputs nobody declared.
  defaultWallpaper =
    if primary == null
    then null
    else wallpaperFor primary.name primary.value;
  # Leftmost placed output (top edge breaks ties); the primary output stands in
  # when no output has an explicit position.
  placed = builtins.filter (output: output.value.position != null) outputs;
  leftmost =
    if placed == []
    then primary
    else
      builtins.head (lib.sort (a: b: let
        pa = a.value.position;
        pb = b.value.position;
      in
        pa.x < pb.x || (pa.x == pb.x && pa.y < pb.y))
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
    else wallpaperFor leftmost.name leftmost.value;
  names = builtins.attrNames enabled;
  wallpapers = lib.mapAttrs wallpaperFor enabled;

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

  # Logical center of each enabled output, for Noctalia widgets placed in
  # output-local coordinates. Outputs without a declared mode have no known size.
  logicalCenters = lib.mapAttrs (_: monitor: let
    sideways = monitor.rotation == 90 || monitor.rotation == 270;
    width =
      (
        if sideways
        then monitor.mode.height
        else monitor.mode.width
      )
      / monitor.scale;
    height =
      (
        if sideways
        then monitor.mode.width
        else monitor.mode.height
      )
      / monitor.scale;
  in {
    cx = width / 2.0;
    cy = height / 2.0;
  }) (lib.filterAttrs (_: monitor: monitor.mode != null) enabled);

  noctaliaWallpaper = {
    enabled = true;
    automation.enabled = false;
    default.path = toString defaultWallpaper;
    monitors = lib.mapAttrs (name: monitor: {path = toString (wallpaperFor name monitor);}) enabled;
  };
}

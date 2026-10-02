{
  config,
  lib,
  pkgs,
  ...
}: let
  primary = lib.findFirst (monitor: monitor.enable && monitor.primary) null (lib.attrValues config.desktop.monitors);
  mode =
    if primary == null
    then null
    else primary.mode;
  # grub2-themes ships artwork per screen class; pick the one closest to the
  # primary monitor, then render at its exact resolution.
  grubScreen =
    if mode == null
    then "1080p"
    else if mode.height >= 2160
    then "4k"
    else if mode.height >= 1440
    then
      if mode.width * 9 > mode.height * 16
      then "ultrawide2k"
      else "2k"
    else if mode.width * 9 > mode.height * 16
    then "ultrawide"
    else "1080p";
  # Already converted for the primary output (lib/wallpaper.nix).
  wallpaper = let
    prepared = (import ../lib/monitors.nix {inherit lib pkgs;} config.desktop.monitors).defaultWallpaper;
  in
    if prepared != null
    then prepared
    else config.stylix.image;
  # WhiteSur's frosted-glass panel is painted into its own background art, so
  # a plain wallpaper would leave the menu floating on bare pixels. Recreate
  # it: fill the screen with the wallpaper (cropped, never stretched), then
  # blur, frost and round the area behind the menu (theme.txt puts the menu at
  # 30-70% of each axis) and give it a soft drop shadow.
  grubBackground = let
    w = mode.width;
    h = mode.height;
    margin = h / 20;
    panelW = w * 2 / 5 + 2 * margin;
    panelH = h * 11 / 20;
    x = (w - panelW) / 2;
    y = (h - panelH) / 2;
    radius = h / 16;
    shadow = h / 48;
    drop = h / 180;
    str = toString;
  in
    pkgs.runCommand "grub-background" {nativeBuildInputs = [pkgs.imagemagick];} ''
      mkdir $out
      magick ${wallpaper} -resize ${str w}x${str h}^ -gravity center -extent ${str w}x${str h} +repage base.png
      magick base.png -crop ${str panelW}x${str panelH}+${str x}+${str y} +repage \
        -resize 1.5% -resize ${str panelW}x${str panelH}! -blur 0x8 \
        -fill white -colorize 12% -modulate 100,85 glass.png
      magick -size ${str panelW}x${str panelH} xc:black -fill white \
        -draw "roundrectangle 0,0 ${str (panelW - 1)},${str (panelH - 1)} ${str radius},${str radius}" mask.png
      magick glass.png mask.png -alpha off -compose CopyOpacity -composite panel.png
      magick panel.png \( +clone -background black -shadow 55x${str shadow}+0+${str drop} \) \
        +swap -background none -layers merge +repage panel-shadow.png
      magick base.png panel-shadow.png \
        -geometry +${str (x - 2 * shadow)}+${str (y - 2 * shadow + drop)} -composite $out/background.png
    '';
in {
  imports = [../modules/theme.nix];

  # WhiteSur's frosted-glass menu over this host's desktop wallpaper, so GRUB,
  # the boot splash and the desktop share one look. GRUB only draws on
  # the output the firmware picks, normally the primary monitor.
  stylix.targets.grub.enable = false;
  boot.loader.grub2-theme = {
    enable = true;
    theme = "whitesur";
    icon = "whitesur";
    screen = grubScreen;
    customResolution =
      if mode == null
      then null
      else "${toString mode.width}x${toString mode.height}";
    splashImage =
      if mode == null
      then wallpaper
      else "${grubBackground}/background.png";
  };

  stylix.targets.kmscon.enable = false;
  # The boot splash is an adi1090x theme (system/base.nix).
  stylix.targets.plymouth.enable = false;
  # This target overlays gtksourceview, which changes the hash of everything
  # built on it (Inkscape and friends) and forces source builds on every palette
  # change. Home Manager's gtksourceview target installs the same style per user.
  stylix.targets.gtksourceview.enable = false;

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.ubuntu-mono
    nerd-fonts.jetbrains-mono
    meslo-lgs-nf
    inter
  ];
}

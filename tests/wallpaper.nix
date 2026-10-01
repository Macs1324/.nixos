# lib/wallpaper.nix on an awkward JPEG: stored sideways with an EXIF
# orientation, tagged Adobe RGB, and the wrong size for its output.
{pkgs}: let
  colord = "${pkgs.colord}/share/color/icc/colord";
  # 40x20 stored: red left half, blue right half. Orientation 6 means "turn
  # 90 degrees clockwise to view": upright it is 20x40, red on top. The stripe
  # along the right edge, which ends up at the bottom, is Adobe RGB
  # (200, 100, 0). (ImageMagick's -orient writes no EXIF tag: exiftool does.)
  source = pkgs.runCommand "sideways.jpg" {nativeBuildInputs = [pkgs.imagemagick pkgs.exiftool];} ''
    magick -size 20x20 xc:'rgb(255,0,0)' -size 20x20 xc:'rgb(0,0,255)' +append \
      -fill 'rgb(200,100,0)' -draw 'rectangle 36,0 39,19' \
      -profile ${colord}/AdobeRGB1998.icc -quality 100 -sampling-factor 1x1 sideways.jpg
    exiftool -q -overwrite_original -n -Orientation=6 sideways.jpg
    mv sideways.jpg $out
  '';
  converted = import ../lib/wallpaper.nix {inherit pkgs;} {
    name = "test";
    image = source;
    size = [10 20];
  };
in
  pkgs.runCommand "wallpaper-conversion-tests" {nativeBuildInputs = [pkgs.imagemagick];} ''
    # Channel ($2: r, g or b) of the converted image at $1 ("x,y"), 0..255.
    at() { magick ${converted} -format "%[fx:int(255*p{$1}.$2+0.5)]" info:; }
    fail() { echo "FAIL: $*" >&2; exit 1; }
    [ "$(magick identify -format '%m %wx%h' ${converted})" = "PNG 10x20" ] \
      || fail "not a 10x20 PNG: $(magick identify ${converted})"
    ! magick identify -verbose ${converted} | grep -qi 'profile-icc' || fail "colour profile kept"
    # Upright: red on top, blue below.
    [ "$(at 5,2 r)" -gt 240 ] && [ "$(at 5,2 b)" -lt 15 ] || fail "top is not red"
    [ "$(at 5,12 b)" -gt 240 ] && [ "$(at 5,12 r)" -lt 15 ] || fail "below is not blue"
    # Adobe RGB's red is deeper than sRGB's: its (200,100,0) is about sRGB
    # (225,100,0). Read as sRGB, the red would stay at 200.
    red=$(at 5,19 r)
    [ "$red" -gt 215 ] || fail "stripe red is $red: the Adobe RGB profile was ignored"
    echo "wallpaper conversion tests passed" > $out
  ''

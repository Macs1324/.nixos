# A wallpaper as an output shows it: whatever the source (JPEG, PNG, WebP...),
# a PNG at the output's exact pixel size, upright and in sRGB. Noctalia decodes
# JPEGs with its own small decoder, which ignores colour profiles (photos in
# Display P3 or Adobe RGB came out wrong) and EXIF orientation; here
# ImageMagick does it properly, once, at build time, and nothing downstream
# has to decode a JPEG or scale anything.
{pkgs}: {
  # Names the result: the output it is for.
  name,
  image,
  # Physical pixels [width height] as the output is seen (rotation applied),
  # or null to keep the image's own size.
  size,
}: let
  srgb = "${pkgs.colord}/share/color/icc/colord/sRGB.icc";
  # Fill the output, cropping the overflow evenly; never stretch.
  fit = let
    geometry = "${toString (builtins.elemAt size 0)}x${toString (builtins.elemAt size 1)}";
  in
    if size == null
    then ""
    else "-resize ${geometry}^ -gravity center -extent ${geometry}";
in
  pkgs.runCommand "wallpaper-${name}.png" {nativeBuildInputs = [pkgs.imagemagick];} ''
    # [0]: the first frame only. An embedded profile is converted from; an
    # image without one is taken as sRGB already.
    magick ${image}'[0]' -auto-orient -profile ${srgb} -colorspace sRGB \
      -background black -alpha remove -alpha off \
      ${fit} +repage -strip -depth 8 PNG24:$out
  ''

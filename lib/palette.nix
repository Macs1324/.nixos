# Stylix's generated palette with base16 accents rebuilt from the image
# (lib/palette.py): its neutrals, but one distinct hue per accent slot.
{pkgs}: {
  image,
  polarity,
  # Stylix's own generator output (config.stylix.generated.json).
  generated,
}:
pkgs.runCommand "palette.json" {
  nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.numpy ps.pillow]))];
} ''
  python3 ${./palette.py} ${polarity} ${image} ${generated} $out
''

"""Give a Stylix palette base16 accents that are actually distinct.

Stylix's generator samples every colour from the image and only maximises the
smallest difference between accents, so a wallpaper with two or three hues
yields two or three accents, repeated, in slots whose base16 meaning (base08
red, base0B green, base0D blue...) is ignored. Its neutral scale is good, so
this keeps base00-07 and rebuilds base08-0F in OKLCH: each slot gets its own
hue, taken from the image when the image has it, otherwise synthesised and
leant towards the image's dominant hue. All accents share one lightness, and a
chroma taken from the image, so none of them stands out.

Usage: palette.py POLARITY IMAGE GENERATED_JSON OUT_JSON
"""

import json
import sys

import numpy as np
from PIL import Image

# OKLCH hue of each base16 accent, and its lightness relative to the others:
# equal lightness makes yellow look dull and red or blue glare. base0F
# ("deprecated", usually brown) is derived from orange below.
SLOTS = {
    "base08": (25, -0.04),  # red
    "base09": (55, 0.0),  # orange
    "base0A": (95, 0.08),  # yellow
    "base0B": (145, 0.03),  # green
    "base0C": (195, 0.03),  # cyan
    "base0D": (255, -0.01),  # blue
    "base0E": (315, -0.02),  # magenta
}
# A slot takes the image's hue if it has this much of it within WINDOW degrees,
# as a share of all the image's chroma.
WINDOW = 18
PRESENT = 0.02
# Pixels below this OKLCH chroma count as grey.
CHROMATIC = 0.04
# How far a synthesised hue leans towards the dominant one (as Material You
# "harmonizes" custom colours): half the gap, at most this many degrees.
LEAN = 15


def srgb_to_oklab(rgb):
    c = rgb / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    lms = lin @ np.array(
        [
            [0.4122214708, 0.2119034982, 0.0883024619],
            [0.5363325363, 0.6806995451, 0.2817188376],
            [0.0514459929, 0.1073969566, 0.6299787005],
        ]
    )
    return np.cbrt(lms) @ np.array(
        [
            [0.2104542553, 1.9779984951, 0.0259040371],
            [0.7936177850, -2.4285922050, 0.7827717662],
            [-0.0040720468, 0.4505937099, -0.8086757660],
        ]
    )


def oklch_to_linear(l, c, h):
    a, b = c * np.cos(np.radians(h)), c * np.sin(np.radians(h))
    lms = (
        np.array([l + 0.3963377774 * a + 0.2158037573 * b,
                  l - 0.1055613458 * a - 0.0638541728 * b,
                  l - 0.0894841775 * a - 1.2914855480 * b])
        ** 3
    )
    return np.array(
        [
            [4.0767416621, -3.3077115913, 0.2309699292],
            [-1.2684380046, 2.6097574011, -0.3413193965],
            [-0.0041960863, -0.7034186147, 1.7076147010],
        ]
    ) @ lms


def to_hex(l, c, h):
    # Keep hue and lightness; give up chroma until the colour fits in sRGB.
    lo, hi = 0.0, c
    if np.all((oklch_to_linear(l, c, h) >= 0) & (oklch_to_linear(l, c, h) <= 1)):
        lo = c
    for _ in range(30):
        if hi - lo < 1e-5:
            break
        mid = (lo + hi) / 2
        lin = oklch_to_linear(l, mid, h)
        if np.all((lin >= 0) & (lin <= 1)):
            lo = mid
        else:
            hi = mid
    lin = np.clip(oklch_to_linear(l, lo, h), 0, 1)
    srgb = np.where(lin <= 0.0031308, 12.92 * lin, 1.055 * lin ** (1 / 2.4) - 0.055)
    return "".join(f"{round(v * 255):02x}" for v in srgb)


def hue_gap(a, b):
    """Signed degrees from a to b, in (-180, 180]."""
    return (b - a + 180) % 360 - 180


def circular_mean(hues, weights):
    r = np.radians(hues)
    return np.degrees(np.arctan2((weights * np.sin(r)).sum(), (weights * np.cos(r)).sum())) % 360


def accents(polarity, image):
    img = Image.open(image).convert("RGB")
    img.thumbnail((256, 256))
    lab = srgb_to_oklab(np.asarray(img, dtype=float).reshape(-1, 3))
    chroma = np.hypot(lab[:, 1], lab[:, 2])
    hue = np.degrees(np.arctan2(lab[:, 2], lab[:, 1])) % 360
    keep = chroma >= CHROMATIC
    chroma, hue = chroma[keep], hue[keep]

    if chroma.size:
        # Dominant hue: the heaviest 10-degree bin of chroma.
        bins = np.bincount((hue // 10).astype(int), weights=chroma, minlength=36)
        peak = np.argmax(bins)
        near = np.abs(hue_gap(hue, peak * 10 + 5)) <= 10
        dominant = circular_mean(hue[near], chroma[near])
        accent_chroma = float(np.clip(np.percentile(chroma, 90), 0.10, 0.17))
    else:
        dominant = None
        accent_chroma = 0.10
    lightness = 0.55 if polarity == "light" else 0.74

    result = {}
    for slot, (target, offset) in SLOTS.items():
        near = np.abs(hue_gap(hue, target)) <= WINDOW
        if chroma.size and chroma[near].sum() >= PRESENT * chroma.sum():
            h = circular_mean(hue[near], chroma[near])
        elif dominant is not None:
            gap = hue_gap(target, dominant)
            h = target + np.sign(gap) * min(abs(gap) / 2, LEAN)
        else:
            h = target
        result[slot] = (lightness + offset, accent_chroma, h)

    # base0F: a muted, darker orange (brown).
    l, c, h = result["base09"]
    result["base0F"] = (l - 0.12, c * 0.6, h)
    return {slot: to_hex(*lch) for slot, lch in result.items()}


def main():
    polarity, image, generated, out = sys.argv[1:]
    with open(generated) as f:
        palette = json.load(f)
    palette.update(accents(polarity, image))
    with open(out, "w") as f:
        json.dump(palette, f, indent=2)


if __name__ == "__main__":
    main()

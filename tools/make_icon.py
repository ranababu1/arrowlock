"""Builds the Android launcher icons from the owner's icon art.

Usage: python -I tools/make_icon.py [source.png]   (default tools/icon_source.png)

Writes to assets/icon/:
  icon_512.png                  rounded-square icon with transparent corners
                                (project icon, legacy launcher icon)
  adaptive_foreground_432.png   the two chevrons only, inside the 66 dp safe zone
  adaptive_background_432.png   the navy gradient
  adaptive_monochrome_432.png   white chevrons for Android 13 themed icons

The source is a 1254x1254 RGB render: a navy rounded square on black with a
green and a white chevron. The chevrons are cut out by brightness (the navy
never gets brighter than ~75 in any channel; the chevrons are far brighter).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icon"

# Navy measured from the source: lighter top-left, darker bottom-right.
NAVY_LIGHT = (36, 48, 72)
NAVY_DARK = (14, 23, 41)
# Brightness (max channel) ramp that turns navy -> transparent, chevron -> opaque.
KEY_LOW, KEY_HIGH = 80, 125
# Where the chevrons are in the source (x0, y0, x1, y1). Keying only inside it
# keeps the faint light rim of the rounded square out of the cut-out.
CHEVRON_REGION = (270, 280, 985, 1000)
# Rounded square in the source: inset and corner radius, in source pixels.
SQUARE_INSET, SQUARE_RADIUS = 6, 380
# Adaptive canvas 432 px = 108 dp; launchers show the middle 72 dp and only the
# middle 66 dp circle is guaranteed. Chevron height chosen so its bounding box
# diagonal stays inside that circle.
ADAPTIVE = 432
CHEVRON_HEIGHT = 190


def gradient(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(NAVY_LIGHT, NAVY_DARK))
    return img


def chevrons(src: Image.Image) -> Image.Image:
    """RGBA cut-out of the chevrons, cropped to their bounding box."""
    rgb = src.convert("RGB")
    alpha = Image.new("L", rgb.size)
    a = alpha.load()
    p = rgb.load()
    x0, y0, x1, y1 = CHEVRON_REGION
    for y in range(y0, y1):
        for x in range(x0, x1):
            m = max(p[x, y])
            a[x, y] = 0 if m <= KEY_LOW else 255 if m >= KEY_HIGH else round(255 * (m - KEY_LOW) / (KEY_HIGH - KEY_LOW))
    # Drop the black outer corners and any stray bright texture specks.
    alpha = alpha.filter(ImageFilter.MedianFilter(5))
    cut = rgb.convert("RGBA")
    cut.putalpha(alpha)
    return cut.crop(alpha.getbbox())


def rounded(src: Image.Image) -> Image.Image:
    mask = Image.new("L", src.size, 0)
    s = src.size[0]
    ImageDraw.Draw(mask).rounded_rectangle(
        (SQUARE_INSET, SQUARE_INSET, s - 1 - SQUARE_INSET, s - 1 - SQUARE_INSET), SQUARE_RADIUS, fill=255)
    out = src.convert("RGBA")
    out.putalpha(mask)
    return out


def main() -> None:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "tools" / "icon_source.png"
    src = Image.open(source)
    OUT.mkdir(parents=True, exist_ok=True)

    rounded(src).resize((512, 512), Image.LANCZOS).save(OUT / "icon_512.png")
    gradient(ADAPTIVE).save(OUT / "adaptive_background_432.png")

    cut = chevrons(src)
    scale = CHEVRON_HEIGHT / cut.height
    cut = cut.resize((round(cut.width * scale), CHEVRON_HEIGHT), Image.LANCZOS)
    fg = Image.new("RGBA", (ADAPTIVE, ADAPTIVE), (0, 0, 0, 0))
    fg.alpha_composite(cut, ((ADAPTIVE - cut.width) // 2, (ADAPTIVE - cut.height) // 2))
    fg.save(OUT / "adaptive_foreground_432.png")

    mono = Image.new("RGBA", fg.size, (255, 255, 255, 0))
    mono.putalpha(fg.getchannel("A"))
    mono.save(OUT / "adaptive_monochrome_432.png")

    print("bbox", cut.size, "->", sorted(p.name for p in OUT.glob("*.png")))


if __name__ == "__main__":
    main()

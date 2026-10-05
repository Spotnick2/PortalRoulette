"""Build the README screenshots from raw in-game shots.

    python Tools/make_screenshots.py <screenshots folder>

Crops only the addon (no chat, unit frames or other player names) and
writes JPEGs to docs/screenshots/. Crop boxes are measured on a 2000 px
wide view and scaled to each shot's real size (WoW saves at screen
resolution, e.g. 3840x2160).
"""

import os
import sys

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "docs", "screenshots")

SHOTS = {
    "horde": "WoWScrnShot_100526_174843.jpg",      # Horde wheel, preview
    "hero": "WoWScrnShot_100526_174851.jpg",       # troll + wheel, full frame
    "unlearned": "WoWScrnShot_100526_175113.jpg",  # Alliance, nothing learned
    "alliance": "WoWScrnShot_100526_175124.jpg",   # Alliance wheel, preview
    "hover": "WoWScrnShot_100526_175138.jpg",      # hover tooltip on Stormwind
    "launcher": "WoWScrnShot_100526_175241.jpg",   # launcher spell alert + prompt
}

WHEEL_BOX = (1085, 215, 1610, 775)     # header, disc, Karazhan, reagent strip
HOVER_BOX = (1085, 215, 1600, 775)
LAUNCHER_BOX = (385, 595, 590, 745)    # prompt + launcher only


REFERENCE_WIDTH = 2000


def load(folder, key):
    return Image.open(os.path.join(folder, SHOTS[key])).convert("RGB")


def crop(img, box):
    k = img.width / REFERENCE_WIDTH
    return img.crop(tuple(round(v * k) for v in box))


def side_by_side(images, gap=12, background=(14, 18, 28)):
    h = max(i.height for i in images)
    w = sum(i.width for i in images) + gap * (len(images) - 1)
    canvas = Image.new("RGB", (w, h), background)
    x = 0
    for img in images:
        canvas.paste(img, (x, (h - img.height) // 2))
        x += img.width + gap
    return canvas


def save(img, name, width=None):
    if width and img.width > width:
        img = img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    img.save(path, "JPEG", quality=88, optimize=True, progressive=True)
    print("wrote", os.path.normpath(path), img.size)


def main(folder):
    save(load(folder, "hero"), "hero.jpg", width=1400)
    save(side_by_side([crop(load(folder, "horde"), WHEEL_BOX),
                       crop(load(folder, "alliance"), WHEEL_BOX)]), "wheels.jpg", width=1100)
    save(side_by_side([crop(load(folder, "unlearned"), WHEEL_BOX),
                       crop(load(folder, "hover"), HOVER_BOX)]), "states.jpg", width=1100)
    save(crop(load(folder, "launcher"), LAUNCHER_BOX), "launcher.jpg", width=400)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else
         r"C:\Program Files (x86)\World of Warcraft\_classic_beta_\Screenshots")

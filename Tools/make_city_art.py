"""Build the city textures from the retained imagegen PNG sources.

    python Tools/make_city_art.py

Sources and generation prompts live in Tools/Art/Cities/. This step only
resizes and exports; WoW's existing round mask and glass draw the frame.
Requires the project's existing Pillow dependency. Never hand-edit the TGAs.
"""

from pathlib import Path
import sys

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Tools" / "Art" / "Cities"
OUT = ROOT / "Media" / "CityIcons" / "Scenes"
CITIES = ("stormwind", "ironforge", "darnassus", "orgrimmar",
          "undercity", "thunder_bluff", "dalaran", "karazhan")


def main():
    # Validate the whole set before replacing any output.
    for city in CITIES:
        with Image.open(SOURCE / f"{city}.png") as img:
            if img.width != img.height:
                raise ValueError(f"{city}: expected a square source, got {img.size}")
    OUT.mkdir(parents=True, exist_ok=True)
    for city in CITIES:
        with Image.open(SOURCE / f"{city}.png") as img:
            icon = img.convert("RGBA").resize((256, 256), Image.Resampling.LANCZOS)
            icon.save(OUT / f"{city}.tga", compression=None)
            print("wrote", OUT / f"{city}.tga")
    if "--preview" in sys.argv:
        preview()


def preview():
    """Contact sheet with circular crops at 128px and actual 64px art size.
    This checks composition/readability, not the client's glass rendering.
    """
    sheet = Image.new("RGB", (960, 440), (24, 31, 43))
    draw = ImageDraw.Draw(sheet)
    for index, city in enumerate(CITIES):
        x, y = index % 4 * 240, index // 4 * 220
        with Image.open(OUT / f"{city}.tga") as img:
            for size, offset in ((128, 8), (64, 154)):
                icon = img.resize((size, size), Image.Resampling.LANCZOS)
                mask = Image.new("L", (size * 4, size * 4), 0)
                ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
                mask = mask.resize((size, size), Image.Resampling.LANCZOS)
                sheet.paste(icon, (x + offset, y + 15 + (128 - size) // 2), mask)
        draw.text((x + 10, y + 155), city.replace("_", " ").title(), fill="white")
        draw.text((x + 10, y + 175), "128px / 64px circular crops", fill=(164, 186, 211))
    dest = ROOT / ".tmp_video_review" / "city-scenes.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(dest)
    print("preview", dest)


if __name__ == "__main__":
    main()

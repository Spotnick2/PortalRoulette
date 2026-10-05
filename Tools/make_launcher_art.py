"""Export the retained launcher PNG and generate its small tutorial pointer.

    python Tools/make_launcher_art.py

Game textures are uncompressed RGBA TGAs. Source art/prompt: Tools/Art/Launcher.
The icon frame and hover treatment are separate runtime regions.
"""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Media" / "Launcher"


def main():
    with Image.open(ROOT / "Tools" / "Art" / "Launcher" / "portal.png") as source:
        if source.width != source.height:
            raise ValueError("Launcher source must be square")
        icon = source.convert("RGBA").resize((256, 256), Image.Resampling.LANCZOS)
        icon.save(OUT / "Portal_256.tga", compression=None)
    # White RGB, shape in alpha: no dark fringe on the pointing tip.
    alpha = Image.new("L", (128, 64), 0)
    ImageDraw.Draw(alpha).polygon([(4, 0), (123, 0), (64, 60)], fill=255)
    pointer = Image.new("RGBA", (32, 16), "white")
    pointer.putalpha(alpha.resize(pointer.size, Image.Resampling.LANCZOS))
    pointer.save(OUT / "TipPointer_32x16.tga", compression=None)
    print("wrote Portal_256.tga and TipPointer_32x16.tga")


if __name__ == "__main__":
    main()

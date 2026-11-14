"""Build offline static font instances from the checked-in OFL variable fonts."""

from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "fonts" / "source"
DEST = ROOT / "assets" / "fonts"

FONTS = {
    "Newsreader": (SOURCE / "Newsreader-Variable.ttf", (500, 600)),
    "Inter": (SOURCE / "Inter-Variable.ttf", (400, 500, 600, 700)),
}


def main() -> None:
    for family, (path, weights) in FONTS.items():
        if not path.is_file():
            raise SystemExit(f"Missing variable font: {path}")
        for weight in weights:
            font = TTFont(path)
            instance = instantiateVariableFont(
                font, {"opsz": 14, "wght": weight}, inplace=True
            )
            output = DEST / f"{family}-{weight}.ttf"
            instance.save(output)
            print(f"Created {output.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

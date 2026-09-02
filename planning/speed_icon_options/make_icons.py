from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

EMPTY = (0, 0, 0, 0)
H = (235, 237, 233, 255)  # highlight — matches damage_icon
M = (199, 207, 204, 255)  # mid
A = (168, 181, 178, 255)  # mid-dark
S = (129, 151, 150, 255)  # shadow
B = (173, 119, 87, 255)  # brown (hilt / leather)
D = (122, 72, 65, 255)  # dark brown

PAL = {
    ".": EMPTY,
    "H": H,
    "M": M,
    "A": A,
    "S": S,
    "B": B,
    "D": D,
}

# Same 8x8 / 4–5 color language as damage_icon.png and splash_icon.png.
ICONS = {
    "01_chevrons": """
........
.H...H..
SMH.SMH.
.SMH.SMH
SMH.SMH.
.H...H..
........
........
""",
    "02_arrow": """
........
.....HH.
....HMMH
HHHHHHM.
HHHHHHM.
....HMMH
.....HH.
........
""",
    "03_wing": """
......HH
....HHMH
..HHM.MH
.HM.M.M.
HM.M.M..
.M.M....
..M.....
........
""",
    "04_comet": """
........
....HH..
...HMMH.
.HHHMMH.
HH..HH..
.H......
........
........
""",
    "05_streaks": """
.....H.H
...H.H.H
.H.H.HH.
H.H.HH..
.H.HH...
H.HH....
.HH.....
........
""",
    "06_boot": """
...H.H..
..HMH...
.HM.....
BBBBBB..
BMMMMMB.
BM.M.MB.
BBBBBBB.
........
""",
}

BG = (18, 22, 28, 255)
OUT = Path(__file__).resolve().parent


def parse_grid(text: str) -> list[str]:
    rows = [line.rstrip("\n") for line in text.strip("\n").splitlines()]
    rows = [row if len(row) == 8 else row.ljust(8, ".")[:8] for row in rows]
    if len(rows) != 8:
        raise ValueError(f"expected 8 rows, got {len(rows)}: {rows}")
    return rows


def make_icon(rows: list[str]) -> Image.Image:
    im = Image.new("RGBA", (8, 8), EMPTY)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            im.putpixel((x, y), PAL[ch])
    return im


def main() -> None:
    scale = 8
    gap = 10
    label_h = 18
    thumb = 8 * scale
    names = list(ICONS)
    n = len(names)
    sheet = Image.new("RGBA", (gap + n * (thumb + gap), gap + thumb + gap + label_h), BG)
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 11)
    except OSError:
        font = ImageFont.load_default()

    for i, name in enumerate(names):
        rows = parse_grid(ICONS[name])
        im = make_icon(rows)
        im.save(OUT / f"{name}.png")

        preview = Image.new("RGBA", (64, 64), BG)
        preview.alpha_composite(im.resize((64, 64), Image.NEAREST))
        preview.save(OUT / f"{name}_64.png")

        x0 = gap + i * (thumb + gap)
        y0 = gap
        cell = Image.new("RGBA", (thumb, thumb), (12, 14, 18, 255))
        cell.alpha_composite(im.resize((thumb, thumb), Image.NEAREST))
        sheet.alpha_composite(cell, (x0, y0))
        label = name.split("_", 1)[1]
        bbox = draw.textbbox((0, 0), label, font=font)
        tw = bbox[2] - bbox[0]
        draw.text(
            (x0 + (thumb - tw) // 2, y0 + thumb + 3),
            label,
            fill=(199, 207, 204, 255),
            font=font,
        )
        opaque = sum(1 for y in range(8) for x in range(8) if im.getpixel((x, y))[3])
        print(name, "opaque", opaque)

    sheet.save(OUT / "sheet.png")


if __name__ == "__main__":
    main()

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SHEETS = ROOT / "assets" / "cocoa" / "sheets"
OUT = ROOT / "assets" / "cocoa" / "items"
OUT.mkdir(parents=True, exist_ok=True)

SPECS = {
    "board1_juices.png": (["watermelon", "pineapple", "grape"], ["fruit", "juice", "fancy_juice", "pitcher"]),
    "board2_creams.png": (["rose", "passion_fruit", "kiwi", "lychee"], ["cream_swirl", "cream_bowl", "macaron", "ice_cream_macaron"]),
    "board3_chocolates.png": (["strawberry_star", "almond_square", "raspberry_heart", "caramel_flower"], ["single", "trio", "small_box", "large_box"]),
    "board4_cotton_candy.png": (["blueberry_lavender", "strawberry_cream", "apple_cinnamon", "honey_lemon"], ["sugar_cube", "spun_sugar", "small_cotton_candy", "grand_cotton_candy"]),
    "board5_gelatin.png": (["lime_gelatin", "grape_gelatin", "rose_gelatin", "orange_gelatin"], ["piece"]),
    "board6_slushies.png": (["blue_raspberry_slushie", "mango_slushie", "pineapple_slushie", "cola_slushie"], ["piece"]),
    "board7_cakes.png": (["party_cake", "tres_leches", "cherry_truffle", "black_forest", "chocolate_mousse"], ["piece"]),
    "board8_breads.png": (["dinner_roll", "bagel", "sourdough", "brioche", "english_muffin"], ["piece"]),
}

for sheet_name, (columns, rows) in SPECS.items():
    image = Image.open(SHEETS / sheet_name).convert("RGBA")
    cell_w, cell_h = image.width / len(columns), image.height / len(rows)
    board = sheet_name.split("_")[0]
    for row, level in enumerate(rows):
        for column, flavor in enumerate(columns):
            box = (round(column * cell_w), round(row * cell_h), round((column + 1) * cell_w), round((row + 1) * cell_h))
            sprite = image.crop(box)
            bbox = sprite.getbbox()
            if bbox:
                sprite = sprite.crop(bbox)
            sprite.thumbnail((456, 456), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            canvas.alpha_composite(sprite, ((512 - sprite.width) // 2, (512 - sprite.height) // 2))
            canvas.save(OUT / f"{board}_{flavor}_{level}.png", optimize=True)

print(f"Wrote {len(list(OUT.glob('*.png')))} Cocoa Moon sprites to {OUT}")

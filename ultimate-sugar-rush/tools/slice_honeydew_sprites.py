from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SHEETS = ROOT / "assets" / "honeydew" / "sheets"
OUT = ROOT / "assets" / "honeydew" / "items"
OUT.mkdir(parents=True, exist_ok=True)

SPECS = {
    "board1_fruit_pastries.png": (["cherry", "raspberry", "blueberry"], ["fruit", "crushed_bowl", "pie", "grand_dessert"]),
    "board2_ice_cream.png": (["neapolitan", "cookies_cream", "mint_chip", "raspberry_swirl"], ["scoop", "sandwich", "sundae", "grand_sundae"]),
    "board3_baking.png": (["matcha", "tiramisu", "coconut", "oat"], ["flour_cup", "mixing_bowl", "cupcake", "layer_cake"]),
    "board4_boba.png": (["peach", "mango", "honeydew", "taro"], ["fruit", "drink", "boba", "grand_boba"]),
    "board4_syrup.png": (["pumpkin", "honey", "coffee", "caramel"], ["small_syrup", "syrup_jug", "accent_coffee"]),
    "board5_macarons.png": (["blueberry_macaron", "lemon_macaron", "strawberry_macaron", "matcha_macaron"], ["piece"]),
    "board6_donuts.png": (["powdered_donut", "red_velvet_donut", "vanilla_drizzle_donut", "cruller"], ["piece"]),
    "board7_ice_pops.png": (["mixed_berry_pop", "orange_cream_pop", "watermelon_pop", "strawberry_banana_pop"], ["piece"]),
    "board8_pastries.png": (["croissant", "cream_horn", "chocolate_eclair", "cream_puff"], ["piece"]),
}

for sheet_name, (columns, rows) in SPECS.items():
    image = Image.open(SHEETS / sheet_name).convert("RGBA")
    cell_w, cell_h = image.width / len(columns), image.height / len(rows)
    board = sheet_name.split("_")[0]
    for row, level in enumerate(rows):
        for column, flavor in enumerate(columns):
            left, top = round(column * cell_w), round(row * cell_h)
            right, bottom = round((column + 1) * cell_w), round((row + 1) * cell_h)
            sprite = image.crop((left, top, right, bottom))
            bbox = sprite.getbbox()
            if bbox:
                sprite = sprite.crop(bbox)
            sprite.thumbnail((456, 456), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            canvas.alpha_composite(sprite, ((512 - sprite.width) // 2, (512 - sprite.height) // 2))
            canvas.save(OUT / f"{board}_{flavor}_{level}.png", optimize=True)

print(f"Wrote {len(list(OUT.glob('*.png')))} Honeydew sprites to {OUT}")

from pathlib import Path
from PIL import Image

ROOT = Path(r"D:\UltimateSugarRush")
SOURCE_DIR = Path(r"C:\Users\darkm\.codex\generated_images\019ffcde-1b96-7ec0-a2a9-b02439f50212")
MASTER_DIR = ROOT / "art-source" / "match3"
OUTPUT = ROOT / "ultimate-sugar-rush" / "assets" / "match3"

MASTER_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT.mkdir(parents=True, exist_ok=True)

sources = {
    "red_round_candy": "exec-82640546-c147-418b-90cc-d74b339513a4.png",
    "green_hard_candy": "exec-4d36aa89-690f-4416-a557-db8d2cd573f7.png",
    "gold_butterscotch": "exec-c0ddc9a5-1c0f-4022-a100-3ccc5daf8fd8.png",
    "blue_heart_candy": "exec-7740dacd-9635-4329-8888-fa9794a8daba.png",
}

powerups = {
    "double_ended_rocket": "exec-db999174-068e-4f3a-9a53-e6da846e9859.png",
    "flying_rocket": "exec-8d011ef2-6f5c-44d3-9d06-8ac4941d9e23.png",
    "candy_bomb": "exec-4e3b00f9-8760-475c-a5b9-c953a9ff4254.png",
    "disco_ball": "exec-8bd9ab7a-74c8-4765-888c-58a5362eb8e5.png",
}

for name, filename in (sources | powerups).items():
    image = Image.open(SOURCE_DIR / filename).convert("RGBA")
    image.save(MASTER_DIR / f"{name}_master.png")
    piece = image.copy()
    alpha = piece.getchannel("A")
    bounds = alpha.getbbox()
    if bounds:
        piece = piece.crop(bounds)
    canvas = Image.new("RGBA", (512, 512))
    piece.thumbnail((440, 440), Image.Resampling.LANCZOS)
    if name in {"green_hard_candy", "gold_butterscotch"}:
        # Match the visual weight of the round and heart pieces while retaining
        # transparent side margins inside the common 512 px cell canvas.
        piece = piece.resize((430, 360), Image.Resampling.LANCZOS)
    canvas.alpha_composite(piece, ((512 - piece.width) // 2, (512 - piece.height) // 2))
    canvas.save(OUTPUT / f"{name}.png", optimize=True)
    print(name, piece.size)

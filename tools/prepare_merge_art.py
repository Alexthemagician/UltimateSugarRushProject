from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


GENERATED = Path(r"C:\Users\darkm\.codex\generated_images\019ffcde-1b96-7ec0-a2a9-b02439f50212")
ROOT = Path(r"D:\UltimateSugarRush")
ASSET_DIR = ROOT / "ultimate-sugar-rush" / "assets" / "merge"
SOURCE_DIR = ROOT / "art-source" / "merge"

FILES = {
    "orange": "exec-d7d0febc-7871-4ce7-a64d-f7bdb8f3afe0.png",
    "orange_juice": "exec-7e0651f7-0778-444e-a065-f69d622e1916.png",
    "orange_pitcher": "exec-de4d6ec9-50e8-4d39-86e4-dd996b2012e9.png",
    "apple": "exec-dfc732fc-3cea-4225-beb0-9579b6811351.png",
    "apple_juice": "exec-cf78a031-6ef1-475c-abb8-304fa5ecc685.png",
    "apple_pitcher": "exec-005ab92f-10ea-45f5-837b-656d7d1efba6.png",
    "exotic_orange_juice": "exec-f5e5685f-fc6f-4f6c-baab-cbbe8cf42c4c.png",
    "exotic_apple_juice": "exec-bf35f9e3-5f44-48ff-9cce-9ea87192a952.png",
    "multi_fruit_icon": "exec-8a190c3a-12c9-47d8-8bd8-f501844cd188.png",
    "coin_icon": "exec-1c64cb38-5aba-48e0-8ae4-703d01f4b018.png",
    "trash_icon": "exec-73d46044-33f8-4183-acad-6084fd0bc700.png",
    "chocolate_bar": "exec-af61d48f-16f5-41dd-8405-bcac76b00d6d.png",
    "chocolate_batter": "exec-40c2d0f3-ea8c-425e-b38d-bcef09e8e7af.png",
    "chocolate_cake_slice": "exec-f253d0ee-8e68-4841-a386-34afe78cf5ef.png",
    "chocolate_cake": "exec-df630ea9-5bbf-4980-b8ac-20e7aa36b8aa.png",
    "strawberry": "exec-838a741c-7083-4a6e-987f-1cd276ed3a1b.png",
    "strawberry_batter": "exec-a32faf3e-04f0-40f1-8cad-19a7387cfca4.png",
    "strawberry_cake_slice": "exec-820df822-ff07-456e-ad6a-4fe3e295390e.png",
    "strawberry_cake": "exec-b860a9ed-586b-4d19-8087-98709813d5f7.png",
    "vanilla_flowers": "exec-84faac91-e67b-4cf5-9445-05ba057b28cc.png",
    "vanilla_batter": "exec-5e74a1b3-7852-4bee-9a7c-c193aa507d43.png",
    "vanilla_cake_slice": "exec-4c818ae9-d6b7-4cf8-b337-67b4685c2634.png",
    "vanilla_cake": "exec-ce5e011d-8c78-404c-9bb3-9781292ab630.png",
    "blueberries": "exec-fb749bce-f686-4c2e-9b77-6df64c1608db.png",
    "blueberry_batter": "exec-55c4326d-ed20-4dbd-ab23-a960501dac86.png",
    "blueberry_cake_slice": "exec-7bd5bfa2-aa08-4cdb-9353-da30989bf174.png",
    "blueberry_cake": "exec-aae81f38-5daf-47c4-a3c7-d2c26fd83515.png",
    "cake_ingredients_icon": "exec-646c8c89-74ef-4793-aa58-2b3f316cd2f9.png",
    "chocolate_chip_cookie": "exec-0ff17748-cdc5-40e0-b5ac-9ceef9c1650e.png",
    "chocolate_chip_cookie_stack": "exec-4df8c703-7a1f-4374-91ef-309a41c991bc.png",
    "chocolate_chip_cookie_jar": "exec-913ea1bc-7fc4-4f2a-a63d-d238318db14e.png",
    "chocolate_chip_cookie_box": "exec-1268633e-9d40-40d6-b4a0-fe8eb95c61f8.png",
    "pink_sugar_cookie": "exec-b934726f-89a1-4ee9-a790-ceca8255bac8.png",
    "pink_sugar_cookie_stack": "exec-684c81d9-0df4-44a5-991c-1d4b7be88104.png",
    "pink_sugar_cookie_jar": "exec-bfc6fcb9-4388-4433-8291-ffc36d472525.png",
    "pink_sugar_cookie_box": "exec-f60a4945-9262-46e3-b4ce-4ec2a858cc55.png",
    "sandwich_cookie": "exec-d6043e9d-0b5a-45e5-8f39-cc0f0846be0b.png",
    "sandwich_cookie_stack": "exec-2479c531-71d5-42de-8b44-a5008b7d5e38.png",
    "sandwich_cookie_jar": "exec-c6b19b20-10bb-4a1f-8fd6-ee611a63ed18.png",
    "sandwich_cookie_box": "exec-5937faaa-ebc4-4ac3-806b-d9af8e14c947.png",
    "lucky_cookie": "exec-a56af5c3-7265-4c84-bdb4-cc484801f660.png",
    "lucky_cookie_stack": "exec-321eb5b6-9345-4cac-bd69-ba8f8e51c363.png",
    "lucky_cookie_jar": "exec-abd57fe1-b316-4aad-b759-03970809ce4b.png",
    "lucky_cookie_box": "exec-dda65c57-7b66-407d-b041-81f385b1bb2b.png",
    "cookie_ingredients_icon": "exec-5f297757-69b7-4d9a-8bc4-b0616b20e729.png",
    "milk_pitcher": "exec-eedcbbc1-dec4-40b4-a3ea-c22e680ef1b7.png",
    "vanilla_cream": "exec-b6edf8da-805e-49c2-8d17-44b647edd66c.png",
    "vanilla_cone": "exec-734b0af0-f1e4-41d2-9ade-bdc67d5afa8a.png",
    "vanilla_ice_cream_bowl": "exec-11be78a5-7f7e-4974-a13b-9f5d850e3758.png",
    "chocolate_milk": "exec-43724291-d580-419b-acb0-844c984ec023.png",
    "chocolate_cream": "exec-ca8fbd33-9cbf-496b-bffd-7fcba9de9bed.png",
    "chocolate_cone": "exec-575dde5e-fb09-402e-9c4d-907f00a31990.png",
    "chocolate_ice_cream_bowl": "exec-5fb70d86-277a-4fe0-ba6d-cc0a32fce9f6.png",
    "pistachios": "exec-79168fa5-49cb-4510-bfa8-75a0d84ba8e6.png",
    "pistachio_cream": "exec-a6ff4167-402f-4cbd-9227-6ccd0f953f6d.png",
    "pistachio_cone": "exec-b52123ab-a95f-45de-b99c-8855371caeae.png",
    "pistachio_ice_cream_bowl": "exec-7cb367c5-333c-42c7-84e8-f470e051d682.png",
    "ice_cream_ingredients_icon": "exec-71b1c20b-3df6-4aed-b530-a008c3f5e70c.png",
    "mixed_ingredients_icon": "exec-84985c45-9984-4029-9ff7-387a76169479.png",
    "sugar_die_three": "exec-3db568f0-968b-4a8e-ae1c-8de85bfdfea1.png",
}

COLLECTIBLES = {
    "autumn_harvest": "exec-486aa692-f6dd-4ce8-8b69-231634fadb76.png",
    "summer_fruits": "exec-b4aff906-a056-41be-85f4-403265baa4f4.png",
    "berry_sweets": "exec-f766ddd4-9ab3-45a1-8f19-0010da7543d3.png",
    "sugar_sack": "exec-6aaf54da-32f6-41ab-a44f-7ea4e8a40c8e.png",
    "honey_pot": "exec-07232d8b-ca04-4596-9984-0bd166ec0ddb.png",
    "flour_mill": "exec-ca061efa-5360-4180-b014-1d650b76d43d.png",
    "cookie_jar_collectible": "exec-4c6410e4-9b86-402a-a896-e0245ee4826c.png",
    "waffle_jacks": "exec-f43527fe-d370-48f2-93b4-22559a97dd41.png",
    "smart_tarts": "exec-dd81aec5-2ed9-4d1e-b848-a5393ebd4736.png",
    "cinnamon_yums": "exec-8c36e294-d0e6-40be-8c66-3783713a611f.png",
}


def remove_connected_checkerboard(image: Image.Image, interior_seeds: tuple[tuple[float, float], ...] = ()) -> Image.Image:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    background = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def candidate(x: int, y: int) -> bool:
        red, green, blue = pixels[x, y]
        return max(red, green, blue) - min(red, green, blue) < 24 and min(red, green, blue) > 210

    for x in range(width):
        for y in (0, height - 1):
            if candidate(x, y):
                queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            if candidate(x, y):
                queue.append((x, y))
    for relative_x, relative_y in interior_seeds:
        seed_x = round(relative_x * (width - 1))
        seed_y = round(relative_y * (height - 1))
        # Find a nearby checker pixel in case the exact point lands on an outline.
        for radius in range(0, 80):
            found = False
            for x in range(max(0, seed_x - radius), min(width, seed_x + radius + 1)):
                for y in (max(0, seed_y - radius), min(height - 1, seed_y + radius)):
                    if candidate(x, y):
                        queue.append((x, y))
                        found = True
                        break
                if found:
                    break
            if found:
                break

    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if background[index] or not candidate(x, y):
            continue
        background[index] = 255
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))

    # The pitcher's handle encloses part of the generated checkerboard, so it is
    # not connected to the outer background. Clear only neutral checker pixels
    # inside the supplied handle region while preserving the colored outline.
    if interior_seeds:
        for y in range(round(height * 0.22), round(height * 0.66)):
            for x in range(round(width * 0.60), round(width * 0.82)):
                if candidate(x, y):
                    background[y * width + x] = 255

    alpha = Image.frombytes("L", (width, height), bytes(255 - value for value in background))
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.45))
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def square_crop(image: Image.Image, padding: int = 42) -> Image.Image:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return image
    left, top, right, bottom = bounds
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    cropped = image.crop((left, top, right, bottom))
    side = max(cropped.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(cropped, ((side - cropped.width) // 2, (side - cropped.height) // 2))
    return canvas


ASSET_DIR.mkdir(parents=True, exist_ok=True)
SOURCE_DIR.mkdir(parents=True, exist_ok=True)

for name, filename in FILES.items():
    image = Image.open(GENERATED / filename).convert("RGBA")
    if image.getchannel("A").getextrema() == (255, 255):
        seeds = ((0.74, 0.45),) if name.endswith("_pitcher") else ()
        image = remove_connected_checkerboard(image, seeds)
    image = square_crop(image)
    image.save(SOURCE_DIR / f"{name}_master.png")
    image.resize((512, 512), Image.Resampling.LANCZOS).save(ASSET_DIR / f"{name}.png", optimize=True)
    print(name, image.size, image.getchannel("A").getextrema())

collectible_asset_dir = ROOT / "ultimate-sugar-rush" / "assets" / "collectibles"
collectible_source_dir = ROOT / "art-source" / "collectibles"
collectible_asset_dir.mkdir(parents=True, exist_ok=True)
collectible_source_dir.mkdir(parents=True, exist_ok=True)
for name, filename in COLLECTIBLES.items():
    image = square_crop(Image.open(GENERATED / filename).convert("RGBA"))
    image.save(collectible_source_dir / f"{name}_master.png")
    image.resize((512, 512), Image.Resampling.LANCZOS).save(collectible_asset_dir / f"{name}.png", optimize=True)
    print(name, image.size, image.getchannel("A").getextrema())

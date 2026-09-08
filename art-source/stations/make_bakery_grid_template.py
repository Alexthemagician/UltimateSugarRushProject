from PIL import Image, ImageDraw

SIZE = 1024
TILE_W = 168
TILE_H = 84
HEIGHT = 192
ORIGIN = (512, 500)
CELLS = {
    (0, 0), (1, 0), (2, 0), (3, 0),
    (0, 1), (1, 1), (2, 1), (3, 1),
    (0, 2), (1, 2),
    (0, 3), (1, 3),
}


def iso(cell):
    x, y = cell
    return (
        ORIGIN[0] + (x - y) * TILE_W // 2,
        ORIGIN[1] + (x + y) * TILE_H // 2,
    )


def tile(cell, rise=0):
    cx, cy = iso(cell)
    cy -= rise
    return [
        (cx, cy - TILE_H // 2),
        (cx + TILE_W // 2, cy),
        (cx, cy + TILE_H // 2),
        (cx - TILE_W // 2, cy),
    ]


image = Image.new("RGB", (SIZE, SIZE), "#00ff00")
draw = ImageDraw.Draw(image)

# Exact floor cells: the blue geometry authority.
for cell in sorted(CELLS, key=lambda value: sum(value)):
    floor = tile(cell)
    draw.polygon(floor, fill="#d8f3ff", outline="#147fc1", width=4)

# Exact screen-facing walls rising vertically from the accepted floor edges.
for cell in sorted(CELLS, key=lambda value: sum(value)):
    floor = tile(cell)
    top = tile(cell, HEIGHT)
    if (cell[0] + 1, cell[1]) not in CELLS:
        draw.polygon([top[1], top[2], floor[2], floor[1]], fill="#ef8d96", outline="#873f48", width=4)
    if (cell[0], cell[1] + 1) not in CELLS:
        draw.polygon([top[2], top[3], floor[3], floor[2]], fill="#f5a2a1", outline="#873f48", width=4)

# Seamless elevated L-shaped countertop. Internal cell edges are intentionally absent.
for cell in sorted(CELLS, key=lambda value: sum(value)):
    draw.polygon(tile(cell, HEIGHT), fill="#fff0d8")

edge_neighbors = [(0, -1), (1, 0), (0, 1), (-1, 0)]
for cell in CELLS:
    polygon = tile(cell, HEIGHT)
    for index, delta in enumerate(edge_neighbors):
        neighbor = (cell[0] + delta[0], cell[1] + delta[1])
        if neighbor not in CELLS:
            draw.line([polygon[index], polygon[(index + 1) % 4]], fill="#873f48", width=5)

# Construction stencil: show every one-square top module so the two-square arm
# depth and square 2x2 elbow are explicit to the repainting model.
for cell in CELLS:
    draw.line(tile(cell, HEIGHT) + [tile(cell, HEIGHT)[0]], fill="#1789d0", width=4)

image.save(r"D:\UltimateSugarRush\art-source\stations\bakery_3d_construction_stencil.png")

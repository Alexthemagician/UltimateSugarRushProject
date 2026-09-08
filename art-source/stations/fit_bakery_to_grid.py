from pathlib import Path

import numpy as np
from PIL import Image


SOURCE = Path(r"D:\UltimateSugarRush\ultimate-sugar-rush\assets\stations\bakery_station_grid_aligned.png")
OUTPUT = Path(r"D:\UltimateSugarRush\ultimate-sugar-rush\assets\stations\bakery_station_grid_fitted.png")
PIVOT_X = 627.0
PIVOT_Y = 789.0
LEFT_Y_FACTOR = 0.847
RIGHT_Y_FACTOR = 0.761
BLEND_START = 570.0
BLEND_END = 700.0


image = Image.open(SOURCE).convert("RGBA")
source = np.asarray(image, dtype=np.float32) / 255.0
height, width, _ = source.shape

# Interpolate between the independently measured arm corrections across the
# elbow so the remap remains continuous and does not create a visible seam.
x = np.arange(width, dtype=np.float32)
t = np.clip((x - BLEND_START) / (BLEND_END - BLEND_START), 0.0, 1.0)
t = t * t * (3.0 - 2.0 * t)
factors = LEFT_Y_FACTOR + (RIGHT_Y_FACTOR - LEFT_Y_FACTOR) * t

y_out = np.arange(height, dtype=np.float32)[:, None]
y_source = PIVOT_Y + (y_out - PIVOT_Y) / factors[None, :]
y_source = np.clip(y_source, 0.0, height - 1.001)
y0 = np.floor(y_source).astype(np.int32)
y1 = np.minimum(y0 + 1, height - 1)
weight = (y_source - y0)[..., None]
x_index = np.broadcast_to(np.arange(width, dtype=np.int32), y0.shape)

# Sample premultiplied color to keep transparent antialiased edges clean.
premultiplied = source.copy()
premultiplied[..., :3] *= premultiplied[..., 3:4]
sample0 = premultiplied[y0, x_index]
sample1 = premultiplied[y1, x_index]
result = sample0 * (1.0 - weight) + sample1 * weight
alpha = result[..., 3:4]
result[..., :3] = np.where(alpha > 1e-5, result[..., :3] / np.maximum(alpha, 1e-5), 0.0)

Image.fromarray(np.clip(result * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGBA").save(OUTPUT)
print(f"Wrote {OUTPUT}")

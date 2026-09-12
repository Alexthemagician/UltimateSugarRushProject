class_name CandyCutout
extends RefCounted

static var cache: Dictionary = {}

# Remove only neutral pixels connected to the exterior; enclosed white glints
# remain part of the candy. Cache the normalized texture for board and HUD use.
static func clean(source: Texture2D) -> Texture2D:
	if cache.has(source.resource_path):
		return cache[source.resource_path]
	var image := source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	visited[0] = 1
	var cursor := 0
	while cursor < queue.size():
		var pos: Vector2i = queue[cursor]
		cursor += 1
		var color := image.get_pixelv(pos)
		var saturation := maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))
		if color.a > 0.01 and (saturation > 0.13 or color.r < 0.55):
			continue
		image.set_pixelv(pos, Color.TRANSPARENT)
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := pos + offset
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			var index := neighbor.y * width + neighbor.x
			if visited[index] == 0:
				visited[index] = 1
				queue.append(neighbor)
	var piece := image.get_region(image.get_used_rect())
	var ratio := 440.0 / maxf(piece.get_width(), piece.get_height())
	piece.resize(roundi(piece.get_width() * ratio), roundi(piece.get_height() * ratio), Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), (Vector2i(512, 512) - piece.get_size()) / 2)
	canvas.generate_mipmaps()
	var texture := ImageTexture.create_from_image(canvas)
	cache[source.resource_path] = texture
	return texture

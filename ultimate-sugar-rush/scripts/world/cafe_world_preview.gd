extends Node2D
class_name CafeWorldPreview

signal station_selected(station_id: String, display_name: String, world_position: Vector2)
signal bakery_edit_requested
signal bakery_placement_changed(is_valid: bool)

const GRID_SIZE := Vector2i(18, 18)
const TILE_SIZE := Vector2(168.0, 84.0)
const GRID_AXIS_COLUMN := Vector2(TILE_SIZE.x * 0.5, TILE_SIZE.y * 0.5)
const GRID_AXIS_ROW := Vector2(-TILE_SIZE.x * 0.5, TILE_SIZE.y * 0.5)
const FLOOR_LIGHT := Color("fff4df")
const FLOOR_DARK := Color("f5dec1")
const GROUT := Color("d9bc9b")
const BAKERY_FOOTPRINT_FILL := Color("62b9e680")
const BAKERY_FOOTPRINT_EDGE := Color("2788ba")
const BAKERY_BASE_TOP := Color("fff0d8")
const BAKERY_BASE_LEFT := Color("f08d91")
const BAKERY_BASE_RIGHT := Color("df737d")
const BAKERY_OUTLINE := Color("873f48")
const BAKERY_PANEL_LIGHT := Color("ffb5b0")
const BAKERY_PANEL_DARK := Color("e98b92")
const BAKERY_CREAM_TRIM := Color("f9d4b8")
const BAKERY_GOLD := Color("e9a52f")
# One full isometric floor diamond taller than the initial 108 px cabinet.
# The floor-level footprint remains unchanged; only the upper plane is raised.
const BAKERY_BASE_HEIGHT := 108.0 + TILE_SIZE.y
const SHOW_CAFE_OCCUPANTS := false

const STATIONS := {
	"lemon_bar": {"name": "Lemon Bar", "cell": Vector2(3, 3), "footprint": Vector2(4, 2), "focus_zoom": 1.35},
	"bakery": {"name": "Bakery Counter", "cell": Vector2(12, 3), "footprint": Vector2(4, 2), "focus_zoom": 1.4},
	"sweets": {"name": "Sweets Counter", "cell": Vector2(3, 12), "footprint": Vector2(4, 2), "focus_zoom": 1.35},
	"tea_bar": {"name": "Tea Bar", "cell": Vector2(10, 10), "footprint": Vector2(7, 6), "focus_zoom": 1.4},
}
const BAKERY_EQUIPMENT_TEXTURE := preload("res://assets/stations/bakery_equipment.png")
const BAKERY_REDRAW_TEXTURE := preload("res://assets/stations/bakery_station_redrawn.png")
const BAKERY_GRID_ALIGNED_TEXTURE := preload("res://assets/stations/bakery_station_grid_aligned.png")
const BAKERY_GRID_FITTED_TEXTURE := preload("res://assets/stations/bakery_station_grid_fitted.png")
const BAKERY_TWO_WIDE_TEXTURE := preload("res://assets/stations/bakery_station_two_wide.png")
const BAKERY_ENGINE_FOOTPRINT_TEXTURE := preload("res://assets/stations/bakery_station_engine_footprint.png")
const BAKERY_POLISHED_GRID_EXACT_TEXTURE := preload("res://assets/stations/bakery_station_polished_corner_exact.png")
const BAKERY_POLISHED_ZOOM_OUT_TEXTURE := preload("res://assets/stations/bakery_station_polished_zoom_out_corner_exact.png")
const TEA_BAR_TEXTURE := preload("res://assets/stations/tea_bar_true_2to1_v16.png")
const BAKERY_DEFAULT_CELL := Vector2i(12, 3)
const TEA_BAR_CELL := Vector2i(10, 10)

var bakery_cell := BAKERY_DEFAULT_CELL
var bakery_orientation := 0
var bakery_editing := false
var bakery_move_mode := false
var tea_debug_footprint := false
var show_tea_bar := false
var bakery_preview_cell := BAKERY_DEFAULT_CELL


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	bakery_cell = Vector2i(
		int(SaveSystem.get_value("cafe_layout", "bakery_column", BAKERY_DEFAULT_CELL.x)),
		int(SaveSystem.get_value("cafe_layout", "bakery_row", BAKERY_DEFAULT_CELL.y))
	)
	bakery_orientation = int(SaveSystem.get_value("cafe_layout", "bakery_orientation", 0)) % 2
	bakery_preview_cell = bakery_cell
	queue_redraw()


func _draw() -> void:
	_draw_floor()
	_draw_walls()
	_draw_garden()
	_draw_service_counters()
	if SHOW_CAFE_OCCUPANTS:
		_draw_tables()
		_draw_characters()


func _iso(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_SIZE.x * 0.5, (cell.x + cell.y) * TILE_SIZE.y * 0.5)


func select_at_world_position(world_position: Vector2) -> bool:
	var local_point := to_local(world_position)
	var best_id := ""
	var best_distance := INF
	for station_id: String in STATIONS:
		var station: Dictionary = STATIONS[station_id]
		var center := _iso(Vector2(bakery_cell) if station_id == "bakery" else station.cell)
		var normalized := local_point - center
		var distance := absf(normalized.x) / 360.0 + absf(normalized.y) / 210.0
		if distance < 1.0 and distance < best_distance:
			best_distance = distance
			best_id = station_id
	if best_id.is_empty():
		return false
	select_station(best_id)
	return true


func select_station(station_id: String) -> void:
	if not STATIONS.has(station_id):
		return
	var station: Dictionary = STATIONS[station_id]
	var station_cell: Vector2 = Vector2(bakery_cell) if station_id == "bakery" else station.cell
	station_selected.emit(station_id, station.name, to_global(_iso(station_cell)))


func get_station_focus_zoom(station_id: String) -> float:
	if not STATIONS.has(station_id):
		return 1.3
	return float(STATIONS[station_id].focus_zoom)


func request_edit_at(world_position: Vector2) -> bool:
	if _bakery_contains_world(world_position):
		bakery_editing = true
		bakery_preview_cell = bakery_cell
		bakery_edit_requested.emit()
		queue_redraw()
		return true
	return false


func set_bakery_move_mode(enabled: bool) -> void:
	bakery_move_mode = enabled
	bakery_preview_cell = bakery_cell
	queue_redraw()


func rotate_bakery() -> void:
	bakery_orientation = 1 - bakery_orientation
	if not _is_bakery_placement_valid(bakery_cell, bakery_orientation):
		bakery_orientation = 1 - bakery_orientation
		bakery_placement_changed.emit(false)
		return
	_save_bakery_layout()
	bakery_placement_changed.emit(true)
	queue_redraw()


func try_place_bakery_at(world_position: Vector2) -> bool:
	if not bakery_editing or not bakery_move_mode:
		return false
	var candidate := _world_to_cell(to_local(world_position))
	bakery_preview_cell = candidate
	var valid := _is_bakery_placement_valid(candidate, bakery_orientation)
	if valid:
		bakery_cell = candidate
		bakery_move_mode = false
		_save_bakery_layout()
	bakery_placement_changed.emit(valid)
	queue_redraw()
	return true


func close_bakery_edit() -> void:
	bakery_editing = false
	bakery_move_mode = false
	bakery_preview_cell = bakery_cell
	queue_redraw()


func _tile_polygon(cell: Vector2) -> PackedVector2Array:
	var center := _iso(cell)
	return PackedVector2Array([
		center + Vector2(0.0, -TILE_SIZE.y * 0.5),
		center + Vector2(TILE_SIZE.x * 0.5, 0.0),
		center + Vector2(0.0, TILE_SIZE.y * 0.5),
		center + Vector2(-TILE_SIZE.x * 0.5, 0.0),
	])


func _draw_floor() -> void:
	for row in GRID_SIZE.y:
		for column in GRID_SIZE.x:
			var color := FLOOR_LIGHT if (row + column) % 2 == 0 else FLOOR_DARK
			var polygon := _tile_polygon(Vector2(column, row))
			draw_colored_polygon(polygon, color)
			draw_polyline(polygon + PackedVector2Array([polygon[0]]), GROUT, 2.0, true)


func _draw_walls() -> void:
	var first_tile := _tile_polygon(Vector2.ZERO)
	var last_tile := _tile_polygon(Vector2(GRID_SIZE.x - 1, 0))
	var base_left := first_tile[0]
	var base_right := last_tile[1]
	var wall_rise := Vector2(0.0, -250.0)
	draw_colored_polygon(PackedVector2Array([
		base_left + wall_rise, base_right + wall_rise, base_right, base_left,
	]), Color("a9573e"))
	draw_line(base_left, base_right, Color("78382f"), 5.0, true)
	draw_line(base_left + wall_rise, base_right + wall_rise, Color("d88b68"), 4.0, true)
	for index in GRID_SIZE.x + 1:
		var base_point := base_left + GRID_AXIS_COLUMN * float(index)
		draw_line(base_point + wall_rise, base_point, Color("d88b68"), 3.0, true)


func _draw_service_counters() -> void:
	_draw_block(_iso(Vector2(3, 3)), Vector2(4, 2), 118.0, Color("84b8aa"), Color("477e73"), "LEMON BAR")
	_draw_bakery()
	_draw_block(_iso(Vector2(3, 12)), Vector2(4, 2), 116.0, Color("d7a9d2"), Color("925d8d"), "SWEETS")
	if show_tea_bar:
		_draw_tea_bar()


func _draw_tea_bar() -> void:
	# The visible front-foot midpoint is registered to the matching midpoint of
	# the locked 7x6 U footprint. The seventh rear cell supports the fridge and
	# the two-square-wide side runs project four cells toward the camera.
	const ART_SCALE := 0.726
	const ART_FRONT_MIDPOINT := Vector2(638.0, 1173.0)
	var rear_left_vertex := _iso(Vector2(TEA_BAR_CELL)) + Vector2(0.0, -TILE_SIZE.y * 0.5)
	# Register the painted cabinet feet—not the transparent texture bounds—to the
	# corresponding grout vertices of the logical footprint.
	var target_front_midpoint := rear_left_vertex + GRID_AXIS_COLUMN * 3.5 + GRID_AXIS_ROW * 6.0 + Vector2(110.0, 15.0)
	var art_size := Vector2(1417.0, 1417.0) * ART_SCALE
	var art_origin := target_front_midpoint - ART_FRONT_MIDPOINT * ART_SCALE
	draw_texture_rect(TEA_BAR_TEXTURE, Rect2(art_origin, art_size), false)
	if tea_debug_footprint:
		for occupied_cell: Vector2i in _tea_bar_cells():
			var polygon := _tile_polygon(Vector2(occupied_cell))
			draw_colored_polygon(polygon, Color("62b9e665"))
			draw_polyline(polygon + PackedVector2Array([polygon[0]]), Color("1769ff"), 4.0, true)


func _tea_bar_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for column in 7:
		for row in 2:
			cells.append(TEA_BAR_CELL + Vector2i(column, row))
	for row in range(2, 6):
		for column in [0, 1, 5, 6]:
			cells.append(TEA_BAR_CELL + Vector2i(column, row))
	return cells


func _draw_bakery() -> void:
	var draw_cell := bakery_preview_cell if bakery_move_mode else bakery_cell
	var occupied_cells := _bakery_cells(draw_cell, bakery_orientation)
	_draw_bakery_painted(draw_cell, bakery_orientation)
	if bakery_editing:
		var valid := _is_bakery_placement_valid(draw_cell, bakery_orientation)
		var fill_color := Color("79d69c70") if valid else Color("ef718870")
		var edge_color := Color("3a9f66") if valid else Color("c84461")
		for occupied_cell: Vector2i in occupied_cells:
			var polygon := _tile_polygon(Vector2(occupied_cell))
			draw_colored_polygon(polygon, fill_color)
			draw_polyline(polygon + PackedVector2Array([polygon[0]]), edge_color, 4.0, true)


func _draw_bakery_painted(anchor: Vector2i, orientation: int) -> void:
	# The logical anchor is the rear elbow cell. For two-cell-wide arms, the
	# concave floor corner is the grid vertex 1.5 row/column steps from that
	# cell center. Its horizontal components cancel, leaving this exact offset.
	var center := _iso(Vector2(anchor)) + Vector2(0.0, TILE_SIZE.y * 1.5)
	# The current artwork is a fresh orthographic repaint built on a two-square-
	# deep construction stencil, not a deformation of the narrow station.
	# Calibrated from the sprite's three floor-contact vertices: each arm spans
	# exactly three isometric grid steps from the fixed inner corner.
	const PAINTED_SCALE := 0.70
	const PAINTED_INNER_FLOOR := Vector2(708.0, 672.0)
	var painted_scale := Vector2.ONE * PAINTED_SCALE
	var painted_size := Vector2(1320.0, 1191.0) * painted_scale
	var painted_origin := -PAINTED_INNER_FLOOR * painted_scale
	var active_camera := get_viewport().get_camera_2d()
	var painted_texture: Texture2D = BAKERY_POLISHED_GRID_EXACT_TEXTURE
	if active_camera and active_camera.zoom.x <= 0.95:
		painted_texture = BAKERY_POLISHED_ZOOM_OUT_TEXTURE
	draw_set_transform(center, 0.0, Vector2(-1.0, 1.0) if orientation == 1 else Vector2.ONE)
	draw_texture_rect(
		painted_texture,
		Rect2(painted_origin, painted_size),
		false
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bakery_equipment(anchor: Vector2i, orientation: int) -> void:
	var center := _iso(Vector2(anchor))
	draw_set_transform(center, 0.0, Vector2(-1.0, 1.0) if orientation == 1 else Vector2.ONE)
	# Painted contact shadows visually seat each equipment group on the raised
	# countertop without changing any prop or cabinet geometry.
	_draw_iso_ellipse(Vector2(-270.0, -88.0), Vector2(82.0, 18.0), Color("8b554329"))
	_draw_iso_ellipse(Vector2(-72.0, -145.0), Vector2(116.0, 18.0), Color("8b554326"))
	_draw_iso_ellipse(Vector2(205.0, -102.0), Vector2(128.0, 20.0), Color("8b55432b"))
	_draw_iso_ellipse(Vector2(281.0, 8.0), Vector2(82.0, 17.0), Color("8b554326"))
	draw_texture_rect(
		BAKERY_EQUIPMENT_TEXTURE,
		Rect2(Vector2(-384.0, -415.0), Vector2(768.0, 512.0)),
		false
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bakery_base(occupied_cells: Array[Vector2i], anchor: Vector2i, orientation: int) -> void:
	# Only the two screen-facing boundary directions need cabinet walls. Their
	# lower edges come directly from the floor diamonds. The upper edges are
	# vertical translations, keeping them exactly parallel to the floor base.
	var rise := Vector2(0.0, -BAKERY_BASE_HEIGHT)
	var direction := -1 if orientation == 1 else 1
	var vertical_face_column := direction if direction > 0 else 0
	for cell: Vector2i in occupied_cells:
		var polygon := _tile_polygon(Vector2(cell))
		if not occupied_cells.has(cell + Vector2i(1, 0)):
			_draw_bakery_cabinet_face(
				polygon[1] + rise, polygon[2] + rise, polygon[2], polygon[1], BAKERY_BASE_RIGHT
			)
		if not occupied_cells.has(cell + Vector2i(0, 1)):
			var feature := ""
			if cell == anchor + Vector2i(direction * 2, 1):
				feature = "pantry_bowls"
			elif cell == anchor + Vector2i(direction * 3, 1):
				feature = "pantry_basket"
			_draw_bakery_cabinet_face(
				polygon[2] + rise, polygon[3] + rise, polygon[3], polygon[2], BAKERY_BASE_LEFT, feature
			)
	var oven_near := _tile_polygon(Vector2(anchor + Vector2i(vertical_face_column, 2)))
	var oven_far := _tile_polygon(Vector2(anchor + Vector2i(vertical_face_column, 3)))
	_draw_bakery_oven(oven_near[1] + rise, oven_far[2] + rise, oven_near[1], oven_far[2])
	# Fill every top cell first, then outline only the exterior boundary. This
	# creates the seamless cream countertop of the painted reference instead of
	# making the station look like a stack of floor tiles.
	for cell: Vector2i in occupied_cells:
		var polygon := _tile_polygon(Vector2(cell))
		for index in polygon.size():
			polygon[index] += rise
		draw_colored_polygon(polygon, BAKERY_BASE_TOP)
		var surface_center := polygon[0].lerp(polygon[2], 0.5)
		draw_line(
			surface_center + Vector2(-22.0, -8.0),
			surface_center + Vector2(18.0, 12.0),
			Color("ffffff20"), 3.0, true
		)
		draw_circle(surface_center + Vector2(28.0, -4.0), 2.0, Color("dcae921c"))
	for cell: Vector2i in occupied_cells:
		var polygon := _tile_polygon(Vector2(cell))
		for index in polygon.size():
			polygon[index] += rise
		var neighbors := [
			Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
		]
		for edge_index in 4:
			if not occupied_cells.has(cell + neighbors[edge_index]):
				var next_index := (edge_index + 1) % 4
				draw_line(polygon[edge_index], polygon[next_index], BAKERY_OUTLINE, 5.0, true)
				draw_line(
					polygon[edge_index] + Vector2(0.0, 3.0),
					polygon[next_index] + Vector2(0.0, 3.0),
					Color("fff8e9b8"), 2.0, true
				)


func _draw_bakery_cabinet_face(
		top_a: Vector2, top_b: Vector2, bottom_b: Vector2, bottom_a: Vector2,
		face_color: Color, feature: String = ""
) -> void:
	var face := PackedVector2Array([top_a, top_b, bottom_b, bottom_a])
	draw_colored_polygon(face, face_color)
	# Layered translucent glazing gives the flat geometry the soft painted depth
	# of the reference while leaving every boundary vertex untouched.
	var upper_glaze := _bakery_face_quad(top_a, top_b, bottom_a, bottom_b, 0.0, 0.0, 1.0, 0.44)
	var lower_shade := _bakery_face_quad(top_a, top_b, bottom_a, bottom_b, 0.0, 0.68, 1.0, 1.0)
	draw_colored_polygon(upper_glaze, Color("ffd8d02e"))
	draw_colored_polygon(lower_shade, Color("873f4824"))
	draw_polyline(face + PackedVector2Array([face[0]]), BAKERY_OUTLINE, 4.0, true)
	draw_line(top_a + Vector2(0.0, 18.0), bottom_a + Vector2(0.0, -18.0), Color("ffc4be80"), 3.0, true)
	for u in [0.07, 0.93]:
		var grain_top := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, u, 0.16)
		var grain_bottom := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, u, 0.90)
		draw_line(grain_top, grain_bottom, Color("fff0e038"), 2.0, true)

	# Cream counter lip and darker kickboard follow the same grid-derived edges.
	var lip_drop := Vector2(0.0, 13.0)
	draw_colored_polygon(PackedVector2Array([top_a, top_b, top_b + lip_drop, top_a + lip_drop]), BAKERY_CREAM_TRIM)
	draw_line(top_a, top_b, Color("fff8ec"), 3.0, true)
	draw_line(top_a + lip_drop, top_b + lip_drop, BAKERY_OUTLINE, 3.0, true)
	var kick_rise := Vector2(0.0, -15.0)
	draw_colored_polygon(PackedVector2Array([bottom_a + kick_rise, bottom_b + kick_rise, bottom_b, bottom_a]), BAKERY_OUTLINE.lightened(0.12))

	# Each exposed grid cell becomes one framed cabinet panel.
	var panel_top_a := top_a.lerp(top_b, 0.13) + Vector2(0.0, 31.0)
	var panel_top_b := top_a.lerp(top_b, 0.87) + Vector2(0.0, 31.0)
	var panel_bottom_a := bottom_a.lerp(bottom_b, 0.13) + Vector2(0.0, -30.0)
	var panel_bottom_b := bottom_a.lerp(bottom_b, 0.87) + Vector2(0.0, -30.0)
	var panel := PackedVector2Array([panel_top_a, panel_top_b, panel_bottom_b, panel_bottom_a])
	draw_colored_polygon(panel, BAKERY_PANEL_LIGHT if face_color == BAKERY_BASE_LEFT else BAKERY_PANEL_DARK)
	draw_polyline(panel + PackedVector2Array([panel[0]]), BAKERY_OUTLINE.lightened(0.12), 3.0, true)
	var panel_inner := _bakery_face_quad(top_a, top_b, bottom_a, bottom_b, 0.22, 0.27, 0.78, 0.78)
	draw_polyline(panel_inner + PackedVector2Array([panel_inner[0]]), Color("ffd7d094"), 2.0, true)
	if feature == "oven":
		_draw_bakery_oven(top_a, top_b, bottom_a, bottom_b)
	elif feature.begins_with("pantry"):
		_draw_bakery_pantry(top_a, top_b, bottom_a, bottom_b, feature)
	else:
		var drawer_a := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.16, 0.43)
		var drawer_b := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.84, 0.43)
		draw_line(drawer_a, drawer_b, BAKERY_OUTLINE.lightened(0.14), 3.0, true)
		var handle_a := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.40, 0.35)
		var handle_b := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.60, 0.35)
		draw_line(handle_a, handle_b, BAKERY_OUTLINE, 7.0, true)
		draw_line(handle_a, handle_b, BAKERY_GOLD, 4.0, true)
		var door_top := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.50, 0.49)
		var door_bottom := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.50, 0.82)
		draw_line(door_top, door_bottom, BAKERY_OUTLINE.lightened(0.18), 3.0, true)
		for u in [0.44, 0.56]:
			var knob := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, u, 0.59)
			draw_circle(knob, 6.5, BAKERY_OUTLINE)
			draw_circle(knob + Vector2(0.0, -1.0), 4.0, BAKERY_GOLD)


func _bakery_face_point(
		top_a: Vector2, top_b: Vector2, bottom_a: Vector2, bottom_b: Vector2,
		u: float, v: float
) -> Vector2:
	return top_a.lerp(top_b, u).lerp(bottom_a.lerp(bottom_b, u), v)


func _bakery_face_quad(
		top_a: Vector2, top_b: Vector2, bottom_a: Vector2, bottom_b: Vector2,
		u0: float, v0: float, u1: float, v1: float
) -> PackedVector2Array:
	return PackedVector2Array([
		_bakery_face_point(top_a, top_b, bottom_a, bottom_b, u0, v0),
		_bakery_face_point(top_a, top_b, bottom_a, bottom_b, u1, v0),
		_bakery_face_point(top_a, top_b, bottom_a, bottom_b, u1, v1),
		_bakery_face_point(top_a, top_b, bottom_a, bottom_b, u0, v1),
	])


func _draw_bakery_oven(top_a: Vector2, top_b: Vector2, bottom_a: Vector2, bottom_b: Vector2) -> void:
	var oven := _bakery_face_quad(top_a, top_b, bottom_a, bottom_b, 0.10, 0.26, 0.90, 0.86)
	draw_colored_polygon(oven, Color("fff0d8"))
	draw_polyline(oven + PackedVector2Array([oven[0]]), BAKERY_OUTLINE, 4.0, true)
	var window := _bakery_face_quad(top_a, top_b, bottom_a, bottom_b, 0.18, 0.48, 0.82, 0.79)
	draw_colored_polygon(window, Color("573a39"))
	draw_polyline(window + PackedVector2Array([window[0]]), Color("b86a50"), 4.0, true)
	var glow := _bakery_face_quad(top_a, top_b, bottom_a, bottom_b, 0.25, 0.57, 0.75, 0.73)
	draw_colored_polygon(glow, Color("d77a2b"))
	var loaf_left := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.39, 0.66)
	var loaf_right := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.61, 0.66)
	draw_circle(loaf_left, 10.0, Color("f2b43f"))
	draw_circle(loaf_right, 10.0, Color("f2b43f"))
	var handle_a := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.22, 0.42)
	var handle_b := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.78, 0.42)
	draw_line(handle_a, handle_b, BAKERY_OUTLINE, 8.0, true)
	draw_line(handle_a, handle_b, BAKERY_GOLD, 4.0, true)
	for u in [0.25, 0.5, 0.75]:
		var control := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, u, 0.33)
		draw_circle(control, 6.0, BAKERY_OUTLINE)
		draw_circle(control, 3.5, BAKERY_GOLD)


func _draw_bakery_pantry(
		top_a: Vector2, top_b: Vector2, bottom_a: Vector2, bottom_b: Vector2, feature: String
) -> void:
	var recess := _bakery_face_quad(top_a, top_b, bottom_a, bottom_b, 0.10, 0.24, 0.90, 0.87)
	draw_colored_polygon(recess, Color("a95756"))
	draw_polyline(recess + PackedVector2Array([recess[0]]), BAKERY_OUTLINE, 4.0, true)
	var shelf_a := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.11, 0.59)
	var shelf_b := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.89, 0.59)
	draw_line(shelf_a, shelf_b, BAKERY_OUTLINE, 8.0, true)
	draw_line(shelf_a, shelf_b, BAKERY_CREAM_TRIM, 4.0, true)
	if feature == "pantry_flour":
		var bag := _bakery_face_quad(top_a, top_b, bottom_a, bottom_b, 0.25, 0.33, 0.69, 0.56)
		draw_colored_polygon(bag, Color("fff0cf"))
		draw_polyline(bag + PackedVector2Array([bag[0]]), Color("c7825b"), 3.0, true)
		var wheat := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.47, 0.45)
		draw_circle(wheat, 6.0, BAKERY_GOLD)
		var bowl := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.49, 0.73)
		draw_circle(bowl, 18.0, Color("54aa9c"))
		draw_arc(bowl, 18.0, 0.0, PI, 16, Color("d8fff2"), 4.0, true)
	elif feature == "pantry_bowls":
		var bowl := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.49, 0.43)
		draw_circle(bowl, 20.0, Color("55a99c"))
		draw_arc(bowl, 20.0, 0.0, PI, 16, Color("d8fff2"), 4.0, true)
		var pan := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.49, 0.73)
		draw_circle(pan, 19.0, Color("4e4a4b"))
		draw_arc(pan, 19.0, PI, TAU, 16, Color("958889"), 4.0, true)
	else:
		# Woven basket with the pink gingham cloth from the painted reference.
		var basket := _bakery_face_quad(top_a, top_b, bottom_a, bottom_b, 0.16, 0.52, 0.84, 0.84)
		draw_colored_polygon(basket, Color("b8732f"))
		draw_polyline(basket + PackedVector2Array([basket[0]]), Color("704027"), 4.0, true)
		for v in [0.61, 0.70, 0.79]:
			var weave_a := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.18, v)
			var weave_b := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.82, v)
			draw_line(weave_a, weave_b, Color("e3a454"), 2.0, true)
		var cloth := _bakery_face_quad(top_a, top_b, bottom_a, bottom_b, 0.23, 0.31, 0.77, 0.60)
		draw_colored_polygon(cloth, Color("f7b5b2"))
		draw_polyline(cloth + PackedVector2Array([cloth[0]]), Color("a84e57"), 3.0, true)
		for u in [0.36, 0.50, 0.64]:
			var stripe_a := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, u, 0.33)
			var stripe_b := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, u, 0.57)
			draw_line(stripe_a, stripe_b, Color("fff0e1a0"), 2.0, true)
		for v in [0.41, 0.50]:
			var stripe_a := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.25, v)
			var stripe_b := _bakery_face_point(top_a, top_b, bottom_a, bottom_b, 0.75, v)
			draw_line(stripe_a, stripe_b, Color("fff0e1a0"), 2.0, true)


func _bakery_cells(anchor: Vector2i, orientation: int) -> Array[Vector2i]:
	var direction := -1 if orientation == 1 else 1
	return [
		anchor,
		anchor + Vector2i(direction, 0),
		anchor + Vector2i(direction * 2, 0),
		anchor + Vector2i(direction * 3, 0),
		anchor + Vector2i(0, 1),
		anchor + Vector2i(direction, 1),
		anchor + Vector2i(direction * 2, 1),
		anchor + Vector2i(direction * 3, 1),
		anchor + Vector2i(0, 2),
		anchor + Vector2i(direction, 2),
		anchor + Vector2i(0, 3),
		anchor + Vector2i(direction, 3),
	]


func _is_bakery_placement_valid(anchor: Vector2i, orientation: int) -> bool:
	for cell: Vector2i in _bakery_cells(anchor, orientation):
		if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE.x or cell.y >= GRID_SIZE.y:
			return false
		for reserved in [Rect2i(1, 2, 5, 4), Rect2i(1, 11, 5, 4), Rect2i(11, 12, 6, 5)]:
			if reserved.has_point(cell):
				return false
	return true


func _bakery_contains_world(world_position: Vector2) -> bool:
	var local_point := to_local(world_position)
	for cell: Vector2i in _bakery_cells(bakery_cell, bakery_orientation):
		if local_point.distance_to(_iso(Vector2(cell))) < 190.0:
			return true
	return false


func _world_to_cell(local_point: Vector2) -> Vector2i:
	var column := local_point.x / TILE_SIZE.x + local_point.y / TILE_SIZE.y
	var row := local_point.y / TILE_SIZE.y - local_point.x / TILE_SIZE.x
	return Vector2i(roundi(column), roundi(row))


func _save_bakery_layout() -> void:
	SaveSystem.set_value("cafe_layout", "bakery_column", bakery_cell.x)
	SaveSystem.set_value("cafe_layout", "bakery_row", bakery_cell.y)
	SaveSystem.set_value("cafe_layout", "bakery_orientation", bakery_orientation)


func _draw_block(center: Vector2, footprint: Vector2, height: float, top_color: Color, side_color: Color, label: String) -> void:
	var grid_x := GRID_AXIS_COLUMN * footprint.x
	var grid_y := GRID_AXIS_ROW * footprint.y
	var top := PackedVector2Array([
		center - grid_x * 0.5 - grid_y * 0.5,
		center + grid_x * 0.5 - grid_y * 0.5,
		center + grid_x * 0.5 + grid_y * 0.5,
		center - grid_x * 0.5 + grid_y * 0.5,
	])
	draw_colored_polygon(top, top_color)
	draw_polyline(top + PackedVector2Array([top[0]]), side_color.darkened(0.18), 4.0, true)
	draw_colored_polygon(PackedVector2Array([top[2], top[1], top[1] + Vector2(0, height), top[2] + Vector2(0, height)]), side_color.darkened(0.08))
	draw_colored_polygon(PackedVector2Array([top[3], top[2], top[2] + Vector2(0, height), top[3] + Vector2(0, height)]), side_color)
	draw_string(ThemeDB.fallback_font, center + Vector2(-95, 14), label, HORIZONTAL_ALIGNMENT_CENTER, 190, 28, Color.WHITE)


func _draw_tables() -> void:
	var bakery_center := _iso(Vector2(bakery_cell))
	for cell in [Vector2(7, 6), Vector2(10, 8), Vector2(7, 11), Vector2(12, 10)]:
		var center := _iso(cell)
		_draw_iso_ellipse(center + Vector2(0, 36), Vector2(92, 46), Color("8b4a3a"))
		_draw_iso_ellipse(center, Vector2(98, 49), Color("e57f77"))
		_draw_iso_ellipse(center, Vector2(68, 34), Color("f8c7a1"))
		draw_circle(center + Vector2(-22, -10), 16, Color("fff0d5"))
		draw_circle(center + Vector2(24, 12), 15, Color("fff0d5"))
		var left_chair := center + Vector2(-135, 28)
		var right_chair := center + Vector2(135, 28)
		if left_chair.distance_to(bakery_center) >= 620.0:
			_draw_iso_chair(left_chair, -1.0)
		if right_chair.distance_to(bakery_center) >= 620.0:
			_draw_iso_chair(right_chair, 1.0)


func _draw_iso_chair(center: Vector2, direction: float) -> void:
	var axis_x := Vector2(46, 23) * direction
	var axis_y := Vector2(-34, 17) * direction
	var seat := PackedVector2Array([
		center - axis_x - axis_y, center + axis_x - axis_y,
		center + axis_x + axis_y, center - axis_x + axis_y,
	])
	draw_colored_polygon(seat, Color("c66c4c"))
	draw_polyline(seat + PackedVector2Array([seat[0]]), Color("773d32"), 4.0, true)
	draw_line(seat[0], seat[0] + Vector2(0, -70), Color("773d32"), 8.0)
	draw_line(seat[1], seat[1] + Vector2(0, -70), Color("773d32"), 8.0)
	draw_line(seat[0] + Vector2(0, -70), seat[1] + Vector2(0, -70), Color("773d32"), 8.0)


func _draw_garden() -> void:
	var center := _iso(Vector2(7, 14))
	var garden_x := GRID_AXIS_COLUMN * 6.0
	var garden_y := GRID_AXIS_ROW * 6.0
	draw_colored_polygon(PackedVector2Array([
		center - garden_x * 0.5 - garden_y * 0.5,
		center + garden_x * 0.5 - garden_y * 0.5,
		center + garden_x * 0.5 + garden_y * 0.5,
		center - garden_x * 0.5 + garden_y * 0.5,
	]), Color("8dcf83"))
	for offset in [Vector2(-250, -20), Vector2(-120, 80), Vector2(30, -70), Vector2(190, 50), Vector2(300, -40)]:
		draw_circle(center + offset, 54, Color("3f8b56"))
		draw_circle(center + offset + Vector2(-28, 10), 34, Color("66ad66"))
		draw_circle(center + offset + Vector2(24, -12), 32, Color("76bd70"))


func _draw_characters() -> void:
	var palette := [Color("743f2f"), Color("b85b48"), Color("4e705d"), Color("73578f"), Color("d29b42")]
	var cells := [Vector2(5, 6), Vector2(9, 5), Vector2(11, 11), Vector2(6, 13), Vector2(16, 9)]
	var bakery_center := _iso(Vector2(bakery_cell))
	for index in cells.size():
		var center := _iso(cells[index])
		if center.distance_to(bakery_center) < 520.0:
			continue
		_draw_character_body(center + Vector2(0, 12), Vector2(38, 52), palette[index])
		draw_circle(center + Vector2(0, -55), 42, Color("f2b894"))
		draw_arc(center + Vector2(0, -62), 40, PI, TAU, 20, Color("51342d"), 20)
		draw_circle(center + Vector2(-14, -57), 4, Color("34251f"))
		draw_circle(center + Vector2(14, -57), 4, Color("34251f"))


func _draw_character_body(center: Vector2, radius: Vector2, color: Color) -> void:
	_draw_iso_ellipse(center, radius, color)


func _draw_iso_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 28:
		var angle := TAU * float(index) / 28.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

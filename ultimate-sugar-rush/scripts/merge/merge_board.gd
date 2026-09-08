extends Control
class_name MergeBoard

signal board_changed
signal item_merged(item_id: String)
signal item_discarded(item_id: String)

const COLUMNS := 6
const ROWS := 8
const CELL_SIZE := Vector2(158, 158)
const ITEM_INSET := 2.0
const ITEM_SCENE := preload("res://scenes/merge/merge_item.tscn")
const SPAWNABLE_FRUITS := ["lemon", "orange", "apple"]
const SPAWNABLE_CAKE_INGREDIENTS := ["chocolate_bar", "strawberry", "vanilla_flowers", "blueberries"]
const SPAWNABLE_COOKIES := ["chocolate_chip_cookie", "pink_sugar_cookie", "sandwich_cookie", "lucky_cookie"]
const SPAWNABLE_ICE_CREAM_BASES := ["milk_pitcher", "chocolate_milk", "pistachios"]
const SPAWNABLE_MIXED_BASES := ["chocolate_milk", "pink_sugar_cookie", "vanilla_flowers", "apple"]

@export_enum("drinks", "cakes", "cookies", "ice_cream", "mixed") var board_kind := "drinks"

const ITEM_DEFINITIONS := {
	"lemon": {"id":"lemon", "name":"Sunny Lemon", "level":1, "next_id":"lemonade", "texture":"res://assets/merge/lemon.png"},
	"lemonade": {"id":"lemonade", "name":"Fresh Lemonade", "level":2, "next_id":"strawberry_lemonade", "texture":"res://assets/merge/lemonade.png"},
	"strawberry_lemonade": {"id":"strawberry_lemonade", "name":"Berry Lemonade", "level":3, "next_id":"magic_pitcher", "texture":"res://assets/merge/strawberry_lemonade.png"},
	"magic_pitcher": {"id":"magic_pitcher", "name":"Magic Pitcher", "level":4, "next_id":"", "texture":"res://assets/merge/magic_pitcher.png"},
	"orange": {"id":"orange", "name":"Sunset Orange", "level":1, "next_id":"orange_juice", "texture":"res://assets/merge/orange.png"},
	"orange_juice": {"id":"orange_juice", "name":"Fresh Orange Juice", "level":2, "next_id":"exotic_orange_juice", "texture":"res://assets/merge/orange_juice.png"},
	"exotic_orange_juice": {"id":"exotic_orange_juice", "name":"Exotic Orange Juice", "level":3, "next_id":"orange_pitcher", "texture":"res://assets/merge/exotic_orange_juice.png"},
	"orange_pitcher": {"id":"orange_pitcher", "name":"Orange Grove Pitcher", "level":4, "next_id":"", "texture":"res://assets/merge/orange_pitcher.png"},
	"apple": {"id":"apple", "name":"Ruby Apple", "level":1, "next_id":"apple_juice", "texture":"res://assets/merge/apple.png"},
	"apple_juice": {"id":"apple_juice", "name":"Fresh Apple Juice", "level":2, "next_id":"exotic_apple_juice", "texture":"res://assets/merge/apple_juice.png"},
	"exotic_apple_juice": {"id":"exotic_apple_juice", "name":"Exotic Apple Juice", "level":3, "next_id":"apple_pitcher", "texture":"res://assets/merge/exotic_apple_juice.png"},
	"apple_pitcher": {"id":"apple_pitcher", "name":"Orchard Pitcher", "level":4, "next_id":"", "texture":"res://assets/merge/apple_pitcher.png"},
	"chocolate_bar": {"id":"chocolate_bar", "name":"Chocolate Bar", "level":1, "next_id":"chocolate_batter", "texture":"res://assets/merge/chocolate_bar.png"},
	"chocolate_batter": {"id":"chocolate_batter", "name":"Chocolate Batter", "level":2, "next_id":"chocolate_cake_slice", "texture":"res://assets/merge/chocolate_batter.png"},
	"chocolate_cake_slice": {"id":"chocolate_cake_slice", "name":"Chocolate Cake Slice", "level":3, "next_id":"chocolate_cake", "texture":"res://assets/merge/chocolate_cake_slice.png"},
	"chocolate_cake": {"id":"chocolate_cake", "name":"Single-Layer Chocolate Cake", "level":4, "next_id":"", "texture":"res://assets/merge/chocolate_cake.png"},
	"strawberry": {"id":"strawberry", "name":"Strawberries", "level":1, "next_id":"strawberry_batter", "texture":"res://assets/merge/strawberry.png"},
	"strawberry_batter": {"id":"strawberry_batter", "name":"Strawberry Batter", "level":2, "next_id":"strawberry_cake_slice", "texture":"res://assets/merge/strawberry_batter.png"},
	"strawberry_cake_slice": {"id":"strawberry_cake_slice", "name":"Strawberry Cake Slice", "level":3, "next_id":"strawberry_cake", "texture":"res://assets/merge/strawberry_cake_slice.png"},
	"strawberry_cake": {"id":"strawberry_cake", "name":"Strawberry Cake", "level":4, "next_id":"", "texture":"res://assets/merge/strawberry_cake.png"},
	"vanilla_flowers": {"id":"vanilla_flowers", "name":"Vanilla Flowers", "level":1, "next_id":"vanilla_batter", "texture":"res://assets/merge/vanilla_flowers.png"},
	"vanilla_batter": {"id":"vanilla_batter", "name":"Vanilla Batter", "level":2, "next_id":"vanilla_cake_slice", "texture":"res://assets/merge/vanilla_batter.png"},
	"vanilla_cake_slice": {"id":"vanilla_cake_slice", "name":"Vanilla Cake Slice", "level":3, "next_id":"vanilla_cake", "texture":"res://assets/merge/vanilla_cake_slice.png"},
	"vanilla_cake": {"id":"vanilla_cake", "name":"Vanilla Cake", "level":4, "next_id":"", "texture":"res://assets/merge/vanilla_cake.png"},
	"blueberries": {"id":"blueberries", "name":"Blueberries", "level":1, "next_id":"blueberry_batter", "texture":"res://assets/merge/blueberries.png"},
	"blueberry_batter": {"id":"blueberry_batter", "name":"Blueberry Batter", "level":2, "next_id":"blueberry_cake_slice", "texture":"res://assets/merge/blueberry_batter.png"},
	"blueberry_cake_slice": {"id":"blueberry_cake_slice", "name":"Blueberry Cake Slice", "level":3, "next_id":"blueberry_cake", "texture":"res://assets/merge/blueberry_cake_slice.png"},
	"blueberry_cake": {"id":"blueberry_cake", "name":"Blueberry Cake", "level":4, "next_id":"", "texture":"res://assets/merge/blueberry_cake.png"},
	"chocolate_chip_cookie": {"id":"chocolate_chip_cookie", "name":"Chocolate Chip Cookie", "level":1, "next_id":"chocolate_chip_cookie_stack", "texture":"res://assets/merge/chocolate_chip_cookie.png"},
	"chocolate_chip_cookie_stack": {"id":"chocolate_chip_cookie_stack", "name":"Chocolate Chip Cookie Stack", "level":2, "next_id":"chocolate_chip_cookie_jar", "texture":"res://assets/merge/chocolate_chip_cookie_stack.png"},
	"chocolate_chip_cookie_jar": {"id":"chocolate_chip_cookie_jar", "name":"Chocolate Chip Cookie Jar", "level":3, "next_id":"chocolate_chip_cookie_box", "texture":"res://assets/merge/chocolate_chip_cookie_jar.png"},
	"chocolate_chip_cookie_box": {"id":"chocolate_chip_cookie_box", "name":"Chocolate Chip Cookie Box", "level":4, "next_id":"", "texture":"res://assets/merge/chocolate_chip_cookie_box.png"},
	"pink_sugar_cookie": {"id":"pink_sugar_cookie", "name":"Pink Sugar Cookie", "level":1, "next_id":"pink_sugar_cookie_stack", "texture":"res://assets/merge/pink_sugar_cookie.png"},
	"pink_sugar_cookie_stack": {"id":"pink_sugar_cookie_stack", "name":"Pink Sugar Cookie Stack", "level":2, "next_id":"pink_sugar_cookie_jar", "texture":"res://assets/merge/pink_sugar_cookie_stack.png"},
	"pink_sugar_cookie_jar": {"id":"pink_sugar_cookie_jar", "name":"Pink Sugar Cookie Jar", "level":3, "next_id":"pink_sugar_cookie_box", "texture":"res://assets/merge/pink_sugar_cookie_jar.png"},
	"pink_sugar_cookie_box": {"id":"pink_sugar_cookie_box", "name":"Pink Sugar Cookie Box", "level":4, "next_id":"", "texture":"res://assets/merge/pink_sugar_cookie_box.png"},
	"sandwich_cookie": {"id":"sandwich_cookie", "name":"Chocolate Sandwich Cookie", "level":1, "next_id":"sandwich_cookie_stack", "texture":"res://assets/merge/sandwich_cookie.png"},
	"sandwich_cookie_stack": {"id":"sandwich_cookie_stack", "name":"Chocolate Sandwich Cookie Stack", "level":2, "next_id":"sandwich_cookie_jar", "texture":"res://assets/merge/sandwich_cookie_stack.png"},
	"sandwich_cookie_jar": {"id":"sandwich_cookie_jar", "name":"Chocolate Sandwich Cookie Jar", "level":3, "next_id":"sandwich_cookie_box", "texture":"res://assets/merge/sandwich_cookie_jar.png"},
	"sandwich_cookie_box": {"id":"sandwich_cookie_box", "name":"Chocolate Sandwich Cookie Box", "level":4, "next_id":"", "texture":"res://assets/merge/sandwich_cookie_box.png"},
	"lucky_cookie": {"id":"lucky_cookie", "name":"Lucky Charms Cookie", "level":1, "next_id":"lucky_cookie_stack", "texture":"res://assets/merge/lucky_cookie.png"},
	"lucky_cookie_stack": {"id":"lucky_cookie_stack", "name":"Lucky Charms Cookie Stack", "level":2, "next_id":"lucky_cookie_jar", "texture":"res://assets/merge/lucky_cookie_stack.png"},
	"lucky_cookie_jar": {"id":"lucky_cookie_jar", "name":"Lucky Charms Cookie Jar", "level":3, "next_id":"lucky_cookie_box", "texture":"res://assets/merge/lucky_cookie_jar.png"},
	"lucky_cookie_box": {"id":"lucky_cookie_box", "name":"Lucky Charms Cookie Box", "level":4, "next_id":"", "texture":"res://assets/merge/lucky_cookie_box.png"},
	"milk_pitcher": {"id":"milk_pitcher", "name":"Milk Pitcher", "level":1, "next_id":"vanilla_cream", "texture":"res://assets/merge/milk_pitcher.png"},
	"vanilla_cream": {"id":"vanilla_cream", "name":"Vanilla Cream", "level":2, "next_id":"vanilla_cone", "texture":"res://assets/merge/vanilla_cream.png"},
	"vanilla_cone": {"id":"vanilla_cone", "name":"Vanilla Cone", "level":3, "next_id":"vanilla_ice_cream_bowl", "texture":"res://assets/merge/vanilla_cone.png"},
	"vanilla_ice_cream_bowl": {"id":"vanilla_ice_cream_bowl", "name":"Big Vanilla Ice Cream Bowl", "level":4, "next_id":"", "texture":"res://assets/merge/vanilla_ice_cream_bowl.png"},
	"chocolate_milk": {"id":"chocolate_milk", "name":"Chocolate Milk", "level":1, "next_id":"chocolate_cream", "texture":"res://assets/merge/chocolate_milk.png"},
	"chocolate_cream": {"id":"chocolate_cream", "name":"Chocolate Cream", "level":2, "next_id":"chocolate_cone", "texture":"res://assets/merge/chocolate_cream.png"},
	"chocolate_cone": {"id":"chocolate_cone", "name":"Chocolate Cone", "level":3, "next_id":"chocolate_ice_cream_bowl", "texture":"res://assets/merge/chocolate_cone.png"},
	"chocolate_ice_cream_bowl": {"id":"chocolate_ice_cream_bowl", "name":"Big Chocolate Ice Cream Bowl", "level":4, "next_id":"", "texture":"res://assets/merge/chocolate_ice_cream_bowl.png"},
	"pistachios": {"id":"pistachios", "name":"Pistachios", "level":1, "next_id":"pistachio_cream", "texture":"res://assets/merge/pistachios.png"},
	"pistachio_cream": {"id":"pistachio_cream", "name":"Pistachio Cream", "level":2, "next_id":"pistachio_cone", "texture":"res://assets/merge/pistachio_cream.png"},
	"pistachio_cone": {"id":"pistachio_cone", "name":"Pistachio Cone", "level":3, "next_id":"pistachio_ice_cream_bowl", "texture":"res://assets/merge/pistachio_cone.png"},
	"pistachio_ice_cream_bowl": {"id":"pistachio_ice_cream_bowl", "name":"Big Pistachio Ice Cream Bowl", "level":4, "next_id":"", "texture":"res://assets/merge/pistachio_ice_cream_bowl.png"},
}

var _items: Dictionary = {}
var _cells: Dictionary = {}
var _highlighted_cell := Vector2i(-1, -1)
var _dragged_item: TextureRect
var _discard_target: Control
var last_spawn_was_frozen := false
var persistence_enabled := true
var _resolving_action := false


func _ready() -> void:
	custom_minimum_size = Vector2(COLUMNS * CELL_SIZE.x, ROWS * CELL_SIZE.y)
	_create_cells()
	_load_board()
	if _items.is_empty():
		_seed_board()
	elif board_kind == "drinks":
		_ensure_fruit_intro("orange", ["orange", "orange_juice", "exotic_orange_juice", "orange_pitcher"])
		_ensure_fruit_intro("apple", ["apple", "apple_juice", "exotic_apple_juice", "apple_pitcher"])
	elif board_kind == "cakes":
		_ensure_cake_intro("chocolate_bar", ["chocolate_bar", "chocolate_batter", "chocolate_cake_slice", "chocolate_cake"])
		_ensure_cake_intro("strawberry", ["strawberry", "strawberry_batter", "strawberry_cake_slice", "strawberry_cake"])
		_ensure_cake_intro("vanilla_flowers", ["vanilla_flowers", "vanilla_batter", "vanilla_cake_slice", "vanilla_cake"])
		_ensure_cake_intro("blueberries", ["blueberries", "blueberry_batter", "blueberry_cake_slice", "blueberry_cake"])
	elif board_kind == "cookies":
		_ensure_fruit_intro("chocolate_chip_cookie", ["chocolate_chip_cookie", "chocolate_chip_cookie_stack", "chocolate_chip_cookie_jar", "chocolate_chip_cookie_box"])
		_ensure_fruit_intro("pink_sugar_cookie", ["pink_sugar_cookie", "pink_sugar_cookie_stack", "pink_sugar_cookie_jar", "pink_sugar_cookie_box"])
		_ensure_fruit_intro("sandwich_cookie", ["sandwich_cookie", "sandwich_cookie_stack", "sandwich_cookie_jar", "sandwich_cookie_box"])
		_ensure_fruit_intro("lucky_cookie", ["lucky_cookie", "lucky_cookie_stack", "lucky_cookie_jar", "lucky_cookie_box"])
	else:
		if board_kind == "ice_cream":
			_ensure_fruit_intro("milk_pitcher", ["milk_pitcher", "vanilla_cream", "vanilla_cone", "vanilla_ice_cream_bowl"])
			_ensure_fruit_intro("chocolate_milk", ["chocolate_milk", "chocolate_cream", "chocolate_cone", "chocolate_ice_cream_bowl"])
			_ensure_fruit_intro("pistachios", ["pistachios", "pistachio_cream", "pistachio_cone", "pistachio_ice_cream_bowl"])
		else:
			_ensure_fruit_intro("chocolate_milk", ["chocolate_milk", "chocolate_cream", "chocolate_cone", "chocolate_ice_cream_bowl"])
			_ensure_fruit_intro("pink_sugar_cookie", ["pink_sugar_cookie", "pink_sugar_cookie_stack", "pink_sugar_cookie_jar", "pink_sugar_cookie_box"])
			_ensure_fruit_intro("vanilla_flowers", ["vanilla_flowers", "vanilla_batter", "vanilla_cake_slice", "vanilla_cake"])
			_ensure_fruit_intro("apple", ["apple", "apple_juice", "exotic_apple_juice", "apple_pitcher"])
	queue_redraw()


func _draw() -> void:
	for row in ROWS:
		for column in COLUMNS:
			var cell := Vector2i(column, row)
			var rect := Rect2(Vector2(column, row) * CELL_SIZE, CELL_SIZE).grow(-5)
			var color := _cell_color(column, row)
			if cell == _highlighted_cell:
				color = _highlight_color(cell)
			draw_style_box(_cell_style(color), rect)


func add_random_fruit() -> String:
	return add_random_base_item()


func add_random_base_item() -> String:
	if _resolving_action:
		return ""
	var empty := _empty_cells()
	if empty.is_empty():
		return ""
	var cell: Vector2i = empty.pick_random()
	var pool := SPAWNABLE_MIXED_BASES if board_kind == "mixed" else (SPAWNABLE_ICE_CREAM_BASES if board_kind == "ice_cream" else (SPAWNABLE_CAKE_INGREDIENTS if board_kind == "cakes" else (SPAWNABLE_COOKIES if board_kind == "cookies" else SPAWNABLE_FRUITS)))
	var item_id := str(pool.pick_random())
	last_spawn_was_frozen = board_kind == "mixed" and randf() < 0.24
	_spawn_item(item_id, cell, true, last_spawn_was_frozen)
	_save_board()
	return item_id


func reset_board() -> void:
	if _resolving_action:
		return
	for item: TextureRect in _items.values():
		item.queue_free()
	_items.clear()
	_seed_board()


func get_item_count(item_id: String) -> int:
	var count := 0
	for item: TextureRect in _items.values():
		if item.item_id == item_id:
			count += 1
	return count


func set_discard_target(target: Control) -> void:
	_discard_target = target


func play_completion_clear() -> void:
	var delay := 0.0
	for item: TextureRect in _items.values():
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tween := create_tween().set_parallel(true)
		tween.tween_interval(delay)
		tween.tween_property(item, "position:y", size.y + 220.0, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(item, "rotation", randf_range(-1.4, 1.4), 0.72)
		tween.tween_property(item, "modulate:a", 0.0, 0.62).set_delay(0.25)
		delay += 0.035
	await get_tree().create_timer(0.82 + delay).timeout


func _create_cells() -> void:
	_cells.clear()
	for row in ROWS:
		for column in COLUMNS:
			_cells[Vector2i(column, row)] = true


func _seed_board() -> void:
	if board_kind == "cakes":
		var cake_seeds := {
			"chocolate_bar": [Vector2i(0, 1), Vector2i(1, 1)],
			"strawberry": [Vector2i(3, 1), Vector2i(4, 1)],
			"vanilla_flowers": [Vector2i(1, 5), Vector2i(2, 5)],
			"blueberries": [Vector2i(4, 6), Vector2i(5, 6)],
		}
		for item_id: String in cake_seeds:
			for cell: Vector2i in cake_seeds[item_id]:
				_spawn_item(item_id, cell, true)
		_save_board()
		return
	if board_kind == "cookies":
		var cookie_seeds := {
			"chocolate_chip_cookie": [Vector2i(0, 1), Vector2i(1, 1)],
			"pink_sugar_cookie": [Vector2i(3, 1), Vector2i(4, 1)],
			"sandwich_cookie": [Vector2i(1, 5), Vector2i(2, 5)],
			"lucky_cookie": [Vector2i(4, 6), Vector2i(5, 6)],
		}
		for item_id: String in cookie_seeds:
			for cell: Vector2i in cookie_seeds[item_id]:
				_spawn_item(item_id, cell, true)
		_save_board()
		return
	if board_kind == "ice_cream":
		var frozen_seeds := {"milk_pitcher":Vector2i(0, 2), "chocolate_milk":Vector2i(5, 3), "pistachios":Vector2i(2, 6)}
		var free_seeds := {"milk_pitcher":Vector2i(1, 1), "chocolate_milk":Vector2i(4, 1), "pistachios":Vector2i(3, 5)}
		for item_id: String in frozen_seeds:
			_spawn_item(item_id, frozen_seeds[item_id], true, true)
			_spawn_item(item_id, free_seeds[item_id], true)
		_save_board()
		return
	if board_kind == "mixed":
		var frozen_seeds := {"chocolate_milk":Vector2i(0, 2), "pink_sugar_cookie":Vector2i(5, 2), "vanilla_flowers":Vector2i(1, 6), "apple":Vector2i(4, 6)}
		var free_seeds := {"chocolate_milk":Vector2i(1, 1), "pink_sugar_cookie":Vector2i(4, 1), "vanilla_flowers":Vector2i(2, 5), "apple":Vector2i(3, 5)}
		for item_id: String in frozen_seeds:
			_spawn_item(item_id, frozen_seeds[item_id], true, true)
			_spawn_item(item_id, free_seeds[item_id], true)
		_save_board()
		return
	for cell in [Vector2i(1, 1), Vector2i(3, 1), Vector2i(2, 3), Vector2i(4, 4)]:
		_spawn_item("lemon", cell, true)
	for cell in [Vector2i(1, 6), Vector2i(4, 6)]:
		_spawn_item("orange", cell, true)
	for cell in [Vector2i(0, 4), Vector2i(5, 4)]:
		_spawn_item("apple", cell, true)
	_save_board()


func _ensure_fruit_intro(base_item_id: String, chain_ids: Array) -> void:
	for item: TextureRect in _items.values():
		if item.item_id in chain_ids:
			return
	var empty := _empty_cells()
	var items_to_add := mini(2, empty.size())
	for index in items_to_add:
		_spawn_item(base_item_id, empty[index], true)
	if items_to_add > 0:
		_save_board()


func _ensure_cake_intro(base_item_id: String, chain_ids: Array) -> void:
	_ensure_fruit_intro(base_item_id, chain_ids)


func _spawn_item(item_id: String, cell: Vector2i, animate := false, frozen := false) -> TextureRect:
	if not ITEM_DEFINITIONS.has(item_id) or _items.has(cell):
		return null
	var item: TextureRect = ITEM_SCENE.instantiate()
	var definition: Dictionary = ITEM_DEFINITIONS[item_id]
	item.setup(definition, cell, load(definition.texture))
	item.set_frozen(frozen)
	item.custom_minimum_size = CELL_SIZE - Vector2.ONE * ITEM_INSET * 2.0
	item.size = item.custom_minimum_size
	item.pivot_offset = item.size * 0.5
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	item.drag_started.connect(_on_drag_started)
	item.drag_moved.connect(_on_drag_moved)
	item.drag_ended.connect(_on_drag_ended)
	add_child(item)
	_items[cell] = item
	item.set_home_position(Vector2(cell) * CELL_SIZE + Vector2.ONE * ITEM_INSET)
	if animate:
		item.play_spawn()
	return item


func _on_drag_started(item: TextureRect) -> void:
	if _resolving_action:
		item.dragging = false
		item.return_home()
		return
	_dragged_item = item
	move_child(item, get_child_count() - 1)


func _on_drag_moved(item: TextureRect, screen_position: Vector2) -> void:
	var over_discard := _is_over_discard_target(screen_position)
	if _discard_target:
		_discard_target.modulate = Color(1.35, 0.48, 0.48, 1.0) if over_discard else Color.WHITE
	var target := _screen_to_cell(screen_position)
	_highlighted_cell = target if not over_discard and _is_valid_cell(target) and target != item.cell else Vector2i(-1, -1)
	queue_redraw()


func _on_drag_ended(item: TextureRect, screen_position: Vector2) -> void:
	if _resolving_action:
		item.return_home()
		return
	if _discard_target:
		_discard_target.modulate = Color.WHITE
	var target := _screen_to_cell(screen_position)
	_highlighted_cell = Vector2i(-1, -1)
	_dragged_item = null
	queue_redraw()
	if _is_over_discard_target(screen_position):
		_discard_item(item)
		return
	if not _is_valid_cell(target) or target == item.cell:
		item.return_home()
		return
	if not _items.has(target):
		_move_item(item, target)
		return
	var target_item: TextureRect = _items[target]
	if target_item.item_id == item.item_id and not str(ITEM_DEFINITIONS[item.item_id].next_id).is_empty():
		await _merge_items(item, target_item)
	elif target_item.frozen:
		item.return_home()
	else:
		_swap_items(item, target_item)


func _is_over_discard_target(screen_position: Vector2) -> bool:
	return _discard_target != null and _discard_target.get_global_rect().has_point(screen_position)


func _discard_item(item: TextureRect) -> void:
	var discarded_id: String = str(item.item_id)
	if item.frozen:
		item.return_home()
		return
	_items.erase(item.cell)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(item, "scale", Vector2(0.15, 0.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(item, "modulate:a", 0.0, 0.14)
	tween.chain().tween_callback(item.queue_free)
	_save_board()
	item_discarded.emit(discarded_id)


func _move_item(item: TextureRect, target: Vector2i) -> void:
	_items.erase(item.cell)
	item.cell = target
	_items[target] = item
	item.set_home_position(Vector2(target) * CELL_SIZE + Vector2.ONE * ITEM_INSET, true)
	_save_board()


func _swap_items(item: TextureRect, target_item: TextureRect) -> void:
	var source_cell: Vector2i = item.cell
	var target_cell: Vector2i = target_item.cell
	_items[source_cell] = target_item
	_items[target_cell] = item
	item.cell = target_cell
	target_item.cell = source_cell
	item.set_home_position(Vector2(target_cell) * CELL_SIZE + Vector2.ONE * ITEM_INSET, true)
	target_item.set_home_position(Vector2(source_cell) * CELL_SIZE + Vector2.ONE * ITEM_INSET, true)
	_save_board()


func _merge_items(source: TextureRect, target: TextureRect) -> void:
	if _resolving_action or not is_instance_valid(source) or not is_instance_valid(target):
		return
	_resolving_action = true
	var target_cell: Vector2i = target.cell
	var next_id := str(ITEM_DEFINITIONS[source.item_id].next_id)
	_items.erase(source.cell)
	_items.erase(target.cell)
	var converge := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	converge.tween_property(source, "position", target.position, 0.15)
	converge.tween_property(source, "scale", Vector2(0.58, 0.58), 0.15)
	converge.tween_property(target, "scale", Vector2(0.72, 0.72), 0.15)
	converge.tween_property(source, "modulate:a", 0.35, 0.15)
	converge.tween_property(target, "modulate:a", 0.35, 0.15)
	await converge.finished
	_spawn_merge_sparkles(target.position + target.size * 0.5)
	source.queue_free()
	target.queue_free()
	var merged: TextureRect = _spawn_item(next_id, target_cell, false)
	if merged == null:
		_resolving_action = false
		push_error("Merge result could not spawn in cell %s." % target_cell)
		return
	merged.scale = Vector2(0.55, 0.55)
	merged.modulate.a = 0.0
	var reveal := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(merged, "scale", Vector2.ONE, 0.22)
	reveal.tween_property(merged, "modulate:a", 1.0, 0.12)
	await reveal.finished
	merged.play_merge()
	_save_board()
	item_merged.emit(next_id)
	_resolving_action = false


func _spawn_merge_sparkles(at: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.amount = 18
	particles.lifetime = 0.42
	particles.one_shot = true
	particles.explosiveness = 0.96
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 55.0
	particles.initial_velocity_max = 150.0
	particles.gravity = Vector2(0, 170)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color("fff09a")
	particles.z_index = 120
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free)


func _screen_to_cell(screen_position: Vector2) -> Vector2i:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_position
	return Vector2i(floori(local.x / CELL_SIZE.x), floori(local.y / CELL_SIZE.y))


func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS


func _highlight_color(cell: Vector2i) -> Color:
	if not _items.has(cell):
		return Color("b9e6ce")
	if _dragged_item and _items[cell].item_id == _dragged_item.item_id:
		return Color("ffe18a")
	return Color("f2abb8")


func _cell_color(column: int, row: int) -> Color:
	if board_kind == "cakes":
		return Color("eee5ff") if (column + row) % 2 == 0 else Color("d9c8f2")
	if board_kind == "cookies":
		return Color("effbea") if (column + row) % 2 == 0 else Color("d2edc9")
	if board_kind == "ice_cream":
		return Color("effcff") if (column + row) % 2 == 0 else Color("cfeff4")
	if board_kind == "mixed":
		return Color("fff2ec") if (column + row) % 2 == 0 else Color("dcecf5")
	return Color("fff4df") if (column + row) % 2 == 0 else Color("f8e2c7")


func _save_section() -> String:
	return "mixed_merge_board" if board_kind == "mixed" else ("ice_cream_merge_board" if board_kind == "ice_cream" else ("cookie_merge_board" if board_kind == "cookies" else ("cake_merge_board" if board_kind == "cakes" else "merge_board")))


func _cell_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color("ffffffb0")
	return style


func _empty_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _cells:
		if not _items.has(cell):
			result.append(cell)
	return result


func _save_board() -> void:
	if not persistence_enabled:
		return
	var records: Array = []
	for cell: Vector2i in _items:
		var item: TextureRect = _items[cell]
		records.append({"item_id": item.item_id, "column": cell.x, "row": cell.y, "frozen": item.frozen})
	SaveSystem.set_value(_save_section(), "items", records)
	board_changed.emit()


func _load_board() -> void:
	if not persistence_enabled:
		return
	var records: Variant = SaveSystem.get_value(_save_section(), "items", [])
	if not records is Array:
		return
	for record: Variant in records:
		if record is Dictionary:
			_spawn_item(str(record.get("item_id", "lemon")), Vector2i(int(record.get("column", 0)), int(record.get("row", 0))), false, bool(record.get("frozen", false)))

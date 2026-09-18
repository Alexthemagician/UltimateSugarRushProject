extends Control
class_name MergeBoard

signal board_changed
signal item_merged(item_id: String)
signal item_discarded(item_id: String)

const COLUMNS := 10
const ROWS := 6
const CELL_SIZE := Vector2(158, 158)
const ITEM_INSET := 2.0
const ITEM_SCENE := preload("res://scenes/merge/merge_item.tscn")
const SPAWNABLE_FRUITS := ["lemon", "orange", "apple"]
const SPAWNABLE_CAKE_INGREDIENTS := ["chocolate_bar", "strawberry", "vanilla_flowers", "blueberries"]
const SPAWNABLE_COOKIES := ["chocolate_chip_cookie", "pink_sugar_cookie", "sandwich_cookie", "lucky_cookie"]
const SPAWNABLE_ICE_CREAM_BASES := ["milk_pitcher", "chocolate_milk", "pistachios"]
const SPAWNABLE_MIXED_BASES := ["chocolate_milk", "pink_sugar_cookie", "vanilla_flowers", "apple"]

@export_enum("drinks", "cakes", "cookies", "ice_cream", "mixed") var board_kind := "drinks"
@export var regional_mode := false

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
var regional_definitions := {}
var regional_pool: Array = []
var selected_ingredients: Array[String] = []
var regional_objective_ids: Array[String] = []
var regional_objective_names := {}


func _ready() -> void:
	if regional_mode:
		_build_regional_items()
	custom_minimum_size = Vector2(COLUMNS * CELL_SIZE.x, ROWS * CELL_SIZE.y)
	_create_cells()
	_load_board()
	if _items.is_empty():
		_seed_board()
	elif regional_mode:
		queue_redraw()
		return
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


func add_random_fruit_burst(origin_global: Vector2, requested_count := 5) -> Array[String]:
	return add_random_base_items_burst(origin_global, requested_count)


func add_random_base_item() -> String:
	var empty := _empty_cells()
	if empty.is_empty():
		return ""
	var cell: Vector2i = empty.pick_random()
	var pool := _spawn_pool()
	var item_id := str(pool.pick_random())
	last_spawn_was_frozen = board_kind == "mixed" and randf() < 0.24
	_spawn_item(item_id, cell, true, last_spawn_was_frozen)
	_save_board()
	return item_id


func add_random_base_items_burst(origin_global: Vector2, requested_count := 5) -> Array[String]:
	var spawned: Array[String] = []
	var available := _empty_cells().size()
	var count := mini(requested_count, available)
	if count <= 0:
		return spawned
	var local_origin := get_global_transform_with_canvas().affine_inverse() * origin_global
	_spawn_party_cannon(local_origin)
	for index in count:
		var empty := _empty_cells()
		if empty.is_empty():
			break
		var cell: Vector2i = empty.pick_random()
		var item_id := str(_spawn_pool().pick_random())
		last_spawn_was_frozen = board_kind == "mixed" and randf() < 0.24
		var item := _spawn_item(item_id, cell, false, last_spawn_was_frozen)
		if item == null:
			continue
		_play_party_cannon_item(item, local_origin, index, count)
		spawned.append(item_id)
	_save_board()
	return spawned


func reset_board() -> void:
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
	if regional_mode:
		var cells := [Vector2i(0,1),Vector2i(1,1),Vector2i(3,1),Vector2i(4,1),Vector2i(1,4),Vector2i(2,4),Vector2i(7,4),Vector2i(8,4)]
		for index in cells.size():
			var frozen := CafeProgress.stage >= 3 and index%3 == 0
			_spawn_item(regional_pool[(index/2)%regional_pool.size()],cells[index],true,frozen)
		_save_board()
		return
	if board_kind == "cakes":
		var cake_seeds := {
			"chocolate_bar": [Vector2i(0, 1), Vector2i(1, 1)],
			"strawberry": [Vector2i(3, 1), Vector2i(4, 1)],
			"vanilla_flowers": [Vector2i(1, 5), Vector2i(2, 5)],
			"blueberries": [Vector2i(8, 4), Vector2i(9, 4)],
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
			"lucky_cookie": [Vector2i(8, 4), Vector2i(9, 4)],
		}
		for item_id: String in cookie_seeds:
			for cell: Vector2i in cookie_seeds[item_id]:
				_spawn_item(item_id, cell, true)
		_save_board()
		return
	if board_kind == "ice_cream":
		var frozen_seeds := {"milk_pitcher":Vector2i(0, 2), "chocolate_milk":Vector2i(5, 3), "pistachios":Vector2i(7, 4)}
		var free_seeds := {"milk_pitcher":Vector2i(1, 1), "chocolate_milk":Vector2i(4, 1), "pistachios":Vector2i(3, 5)}
		for item_id: String in frozen_seeds:
			_spawn_item(item_id, frozen_seeds[item_id], true, true)
			_spawn_item(item_id, free_seeds[item_id], true)
		_save_board()
		return
	if board_kind == "mixed":
		var frozen_seeds := {"chocolate_milk":Vector2i(0, 2), "pink_sugar_cookie":Vector2i(5, 2), "vanilla_flowers":Vector2i(6, 4), "apple":Vector2i(8, 4)}
		var free_seeds := {"chocolate_milk":Vector2i(1, 1), "pink_sugar_cookie":Vector2i(4, 1), "vanilla_flowers":Vector2i(2, 5), "apple":Vector2i(3, 5)}
		for item_id: String in frozen_seeds:
			_spawn_item(item_id, frozen_seeds[item_id], true, true)
			_spawn_item(item_id, free_seeds[item_id], true)
		_save_board()
		return
	for cell in [Vector2i(1, 1), Vector2i(3, 1), Vector2i(2, 3), Vector2i(4, 4)]:
		_spawn_item("lemon", cell, true)
	for cell in [Vector2i(6, 4), Vector2i(8, 4)]:
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
	var definitions := _item_definitions()
	if not definitions.has(item_id) or _items.has(cell):
		return null
	var item: TextureRect = ITEM_SCENE.instantiate()
	var definition: Dictionary = definitions[item_id]
	var texture_value: Variant = definition.texture
	var texture: Texture2D = load(texture_value) if texture_value is String else texture_value
	item.setup(definition, cell, texture)
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
	_decorate_item(item, definition)
	_items[cell] = item
	item.set_home_position(Vector2(cell) * CELL_SIZE + Vector2.ONE * ITEM_INSET)
	if animate:
		item.play_spawn()
		_spawn_item_burst(cell)
	return item


func _on_drag_started(item: TextureRect) -> void:
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
	if target_item.item_id == item.item_id and not str(_item_definitions()[item.item_id].next_id).is_empty():
		_merge_items(item, target_item)
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
	if not is_instance_valid(source) or not is_instance_valid(target):
		return
	var target_cell: Vector2i = target.cell
	var next_id := str(_item_definitions()[source.item_id].next_id)
	_items.erase(source.cell)
	_items.erase(target.cell)
	# Commit the merge result before playing its decoration. This keeps the board
	# interactive so another item can be moved as soon as the drop is accepted.
	source.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var merged: TextureRect = _spawn_item(next_id, target_cell, false)
	if merged == null:
		push_error("Merge result could not spawn in cell %s." % target_cell)
		return
	merged.scale = Vector2(0.55, 0.55)
	merged.modulate.a = 0.0
	var converge := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	converge.tween_property(source, "position", target.position, 0.15)
	converge.tween_property(source, "scale", Vector2(0.58, 0.58), 0.15)
	converge.tween_property(target, "scale", Vector2(0.72, 0.72), 0.15)
	converge.tween_property(source, "modulate:a", 0.35, 0.15)
	converge.tween_property(target, "modulate:a", 0.35, 0.15)
	converge.finished.connect(func() -> void:
		if is_instance_valid(target): _spawn_merge_sparkles(target.position + target.size * 0.5)
		if is_instance_valid(source): source.queue_free()
		if is_instance_valid(target): target.queue_free()
	)
	var reveal := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(merged, "scale", Vector2.ONE, 0.22)
	reveal.tween_property(merged, "modulate:a", 1.0, 0.12)
	reveal.finished.connect(func() -> void:
		if is_instance_valid(merged): merged.play_merge()
	)
	_save_board()
	item_merged.emit(next_id)


func _spawn_item_burst(cell: Vector2i) -> void:
	var particles := CPUParticles2D.new()
	particles.position = Vector2(cell) * CELL_SIZE + CELL_SIZE * 0.5
	particles.amount = 12
	particles.lifetime = 0.30
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 45.0
	particles.initial_velocity_max = 105.0
	particles.gravity = Vector2(0, 135)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5
	particles.color = Color("fff2a6")
	particles.z_index = 110
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(0.45).timeout.connect(particles.queue_free)


func _spawn_party_cannon(origin: Vector2) -> void:
	_spawn_impact_flash(origin)


func _spawn_impact_flash(origin: Vector2) -> void:
	var flash := Polygon2D.new()
	var points := PackedVector2Array()
	for index in 20:
		var radius := 54.0 if index % 2 == 0 else 19.0
		points.append(Vector2.RIGHT.rotated(float(index) * TAU / 20.0) * radius)
	flash.polygon = points
	flash.position = origin
	flash.color = Color("fff3a8")
	flash.z_index = 175
	add_child(flash)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.65, 1.65), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.20)
	tween.chain().tween_callback(flash.queue_free)


func _play_party_cannon_item(item: TextureRect, origin: Vector2, index: int, count: int) -> void:
	var destination := item.position
	var target_center := destination + item.size * 0.5
	var fan := (float(index) - float(count - 1) * 0.5) * 52.0
	var control := origin.lerp(target_center, 0.46) + Vector2(fan, -190.0 - absf(fan) * 0.28)
	item.position = origin - item.size * 0.5
	item.scale = Vector2(0.22, 0.22)
	item.modulate.a = 1.0
	item.rotation = randf_range(-0.55, 0.55)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.z_index = 150 + index
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_party_item_progress.bind(item, origin, control, target_center), 0.0, 1.0, 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "rotation", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if not is_instance_valid(item): return
		item.position = destination
		item.z_index = 2
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		_spawn_item_burst(item.cell)
	)


func _set_party_item_progress(progress: float, item: TextureRect, origin: Vector2, control: Vector2, destination: Vector2) -> void:
	if not is_instance_valid(item):
		return
	var inverse := 1.0 - progress
	var center := inverse * inverse * origin + 2.0 * inverse * progress * control + progress * progress * destination
	item.position = center - item.size * 0.5


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
	if regional_mode:
		var colors := [Color("eff9e8"),Color("d8efd2")] if CafeProgress.region==1 else [Color("f3eafa"),Color("dfd1ef")]
		return colors[(column+row)%2]
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
	if regional_mode:
		return "regional_merge_board_%d_%d" % [CafeProgress.region,CafeProgress.stage]
	return "mixed_merge_board" if board_kind == "mixed" else ("ice_cream_merge_board" if board_kind == "ice_cream" else ("cookie_merge_board" if board_kind == "cookies" else ("cake_merge_board" if board_kind == "cakes" else "merge_board")))


func _item_definitions() -> Dictionary:
	if regional_mode:
		return regional_definitions
	return ITEM_DEFINITIONS


func _spawn_pool() -> Array:
	if regional_mode:
		return regional_pool
	return SPAWNABLE_MIXED_BASES if board_kind == "mixed" else (SPAWNABLE_ICE_CREAM_BASES if board_kind == "ice_cream" else (SPAWNABLE_CAKE_INGREDIENTS if board_kind == "cakes" else (SPAWNABLE_COOKIES if board_kind == "cookies" else SPAWNABLE_FRUITS)))


func _decorate_item(item: TextureRect, definition: Dictionary) -> void:
	if not regional_mode:
		return
	var badge := Label.new()
	badge.text = ["I","II","III","IV"][int(definition.level)-1]
	badge.position = Vector2(10,8)
	badge.size = Vector2(48,36)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size",20)
	badge.add_theme_color_override("font_color",Color.WHITE)
	badge.add_theme_color_override("font_shadow_color",Color("4b2940"))
	badge.add_theme_constant_override("shadow_offset_x",2)
	badge.add_theme_constant_override("shadow_offset_y",2)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(badge)


func _build_regional_items() -> void:
	if CafeProgress.region == 1 and CafeProgress.stage < 4:
		_build_honeydew_items()
		return
	if CafeProgress.region == 2 and CafeProgress.stage < 4:
		_build_cocoa_items()
		return
	var pool: Array = CafeProgress.POOLS[CafeProgress.region]
	for offset in 4:
		var ingredient_id: String = pool[(CafeProgress.stage + offset) % pool.size()]
		selected_ingredients.append(ingredient_id)
		regional_pool.append(regional_chain_id(ingredient_id,1))
		for level in range(1,5):
			var item_id := regional_chain_id(ingredient_id,level)
			regional_definitions[item_id] = {"id":item_id,"name":"%s %s" % [CafeProgress.INGREDIENTS[ingredient_id],["Sprig","Bundle","Basket","Crate"][level-1]],"level":level,"next_id":regional_chain_id(ingredient_id,level+1) if level<4 else "","texture":regional_ingredient_texture(ingredient_id)}
		regional_objective_ids.append(regional_chain_id(ingredient_id,4))
		regional_objective_names[regional_chain_id(ingredient_id,4)] = CafeProgress.INGREDIENTS[ingredient_id]


func _build_honeydew_items() -> void:
	var boards := [
		[
			{"id":"cherry","name":"Cherry","levels":["fruit","crushed_bowl","pie","grand_dessert"],"names":["Cherries","Crushed Cherries","Crosshatch Cherry Pie","Ribbon Cherry Roll"]},
			{"id":"raspberry","name":"Raspberry","levels":["fruit","crushed_bowl","pie","grand_dessert"],"names":["Raspberries","Crushed Raspberries","Raspberry Pie","Frosted Raspberry Tarte"]},
			{"id":"blueberry","name":"Blueberry","levels":["fruit","crushed_bowl","pie","grand_dessert"],"names":["Blueberries","Crushed Blueberries","Blueberry Pie","Ribbon Blueberry Roll"]},
		],
		[
			{"id":"neapolitan","name":"Neapolitan","levels":["scoop","sandwich","sundae","grand_sundae"]},
			{"id":"cookies_cream","name":"Cookies & Cream","levels":["scoop","sandwich","sundae","grand_sundae"]},
			{"id":"mint_chip","name":"Mint Chip","levels":["scoop","sandwich","sundae","grand_sundae"]},
			{"id":"raspberry_swirl","name":"Raspberry Swirl","levels":["scoop","sandwich","sundae","grand_sundae"]},
		],
		[
			{"id":"matcha","name":"Matcha","levels":["flour_cup","mixing_bowl","cupcake","layer_cake"]},
			{"id":"tiramisu","name":"Tiramisu","levels":["flour_cup","mixing_bowl","cupcake","layer_cake"]},
			{"id":"coconut","name":"Coconut","levels":["flour_cup","mixing_bowl","cupcake","layer_cake"]},
			{"id":"oat","name":"Oat","levels":["flour_cup","mixing_bowl","cupcake","layer_cake"]},
		],
		[
			{"id":"peach","name":"Peach Boba","levels":["fruit","drink","boba","grand_boba"]},
			{"id":"mango","name":"Mango Boba","levels":["fruit","drink","boba","grand_boba"]},
			{"id":"honeydew","name":"Honeydew Boba","levels":["fruit","drink","boba","grand_boba"]},
			{"id":"taro","name":"Taro Boba","levels":["fruit","drink","boba","grand_boba"]},
			{"id":"pumpkin","name":"Pumpkin Coffee","levels":["small_syrup","syrup_jug","accent_coffee"]},
			{"id":"honey","name":"Honey Coffee","levels":["small_syrup","syrup_jug","accent_coffee"]},
			{"id":"coffee","name":"Coffee","levels":["small_syrup","syrup_jug","accent_coffee"]},
			{"id":"caramel","name":"Caramel Coffee","levels":["small_syrup","syrup_jug","accent_coffee"]},
		],
	]
	var chains: Array = boards[CafeProgress.stage]
	for chain: Dictionary in chains:
		var chain_id: String = chain.id
		selected_ingredients.append(chain_id)
		regional_pool.append(regional_chain_id(chain_id,1))
		var levels: Array = chain.levels
		for level_index in levels.size():
			var level := level_index+1
			var item_id := regional_chain_id(chain_id,level)
			var display_names: Array = chain.get("names",[])
			var item_name := str(display_names[level_index]) if level_index<display_names.size() else "%s %s" % [chain.name,str(levels[level_index]).replace("_"," ").capitalize()]
			regional_definitions[item_id] = {"id":item_id,"name":item_name,"level":level,"next_id":regional_chain_id(chain_id,level+1) if level<levels.size() else "","texture":load("res://assets/honeydew/items/board%d_%s_%s.png" % [CafeProgress.stage+1,chain_id,levels[level_index]])}
		var objective_id := regional_chain_id(chain_id,levels.size())
		regional_objective_ids.append(objective_id)
		regional_objective_names[objective_id] = chain.name


func _build_cocoa_items() -> void:
	var boards := [
		[
			{"id":"watermelon","name":"Watermelon Pitcher","levels":["fruit","juice","fancy_juice","pitcher"]},
			{"id":"pineapple","name":"Pineapple Pitcher","levels":["fruit","juice","fancy_juice","pitcher"]},
			{"id":"grape","name":"Grape Pitcher","levels":["fruit","juice","fancy_juice","pitcher"]},
		],
		[
			{"id":"rose","name":"Rose Ice-cream Macaron","levels":["cream_swirl","cream_bowl","macaron","ice_cream_macaron"]},
			{"id":"passion_fruit","name":"Passion Fruit Ice-cream Macaron","levels":["cream_swirl","cream_bowl","macaron","ice_cream_macaron"]},
			{"id":"kiwi","name":"Kiwi Ice-cream Macaron","levels":["cream_swirl","cream_bowl","macaron","ice_cream_macaron"]},
			{"id":"lychee","name":"Lychee Ice-cream Macaron","levels":["cream_swirl","cream_bowl","macaron","ice_cream_macaron"]},
		],
		[
			{"id":"strawberry_star","name":"Strawberry Star Chocolate Box","levels":["single","trio","small_box","large_box"]},
			{"id":"almond_square","name":"Almond Dark Chocolate Box","levels":["single","trio","small_box","large_box"]},
			{"id":"raspberry_heart","name":"Raspberry White Chocolate Box","levels":["single","trio","small_box","large_box"]},
			{"id":"caramel_flower","name":"Caramel Flower Chocolate Box","levels":["single","trio","small_box","large_box"]},
		],
		[
			{"id":"blueberry_lavender","name":"Blueberry Lavender Cotton Candy","levels":["sugar_cube","spun_sugar","small_cotton_candy","grand_cotton_candy"]},
			{"id":"strawberry_cream","name":"Strawberry Cream Cotton Candy","levels":["sugar_cube","spun_sugar","small_cotton_candy","grand_cotton_candy"]},
			{"id":"apple_cinnamon","name":"Apple Cinnamon Cotton Candy","levels":["sugar_cube","spun_sugar","small_cotton_candy","grand_cotton_candy"]},
			{"id":"honey_lemon","name":"Honey Lemon Cotton Candy","levels":["sugar_cube","spun_sugar","small_cotton_candy","grand_cotton_candy"]},
		],
	]
	var chains: Array = boards[CafeProgress.stage]
	for chain: Dictionary in chains:
		var chain_id: String = chain.id
		selected_ingredients.append(chain_id)
		regional_pool.append(regional_chain_id(chain_id,1))
		var levels: Array = chain.levels
		for level_index in levels.size():
			var level := level_index+1
			var item_id := regional_chain_id(chain_id,level)
			regional_definitions[item_id] = {"id":item_id,"name":"%s %s" % [chain.name,str(levels[level_index]).replace("_"," ").capitalize()],"level":level,"next_id":regional_chain_id(chain_id,level+1) if level<levels.size() else "","texture":load("res://assets/cocoa/items/board%d_%s_%s.png" % [CafeProgress.stage+1,chain_id,levels[level_index]])}
		var objective_id := regional_chain_id(chain_id,levels.size())
		regional_objective_ids.append(objective_id)
		regional_objective_names[objective_id] = chain.name


func regional_chain_id(ingredient_id: String, level: int) -> String:
	return "regional_%s_%d" % [ingredient_id,level]


func regional_ingredient_texture(ingredient_id: String) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/cafe/stock_atlas.png")
	var index := CafeProgress.INGREDIENTS.keys().find(ingredient_id)
	var tile := Vector2(texture.atlas.get_width()/6.0,texture.atlas.get_height()/4.0)
	texture.region = Rect2(Vector2(index%6,index/6)*tile,tile)
	texture.filter_clip = true
	return texture


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
	SaveSystem.set_value(_save_section(), "columns", COLUMNS)
	board_changed.emit()


func _load_board() -> void:
	if not persistence_enabled:
		return
	var records: Variant = SaveSystem.get_value(_save_section(), "items", [])
	if not records is Array:
		return
	for record: Variant in records:
		if record is Dictionary:
			var old_columns := int(SaveSystem.get_value(_save_section(), "columns", 6))
			var slot := int(record.get("row", 0)) * old_columns + int(record.get("column", 0))
			var cell := Vector2i(slot % COLUMNS, slot / COLUMNS)
			_spawn_item(str(record.get("item_id", "lemon")), cell, false, bool(record.get("frozen", false)))

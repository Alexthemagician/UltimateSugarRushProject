class_name MatchThreeBoard
extends Control

signal objective_changed(kind: int, amount: int)
signal large_match_created(position: Vector2i)
signal move_finished

enum Candy { RED, GREEN, GOLD, BLUE }
enum Special { NONE, ROW, COLUMN, FLYER, BOMB, TARGET }

const ROWS := 8
const COLS := 8
const COLORS := 4
const CELL_PITCH := 112.0
const ITEM_SCENE := preload("res://scenes/merge/merge_item.tscn")
const DEFAULT_TEXTURES := [
	preload("res://assets/match3/red_round_candy.png"),
	preload("res://assets/match3/green_hard_candy.png"),
	preload("res://assets/match3/gold_butterscotch.png"),
	preload("res://assets/match3/blue_heart_candy.png"),
]
const SPECIAL_TEXTURES := [
	null,
	preload("res://assets/match3/double_ended_rocket.png"),
	preload("res://assets/match3/double_ended_rocket.png"),
	preload("res://assets/match3/flying_rocket.png"),
	preload("res://assets/match3/candy_bomb.png"),
	preload("res://assets/match3/disco_ball.png"),
]

var cells: Array = []
var buttons: Array[Button] = []
var candy_items: Array[MergeItem] = []
var selected := Vector2i(-1, -1)
var busy := false
var power_busy := false
var rng := RandomNumberGenerator.new()
var candy_bag: Array[int] = []
var drag_source := Vector2i(-1, -1)
var drag_target := Vector2i(-1, -1)
var drag_origin := Vector2.ZERO
var drag_last := Vector2.ZERO
var drag_preview: TextureRect
var interaction_enabled := true
var piece_textures: Array[Texture2D] = []
var locked_cells: Dictionary = {}
var lock_overlays: Dictionary = {}
var initial_locks: Array[Vector2i] = []
var shift_bottom_each_move := false
var blocker_style := "cage"
var objective_targets: Array[Control] = []
var collection_starts: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	piece_textures.assign(DEFAULT_TEXTURES)
	for kind in [Candy.GREEN, Candy.GOLD]:
		piece_textures[kind] = CandyCutout.clean(DEFAULT_TEXTURES[kind])
	_build_buttons()
	reset_board()


func configure(textures: Array[Texture2D], lock_positions: Array[Vector2i] = [], shift_bottom := false) -> void:
	piece_textures.assign(textures)
	initial_locks = lock_positions.duplicate()
	shift_bottom_each_move = shift_bottom
	reset_board()


func reset_board() -> void:
	selected = Vector2i(-1, -1)
	power_busy = false
	candy_bag.clear()
	_clear_lock_overlays()
	locked_cells.clear()
	cells.clear()
	for y in ROWS:
		var row: Array = []
		for x in COLS:
			var kind := _next_random_kind()
			while (x >= 2 and int(row[x - 1].kind) == kind and int(row[x - 2].kind) == kind) or (y >= 2 and int(cells[y - 1][x].kind) == kind and int(cells[y - 2][x].kind) == kind) or (x >= 1 and y >= 1 and int(row[x - 1].kind) == kind and int(cells[y - 1][x].kind) == kind and int(cells[y - 1][x - 1].kind) == kind):
				kind = _next_random_kind()
			row.append({"kind": kind, "special": Special.NONE})
		cells.append(row)
	_ensure_candy_items()
	for pos: Vector2i in initial_locks:
		if pos.x >= 0 and pos.x < COLS and pos.y >= 0 and pos.y < ROWS:
			locked_cells[pos] = true
			_create_lock_overlay(pos)
	_refresh()
	call_deferred("_verify_initial_board")


func _verify_initial_board() -> void:
	if busy or not is_inside_tree():
		return
	busy = true
	await _ensure_playable_board()
	busy = false


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not enabled:
		selected = Vector2i(-1, -1)
		_refresh()


func set_objective_targets(targets: Array[Control]) -> void:
	# Keep the live controls, not positions sampled during _ready(). Containers do
	# their final layout afterward and early positions all collapse to one corner.
	objective_targets = targets.duplicate()
	for kind in mini(targets.size(), piece_textures.size()):
		if targets[kind] is TextureRect:
			targets[kind].texture = piece_textures[kind]


func _next_random_kind() -> int:
	if candy_bag.is_empty():
		for kind in COLORS:
			for _copy_index in 5:
				candy_bag.append(kind)
		for index in range(candy_bag.size() - 1, 0, -1):
			var swap_index := rng.randi_range(0, index)
			var value := candy_bag[index]
			candy_bag[index] = candy_bag[swap_index]
			candy_bag[swap_index] = value
	return candy_bag.pop_back()


func _ensure_candy_items() -> void:
	while candy_items.size() < ROWS * COLS:
		var index := candy_items.size()
		var pos := Vector2i(index % COLS, index / COLS)
		var item: MergeItem = ITEM_SCENE.instantiate()
		item.setup({"id": str(index), "level": 1, "name": "Candy"}, pos, piece_textures[0])
		item.custom_minimum_size = Vector2(96, 96)
		item.size = item.custom_minimum_size
		item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		item.drag_started.connect(_on_candy_drag_started)
		item.drag_moved.connect(_on_candy_drag_moved)
		item.drag_ended.connect(_on_candy_drag_ended)
		add_child(item)
		candy_items.append(item)
		_set_item_home(item, pos, false)


func _set_item_home(item: MergeItem, pos: Vector2i, animated: bool) -> void:
	item.cell = pos
	item.set_home_position(buttons[pos.y * COLS + pos.x].position + Vector2(6, 6), animated)


func _on_candy_drag_started(item: MergeItem) -> void:
	var is_power := _is_power_cell(item.cell)
	if not interaction_enabled or locked_cells.has(item.cell) or power_busy or (busy and not is_power):
		item.dragging = false
		item.return_home()
		return
	move_child(item, get_child_count() - 1)


func _on_candy_drag_moved(item: MergeItem, screen_position: Vector2) -> void:
	drag_source = item.cell
	drag_target = _cell_at_global(screen_position)
	_highlight_drop_target()


func _on_candy_drag_ended(item: MergeItem, screen_position: Vector2) -> void:
	var source := item.cell
	var target := _cell_at_global(screen_position)
	drag_source = Vector2i(-1, -1)
	drag_target = Vector2i(-1, -1)
	_refresh_highlights()
	if target == source and _is_power_cell(source):
		_request_power_activation(source)
		return
	if busy:
		item.return_home()
		return
	if not _adjacent(source, target):
		item.return_home()
		return
	await _try_item_swap(item, source, target)


func _tap_target_kind(pos: Vector2i) -> int:
	var candidates: Array[int] = []
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var nearby: Vector2i = pos + offset
		if nearby.x >= 0 and nearby.x < COLS and nearby.y >= 0 and nearby.y < ROWS:
			if int(cells[nearby.y][nearby.x].special) == Special.NONE:
				candidates.append(int(cells[nearby.y][nearby.x].kind))
	return candidates.pick_random() if not candidates.is_empty() else int(cells[pos.y][pos.x].kind)


func _try_item_swap(dragged: MergeItem, a: Vector2i, b: Vector2i) -> void:
	if locked_cells.has(a) or locked_cells.has(b):
		dragged.return_home()
		return
	busy = true
	_swap(a, b)
	var special_pos := b if int(cells[b.y][b.x].special) != Special.NONE else (a if int(cells[a.y][a.x].special) != Special.NONE else Vector2i(-1, -1))
	var activates_special := special_pos.x >= 0
	var valid := activates_special or _has_match()
	_swap(a, b)
	if not valid:
		# Complete the attempted exchange visually, then reverse it. Returning only
		# the dragged candy made invalid moves look like a dropped UI icon rather
		# than the elastic swap-back used by polished match-three games.
		var b_index := b.y * COLS + b.x
		var displaced: MergeItem = candy_items[b_index]
		_set_item_home(dragged, b, true)
		_set_item_home(displaced, a, true)
		await get_tree().create_timer(0.16).timeout
		_set_item_home(dragged, a, true)
		_set_item_home(displaced, b, true)
		await get_tree().create_timer(0.18).timeout
		busy = false
		return
	var a_index := a.y * COLS + a.x
	var b_index := b.y * COLS + b.x
	var displaced: MergeItem = candy_items[b_index]
	_set_item_home(dragged, b, true)
	_set_item_home(displaced, a, true)
	await get_tree().create_timer(0.23).timeout
	_swap(a, b)
	candy_items[a_index] = displaced
	candy_items[b_index] = dragged
	_refresh()
	if activates_special:
		await _activate_swapped_special(a,b,special_pos)
	else:
		await _resolve_cascades(b)
	await _after_completed_move()
	busy = false
	move_finished.emit()


func _refresh_highlights() -> void:
	for button: Button in buttons:
		button.modulate = Color.WHITE


func play_completion_clear() -> void:
	busy = true
	var delay := 0.0
	for item: MergeItem in candy_items:
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tween := create_tween().set_parallel(true)
		tween.tween_interval(delay)
		tween.tween_property(item, "position:y", size.y + 180.0, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(item, "rotation", randf_range(-1.2, 1.2), 0.72)
		tween.tween_property(item, "modulate:a", 0.0, 0.62).set_delay(0.22)
		delay += 0.02
	await get_tree().create_timer(0.82 + delay).timeout


func _build_buttons() -> void:
	var cell_style := StyleBoxFlat.new()
	cell_style.bg_color = Color("fff9ff")
	cell_style.border_color = Color("c99bd8")
	cell_style.set_border_width_all(3)
	cell_style.set_corner_radius_all(12)
	var hover_style := cell_style.duplicate()
	hover_style.bg_color = Color("fff1c9")
	hover_style.border_color = Color("ef709c")
	for index in ROWS * COLS:
		var button := Button.new()
		button.position = Vector2(index % COLS, index / COLS) * CELL_PITCH
		button.size = Vector2(107, 107)
		button.custom_minimum_size = button.size
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 92)
		button.add_theme_stylebox_override("normal", cell_style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", hover_style)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_theme_font_size_override("font_size", 29)
		add_child(button)
		buttons.append(button)


func _board_gui_input(event: InputEvent) -> void:
	if busy or not interaction_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var global_point: Vector2 = get_global_transform() * event.position
		if event.pressed:
			_begin_drag(_cell_at_global(global_point), global_point)
		else:
			await _finish_drag(global_point)
		accept_event()
	elif event is InputEventMouseMotion and drag_source.x >= 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_update_drag(get_global_transform() * event.position)
		accept_event()
	elif event is InputEventScreenTouch:
		var global_point: Vector2 = get_global_transform() * event.position
		if event.pressed:
			_begin_drag(_cell_at_global(global_point), global_point)
		else:
			await _finish_drag(global_point)
		accept_event()
	elif event is InputEventScreenDrag and drag_source.x >= 0:
		_update_drag(get_global_transform() * event.position)
		accept_event()


func _begin_drag(pos: Vector2i, global_point: Vector2) -> void:
	if pos.x < 0 or locked_cells.has(pos):
		return
	drag_source = pos
	drag_target = Vector2i(-1, -1)
	drag_origin = global_point
	drag_last = global_point


func _update_drag(global_point: Vector2) -> void:
	if drag_preview == null and global_point.distance_to(drag_origin) < 12.0:
		return
	if drag_preview == null:
		drag_preview = TextureRect.new()
		drag_preview.texture = piece_textures[int(cells[drag_source.y][drag_source.x].kind)]
		drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drag_preview.size = buttons[0].size * 1.12
		drag_preview.z_index = 50
		add_child(drag_preview)
		buttons[drag_source.y * COLS + drag_source.x].modulate.a = 0.3
	var movement := global_point - drag_last
	drag_last = global_point
	drag_preview.position = _global_to_board(global_point) - drag_preview.size * 0.5
	drag_preview.rotation = clampf(movement.x * 0.006, -0.12, 0.12)
	drag_preview.scale = Vector2(1.08, 1.08)
	drag_target = _cell_at_global(global_point)
	_highlight_drop_target()


func _finish_drag(global_point: Vector2) -> void:
	if drag_source.x < 0:
		return
	var source := drag_source
	var target := _cell_at_global(global_point)
	var was_dragging := drag_preview != null
	if was_dragging and _adjacent(source, target):
		drag_source = Vector2i(-1, -1)
		drag_target = Vector2i(-1, -1)
		await _try_swap(source, target, true)
		return
	if was_dragging:
		var destination := buttons[source.y * COLS + source.x].global_position + buttons[0].size * 0.5
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(drag_preview, "rotation", 0.0, 0.14)
		tween.parallel().tween_property(drag_preview, "scale", Vector2.ONE, 0.14)
		tween.tween_property(drag_preview, "position", _global_to_board(destination) - drag_preview.size * 0.5, 0.14)
		await tween.finished
		drag_preview.queue_free()
		drag_preview = null
	buttons[source.y * COLS + source.x].modulate = Color.WHITE
	drag_source = Vector2i(-1, -1)
	drag_target = Vector2i(-1, -1)
	_refresh()
	if not was_dragging:
		await _cell_pressed(source)


func _cell_at_global(global_point: Vector2) -> Vector2i:
	for index in buttons.size():
		if buttons[index].get_global_rect().has_point(global_point):
			return Vector2i(index % COLS, index / COLS)
	return Vector2i(-1, -1)


func _global_to_board(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return b.x >= 0 and not locked_cells.has(a) and not locked_cells.has(b) and absi(a.x - b.x) + absi(a.y - b.y) == 1


func _highlight_drop_target() -> void:
	for index in buttons.size():
		var pos := Vector2i(index % COLS, index / COLS)
		if pos == drag_target and _adjacent(drag_source, pos):
			buttons[index].modulate = Color(1.35, 1.35, 0.85)
		elif pos != drag_source:
			buttons[index].modulate = Color.WHITE


func _cell_pressed(pos: Vector2i) -> void:
	if not interaction_enabled or power_busy:
		return
	if busy:
		if _is_power_cell(pos):
			_request_power_activation(pos)
		return
	if locked_cells.has(pos):
		_animate_locked_nudge(pos)
		return
	if selected.x < 0:
		selected = pos
		_refresh()
		return
	if selected == pos:
		selected = Vector2i(-1, -1)
		_refresh()
		return
	if absi(selected.x - pos.x) + absi(selected.y - pos.y) != 1:
		selected = pos
		_refresh()
		return
	var first := selected
	selected = Vector2i(-1, -1)
	await _try_swap(first, pos)


func _is_power_cell(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < COLS and pos.y >= 0 and pos.y < ROWS and cells[pos.y][pos.x] != null and int(cells[pos.y][pos.x].special) != Special.NONE


func _request_power_activation(pos: Vector2i) -> void:
	if power_busy or not _is_power_cell(pos):
		return
	power_busy = true
	# Store the request on the candy data itself. Gravity moves this dictionary,
	# so a power-up tapped during a refill is still the one that activates after
	# the current board mutation finishes.
	cells[pos.y][pos.x]["activation_queued"] = true
	var item: MergeItem = candy_items[pos.y * COLS + pos.x]
	var acknowledgement := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	acknowledgement.tween_property(item, "scale", Vector2(1.18, 1.18), 0.08)
	acknowledgement.tween_property(item, "scale", Vector2.ONE, 0.10)
	_run_queued_power.call_deferred()


func _run_queued_power() -> void:
	while busy and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		power_busy = false
		return
	var queued := Vector2i(-1, -1)
	for y in ROWS:
		for x in COLS:
			if cells[y][x] != null and bool(cells[y][x].get("activation_queued", false)):
				queued = Vector2i(x, y)
				break
		if queued.x >= 0:
			break
	if queued.x < 0 or not _is_power_cell(queued):
		power_busy = false
		return
	cells[queued.y][queued.x].erase("activation_queued")
	# The queued-input lock ends as the effect begins. _play_power_effect_locked()
	# owns the lock during the actual power animation; once that visual ends, a
	# second power-up may be queued during the remaining candy fall animations.
	power_busy = false
	busy = true
	await _activate_special(queued, _tap_target_kind(queued))
	await _after_completed_move()
	busy = false
	move_finished.emit()


func _try_swap(a: Vector2i, b: Vector2i, from_drag := false) -> void:
	busy = true
	var completed_move := false
	await _animate_swap(a, b, from_drag)
	_swap(a, b)
	_refresh()
	await get_tree().create_timer(0.14).timeout
	var special_pos := b if int(cells[b.y][b.x].special) != Special.NONE else (a if int(cells[a.y][a.x].special) != Special.NONE else Vector2i(-1, -1))
	if special_pos.x >= 0:
		completed_move = true
		await _activate_swapped_special(a,b,special_pos)
	elif not _has_match():
		await _animate_invalid_swap(a, b)
		_swap(a, b)
		_refresh()
	else:
		completed_move = true
		await _resolve_cascades(b)
	if completed_move:
		await _after_completed_move()
	busy = false
	if completed_move:
		move_finished.emit()


func _animate_swap(a: Vector2i, b: Vector2i, from_drag: bool) -> void:
	var first := buttons[a.y * COLS + a.x]
	var second := buttons[b.y * COLS + b.x]
	var first_sprite: TextureRect = drag_preview if from_drag else _make_moving_sprite(first.icon, first.position)
	var second_sprite := _make_moving_sprite(second.icon, second.position)
	first.modulate.a = 0.12
	second.modulate.a = 0.12
	var direction := (second.position - first.position).normalized()
	var lift := Vector2(-direction.y, direction.x) * 14.0
	var first_destination := second.position + (second.size - first_sprite.size) * 0.5
	var first_mid := first_sprite.position.lerp(first_destination, 0.5) + lift
	var second_mid := second.position.lerp(first.position, 0.5) - lift
	var first_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	first_tween.tween_property(first_sprite, "position", first_mid, 0.11)
	first_tween.parallel().tween_property(first_sprite, "rotation", 0.06 if direction.x + direction.y > 0 else -0.06, 0.11)
	first_tween.tween_property(first_sprite, "position", first_destination, 0.11)
	first_tween.parallel().tween_property(first_sprite, "scale", Vector2.ONE, 0.11)
	first_tween.parallel().tween_property(first_sprite, "rotation", 0.0, 0.11)
	var second_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	second_tween.tween_property(second_sprite, "position", second_mid, 0.11)
	second_tween.parallel().tween_property(second_sprite, "scale", Vector2(1.1, 1.1), 0.11)
	second_tween.tween_property(second_sprite, "position", first.position, 0.11)
	second_tween.parallel().tween_property(second_sprite, "scale", Vector2.ONE, 0.11)
	await second_tween.finished
	first_sprite.queue_free()
	if from_drag:
		drag_preview = null
	second_sprite.queue_free()
	first.modulate = Color.WHITE
	second.modulate = Color.WHITE


func _make_moving_sprite(texture: Texture2D, start_position: Vector2) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2.ZERO
	sprite.position = start_position
	sprite.size = buttons[0].size
	sprite.pivot_offset = sprite.size * 0.5
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.z_index = 60
	add_child(sprite)
	return sprite


func _animate_invalid_swap(a: Vector2i, b: Vector2i) -> void:
	await get_tree().create_timer(0.07).timeout
	await _animate_swap(a, b, false)


func _resolve_cascades(preferred: Vector2i) -> void:
	var cascade_count := 0
	while true:
		var matches := _find_matches()
		if matches.clear.is_empty():
			break
		cascade_count += 1
		if cascade_count >= 2:
			_animate_combo_callout(cascade_count)
		var clear_set: Dictionary = matches.clear
		_expand_triggered_specials(clear_set)
		_remove_locked_from_clear(clear_set)
		var creation: Dictionary = _choose_special(matches, preferred)
		var bonus_positions: Array[Vector2i] = _large_match_positions(matches, preferred)
		for bonus_position: Vector2i in bonus_positions:
			large_match_created.emit(bonus_position)
		var score_set: Dictionary = clear_set.duplicate()
		if not creation.is_empty():
			clear_set.erase(creation.pos)
			# The candy transformed into a power-up still belongs to the match and
			# must count toward its objective (four matched means four collected).
			score_set[creation.pos] = true
		await _animate_chained_effects(clear_set)
		await _animate_clear(clear_set)
		await _damage_adjacent_locks(clear_set)
		await _score_clear(score_set)
		for pos: Vector2i in clear_set:
			cells[pos.y][pos.x] = null
		if not creation.is_empty():
			cells[creation.pos.y][creation.pos.x] = {"kind": creation.kind, "special": creation.special}
		_refresh()
		if not creation.is_empty():
			await _animate_special_created(creation.pos)
		# Let the cleared spaces read before gravity takes over.
		await get_tree().create_timer(0.14).timeout
		var fall_rows := _collapse_and_refill()
		_refresh()
		await _animate_refill(fall_rows)
		preferred = Vector2i(-1, -1)
	await _ensure_playable_board()


func _large_match_positions(matches: Dictionary, preferred: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for run: Dictionary in matches.runs:
		if run.items.size() >= 4:
			var pos: Vector2i = preferred if preferred in run.items else run.items[run.items.size()/2]
			if pos not in result: result.append(pos)
	for square: Dictionary in matches.squares:
		var pos: Vector2i = preferred if preferred in square.items else square.items[0]
		if pos not in result: result.append(pos)
	return result


func animate_bonus_collection(origin: Vector2i, texture: Texture2D, target: Control) -> void:
	if not is_instance_valid(target): return
	var start := buttons[origin.y*COLS+origin.x].position+Vector2(14,14)
	var destination_center := _global_to_board(target.get_global_rect().get_center())
	var destination := destination_center-Vector2(39,39)
	var sprite := _make_moving_sprite(texture,start)
	sprite.size=Vector2(82,82); sprite.pivot_offset=sprite.size*0.5; sprite.scale=Vector2(0.35,0.35); sprite.z_index=140
	var tween := create_tween()
	tween.tween_property(sprite,"scale",Vector2(1.08,1.08),0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite,"position:y",start.y-42.0,0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var midpoint := start.lerp(destination,0.5)+Vector2(0,-115)
	tween.tween_property(sprite,"position",midpoint,0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite,"position",destination,0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite,"scale",Vector2(0.38,0.38),0.26)
	await tween.finished
	sprite.queue_free(); _spawn_sugar_burst(destination_center,Color("fff3c7"),16); _pulse_objective(target)


func _ensure_playable_board() -> void:
	if _has_available_move():
		return
	# A special can always be tapped, so it also counts as a legal move.
	for y in ROWS:
		for x in COLS:
			if not locked_cells.has(Vector2i(x, y)) and int(cells[y][x].special) != Special.NONE:
				return
	var fade := create_tween().set_parallel(true)
	for item: MergeItem in candy_items:
		fade.tween_property(item, "scale", Vector2(0.72, 0.72), 0.12)
		fade.tween_property(item, "modulate:a", 0.35, 0.12)
	await fade.finished
	var attempts := 0
	while attempts < 80:
		attempts += 1
		for y in ROWS:
			for x in COLS:
				if not locked_cells.has(Vector2i(x, y)):
					cells[y][x] = {"kind": _next_random_kind(), "special": Special.NONE}
		if not _has_match() and _has_available_move():
			break
	_refresh()
	var appear := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for item: MergeItem in candy_items:
		item.scale = Vector2(0.72, 0.72)
		item.modulate.a = 0.35
		appear.tween_property(item, "scale", Vector2.ONE, 0.20)
		appear.tween_property(item, "modulate:a", 1.0, 0.16)
	await appear.finished


func _has_available_move() -> bool:
	for y in ROWS:
		for x in COLS:
			var a := Vector2i(x, y)
			if locked_cells.has(a):
				continue
			for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var b: Vector2i = a + offset
				if b.x >= COLS or b.y >= ROWS or locked_cells.has(b):
					continue
				_swap(a, b)
				var makes_match := _has_match()
				_swap(a, b)
				if makes_match:
					return true
	return false


func _animate_special_created(pos: Vector2i) -> void:
	var item := candy_items[pos.y * COLS + pos.x]
	item.pivot_offset = item.size * 0.5
	item.scale = Vector2(0.35, 0.35)
	var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", Vector2(1.18, 1.18), 0.22)
	tween.tween_property(item, "scale", Vector2.ONE, 0.10)
	await tween.finished


func _animate_clear(clear_set: Dictionary) -> void:
	if clear_set.is_empty():
		return
	var anticipate := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for pos: Vector2i in clear_set:
		var item := candy_items[pos.y * COLS + pos.x]
		item.pivot_offset = item.size * 0.5
		anticipate.tween_property(item, "scale", Vector2(1.13, 0.9), 0.08)
	await anticipate.finished
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var burst_count := 0
	for pos: Vector2i in clear_set:
		var item := candy_items[pos.y * COLS + pos.x]
		item.pivot_offset = item.size * 0.5
		tween.tween_property(item, "scale", Vector2(1.38, 1.38), 0.105)
		tween.tween_property(item, "modulate", Color(1.45, 1.45, 1.45, 0.0), 0.13)
		if burst_count < 14:
			_spawn_sugar_burst(buttons[pos.y * COLS + pos.x].position + buttons[0].size * 0.5, Color("fff0a6"), 8)
			burst_count += 1
	await tween.finished
	for pos: Vector2i in clear_set:
		var item := candy_items[pos.y * COLS + pos.x]
		item.scale = Vector2.ONE
		item.modulate.a = 0.0


func _animate_refill(fall_rows: Dictionary) -> void:
	if fall_rows.is_empty():
		return
	var longest_time := 0.0
	for pos: Vector2i in fall_rows:
		var item := candy_items[pos.y * COLS + pos.x]
		var target := buttons[pos.y * COLS + pos.x].position + Vector2(6, 6)
		var distance := maxi(1, int(fall_rows[pos]))
		# Bottom pieces settle first, while higher pieces naturally follow them.
		var delay := float(ROWS - 1 - pos.y) * 0.012
		var duration := sqrt(2.0 * CELL_PITCH * float(distance) / 2600.0)
		longest_time = maxf(longest_time, delay + duration + 0.12)
		item.position = target - Vector2(0, CELL_PITCH * distance)
		item.pivot_offset = item.size * 0.5
		item.scale = Vector2.ONE
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(item, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# A restrained squash gives the candy weight without a cartoon bounce.
		tween.tween_property(item, "scale", Vector2(1.045, 0.955), 0.035)
		tween.tween_property(item, "scale", Vector2.ONE, 0.075).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(longest_time).timeout


func _animate_combo_callout(count: int) -> void:
	var label := Label.new()
	var sayings: Array[String]
	if count == 2:
		sayings = ["BERRY GOOD!", "SWEET MOVE!", "YOU'RE ON A ROLL!", "TREAT-TASTIC!"]
	elif count == 3:
		sayings = ["CHOC FULL OF TALENT!", "WHISK-TAKING!", "THAT TAKES THE CAKE!", "SUGAR SPARKLE!"]
	else:
		sayings = ["CONFECTION PERFECTION!", "UN-FUDGE-GETTABLE!", "ABSOLUTELY FLAN-TASTIC!", "SWEET DREAM TEAM!"]
	label.text = sayings.pick_random() + "  x%d" % count
	label.position = Vector2(160, 390)
	label.size = Vector2(580, 110)
	label.pivot_offset = label.size * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color("fff3a8"))
	label.add_theme_color_override("font_outline_color", Color("9b2865"))
	label.add_theme_constant_override("outline_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 120
	label.scale = Vector2(0.2, 0.2)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.28)
	tween.tween_property(label, "position:y", label.position.y - 70.0, 0.25)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(label.queue_free)


func _find_matches() -> Dictionary:
	var clear: Dictionary = {}
	var runs: Array = []
	for y in ROWS:
		var x := 0
		while x < COLS:
			var end := x + 1
			while end < COLS and not locked_cells.has(Vector2i(x, y)) and not locked_cells.has(Vector2i(end, y)) and int(cells[y][end].kind) == int(cells[y][x].kind): end += 1
			if not locked_cells.has(Vector2i(x, y)) and end - x >= 3:
				var run: Array[Vector2i] = []
				for rx in range(x, end): run.append(Vector2i(rx, y)); clear[Vector2i(rx, y)] = true
				runs.append({"axis": "row", "items": run, "kind": int(cells[y][x].kind)})
			x = end
	for x in COLS:
		var y := 0
		while y < ROWS:
			var end := y + 1
			while end < ROWS and not locked_cells.has(Vector2i(x, y)) and not locked_cells.has(Vector2i(x, end)) and int(cells[end][x].kind) == int(cells[y][x].kind): end += 1
			if not locked_cells.has(Vector2i(x, y)) and end - y >= 3:
				var run: Array[Vector2i] = []
				for ry in range(y, end): run.append(Vector2i(x, ry)); clear[Vector2i(x, ry)] = true
				runs.append({"axis": "column", "items": run, "kind": int(cells[y][x].kind)})
			y = end
	# A same-color 2x2 is the side-by-side four-piece formation.
	var squares: Array = []
	for y in ROWS - 1:
		for x in COLS - 1:
			if locked_cells.has(Vector2i(x,y)) or locked_cells.has(Vector2i(x+1,y)) or locked_cells.has(Vector2i(x,y+1)) or locked_cells.has(Vector2i(x+1,y+1)):
				continue
			var k := int(cells[y][x].kind)
			if int(cells[y][x + 1].kind) == k and int(cells[y + 1][x].kind) == k and int(cells[y + 1][x + 1].kind) == k:
				var square := [Vector2i(x,y), Vector2i(x+1,y), Vector2i(x,y+1), Vector2i(x+1,y+1)]
				for p: Vector2i in square: clear[p] = true
				squares.append({"items": square, "kind": k})
	return {"clear": clear, "runs": runs, "squares": squares}


func _choose_special(matches: Dictionary, preferred: Vector2i) -> Dictionary:
	var runs: Array = matches.runs
	var clear: Dictionary = matches.clear
	# Five in a straight line always wins over any incidental overlap.
	for run: Dictionary in runs:
		if run.items.size() >= 5:
			return {"pos": preferred if preferred in run.items else run.items[run.items.size() / 2], "kind": int(run.kind), "special": Special.TARGET}
	# Intersecting horizontal/vertical runs form the requested plus/T bomb.
	for a: Dictionary in runs:
		for b: Dictionary in runs:
			if a.axis == b.axis or int(a.kind) != int(b.kind): continue
			for pos: Vector2i in a.items:
				if pos in b.items:
					return {"pos": preferred if clear.has(preferred) else pos, "kind": int(a.kind), "special": Special.BOMB}
	# A clean four-piece line creates the axis-specific double-ended rocket.
	for run: Dictionary in runs:
		if run.items.size() == 4:
			return {"pos": preferred if preferred in run.items else run.items[1], "kind": int(run.kind), "special": Special.ROW if run.axis == "row" else Special.COLUMN}
	# A compact side-by-side 2x2 formation creates the flying rocket.
	if not matches.squares.is_empty():
		var square: Dictionary = matches.squares[0]
		return {"pos": preferred if preferred in square.items else square.items[0], "kind": int(square.kind), "special": Special.FLYER}
	return {}


func _expand_triggered_specials(clear_set: Dictionary) -> void:
	var queue: Array = clear_set.keys()
	var seen: Dictionary = {}
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		if seen.has(pos): continue
		seen[pos] = true
		var special := int(cells[pos.y][pos.x].special)
		var additions: Array[Vector2i] = []
		if special == Special.ROW:
			for x in COLS: additions.append(Vector2i(x, pos.y))
		elif special == Special.COLUMN:
			for y in ROWS: additions.append(Vector2i(pos.x, y))
		elif special == Special.BOMB:
			for y in range(maxi(0,pos.y-1), mini(ROWS,pos.y+2)):
				for x in range(maxi(0,pos.x-1), mini(COLS,pos.x+2)): additions.append(Vector2i(x,y))
		elif special == Special.FLYER:
			var center := Vector2i(rng.randi_range(0,COLS-2), rng.randi_range(0,ROWS-2))
			additions = [center, center+Vector2i.RIGHT, center+Vector2i.DOWN, center+Vector2i(1,1)]
		elif special == Special.TARGET:
			var target_kind := int(cells[pos.y][pos.x].kind)
			for y in ROWS:
				for x in COLS:
					if int(cells[y][x].kind) == target_kind: additions.append(Vector2i(x, y))
		for added: Vector2i in additions:
			if not clear_set.has(added): clear_set[added] = true; queue.append(added)


func _activate_special(pos: Vector2i, kind: int) -> void:
	var clear_set: Dictionary = {pos: true}
	var special := int(cells[pos.y][pos.x].special)
	if special == Special.TARGET:
		for y in ROWS:
			for x in COLS:
				if int(cells[y][x].kind) == kind: clear_set[Vector2i(x,y)] = true
	else:
		_expand_triggered_specials(clear_set)
	_remove_locked_from_clear(clear_set)
	await _play_power_effect_locked(special, pos, clear_set)
	await _animate_chained_effects(clear_set, pos)
	await _animate_clear(clear_set)
	await _damage_adjacent_locks(clear_set)
	await _score_clear(clear_set)
	for target: Vector2i in clear_set: cells[target.y][target.x] = null
	_refresh()
	await get_tree().create_timer(0.14).timeout
	var fall_rows := _collapse_and_refill()
	_refresh()
	await _animate_refill(fall_rows)
	await _resolve_cascades(Vector2i(-1,-1))


func _activate_target(pos: Vector2i, kind: int) -> void:
	await _activate_special(pos, kind)


func _activate_swapped_special(a: Vector2i, b: Vector2i, fallback_special_pos: Vector2i) -> void:
	var a_special := int(cells[a.y][a.x].special)
	var b_special := int(cells[b.y][b.x].special)
	if a_special==Special.TARGET and b_special in [Special.ROW,Special.COLUMN,Special.FLYER,Special.BOMB]:
		await _activate_target_powerup_combo(a,b,b_special)
		return
	if b_special==Special.TARGET and a_special in [Special.ROW,Special.COLUMN,Special.FLYER,Special.BOMB]:
		await _activate_target_powerup_combo(b,a,a_special)
		return
	var other_pos := a if fallback_special_pos==b else b
	await _activate_special(fallback_special_pos,int(cells[other_pos.y][other_pos.x].kind))


func _activate_target_powerup_combo(target_pos: Vector2i, power_pos: Vector2i, powerup: int) -> void:
	# A disco-ball combination transforms random occupied squares into copies of
	# the paired power-up, replacing whatever normal item was in each square.
	var candidates: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			var pos := Vector2i(x,y)
			if pos!=target_pos and pos!=power_pos and not locked_cells.has(pos): candidates.append(pos)
	for index in range(candidates.size()-1,0,-1):
		var swap_index := rng.randi_range(0,index)
		var value := candidates[index]; candidates[index]=candidates[swap_index]; candidates[swap_index]=value
	var spawn_count := mini(8,candidates.size())
	cells[target_pos.y][target_pos.x]={"kind":rng.randi_range(0,COLORS-1),"special":Special.NONE}
	cells[power_pos.y][power_pos.x]={"kind":rng.randi_range(0,COLORS-1),"special":Special.NONE}
	for index in spawn_count:
		var pos: Vector2i = candidates[index]
		cells[pos.y][pos.x].special=powerup
	_refresh()
	var owned_power_lock := not power_busy
	power_busy = true
	await _animate_disco_electricity(target_pos,{target_pos:true,power_pos:true})
	if owned_power_lock:
		power_busy = false
	for index in spawn_count:
		var item: MergeItem = candy_items[candidates[index].y*COLS+candidates[index].x]
		item.scale=Vector2(0.25,0.25)
		create_tween().tween_property(item,"scale",Vector2.ONE,0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.32).timeout


func _animate_chained_effects(clear_set: Dictionary, already_played := Vector2i(-1, -1)) -> void:
	for pos: Vector2i in clear_set:
		if pos == already_played:
			continue
		var special := int(cells[pos.y][pos.x].special)
		if special in [Special.ROW, Special.COLUMN, Special.BOMB]:
			await _play_power_effect_locked(special, pos, clear_set)


func _play_power_effect_locked(special: int, origin: Vector2i, clear_set: Dictionary) -> void:
	var owned_power_lock := not power_busy
	power_busy = true
	await _animate_power_effect(special, origin, clear_set)
	if owned_power_lock:
		power_busy = false


func _animate_power_effect(special: int, origin: Vector2i, clear_set: Dictionary) -> void:
	match special:
		Special.BOMB:
			var neighbors: Dictionary = {}
			for pos: Vector2i in clear_set:
				if absi(pos.x - origin.x) <= 1 and absi(pos.y - origin.y) <= 1:
					neighbors[pos] = true
			await _animate_bomb_charge(origin, neighbors)
		Special.ROW, Special.COLUMN:
			await _animate_directional_blast(origin, special == Special.ROW)
		Special.FLYER:
			await _animate_flying_rocket(origin, clear_set)
		Special.TARGET:
			await _animate_disco_electricity(origin, clear_set)


func _animate_bomb_charge(origin: Vector2i, clear_set: Dictionary) -> void:
	var center := buttons[origin.y * COLS + origin.x].position + buttons[0].size * 0.5
	var bomb := candy_items[origin.y * COLS + origin.x]
	var charge := create_tween()
	charge.tween_property(bomb, "scale", Vector2(1.3, 1.3), 0.18)
	await charge.finished
	_spawn_impact_flash(center, Color("ffd66b"))
	_spawn_shockwave(center, Color("ff73b9"))
	_spawn_sugar_burst(center, Color("ffd66b"), 30)
	var blast := create_tween().set_parallel(true)
	for pos: Vector2i in clear_set:
		var item := candy_items[pos.y * COLS + pos.x]
		var offset := item.position + item.size * 0.5 - center
		var destination := item.position + offset.normalized() * 75.0
		var delay := 0.045 + offset.length() / 1800.0
		blast.tween_property(item, "position", destination, 0.18).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		blast.tween_property(item, "rotation", offset.x * 0.003, 0.18).set_delay(delay)
		collection_starts[pos] = destination + Vector2(8, 8)
	await blast.finished
	await get_tree().create_timer(0.10).timeout


func _animate_directional_blast(origin: Vector2i, horizontal: bool) -> void:
	var center := buttons[origin.y * COLS + origin.x].position + buttons[0].size * 0.5
	var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var trails: Array[Line2D] = []
	for _direction in 2:
		var trail := Line2D.new()
		trail.width = 42.0
		trail.z_index = 80
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(1, 0.3, 0.6, 0), Color(1, 0.65, 0.3, 0.6), Color(1, 1, 0.8, 1)])
		gradient.offsets = PackedFloat32Array([0, 0.6, 1])
		trail.gradient = gradient
		add_child(trail)
		trails.append(trail)
	_spawn_impact_flash(center, Color("fff4a8"))
	var hit: Dictionary = {}
	var tween := create_tween()
	tween.tween_method(_advance_lane_blast.bind(origin, center, axis, trails, hit), 0.0, CELL_PITCH * 9.0, 0.62)
	await tween.finished
	for trail: Line2D in trails:
		trail.queue_free()


func _advance_lane_blast(distance: float, origin: Vector2i, center: Vector2, axis: Vector2, trails: Array[Line2D], hit: Dictionary) -> void:
	for index in 2:
		var direction := axis * (-1.0 if index == 0 else 1.0)
		trails[index].points = PackedVector2Array([center + direction * maxf(0.0, distance - CELL_PITCH * 1.6), center + direction * distance])
	for index in COLS:
		var pos := Vector2i(index, origin.y) if axis.x > 0 else Vector2i(origin.x, index)
		if hit.has(pos) or locked_cells.has(pos):
			continue
		var impact := buttons[pos.y * COLS + pos.x].position + buttons[0].size * 0.5
		if impact.distance_to(center) <= distance:
			hit[pos] = true
			candy_items[pos.y * COLS + pos.x].modulate.a = 0.0
			_spawn_sugar_burst(impact, Color("ffb679"), 10)


func _animate_flying_rocket(origin: Vector2i, clear_set: Dictionary) -> void:
	var targets: Array[Vector2i] = []
	for pos: Vector2i in clear_set:
		if pos != origin: targets.append(pos)
	if targets.is_empty(): return
	var target_pos: Vector2i = targets[0]
	var destination := buttons[target_pos.y * COLS + target_pos.x].position
	var launch := buttons[origin.y * COLS + origin.x].position
	var origin_item := candy_items[origin.y * COLS + origin.x]
	origin_item.modulate.a = 0.0
	var sprite := _make_moving_sprite(SPECIAL_TEXTURES[Special.FLYER], launch)
	sprite.pivot_offset = sprite.size * 0.5
	sprite.scale = Vector2(0.82, 0.82)
	var trail := Line2D.new()
	var start_center := launch + buttons[0].size * 0.5
	var end_center := destination + buttons[0].size * 0.5
	var distance := start_center.distance_to(end_center)
	var arc_height := clampf(distance * 0.38, 70.0, 145.0)
	var arc := start_center.lerp(end_center, 0.5) + Vector2(0, -arc_height)
	trail.points = PackedVector2Array([start_center, start_center])
	trail.width = 9.0
	trail.default_color = Color("9ff8ff")
	trail.modulate.a = 0.72
	trail.z_index = 55
	add_child(trail)
	# Keep the rocket readable and fly it along one continuous quadratic arc.
	# The impact owns the scale/flash so launch never looks like a spinning pulse.
	_move_flying_rocket(0.0, sprite, trail, start_center, arc, end_center)
	var tween := create_tween()
	tween.tween_method(
		_move_flying_rocket.bind(sprite, trail, start_center, arc, end_center),
		0.0,
		1.0,
		0.46
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	sprite.modulate.a = 0.0
	trail.modulate.a = 0.0
	_spawn_impact_flash(end_center, Color("fff08a"))
	_spawn_shockwave(end_center, Color("fff4a8"))
	_spawn_sugar_burst(end_center, Color("fff4a8"), 42)
	var explode := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for pos: Vector2i in targets:
		var item := candy_items[pos.y * COLS + pos.x]
		item.pivot_offset = item.size * 0.5
		explode.tween_property(item, "scale", Vector2(1.3, 1.3), 0.1)
	await explode.finished
	for pos: Vector2i in targets:
		candy_items[pos.y * COLS + pos.x].scale = Vector2.ONE
	origin_item.modulate.a = 0.0
	trail.queue_free()
	sprite.queue_free()


func _move_flying_rocket(
	progress: float,
	sprite: TextureRect,
	trail: Line2D,
	start: Vector2,
	control: Vector2,
	finish: Vector2
) -> void:
	if not is_instance_valid(sprite) or not is_instance_valid(trail):
		return
	var inverse := 1.0 - progress
	var center := inverse * inverse * start + 2.0 * inverse * progress * control + progress * progress * finish
	var tangent := 2.0 * inverse * (control - start) + 2.0 * progress * (finish - control)
	sprite.position = center - sprite.size * 0.5
	# The sprite nose points diagonally up-right (-45 degrees).
	sprite.rotation = tangent.angle() + PI * 0.25
	var points := PackedVector2Array()
	var steps := maxi(2, int(12.0 * progress))
	for index in steps + 1:
		var sample_progress := progress * float(index) / float(steps)
		var sample_inverse := 1.0 - sample_progress
		points.append(
			sample_inverse * sample_inverse * start
			+ 2.0 * sample_inverse * sample_progress * control
			+ sample_progress * sample_progress * finish
		)
	trail.points = points


func _animate_disco_electricity(origin: Vector2i, clear_set: Dictionary) -> void:
	var start := buttons[origin.y * COLS + origin.x].position + buttons[0].size * 0.5
	var effects: Array[Line2D] = []
	for pos: Vector2i in clear_set:
		if pos == origin: continue
		var finish := buttons[pos.y * COLS + pos.x].position + buttons[0].size * 0.5
		var line := Line2D.new()
		var one_third := start.lerp(finish, 0.33) + Vector2(randf_range(-24, 24), randf_range(-24, 24))
		var two_thirds := start.lerp(finish, 0.67) + Vector2(randf_range(-24, 24), randf_range(-24, 24))
		line.points = PackedVector2Array([start, one_third, two_thirds, finish])
		line.width = 7.0
		line.default_color = Color("8ff8ff")
		line.z_index = 85
		add_child(line)
		effects.append(line)
		candy_items[pos.y * COLS + pos.x].modulate = Color(1.35, 1.55, 1.8, 1)
	var tween := create_tween().set_parallel(true)
	for line: Line2D in effects:
		tween.tween_property(line, "modulate:a", 0.0, 0.30).set_delay(0.12)
	await get_tree().create_timer(0.42).timeout
	for line: Line2D in effects: line.queue_free()
	for pos: Vector2i in clear_set: candy_items[pos.y * COLS + pos.x].modulate = Color.WHITE
	_spawn_sugar_burst(start, Color("8ff8ff"), 32)


func _spawn_sugar_burst(at: Vector2, tint: Color, count: int) -> void:
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.amount = count
	particles.lifetime = 0.48
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 240.0
	particles.gravity = Vector2(0, 260)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color = tint
	particles.z_index = 100
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(0.65).timeout.connect(particles.queue_free)


func _spawn_shockwave(at: Vector2, tint: Color) -> void:
	var ring := Panel.new()
	ring.position = at - Vector2(70, 70)
	ring.size = Vector2(140, 140)
	ring.pivot_offset = ring.size * 0.5
	ring.scale = Vector2(0.15, 0.15)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 95
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = tint
	style.set_border_width_all(12)
	style.set_corner_radius_all(999)
	ring.add_theme_stylebox_override("panel", style)
	add_child(ring)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.34)
	tween.tween_property(ring, "modulate:a", 0.0, 0.34)
	tween.chain().tween_callback(ring.queue_free)


func _spawn_impact_flash(at: Vector2, tint: Color) -> void:
	var flash := Panel.new()
	flash.position = at - Vector2(62, 62)
	flash.size = Vector2(124, 124)
	flash.pivot_offset = flash.size * 0.5
	flash.scale = Vector2(0.16, 0.16)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 108
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.92)
	style.border_color = Color(1.0, 1.0, 1.0, 0.96)
	style.set_border_width_all(10)
	style.set_corner_radius_all(999)
	flash.add_theme_stylebox_override("panel", style)
	add_child(flash)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", Vector2(1.45, 1.45), 0.22)
	tween.tween_property(flash, "modulate:a", 0.0, 0.22).set_delay(0.035)
	tween.chain().tween_callback(flash.queue_free)


func _clear_lock_overlays() -> void:
	for overlay: Control in lock_overlays.values():
		if is_instance_valid(overlay):
			overlay.queue_free()
	lock_overlays.clear()


func _create_lock_overlay(pos: Vector2i) -> void:
	var overlay := Control.new()
	overlay.position = buttons[pos.y * COLS + pos.x].position + Vector2(4, 4)
	overlay.size = buttons[pos.y * COLS + pos.x].size - Vector2(8, 8)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 35
	if blocker_style != "cage":
		var cover := Panel.new()
		cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		if blocker_style == "jelly":
			style.bg_color = Color("dc77b5d8")
			style.border_color = Color("ffbde7ee")
		elif blocker_style == "ice":
			style.bg_color = Color("a9e5f3c8")
			style.border_color = Color("e9fbffff")
		else:
			style.bg_color = Color("6b351ee8")
			style.border_color = Color("c17a4cff")
		style.set_border_width_all(5)
		style.set_corner_radius_all(18 if blocker_style=="jelly" else 8)
		cover.add_theme_stylebox_override("panel",style)
		overlay.add_child(cover)
		var mark := Label.new()
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mark.text = "●" if blocker_style=="jelly" else ("✧" if blocker_style=="ice" else "✦")
		mark.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size",44)
		mark.add_theme_color_override("font_color",Color("ffd8eff0") if blocker_style=="jelly" else (Color("ffffffff") if blocker_style=="ice" else Color("d99a70ff")))
		mark.mouse_filter=Control.MOUSE_FILTER_IGNORE
		overlay.add_child(mark)
		add_child(overlay)
		lock_overlays[pos]=overlay
		return
	for x_offset in [18.0, 48.0, 78.0]:
		var bar := ColorRect.new()
		bar.position = Vector2(x_offset, 4)
		bar.size = Vector2(10, 91)
		bar.color = Color("8a6e88")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(bar)
		var shine := ColorRect.new()
		shine.position = Vector2(2, 0)
		shine.size = Vector2(3, 91)
		shine.color = Color("f4dff2")
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(shine)
	for y_offset in [9.0, 83.0]:
		var rail := ColorRect.new()
		rail.position = Vector2(7, y_offset)
		rail.size = Vector2(92, 11)
		rail.color = Color("624a67")
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(rail)
	add_child(overlay)
	lock_overlays[pos] = overlay


func _animate_locked_nudge(pos: Vector2i) -> void:
	var overlay: Control = lock_overlays.get(pos)
	if overlay == null:
		return
	var home := overlay.position
	var tween := create_tween()
	tween.tween_property(overlay, "position:x", home.x - 4.0, 0.045)
	tween.tween_property(overlay, "position:x", home.x + 4.0, 0.07)
	tween.tween_property(overlay, "position:x", home.x, 0.045)


func _damage_adjacent_locks(clear_set: Dictionary) -> void:
	var opened: Array[Vector2i] = []
	for lock_pos: Vector2i in locked_cells:
		for cleared: Vector2i in clear_set:
			if absi(lock_pos.x - cleared.x) + absi(lock_pos.y - cleared.y) == 1:
				opened.append(lock_pos)
				break
	if opened.is_empty():
		return
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for pos: Vector2i in opened:
		var overlay: Control = lock_overlays[pos]
		overlay.pivot_offset = overlay.size * 0.5
		tween.tween_property(overlay, "scale", Vector2(1.18, 0.08), 0.18)
		tween.tween_property(overlay, "modulate:a", 0.0, 0.18)
		_spawn_sugar_burst(overlay.position + overlay.size * 0.5, Color("f5d8ff"), 12)
	await tween.finished
	for pos: Vector2i in opened:
		locked_cells.erase(pos)
		var overlay: Control = lock_overlays[pos]
		lock_overlays.erase(pos)
		overlay.queue_free()


func _remove_locked_from_clear(clear_set: Dictionary) -> void:
	for pos: Vector2i in locked_cells:
		clear_set.erase(pos)


func _after_completed_move() -> void:
	if shift_bottom_each_move:
		await _shift_bottom_row_left()
		await _resolve_cascades(Vector2i(-1, -1))


func _shift_bottom_row_left() -> void:
	var row := ROWS - 1
	var movers: Array[TextureRect] = []
	for x in COLS:
		var index := row * COLS + x
		var sprite := _make_moving_sprite(candy_items[index].texture, buttons[index].position + Vector2(6, 6))
		sprite.size = candy_items[index].size
		movers.append(sprite)
		candy_items[index].modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	for x in COLS:
		var destination_x := buttons[row * COLS].position.x - CELL_PITCH if x == 0 else buttons[row * COLS + x - 1].position.x + 6.0
		if x == 0:
			tween.tween_property(movers[x], "modulate:a", 0.0, 0.13)
		else:
			tween.tween_property(movers[x], "position:x", destination_x, 0.24)
	await tween.finished
	var first: Variant = cells[row][0]
	for x in COLS - 1:
		cells[row][x] = cells[row][x + 1]
	cells[row][COLS - 1] = first
	_refresh()
	var incoming := _make_moving_sprite(candy_items[row * COLS + COLS - 1].texture, buttons[row * COLS + COLS - 1].position + Vector2(CELL_PITCH, 6))
	incoming.size = candy_items[row * COLS + COLS - 1].size
	candy_items[row * COLS + COLS - 1].modulate.a = 0.0
	var enter := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	enter.tween_property(incoming, "position:x", buttons[row * COLS + COLS - 1].position.x + 6.0, 0.16)
	await enter.finished
	for sprite: TextureRect in movers:
		sprite.queue_free()
	incoming.queue_free()
	_refresh()


func _score_clear(clear_set: Dictionary) -> void:
	var positions_by_kind: Dictionary = {}
	for pos: Vector2i in clear_set:
		var kind := int(cells[pos.y][pos.x].kind)
		if not positions_by_kind.has(kind):
			positions_by_kind[kind] = []
		positions_by_kind[kind].append(pos)
	for kind: int in positions_by_kind:
		_animate_objective_collection(kind, positions_by_kind[kind])
	collection_starts.clear()
	# Counters change on arrival, not while their candies are still on the board.
	get_tree().create_timer(0.64).timeout.connect(func() -> void:
		for kind: int in positions_by_kind:
			objective_changed.emit(kind, positions_by_kind[kind].size())
	)


func _animate_objective_collection(kind: int, cleared_positions: Array) -> void:
	if kind < 0 or kind >= objective_targets.size():
		return
	var target: Control = objective_targets[kind]
	if not is_instance_valid(target):
		return
	var target_center_global := target.get_global_rect().get_center()
	var destination_center := _global_to_board(target_center_global)
	var destination := destination_center - Vector2(39, 39)
	# Every scored piece gets a visible receipt. Capping this at three made large
	# clears increase the counter without showing where most pieces went.
	var fly_count := cleared_positions.size()
	for index in fly_count:
		var pos: Vector2i = cleared_positions[index]
		var start: Vector2 = collection_starts.get(pos, buttons[pos.y * COLS + pos.x].position + Vector2(14, 14))
		var sprite := _make_moving_sprite(piece_textures[kind], start)
		sprite.size = Vector2(78, 78)
		sprite.pivot_offset = sprite.size * 0.5
		sprite.scale = Vector2(0.72, 0.72)
		sprite.modulate.a = 0.94
		sprite.z_index = 130
		var midpoint := start.lerp(destination, 0.48) + Vector2((index % 5 - 2) * 12.0, -95.0)
		var tween := create_tween()
		tween.tween_interval(mini(index, 12) * 0.018)
		tween.tween_property(sprite, "position", midpoint, 0.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "scale", Vector2(0.88, 0.88), 0.19)
		tween.tween_property(sprite, "position", destination, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(sprite, "scale", Vector2(0.38, 0.38), 0.22)
		tween.parallel().tween_property(sprite, "modulate:a", 0.25, 0.22)
		tween.tween_callback(sprite.queue_free)
	get_tree().create_timer(0.64).timeout.connect(func() -> void:
		_spawn_sugar_burst(destination_center, Color("fff3a8"), 14)
		_pulse_objective(target)
	)


func _pulse_objective(target: Control) -> void:
	if not is_instance_valid(target):
		return
	target.pivot_offset = target.size * 0.5
	var tween := target.create_tween()
	tween.tween_property(target, "scale", Vector2(1.18, 1.18), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _collapse_and_refill() -> Dictionary:
	var fall_rows: Dictionary = {}
	for x in COLS:
		var segment_bottom := ROWS - 1
		while segment_bottom >= 0:
			if locked_cells.has(Vector2i(x, segment_bottom)):
				segment_bottom -= 1
				continue
			var segment_top := segment_bottom
			while segment_top > 0 and not locked_cells.has(Vector2i(x, segment_top - 1)):
				segment_top -= 1
			var write := segment_bottom
			for y in range(segment_bottom, segment_top - 1, -1):
				if cells[y][x] != null:
					cells[write][x] = cells[y][x]
					if write != y:
						cells[y][x] = null
						fall_rows[Vector2i(x, write)] = write - y
					write -= 1
			var spawn_order := 1
			while write >= segment_top:
				cells[write][x] = {"kind": _next_random_kind(), "special": Special.NONE}
				fall_rows[Vector2i(x, write)] = write + spawn_order
				spawn_order += 1
				write -= 1
			segment_bottom = segment_top - 1
	return fall_rows


func _has_match() -> bool:
	return not _find_matches().clear.is_empty()


func _swap(a: Vector2i, b: Vector2i) -> void:
	var value: Variant = cells[a.y][a.x]
	cells[a.y][a.x] = cells[b.y][b.x]
	cells[b.y][b.x] = value


func _refresh() -> void:
	for y in ROWS:
		for x in COLS:
			var index := y * COLS + x
			var button: Button = buttons[index]
			var item: MergeItem = candy_items[index]
			button.icon = null
			item.modulate = Color.WHITE
			if cells[y][x] == null:
				button.text = ""
				item.visible = false
				continue
			var cell: Dictionary = cells[y][x]
			item.visible = true
			var special := int(cell.special)
			item.texture = piece_textures[int(cell.kind)] if special == Special.NONE else SPECIAL_TEXTURES[special]
			item.rotation = PI * 0.5 if special == Special.COLUMN else 0.0
			item.tooltip_text = _special_name(int(cell.special))
			_set_item_home(item, Vector2i(x, y), false)
			var special_label: Label = item.get_node_or_null("SpecialLabel")
			if special_label == null:
				special_label = Label.new()
				special_label.name = "SpecialLabel"
				special_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				special_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				special_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				special_label.add_theme_font_size_override("font_size", 31)
				special_label.add_theme_color_override("font_color", Color.WHITE)
				special_label.add_theme_color_override("font_outline_color", Color("6f244c"))
				special_label.add_theme_constant_override("outline_size", 7)
				item.add_child(special_label)
			special_label.text = ""
			button.text = ""
			button.modulate = Color(1.2, 1.2, 1.2) if selected == Vector2i(x,y) else Color.WHITE


func _special_symbol(special: int) -> String:
	match special:
		Special.ROW: return "↔"
		Special.COLUMN: return "↕"
		Special.FLYER: return "🚀"
		Special.BOMB: return "✹"
		Special.TARGET: return "◎"
	return ""


func _special_name(special: int) -> String:
	return ["Candy", "Clear row rocket", "Clear column rocket", "Flying rocket", "Candy bomb", "Targeting bomb"][special]

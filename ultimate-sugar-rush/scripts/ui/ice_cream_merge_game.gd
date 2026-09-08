extends Control

const HOLD_START_DELAY := 0.42
const HOLD_REPEAT_INTERVAL := 0.20
const MAX_ITEMS_PER_PRESS := 12
const OBJECTIVE_SAVE_SECTION := "ice_cream_merge_objectives"
const CAKE_XP_REWARD := "xp_small"
const CAKE_COIN_REWARD := "coins_small"
const OBJECTIVES := {
	"vanilla_ice_cream_bowl": {"label":"VANILLA", "target":8, "node":"ChocolateObjective"},
	"chocolate_ice_cream_bowl": {"label":"CHOCOLATE", "target":8, "node":"StrawberryObjective"},
	"pistachio_ice_cream_bowl": {"label":"PISTACHIO", "target":8, "node":"VanillaObjective"},
}

@onready var board: Control = %MergeBoard
@onready var status_label: Label = %StatusLabel

var _button_held := false
var _hold_time := 0.0
var _spawn_count := 0
var _objective_progress: Dictionary = {}
var _completion_started := false


func _ready() -> void:
	%BackButton.pressed.connect(_go_back)
	%AddItemButton.button_down.connect(_start_adding)
	%AddItemButton.button_up.connect(_stop_adding)
	%ResetButton.pressed.connect(_reset_board)
	board.board_changed.connect(_update_status)
	board.item_merged.connect(_on_item_merged)
	board.item_discarded.connect(_on_item_discarded)
	board.set_discard_target(%TrashDrop)
	_load_objectives()
	_update_objectives()
	_update_player_stats()
	_update_status()
	_complete_board_if_ready()
	_show_tutorial()


func _process(delta: float) -> void:
	if not _button_held or _spawn_count >= MAX_ITEMS_PER_PRESS:
		return
	_hold_time += delta
	var next_spawn_time := HOLD_START_DELAY + float(_spawn_count - 1) * HOLD_REPEAT_INTERVAL
	while _button_held and _spawn_count < MAX_ITEMS_PER_PRESS and _hold_time >= next_spawn_time:
		if not _add_item():
			_button_held = false
			return
		next_spawn_time = HOLD_START_DELAY + float(_spawn_count - 1) * HOLD_REPEAT_INTERVAL


func _go_back() -> void:
	SaveSystem.save_now()
	if not SceneRouter.go_back():
		SceneRouter.replace_scene("res://scenes/map/world_map.tscn")


func _start_adding() -> void:
	_button_held = true
	_hold_time = 0.0
	_spawn_count = 0
	if not _add_item():
		_button_held = false


func _stop_adding() -> void:
	_button_held = false


func _add_item() -> bool:
	var item_id: String = board.add_random_base_item()
	if item_id.is_empty():
		status_label.text = "The board is full. Merge something first!"
		return false
	_spawn_count += 1
	status_label.text = "%s appeared!" % item_id.replace("_", " ").capitalize()
	return true


func _reset_board() -> void:
	_button_held = false
	_completion_started = false
	%AddItemButton.disabled = false
	SaveSystem.set_section(OBJECTIVE_SAVE_SECTION, {})
	SaveSystem.set_value("progression", "level_3_complete", false)
	SaveSystem.set_value("progression", "level_4_complete", false)
	_objective_progress.clear()
	board.reset_board()
	_load_objectives()
	_update_objectives()
	SaveSystem.save_now()
	status_label.text = "Frozen Scoops fully reset for testing."
	_show_tutorial()


func _update_status() -> void:
	status_label.text = "Match free ingredients with frozen copies to thaw and merge them."


func _on_item_discarded(item_id: String) -> void:
	status_label.text = "%s discarded." % item_id.replace("_", " ").capitalize()


func _load_objectives() -> void:
	for item_id: String in OBJECTIVES:
		var saved_count := int(SaveSystem.get_value(OBJECTIVE_SAVE_SECTION, item_id, 0))
		var credited_count := maxi(saved_count, board.get_item_count(item_id))
		_objective_progress[item_id] = mini(credited_count, int(OBJECTIVES[item_id].target))
		if credited_count > saved_count:
			SaveSystem.set_value(OBJECTIVE_SAVE_SECTION, item_id, _objective_progress[item_id])


func _on_item_merged(item_id: String) -> void:
	if not OBJECTIVES.has(item_id):
		return
	var objective: Dictionary = OBJECTIVES[item_id]
	var previous := int(_objective_progress.get(item_id, 0))
	var target := int(objective.target)
	if previous >= target:
		return
	_objective_progress[item_id] = previous + 1
	SaveSystem.set_value(OBJECTIVE_SAVE_SECTION, item_id, _objective_progress[item_id])
	GameDatabase.grant_xp(CAKE_XP_REWARD)
	GameDatabase.grant_currency(CAKE_COIN_REWARD)
	_update_player_stats()
	_update_objectives()
	if int(_objective_progress[item_id]) >= target:
		status_label.text = "%s ice-cream objective complete!" % str(objective.label).capitalize()
	_complete_board_if_ready()


func _complete_board_if_ready() -> void:
	if _completion_started or bool(SaveSystem.get_value("progression", "level_4_complete", false)) or not _all_objectives_complete():
		return
	_completion_started = true
	SaveSystem.set_value("progression", "level_4_complete", true)
	SaveSystem.set_value("progression", "level_5_unlocked", true)
	SaveSystem.save_now()
	var collectible_rewards: Node = get_node("/root/CollectibleRewards")
	await collectible_rewards.play_completion(self, board, "LEVEL COMPLETED!")
	SceneRouter.replace_scene("res://scenes/map/world_map.tscn")


func _show_tutorial() -> void:
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%AddItemButton.disabled = true
	var overlay := ColorRect.new()
	overlay.color = Color(0.06, 0.13, 0.22, 0.9)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 200
	add_child(overlay)
	var title := Label.new()
	title.text = "FROZEN SCOOPS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("dffcff"))
	title.position = Vector2(90, 300)
	title.size = Vector2(900, 90)
	overlay.add_child(title)
	var instructions := Label.new()
	instructions.text = "Create 8 big bowls of each ice-cream flavor.\nFrozen ingredients cannot move or be discarded.\nDrag a matching FREE ingredient onto the frozen one\nto break the ice and merge!"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 28)
	instructions.add_theme_color_override("font_color", Color.WHITE)
	instructions.position = Vector2(80, 410)
	instructions.size = Vector2(920, 220)
	overlay.add_child(instructions)
	var free_icon := _tutorial_icon("res://assets/merge/milk_pitcher.png", Vector2(160, 700))
	var frozen_icon := _tutorial_icon("res://assets/merge/milk_pitcher.png", Vector2(670, 700))
	frozen_icon.modulate = Color(0.52, 0.88, 1.15, 0.72)
	overlay.add_child(free_icon)
	overlay.add_child(frozen_icon)
	var arrow := Label.new()
	arrow.text = "MATCH  →  THAW + MERGE"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 28)
	arrow.add_theme_color_override("font_color", Color("fff1a8"))
	arrow.position = Vector2(250, 930)
	arrow.size = Vector2(580, 60)
	overlay.add_child(arrow)
	var okay := Button.new()
	okay.text = "OK — START!"
	okay.disabled = true
	okay.add_theme_font_size_override("font_size", 30)
	okay.position = Vector2(290, 1120)
	okay.size = Vector2(500, 100)
	overlay.add_child(okay)
	var demo := create_tween().set_loops(2)
	demo.tween_property(free_icon, "position", Vector2(670, 700), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	demo.tween_property(free_icon, "scale", Vector2(1.18, 1.18), 0.15)
	demo.tween_property(free_icon, "modulate:a", 0.0, 0.18)
	demo.tween_callback(func() -> void: free_icon.position = Vector2(160, 700); free_icon.scale = Vector2.ONE; free_icon.modulate.a = 1.0)
	await demo.finished
	okay.disabled = false
	okay.grab_focus()
	await okay.pressed
	var fade := create_tween()
	fade.tween_property(overlay, "modulate:a", 0.0, 0.24)
	await fade.finished
	overlay.queue_free()
	board.mouse_filter = Control.MOUSE_FILTER_PASS
	%AddItemButton.disabled = false


func _tutorial_icon(texture_path: String, icon_position: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(texture_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	icon.position = icon_position
	icon.size = Vector2(250, 250)
	icon.pivot_offset = icon.size * 0.5
	return icon


func _all_objectives_complete() -> bool:
	for objective_id: String in OBJECTIVES:
		if int(_objective_progress.get(objective_id, 0)) < int(OBJECTIVES[objective_id].target):
			return false
	return true


func _update_objectives() -> void:
	for item_id: String in OBJECTIVES:
		var objective: Dictionary = OBJECTIVES[item_id]
		var count := int(_objective_progress.get(item_id, 0))
		var target := int(objective.target)
		var label: Label = get_node("%" + str(objective.node))
		label.text = "%s\n%d / %d%s" % [objective.label, count, target, "  ✓" if count >= target else ""]


func _update_player_stats() -> void:
	var stats := GameDatabase.get_player_stats()
	%XpAmount.text = str(int(stats.get("xp", 0)))
	%CoinAmount.text = str(int(stats.get("coins", 0)))

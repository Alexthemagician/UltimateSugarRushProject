extends Control

const HOLD_START_DELAY := 0.42
const HOLD_REPEAT_INTERVAL := 0.22
const OBJECTIVE_SAVE_SECTION := "mixed_merge_objectives"
const CAKE_XP_REWARD := "xp_small"
const CAKE_COIN_REWARD := "coins_small"
const OBJECTIVES := {
	"chocolate_ice_cream_bowl": {"label":"CHOC ICE CREAM", "target":8, "node":"ChocolateObjective"},
	"pink_sugar_cookie_box": {"label":"SUGAR COOKIE", "target":8, "node":"StrawberryObjective"},
	"vanilla_cake": {"label":"VANILLA CAKE", "target":8, "node":"VanillaObjective"},
	"apple_pitcher": {"label":"APPLE JUICE", "target":8, "node":"BlueberryObjective"},
}

@onready var board: Control = %MergeBoard
@onready var status_label: Label = %StatusLabel

var _button_held := false
var _hold_time := 0.0
var _spawn_count := 0
var _objective_progress: Dictionary = {}
var _completion_started := false


func _ready() -> void:
	preload("res://scripts/ui/landscape_layout.gd").apply(self)
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


func _process(delta: float) -> void:
	if not _button_held:
		return
	_hold_time += delta
	var next_spawn_time := HOLD_START_DELAY + float(_spawn_count - 1) * HOLD_REPEAT_INTERVAL
	while _button_held and _hold_time >= next_spawn_time:
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
	var item_ids: Array[String] = board.add_random_base_items_burst(%AddItemButton.get_global_rect().get_center(), randi_range(4, 6))
	if item_ids.is_empty():
		status_label.text = "The board is full. Merge something first!"
		return false
	_spawn_count += 1
	status_label.text = "%d treats burst onto the board!" % item_ids.size()
	return true


func _reset_board() -> void:
	_button_held = false
	_completion_started = false
	%AddItemButton.disabled = false
	SaveSystem.set_section(OBJECTIVE_SAVE_SECTION, {})
	SaveSystem.set_value("progression", "level_5_complete", false)
	_objective_progress.clear()
	board.reset_board()
	_load_objectives()
	_update_objectives()
	SaveSystem.save_now()
	status_label.text = "Sugar Shuffle fully reset for testing."


func _update_status() -> void:
	status_label.text = "Build four favorite treats and thaw frozen starters with a matching free item."


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
		status_label.text = "%s objective complete!" % str(objective.label).capitalize()
	_complete_board_if_ready()


func _complete_board_if_ready() -> void:
	if not _all_objectives_complete():
		return
	var was_already_complete := bool(SaveSystem.get_value("progression", "level_5_complete", false))
	if _completion_started or was_already_complete:
		return
	_completion_started = true
	SaveSystem.set_value("progression", "level_5_complete", true)
	SaveSystem.set_value("progression", "level_6_unlocked", true)
	SaveSystem.save_now()
	var collectible_rewards: Node = get_node("/root/CollectibleRewards")
	await collectible_rewards.play_completion(self, board, "LEVEL COMPLETED!")
	await _play_sugar_die()
	SceneRouter.replace_scene(CafeProgress.map_scene_for_region())


func _play_sugar_die() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.12, 0.06, 0.14, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 220
	add_child(overlay)
	var caption := Label.new()
	caption.text = "SUGAR ROLL!"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 50)
	caption.add_theme_color_override("font_color", Color("fff2b2"))
	caption.position = Vector2(90, 390)
	caption.size = Vector2(900, 80)
	overlay.add_child(caption)
	var die := TextureRect.new()
	die.texture = load("res://assets/merge/sugar_die_three.png")
	die.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	die.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	die.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	die.position = Vector2(-430, 650)
	die.size = Vector2(430, 430)
	die.pivot_offset = die.size * 0.5
	overlay.add_child(die)
	var roll := create_tween().set_parallel(true)
	roll.tween_property(die, "position", Vector2(325, 650), 1.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	roll.tween_property(die, "rotation", TAU * 3.0, 1.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await roll.finished
	die.rotation = 0.0
	var settle := create_tween()
	settle.tween_property(die, "scale", Vector2(1.13, 1.13), 0.16).set_trans(Tween.TRANS_BACK)
	settle.tween_property(die, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC)
	await settle.finished
	await get_tree().create_timer(1.1).timeout
	overlay.queue_free()


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

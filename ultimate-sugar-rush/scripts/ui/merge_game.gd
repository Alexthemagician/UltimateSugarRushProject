extends Control

const HOLD_START_DELAY := 0.42
const HOLD_REPEAT_INTERVAL := 0.20
const MAX_FRUIT_PER_PRESS := 12
const OBJECTIVE_SAVE_SECTION := "merge_objectives"
const PITCHER_XP_REWARD := "xp_small"
const PITCHER_COIN_REWARD := "coins_small"
const OBJECTIVES := {
	"magic_pitcher": {"label":"LEMONADE", "target":7, "node":"LemonObjective"},
	"orange_pitcher": {"label":"ORANGE", "target":12, "node":"OrangeObjective"},
	"apple_pitcher": {"label":"APPLE", "target":18, "node":"AppleObjective"},
}

@onready var board: Control = %MergeBoard
@onready var status_label: Label = %StatusLabel

var _fruit_button_held := false
var _fruit_hold_time := 0.0
var _fruit_spawn_count := 0
var _objective_progress: Dictionary = {}
var _board_finishing := false


func _ready() -> void:
	%BackButton.pressed.connect(_go_back)
	%AddItemButton.button_down.connect(_start_adding_fruit)
	%AddItemButton.button_up.connect(_stop_adding_fruit)
	%ResetButton.pressed.connect(_reset_board)
	board.board_changed.connect(_update_status)
	board.item_merged.connect(_on_item_merged)
	board.item_discarded.connect(_on_item_discarded)
	board.set_discard_target(%TrashDrop)
	_load_objectives()
	_update_objectives()
	_update_player_stats()
	_update_status()
	if _all_objectives_complete() and not bool(SaveSystem.get_value("progression", "level_2_unlocked", false)):
		_complete_board.call_deferred()


func _go_back() -> void:
	SaveSystem.save_now()
	if not SceneRouter.go_back():
		SceneRouter.replace_scene("res://scenes/map/world_map.tscn")


func _process(delta: float) -> void:
	if not _fruit_button_held or _fruit_spawn_count >= MAX_FRUIT_PER_PRESS:
		return
	_fruit_hold_time += delta
	var next_spawn_time := HOLD_START_DELAY + float(_fruit_spawn_count - 1) * HOLD_REPEAT_INTERVAL
	while _fruit_button_held and _fruit_spawn_count < MAX_FRUIT_PER_PRESS and _fruit_hold_time >= next_spawn_time:
		if not _add_item():
			_fruit_button_held = false
			return
		next_spawn_time = HOLD_START_DELAY + float(_fruit_spawn_count - 1) * HOLD_REPEAT_INTERVAL


func _start_adding_fruit() -> void:
	_fruit_button_held = true
	_fruit_hold_time = 0.0
	_fruit_spawn_count = 0
	if not _add_item():
		_fruit_button_held = false


func _stop_adding_fruit() -> void:
	_fruit_button_held = false


func _add_item() -> bool:
	var item_id: String = board.add_random_fruit()
	if not item_id.is_empty():
		_fruit_spawn_count += 1
	match item_id:
		"lemon":
			status_label.text = "A sunny lemon appeared!"
		"orange":
			status_label.text = "A sunset orange appeared!"
		"apple":
			status_label.text = "A ruby apple appeared!"
		_:
			status_label.text = "The board is full. Merge something first!"
	return not item_id.is_empty()


func _reset_board() -> void:
	_fruit_button_held = false
	_board_finishing = false
	%AddItemButton.disabled = false
	SaveSystem.set_section(OBJECTIVE_SAVE_SECTION, {})
	SaveSystem.set_value("progression", "level_2_unlocked", false)
	SaveSystem.set_value("progression", "level_2_complete", false)
	SaveSystem.set_value("progression", "level_3_unlocked", false)
	SaveSystem.set_value("progression", "level_3_complete", false)
	SaveSystem.set_value("progression", "level_4_unlocked", false)
	SaveSystem.set_value("progression", "level_4_complete", false)
	_objective_progress.clear()
	board.reset_board()
	_load_objectives()
	_update_objectives()
	SaveSystem.save_now()
	status_label.text = "Level 1 fully reset for testing."


func _update_status() -> void:
	status_label.text = "Drag matching items together to merge them."


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
	_objective_progress[item_id] = mini(previous + 1, target)
	SaveSystem.set_value(OBJECTIVE_SAVE_SECTION, item_id, _objective_progress[item_id])
	GameDatabase.grant_xp(PITCHER_XP_REWARD)
	GameDatabase.grant_currency(PITCHER_COIN_REWARD)
	_update_player_stats()
	_update_objectives()
	if previous < target and int(_objective_progress[item_id]) >= target:
		status_label.text = "%s pitcher objective complete!" % str(objective.label).capitalize()
	if _all_objectives_complete():
		_complete_board()


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


func _on_item_discarded(item_id: String) -> void:
	status_label.text = "%s discarded." % str(item_id).replace("_", " ").capitalize()


func _all_objectives_complete() -> bool:
	for item_id: String in OBJECTIVES:
		if int(_objective_progress.get(item_id, 0)) < int(OBJECTIVES[item_id].target):
			return false
	return true


func _complete_board() -> void:
	if _board_finishing:
		return
	_board_finishing = true
	_fruit_button_held = false
	%AddItemButton.disabled = true
	SaveSystem.set_value("progression", "level_2_unlocked", true)
	SaveSystem.save_now()
	var collectible_rewards: Node = get_node("/root/CollectibleRewards")
	await collectible_rewards.play_completion(self, board, "LEVEL COMPLETED!")
	SceneRouter.replace_scene("res://scenes/map/world_map.tscn")

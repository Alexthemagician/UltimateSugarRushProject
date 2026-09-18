extends Control

const TARGET := 55
const MOVE_LIMIT := 40
const SAVE_SECTION := "candy_match_objectives"
const NAMES := ["RED ROUND", "GREEN HARD", "BUTTERSCOTCH", "BLUE HEART"]

@onready var board: MatchThreeBoard = %MatchThreeBoard
@onready var labels: Array[Label] = [%RedObjective, %GreenObjective, %GoldObjective, %BlueObjective]
var progress := [0, 0, 0, 0]
var moves_remaining := MOVE_LIMIT
var completing := false


func _ready() -> void:
	preload("res://scripts/ui/landscape_layout.gd").apply(self)
	var saved := SaveSystem.get_section(SAVE_SECTION)
	for kind in 4: progress[kind] = int(saved.get(str(kind), 0))
	moves_remaining = int(saved.get("moves_remaining", MOVE_LIMIT))
	board.objective_changed.connect(_on_objective_changed)
	board.move_finished.connect(_on_move_finished)
	%BackButton.pressed.connect(func() -> void: SceneRouter.go_to_scene("res://scenes/map/world_map.tscn"))
	%ResetButton.pressed.connect(_reset)
	_update_labels()
	_update_moves()
	_set_board_objective_targets()
	if moves_remaining <= 0 and not _complete():
		_show_out_of_moves()


func _set_board_objective_targets() -> void:
	var targets: Array[Control] = []
	for label: Label in labels:
		var icon: TextureRect = label.get_parent().get_node("Icon")
		targets.append(icon)
	board.set_objective_targets(targets)


func _on_objective_changed(kind: int, amount: int) -> void:
	if completing: return
	progress[kind] = mini(TARGET, int(progress[kind]) + amount)
	_save()
	_update_labels()
	if _complete():
		completing = true
		await _complete_level()


func _update_labels() -> void:
	for kind in 4:
		labels[kind].text = "%s\n%d / %d" % [NAMES[kind], progress[kind], TARGET]


func _on_move_finished() -> void:
	if completing or moves_remaining <= 0:
		return
	moves_remaining -= 1
	_save()
	_update_moves()
	if moves_remaining <= 0 and not _complete():
		_show_out_of_moves()


func _update_moves() -> void:
	%MovesLabel.text = "MOVES\n%d" % moves_remaining


func _show_out_of_moves() -> void:
	board.set_interaction_enabled(false)
	%StatusLabel.text = "Out of moves! Press RESET to try again."
	%MovesLabel.add_theme_color_override("font_color", Color("d52f59"))


func _save() -> void:
	var values := {}
	for kind in 4: values[str(kind)] = progress[kind]
	values["moves_remaining"] = moves_remaining
	SaveSystem.set_section(SAVE_SECTION, values)


func _complete() -> bool:
	for value: int in progress:
		if value < TARGET: return false
	return true


func _complete_level() -> void:
	SaveSystem.set_value("progression", "level_6_complete", true)
	SaveSystem.set_value("progression", "level_7_unlocked", true)
	SaveSystem.save_now()
	var collectible_rewards: Node = get_node("/root/CollectibleRewards")
	await collectible_rewards.play_completion(self, board, "SWEET MATCH COMPLETE!")
	SceneRouter.replace_scene(CafeProgress.map_scene_for_region())


func _reset() -> void:
	progress = [0, 0, 0, 0]
	moves_remaining = MOVE_LIMIT
	_save()
	board.reset_board()
	board.set_interaction_enabled(true)
	completing = false
	_update_labels()
	_update_moves()
	%MovesLabel.remove_theme_color_override("font_color")
	%StatusLabel.text = "Candy Match fully reset for testing."

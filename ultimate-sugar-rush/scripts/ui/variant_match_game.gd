extends Control

@export var target := 55
@export var move_limit := 40
@export var save_section := "variant_match_objectives"
@export var piece_names: Array[String] = ["RED", "ORANGE", "GREEN", "BLUE"]
@export var piece_textures: Array[Texture2D] = []
@export var initial_locks: Array[Vector2i] = []
@export var shift_bottom_row := false
@export var completion_message := "PUZZLE COMPLETE!"
@export var completion_flag := "level_complete"
@export var unlock_flag := "level_unlocked"

@onready var board: MatchThreeBoard = %MatchThreeBoard
@onready var labels: Array[Label] = [%RedObjective, %GreenObjective, %GoldObjective, %BlueObjective]
var progress := [0, 0, 0, 0]
var moves_remaining := 0
var completing := false


func _ready() -> void:
	moves_remaining = move_limit
	board.configure(piece_textures, initial_locks, shift_bottom_row)
	var saved := SaveSystem.get_section(save_section)
	for kind in 4:
		progress[kind] = int(saved.get(str(kind), 0))
	moves_remaining = int(saved.get("moves_remaining", move_limit))
	board.objective_changed.connect(_on_objective_changed)
	board.move_finished.connect(_on_move_finished)
	%BackButton.pressed.connect(func() -> void: SceneRouter.go_to_scene("res://scenes/map/world_map.tscn"))
	%ResetButton.pressed.connect(_reset)
	var icons: Array[TextureRect] = [
		%RedObjective.get_parent().get_node("Icon"),
		%GreenObjective.get_parent().get_node("Icon"),
		%GoldObjective.get_parent().get_node("Icon"),
		%BlueObjective.get_parent().get_node("Icon"),
	]
	for kind in 4:
		icons[kind].texture = piece_textures[kind]
	var targets: Array[Control] = []
	for icon: TextureRect in icons:
		targets.append(icon)
	board.set_objective_targets(targets)
	_update_labels()
	_update_moves()
	if moves_remaining <= 0 and not _complete():
		_show_out_of_moves()


func _on_objective_changed(kind: int, amount: int) -> void:
	if completing:
		return
	progress[kind] = mini(target, int(progress[kind]) + amount)
	_save()
	_update_labels()
	if _complete():
		completing = true
		await _complete_level()


func _on_move_finished() -> void:
	if completing or moves_remaining <= 0:
		return
	moves_remaining -= 1
	_save()
	_update_moves()
	if moves_remaining <= 0 and not _complete():
		_show_out_of_moves()


func _update_labels() -> void:
	for kind in 4:
		labels[kind].text = "%s\n%d / %d" % [piece_names[kind], progress[kind], target]


func _update_moves() -> void:
	%MovesLabel.text = "MOVES\n%d" % moves_remaining


func _show_out_of_moves() -> void:
	board.set_interaction_enabled(false)
	%StatusLabel.text = "Out of moves! Press RESET to try again."
	%MovesLabel.add_theme_color_override("font_color", Color("d52f59"))


func _save() -> void:
	var values := {"moves_remaining": moves_remaining}
	for kind in 4:
		values[str(kind)] = progress[kind]
	SaveSystem.set_section(save_section, values)


func _complete() -> bool:
	for value: int in progress:
		if value < target:
			return false
	return true


func _complete_level() -> void:
	SaveSystem.set_value("progression", completion_flag, true)
	SaveSystem.set_value("progression", unlock_flag, true)
	SaveSystem.save_now()
	var collectible_rewards: Node = get_node("/root/CollectibleRewards")
	await collectible_rewards.play_completion(self, board, completion_message)
	SceneRouter.replace_scene("res://scenes/map/world_map.tscn")


func _reset() -> void:
	progress = [0, 0, 0, 0]
	moves_remaining = move_limit
	_save()
	board.reset_board()
	board.set_interaction_enabled(true)
	completing = false
	_update_labels()
	_update_moves()
	%MovesLabel.remove_theme_color_override("font_color")
	%StatusLabel.text = "Board fully reset for testing."

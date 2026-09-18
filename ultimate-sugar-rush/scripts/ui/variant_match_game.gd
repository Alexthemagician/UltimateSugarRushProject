extends Control

@export var target := 55
@export var objective_requirements: Array[int] = []
@export var move_limit := 40
@export var save_section := "variant_match_objectives"
@export var piece_names: Array[String] = ["RED", "ORANGE", "GREEN", "BLUE"]
@export var piece_textures: Array[Texture2D] = []
@export var initial_locks: Array[Vector2i] = []
@export var shift_bottom_row := false
@export var completion_message := "PUZZLE COMPLETE!"
@export var completion_flag := "level_complete"
@export var unlock_flag := "level_unlocked"
@export var standby_name := ""
@export var standby_texture: Texture2D
@export var standby_requirement := 0

@onready var board: MatchThreeBoard = %MatchThreeBoard
@onready var labels: Array[Label] = [%RedObjective, %GreenObjective, %GoldObjective, %BlueObjective]
var progress := [0, 0, 0, 0]
var moves_remaining := 0
var completing := false
var standby_progress := 0
var standby_label: Label
var standby_icon: TextureRect


func _ready() -> void:
	preload("res://scripts/ui/landscape_layout.gd").apply(self)
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
	if standby_requirement>0 and standby_texture:
		_build_standby_objective()
		standby_progress=int(saved.get("standby",0))
		board.large_match_created.connect(_on_large_match_created)
	_update_labels()
	_update_moves()
	if moves_remaining <= 0 and not _complete():
		_show_out_of_moves()


func _on_objective_changed(kind: int, amount: int) -> void:
	if completing:
		return
	progress[kind] = mini(_target_for_kind(kind), int(progress[kind]) + amount)
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
		labels[kind].text = "%s\n%d / %d" % [piece_names[kind], progress[kind], _target_for_kind(kind)]
	if standby_label:
		standby_label.text="%s\n%d / %d" % [standby_name,standby_progress,standby_requirement]


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
	if standby_requirement>0: values.standby=standby_progress
	SaveSystem.set_section(save_section, values)


func _complete() -> bool:
	for kind in progress.size():
		if int(progress[kind]) < _target_for_kind(kind):
			return false
	return standby_requirement<=0 or standby_progress>=standby_requirement


func _target_for_kind(kind: int) -> int:
	return objective_requirements[kind] if kind >= 0 and kind < objective_requirements.size() else target


func _complete_level() -> void:
	SaveSystem.set_value("progression", completion_flag, true)
	SaveSystem.set_value("progression", unlock_flag, true)
	SaveSystem.save_now()
	var collectible_rewards: Node = get_node("/root/CollectibleRewards")
	await collectible_rewards.play_completion(self, board, completion_message)
	if CafeProgress.is_unlimited_board(scene_file_path):
		var wheel = load("res://scripts/ui/ingredient_wheel.gd").new()
		wheel.region = CafeProgress.region
		add_child(wheel)
		await wheel.wheel_closed
	SceneRouter.replace_scene(CafeProgress.map_scene_for_region())


func _reset() -> void:
	progress = [0, 0, 0, 0]
	standby_progress = 0
	moves_remaining = move_limit
	_save()
	board.reset_board()
	board.set_interaction_enabled(true)
	completing = false
	_update_labels()
	_update_moves()
	%MovesLabel.remove_theme_color_override("font_color")
	%StatusLabel.text = "Board fully reset for testing."


func _build_standby_objective() -> void:
	var container: Container = get_node("LandscapeLayout/RightObjectives")
	container.add_theme_constant_override("separation",8)
	var cards := container.get_children()
	for card: Control in cards: card.custom_minimum_size=Vector2(460,72)
	var card: Control = cards[0].duplicate()
	card.custom_minimum_size=Vector2(460,72); container.add_child(card)
	standby_label=card.find_children("*","Label",true,false)[0]
	standby_icon=card.find_children("*","TextureRect",true,false)[0]
	standby_icon.texture=standby_texture; standby_icon.custom_minimum_size=Vector2(58,58)
	standby_label.add_theme_font_size_override("font_size",16)


func _on_large_match_created(position: Vector2i) -> void:
	if completing or standby_progress>=standby_requirement: return
	await board.animate_bonus_collection(position,standby_texture,standby_icon)
	standby_progress=mini(standby_progress+1,standby_requirement)
	_save(); _update_labels()
	if _complete() and not completing:
		completing=true
		await _complete_level()

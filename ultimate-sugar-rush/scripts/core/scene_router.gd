extends Node

signal transition_started(scene_path: String)
signal transition_finished(scene_path: String)

const DEFAULT_FADE_DURATION := 0.22

var _history: Array[String] = []
var _transitioning := false
var _overlay: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_transition_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _transitioning:
		if go_back():
			get_viewport().set_input_as_handled()


func go_to_scene(scene_path: String, remember_current: bool = true) -> void:
	if _transitioning or scene_path.is_empty():
		return
	var current_path: String = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	if remember_current and not current_path.is_empty() and current_path != scene_path:
		_history.push_back(current_path)
	_change_scene(scene_path)


func replace_scene(scene_path: String) -> void:
	go_to_scene(scene_path, false)


func go_back() -> bool:
	if _transitioning or _history.is_empty():
		return false
	var previous_path: String = _history.pop_back()
	_change_scene(previous_path)
	return true


func clear_history() -> void:
	_history.clear()


func _create_transition_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "SceneTransitionLayer"
	layer.layer = 1000
	add_child(layer)

	_overlay = ColorRect.new()
	_overlay.name = "SceneTransitionOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color("3f1a2a")
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)


func _change_scene(scene_path: String) -> void:
	_transitioning = true
	transition_started.emit(scene_path)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var fade_out: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.tween_property(_overlay, "modulate:a", 1.0, DEFAULT_FADE_DURATION)
	await fade_out.finished

	if scene_path.begins_with("res://scenes/merge/") or scene_path.begins_with("res://scenes/match3/"):
		CafeProgress.begin_board(scene_path)
	var result: Error = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		push_error("Unable to change scene to %s (error %s)." % [scene_path, result])
		_overlay.modulate.a = 0.0
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_transitioning = false
		return

	await get_tree().process_frame
	var fade_in: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in.tween_property(_overlay, "modulate:a", 0.0, DEFAULT_FADE_DURATION)
	await fade_in.finished

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
	transition_finished.emit(scene_path)

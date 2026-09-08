class_name TouchCameraController
extends Camera2D

signal zoom_changed(zoom_factor: float)
signal movement_started
signal movement_finished
signal tap_requested(screen_position: Vector2, world_position: Vector2)
signal long_press_requested(screen_position: Vector2, world_position: Vector2)

@export_group("Zoom")
@export_range(0.1, 4.0, 0.05) var min_zoom := 0.75
@export_range(0.1, 4.0, 0.05) var max_zoom := 1.85
@export_range(0.01, 0.5, 0.01) var wheel_zoom_step := 0.12

@export_group("Movement")
@export var world_bounds := Rect2(-1800.0, -500.0, 3600.0, 2600.0)
@export_range(0.0, 20.0, 0.5) var inertia_deceleration := 8.0
@export_range(0.0, 100.0, 1.0) var drag_threshold_pixels := 10.0
@export var enable_mouse_pan := true
@export var enable_keyboard_navigation := true
@export_range(100.0, 2000.0, 10.0) var keyboard_pan_speed := 720.0

@export_group("Persistence")
@export var persistence_key := "main_cafe"
@export var remember_view := true

var _touches: Dictionary = {}
var _pinch_distance := 0.0
var _pinch_center := Vector2.ZERO
var _pan_velocity := Vector2.ZERO
var _mouse_dragging := false
var _gesture_active := false
var _drag_distance := 0.0
var _initial_position := Vector2.ZERO
var _initial_zoom := 1.0
var _pinch_occurred := false
var _primary_touch_index := -1
var _primary_touch_position := Vector2.ZERO
var _focus_tween: Tween
var _save_timer: Timer
var _press_started_msec := 0


func _ready() -> void:
	make_current()
	_initial_position = position
	_initial_zoom = clampf(zoom.x, min_zoom, max_zoom)
	zoom = Vector2.ONE * _initial_zoom
	_create_save_timer()
	_load_view_state()
	_clamp_to_bounds()
	zoom_changed.emit(zoom.x)


func _exit_tree() -> void:
	_save_view_state()


func _process(delta: float) -> void:
	_process_keyboard(delta)
	if _touches.is_empty() and not _mouse_dragging and _pan_velocity.length_squared() > 1.0:
		position += _pan_velocity * delta
		_pan_velocity = _pan_velocity.lerp(Vector2.ZERO, clampf(inertia_deceleration * delta, 0.0, 1.0))
		_clamp_to_bounds()
	elif _pan_velocity.length_squared() <= 1.0:
		_pan_velocity = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_dragging:
		_pan_by_screen_delta(event.relative)
		_pan_velocity = -event.velocity / zoom.x
		_drag_distance += event.relative.length()
		get_viewport().set_input_as_handled()


func reset_view(animated: bool = true) -> void:
	_pan_velocity = Vector2.ZERO
	_cancel_focus_tween()
	if not animated:
		position = _initial_position
		_set_zoom(_initial_zoom, get_viewport_rect().size * 0.5)
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _initial_position, 0.28)
	tween.tween_property(self, "zoom", Vector2.ONE * _initial_zoom, 0.28)
	await tween.finished
	_clamp_to_bounds()
	zoom_changed.emit(zoom.x)
	_schedule_save()


func focus_on(world_position: Vector2, target_zoom: float = 1.35, duration: float = 0.34) -> void:
	_cancel_focus_tween()
	_pan_velocity = Vector2.ZERO
	var clamped_zoom := clampf(target_zoom, min_zoom, max_zoom)
	var target_position := _clamped_position(world_position, Vector2.ONE * clamped_zoom)
	_focus_tween = create_tween().set_parallel(true)
	_focus_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(self, "position", target_position, duration)
	_focus_tween.tween_property(self, "zoom", Vector2.ONE * clamped_zoom, duration)
	await _focus_tween.finished
	_clamp_to_bounds()
	zoom_changed.emit(zoom.x)
	_schedule_save()


func zoom_in(screen_focus: Vector2 = get_viewport_rect().size * 0.5) -> void:
	_set_zoom(zoom.x * (1.0 + wheel_zoom_step), screen_focus)


func zoom_out(screen_focus: Vector2 = get_viewport_rect().size * 0.5) -> void:
	_set_zoom(zoom.x / (1.0 + wheel_zoom_step), screen_focus)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_cancel_focus_tween()
		_touches[event.index] = event.position
		_pan_velocity = Vector2.ZERO
		if _touches.size() == 1:
			_press_started_msec = Time.get_ticks_msec()
			_primary_touch_index = event.index
			_primary_touch_position = event.position
			_drag_distance = 0.0
			_pinch_occurred = false
		else:
			_pinch_occurred = true
		if not _gesture_active:
			_gesture_active = true
			movement_started.emit()
	else:
		var should_tap := (
			event.index == _primary_touch_index
			and not _pinch_occurred
			and _drag_distance <= drag_threshold_pixels
		)
		_touches.erase(event.index)
		if should_tap:
			if Time.get_ticks_msec() - _press_started_msec >= 550:
				long_press_requested.emit(event.position, screen_to_world(event.position))
			else:
				tap_requested.emit(event.position, screen_to_world(event.position))
	if _touches.size() >= 2:
		_refresh_pinch_reference()
	elif _touches.size() == 1:
		_pinch_distance = 0.0
		_pinch_center = _touches.values()[0] as Vector2
	else:
		_pinch_distance = 0.0
		if _gesture_active:
			_gesture_active = false
			movement_finished.emit()
			_schedule_save()
	get_viewport().set_input_as_handled()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var previous_position: Vector2 = _touches[event.index]
	_touches[event.index] = event.position
	if _touches.size() == 1:
		var screen_delta := event.position - previous_position
		_pan_by_screen_delta(screen_delta)
		var frame_delta := maxf(get_process_delta_time(), 0.001)
		_pan_velocity = -screen_delta / zoom.x / frame_delta
		_drag_distance += screen_delta.length()
	elif _touches.size() >= 2:
		_apply_pinch()
	get_viewport().set_input_as_handled()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		zoom_in(event.position)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		zoom_out(event.position)
		get_viewport().set_input_as_handled()
	elif enable_mouse_pan and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
		_cancel_focus_tween()
		var was_dragging := _mouse_dragging
		_mouse_dragging = event.pressed
		_pan_velocity = Vector2.ZERO
		if event.pressed:
			_press_started_msec = Time.get_ticks_msec()
			_primary_touch_position = event.position
			_drag_distance = 0.0
			movement_started.emit()
		elif was_dragging:
			if event.button_index == MOUSE_BUTTON_LEFT and _drag_distance <= drag_threshold_pixels:
				if Time.get_ticks_msec() - _press_started_msec >= 550:
					long_press_requested.emit(event.position, screen_to_world(event.position))
				else:
					tap_requested.emit(event.position, screen_to_world(event.position))
			movement_finished.emit()
			_schedule_save()


func _apply_pinch() -> void:
	var points: Array[Vector2] = _first_two_touch_points()
	var new_distance: float = points[0].distance_to(points[1])
	var new_center: Vector2 = (points[0] + points[1]) * 0.5
	if _pinch_distance > 0.0:
		var scale_change: float = new_distance / _pinch_distance
		_set_zoom(zoom.x * scale_change, new_center)
		_pan_by_screen_delta(new_center - _pinch_center)
	_pinch_distance = new_distance
	_pinch_center = new_center
	_pan_velocity = Vector2.ZERO


func _refresh_pinch_reference() -> void:
	var points: Array[Vector2] = _first_two_touch_points()
	_pinch_distance = points[0].distance_to(points[1])
	_pinch_center = (points[0] + points[1]) * 0.5
	_pan_velocity = Vector2.ZERO


func _first_two_touch_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for value: Variant in _touches.values():
		var point: Vector2 = value as Vector2
		points.append(point)
		if points.size() == 2:
			break
	return points


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom.x
	_clamp_to_bounds()


func _set_zoom(target_zoom: float, screen_focus: Vector2) -> void:
	var old_zoom := zoom.x
	var new_zoom := clampf(target_zoom, min_zoom, max_zoom)
	if is_equal_approx(old_zoom, new_zoom):
		return
	var screen_offset := screen_focus - get_viewport_rect().size * 0.5
	position += screen_offset / old_zoom - screen_offset / new_zoom
	zoom = Vector2.ONE * new_zoom
	_clamp_to_bounds()
	zoom_changed.emit(new_zoom)
	_schedule_save()


func screen_to_world(screen_position: Vector2) -> Vector2:
	return position + (screen_position - get_viewport_rect().size * 0.5) / zoom


func _clamp_to_bounds() -> void:
	position = _clamped_position(position, zoom)


func _clamped_position(candidate: Vector2, zoom_value: Vector2) -> Vector2:
	var result := candidate
	var half_view := get_viewport_rect().size * 0.5 / zoom_value
	var minimum := world_bounds.position + half_view
	var maximum := world_bounds.end - half_view
	result.x = world_bounds.get_center().x if minimum.x > maximum.x else clampf(result.x, minimum.x, maximum.x)
	result.y = world_bounds.get_center().y if minimum.y > maximum.y else clampf(result.y, minimum.y, maximum.y)
	return result


func _process_keyboard(delta: float) -> void:
	if not enable_keyboard_navigation or not _touches.is_empty() or _mouse_dragging:
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction.is_zero_approx():
		return
	position += direction * keyboard_pan_speed * delta / zoom.x
	_pan_velocity = Vector2.ZERO
	_clamp_to_bounds()


func _create_save_timer() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.35
	_save_timer.timeout.connect(_save_view_state)
	add_child(_save_timer)


func _schedule_save() -> void:
	if remember_view and _save_timer:
		_save_timer.start()


func _save_view_state() -> void:
	if not remember_view or persistence_key.is_empty() or not is_inside_tree():
		return
	SaveSystem.set_value("camera_views", persistence_key, {
		"position_x": position.x,
		"position_y": position.y,
		"zoom": zoom.x,
	})


func _load_view_state() -> void:
	if not remember_view or persistence_key.is_empty():
		return
	var view_state: Variant = SaveSystem.get_value("camera_views", persistence_key, {})
	if not view_state is Dictionary or view_state.is_empty():
		return
	position = Vector2(
		float(view_state.get("position_x", _initial_position.x)),
		float(view_state.get("position_y", _initial_position.y))
	)
	var saved_zoom := float(view_state.get("zoom", _initial_zoom))
	zoom = Vector2.ONE * clampf(saved_zoom, min_zoom, max_zoom)


func _cancel_focus_tween() -> void:
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

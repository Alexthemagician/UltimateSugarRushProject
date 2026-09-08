extends TextureRect
class_name MergeItem

signal drag_started(item: MergeItem)
signal drag_moved(item: MergeItem, screen_position: Vector2)
signal drag_ended(item: MergeItem, screen_position: Vector2)

var item_id := "lemon"
var item_level := 1
var cell := Vector2i.ZERO
var dragging := false
var frozen := false
var _pointer_offset := Vector2.ZERO
var _home_position := Vector2.ZERO


func setup(definition: Dictionary, board_cell: Vector2i, item_texture: Texture2D) -> void:
	item_id = str(definition.get("id", "lemon"))
	item_level = int(definition.get("level", 1))
	cell = board_cell
	texture = item_texture
	tooltip_text = str(definition.get("name", item_id))
	_create_shadow()


func _create_shadow() -> void:
	var shadow := Panel.new()
	shadow.name = "ItemShadow"
	shadow.anchor_left = 0.22
	shadow.anchor_top = 0.76
	shadow.anchor_right = 0.78
	shadow.anchor_bottom = 0.90
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.10, 0.16, 0.15)
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	shadow.add_theme_stylebox_override("panel", style)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.show_behind_parent = true
	add_child(shadow)


func set_home_position(value: Vector2, animated := false) -> void:
	_home_position = value
	if animated:
		return_home()
	else:
		position = value


func return_home(animated := true) -> void:
	if not animated:
		position = _home_position
		scale = Vector2.ONE
		return
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _home_position, 0.20)
	tween.tween_property(self, "scale", Vector2.ONE, 0.16)
	tween.tween_property(self, "rotation", 0.0, 0.16)


func play_spawn() -> void:
	scale = Vector2(0.62, 0.62)
	modulate.a = 0.0
	position.y -= 18.0
	var target := _home_position
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target, 0.28)
	tween.tween_property(self, "scale", Vector2.ONE, 0.27)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)


func play_merge() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.18, 0.92), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.96, 1.08), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_frozen(value: bool) -> void:
	frozen = value
	queue_redraw()


func _draw() -> void:
	if not frozen:
		return
	draw_style_box(_ice_style(), Rect2(Vector2(5, 5), size - Vector2(10, 10)))
	var center := size * 0.5
	for angle_index in 6:
		var direction := Vector2.RIGHT.rotated(float(angle_index) * PI / 3.0)
		draw_line(center, center + direction * size.x * 0.31, Color("eaffffff"), 5.0, true)


func _ice_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("8bdff26b")
	style.border_color = Color("d9fbffdf")
	style.set_border_width_all(7)
	style.set_corner_radius_all(24)
	return style


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.global_position)
	elif event is InputEventMouseMotion and dragging:
		_move_drag(event.global_position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventScreenDrag and dragging:
		_move_drag(event.position)


func _begin_drag(local_pointer: Vector2) -> void:
	if frozen:
		var shake := create_tween()
		shake.tween_property(self, "rotation", -0.06, 0.06)
		shake.tween_property(self, "rotation", 0.06, 0.08)
		shake.tween_property(self, "rotation", 0.0, 0.06)
		return
	dragging = true
	_pointer_offset = local_pointer
	z_index = 100
	modulate = Color(1.08, 1.08, 1.08, 0.95)
	var lift := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lift.tween_property(self, "scale", Vector2(1.065, 1.065), 0.09)
	drag_started.emit(self)


func _move_drag(screen_position: Vector2) -> void:
	global_position = screen_position - _pointer_offset
	drag_moved.emit(self, screen_position)


func _end_drag(screen_position: Vector2) -> void:
	if not dragging:
		return
	dragging = false
	z_index = 2
	modulate = Color.WHITE
	drag_ended.emit(self, screen_position)

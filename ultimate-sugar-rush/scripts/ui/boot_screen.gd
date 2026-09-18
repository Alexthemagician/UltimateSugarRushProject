extends Control

signal boot_completed

const STATUS_MESSAGES: Array[String] = [
	"Unrolling the world map...",
	"Placing puzzle paths...",
	"Sprinkling anime magic...",
	"Your journey is ready!",
]

@onready var logo_card: PanelContainer = %LogoCard
@onready var pastry_mark: Label = %PastryMark
@onready var status_label: Label = %Status
@onready var progress_bar: ProgressBar = %Progress
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	get_viewport().size_changed.connect(_queue_background_redraw)
	continue_button.pressed.connect(_on_continue_pressed)
	_prepare_intro_state()
	_play_intro()


func _draw() -> void:
	var viewport_size := size
	var unit := minf(viewport_size.x, viewport_size.y) / 1000.0
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("fce2d4"))
	draw_circle(Vector2(viewport_size.x * 0.08, viewport_size.y * 0.12), 150.0 * unit, Color("f7c6cf80"))
	draw_circle(Vector2(viewport_size.x * 0.93, viewport_size.y * 0.20), 210.0 * unit, Color("fff0bd70"))
	draw_circle(Vector2(viewport_size.x * 0.12, viewport_size.y * 0.88), 230.0 * unit, Color("b9dbc875"))
	draw_circle(Vector2(viewport_size.x * 0.91, viewport_size.y * 0.84), 125.0 * unit, Color("e6a5b870"))


func _queue_background_redraw() -> void:
	queue_redraw()


func _prepare_intro_state() -> void:
	logo_card.modulate.a = 0.0
	logo_card.scale = Vector2(0.92, 0.92)
	logo_card.pivot_offset = logo_card.size * 0.5
	pastry_mark.rotation = -0.08
	progress_bar.value = 4.0
	continue_button.modulate.a = 0.0


func _play_intro() -> void:
	var intro := create_tween().set_parallel(true)
	intro.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(logo_card, "modulate:a", 1.0, 0.6)
	intro.tween_property(logo_card, "scale", Vector2.ONE, 0.7)
	intro.tween_property(pastry_mark, "rotation", 0.0, 0.8)

	var loading := create_tween()
	for index in STATUS_MESSAGES.size():
		loading.tween_callback(_set_loading_step.bind(index))
		loading.tween_property(
			progress_bar,
			"value",
			float(index + 1) / float(STATUS_MESSAGES.size()) * 100.0,
			0.38
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loading.tween_callback(_finish_boot)


func _set_loading_step(index: int) -> void:
	status_label.text = STATUS_MESSAGES[index]


func _finish_boot() -> void:
	continue_button.visible = true
	continue_button.grab_focus()
	var reveal := create_tween()
	reveal.tween_property(continue_button, "modulate:a", 1.0, 0.3)
	boot_completed.emit()


func _on_continue_pressed() -> void:
	if not _has_cafe_name():
		_show_cafe_name_prompt()
		return
	_enter_cafe()


func _has_cafe_name() -> bool:
	return not str(SaveSystem.get_value("cafe_profile", "name", "")).strip_edges().is_empty()


func _show_cafe_name_prompt() -> void:
	continue_button.disabled = true
	var shade := ColorRect.new()
	shade.name = "CafeNamePrompt"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.18, 0.07, 0.11, 0.72)
	add_child(shade)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 360)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-380, -180)
	shade.add_child(card)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 38)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Name your café"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "This is the name other chefs will see when they visit."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 25)
	column.add_child(hint)
	var input := LineEdit.new()
	input.name = "CafeNameInput"
	input.placeholder_text = "Your café name"
	input.max_length = 32
	input.custom_minimum_size = Vector2(0, 72)
	input.add_theme_font_size_override("font_size", 28)
	column.add_child(input)
	var start := Button.new()
	start.name = "StartCafeButton"
	start.text = "Open my café"
	start.custom_minimum_size = Vector2(0, 78)
	start.add_theme_font_size_override("font_size", 29)
	column.add_child(start)
	var submit := func() -> void:
		var cafe_name := input.text.strip_edges()
		if cafe_name.length() < 1:
			input.placeholder_text = "Please enter a café name"
			input.grab_focus()
			return
		SaveSystem.set_value("cafe_profile", "name", cafe_name)
		SaveSystem.save_now()
		shade.queue_free()
		_enter_cafe()
	start.pressed.connect(submit)
	input.text_submitted.connect(func(_value: String) -> void: submit.call())
	input.grab_focus()


func _enter_cafe() -> void:
	status_label.text = "Your Sugar Blossom journey is ready!"
	continue_button.disabled = true
	SceneRouter.go_to_scene(CafeProgress.HUB)

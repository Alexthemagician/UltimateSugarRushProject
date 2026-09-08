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
	status_label.text = "Your Sugar Blossom journey is ready!"
	continue_button.disabled = true
	SceneRouter.go_to_scene("res://scenes/map/world_map.tscn")

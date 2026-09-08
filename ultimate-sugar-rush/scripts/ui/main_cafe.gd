extends Node2D

@onready var camera: TouchCameraController = %TouchCamera
@onready var world: CafeWorldPreview = %World
@onready var zoom_label: Label = %ZoomLabel
@onready var help_panel: Control = %HelpPanel
@onready var station_panel: Control = %StationPanel
@onready var station_title: Label = %StationTitle
@onready var settings_panel: Control = %SettingsPanel
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var notifications_toggle: CheckButton = %NotificationsToggle
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SfxValue
@onready var bakery_edit_panel: Control = %BakeryEditPanel
@onready var bakery_edit_status: Label = %BakeryEditStatus


func _ready() -> void:
	camera.zoom_changed.connect(_update_zoom_label)
	camera.zoom_changed.connect(_on_camera_zoom_changed)
	camera.tap_requested.connect(_on_world_tapped)
	camera.long_press_requested.connect(_on_world_long_pressed)
	world.station_selected.connect(_on_station_selected)
	world.bakery_edit_requested.connect(_open_bakery_editor)
	world.bakery_placement_changed.connect(_on_bakery_placement_changed)
	%ZoomInButton.pressed.connect(camera.zoom_in)
	%ZoomOutButton.pressed.connect(camera.zoom_out)
	%ResetButton.pressed.connect(camera.reset_view)
	%BackButton.pressed.connect(_go_back)
	%DismissHelpButton.pressed.connect(_dismiss_help)
	%CloseStationButton.pressed.connect(_close_station_panel)
	%OrderButton.pressed.connect(_focus_order_station)
	%SettingsButton.pressed.connect(_open_settings)
	%MergeButton.pressed.connect(_open_merge_game)
	%CloseSettingsButton.pressed.connect(_close_settings)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	notifications_toggle.toggled.connect(GameSettings.set_notifications_enabled)
	%MoveBakeryButton.pressed.connect(_start_bakery_move)
	%RotateBakeryButton.pressed.connect(_rotate_bakery)
	%CloseBakeryEditButton.pressed.connect(_close_bakery_editor)
	_sync_settings_controls()
	_update_zoom_label(camera.zoom.x)


func _update_zoom_label(value: float) -> void:
	zoom_label.text = "%d%%" % roundi(value * 100.0)


func _on_camera_zoom_changed(_value: float) -> void:
	world.queue_redraw()


func _go_back() -> void:
	if not SceneRouter.go_back():
		SceneRouter.replace_scene("res://scenes/app/boot_screen.tscn")


func _dismiss_help() -> void:
	help_panel.visible = false


func _on_world_tapped(_screen_position: Vector2, world_position: Vector2) -> void:
	if bakery_edit_panel.visible and world.try_place_bakery_at(world_position):
		return
	if not world.select_at_world_position(world_position):
		_close_station_panel()


func _on_world_long_pressed(_screen_position: Vector2, world_position: Vector2) -> void:
	world.request_edit_at(world_position)


func _on_station_selected(station_id: String, display_name: String, world_position: Vector2) -> void:
	station_title.text = display_name.to_upper()
	station_panel.visible = true
	camera.focus_on(world_position, world.get_station_focus_zoom(station_id))


func _focus_order_station() -> void:
	help_panel.visible = false
	world.select_station("lemon_bar")


func _close_station_panel() -> void:
	station_panel.visible = false


func _open_settings() -> void:
	_sync_settings_controls()
	settings_panel.visible = true


func _close_settings() -> void:
	settings_panel.visible = false
	SaveSystem.save_now()


func _open_merge_game() -> void:
	SceneRouter.go_to_scene("res://scenes/merge/merge_game.tscn")


func _sync_settings_controls() -> void:
	music_slider.set_value_no_signal(GameSettings.music_volume * 100.0)
	sfx_slider.set_value_no_signal(GameSettings.sfx_volume * 100.0)
	notifications_toggle.set_pressed_no_signal(GameSettings.notifications_enabled)
	_update_volume_label(music_value, GameSettings.music_volume)
	_update_volume_label(sfx_value, GameSettings.sfx_volume)


func _on_music_volume_changed(value: float) -> void:
	GameSettings.set_music_volume(value / 100.0)
	_update_volume_label(music_value, GameSettings.music_volume)


func _on_sfx_volume_changed(value: float) -> void:
	GameSettings.set_sfx_volume(value / 100.0)
	_update_volume_label(sfx_value, GameSettings.sfx_volume)


func _update_volume_label(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(value * 100.0)


func _open_bakery_editor() -> void:
	station_panel.visible = false
	bakery_edit_panel.visible = true
	bakery_edit_status.text = "Choose move or rotate."


func _start_bakery_move() -> void:
	world.set_bakery_move_mode(true)
	bakery_edit_status.text = "Tap a highlighted free floor space."


func _rotate_bakery() -> void:
	world.rotate_bakery()


func _on_bakery_placement_changed(is_valid: bool) -> void:
	bakery_edit_status.text = "Placement saved." if is_valid else "That space is occupied. Try another tile."


func _close_bakery_editor() -> void:
	world.close_bakery_edit()
	bakery_edit_panel.visible = false

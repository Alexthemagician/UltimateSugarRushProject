extends Control

@onready var message_panel: Control = %MessagePanel
@onready var message_label: Label = %MessageLabel


func _ready() -> void:
	_reconcile_saved_unlocks()
	%Level1.pressed.connect(_open_merge_board)
	var level_2_unlocked := bool(SaveSystem.get_value("progression", "level_2_unlocked", false))
	if level_2_unlocked:
		%Level2.pressed.connect(_open_cake_board)
		%Level2.add_theme_stylebox_override("normal", %Level1.get_theme_stylebox("normal"))
		%Level2.add_theme_stylebox_override("hover", %Level1.get_theme_stylebox("hover"))
		%Level2.add_theme_stylebox_override("pressed", %Level1.get_theme_stylebox("pressed"))
	else:
		%Level2.pressed.connect(_show_locked.bind(%Level2.text))
	var level_3_unlocked := bool(SaveSystem.get_value("progression", "level_3_unlocked", false))
	if level_3_unlocked:
		%Level3.pressed.connect(_open_cookie_board)
		%Level3.add_theme_stylebox_override("normal", %Level1.get_theme_stylebox("normal"))
		%Level3.add_theme_stylebox_override("hover", %Level1.get_theme_stylebox("hover"))
		%Level3.add_theme_stylebox_override("pressed", %Level1.get_theme_stylebox("pressed"))
	else:
		%Level3.pressed.connect(_show_locked.bind(%Level3.text))
	var level_4_unlocked := bool(SaveSystem.get_value("progression", "level_4_unlocked", false))
	if level_4_unlocked:
		%Level4.pressed.connect(_open_ice_cream_board)
		%Level4.add_theme_stylebox_override("normal", %Level1.get_theme_stylebox("normal"))
		%Level4.add_theme_stylebox_override("hover", %Level1.get_theme_stylebox("hover"))
		%Level4.add_theme_stylebox_override("pressed", %Level1.get_theme_stylebox("pressed"))
	else:
		%Level4.pressed.connect(_show_locked.bind(%Level4.text))
	# Level 5 remains directly available during development and is also persisted
	# by completing Frozen Scoops.
	SaveSystem.set_value("progression", "level_5_unlocked", true)
	%Level5.pressed.connect(_open_mixed_board)
	%Level5.add_theme_stylebox_override("normal", %Level1.get_theme_stylebox("normal"))
	%Level5.add_theme_stylebox_override("hover", %Level1.get_theme_stylebox("hover"))
	%Level5.add_theme_stylebox_override("pressed", %Level1.get_theme_stylebox("pressed"))
	# Board 6 is directly available while its new match-three mechanics are developed.
	SaveSystem.set_value("progression", "level_6_unlocked", true)
	%Level6.pressed.connect(_open_candy_match_board)
	%Level6.add_theme_stylebox_override("normal", %Level1.get_theme_stylebox("normal"))
	%Level6.add_theme_stylebox_override("hover", %Level1.get_theme_stylebox("hover"))
	%Level6.add_theme_stylebox_override("pressed", %Level1.get_theme_stylebox("pressed"))
	# Boards 7 and 8 remain directly available while their advanced match-three
	# mechanics are tuned; completion still persists the normal progression flags.
	SaveSystem.set_value("progression", "level_7_unlocked", true)
	SaveSystem.set_value("progression", "level_8_unlocked", true)
	%Level7.pressed.connect(_open_gummy_match_board)
	%Level8.pressed.connect(_open_marshmallow_match_board)
	for button: Button in [%Level7, %Level8]:
		button.add_theme_stylebox_override("normal", %Level1.get_theme_stylebox("normal"))
		button.add_theme_stylebox_override("hover", %Level1.get_theme_stylebox("hover"))
		button.add_theme_stylebox_override("pressed", %Level1.get_theme_stylebox("pressed"))
	%SettingsButton.pressed.connect(_show_settings_note)
	%CloseMessageButton.pressed.connect(func() -> void: message_panel.visible = false)
	%CollectionsButton.pressed.connect(_open_collections)
	%CloseCollectionsButton.pressed.connect(func() -> void: %CollectionsPanel.visible = false)
	var collectible_rewards: Node = get_node("/root/CollectibleRewards")
	%CollectionsButton.visible = not collectible_rewards.get_collection().is_empty()


func _reconcile_saved_unlocks() -> void:
	var cookie_objectives := SaveSystem.get_section("cookie_merge_objectives")
	var cookie_boxes := [
		"chocolate_chip_cookie_box",
		"pink_sugar_cookie_box",
		"sandwich_cookie_box",
		"lucky_cookie_box",
	]
	for item_id: String in cookie_boxes:
		if int(cookie_objectives.get(item_id, 0)) < 8:
			return
	SaveSystem.set_value("progression", "level_3_complete", true)
	SaveSystem.set_value("progression", "level_4_unlocked", true)
	SaveSystem.save_now()


func _open_merge_board() -> void:
	SceneRouter.go_to_scene("res://scenes/merge/merge_game.tscn")


func _open_cake_board() -> void:
	SceneRouter.go_to_scene("res://scenes/merge/cake_merge_game.tscn")


func _open_cookie_board() -> void:
	SceneRouter.go_to_scene("res://scenes/merge/cookie_merge_game.tscn")


func _open_ice_cream_board() -> void:
	SceneRouter.go_to_scene("res://scenes/merge/ice_cream_merge_game.tscn")


func _open_mixed_board() -> void:
	SceneRouter.go_to_scene("res://scenes/merge/mixed_merge_game.tscn")


func _open_candy_match_board() -> void:
	SceneRouter.go_to_scene("res://scenes/match3/candy_match_game.tscn")


func _open_gummy_match_board() -> void:
	SceneRouter.go_to_scene("res://scenes/match3/gummy_match_game.tscn")


func _open_marshmallow_match_board() -> void:
	SceneRouter.go_to_scene("res://scenes/match3/marshmallow_match_game.tscn")


func _show_locked(level_label: String) -> void:
	message_label.text = "Level %s is coming soon!\nComplete the earlier puzzles to unlock the path." % level_label
	message_panel.visible = true


func _show_settings_note() -> void:
	message_label.text = "Map settings will use your saved music, sound, and notification preferences."
	message_panel.visible = true


func _open_collections() -> void:
	for child: Node in %Grid.get_children():
		child.queue_free()
	var collectible_rewards: Node = get_node("/root/CollectibleRewards")
	var collection: Dictionary = collectible_rewards.get_collection()
	var catalog: Dictionary = collectible_rewards.CATALOG
	for item_id: String in catalog:
		var data: Dictionary = catalog[item_id]
		var count := int(collection.get(item_id, 0))
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(420, 300)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(0, 215)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		icon.texture = load(data.texture)
		if count == 0:
			icon.modulate = Color(0.24, 0.24, 0.24, 0.42)
		var label := Label.new()
		label.text = "%s%s" % [str(data.name), "  x%d" % count if count > 1 else ""]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 23)
		label.add_theme_color_override("font_color", Color("64213d"))
		if count == 0:
			label.modulate = Color(0.42, 0.42, 0.42, 0.72)
		card.add_child(icon)
		card.add_child(label)
		%Grid.add_child(card)
	%CollectionsPanel.visible = true

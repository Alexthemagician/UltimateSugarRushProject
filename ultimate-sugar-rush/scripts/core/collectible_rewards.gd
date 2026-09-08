extends Node

const SAVE_SECTION := "collections"
const CATALOG := {
	"autumn_harvest": {"name":"Autumn Harvest", "description":"Basket of vegetables", "texture":"res://assets/collectibles/autumn_harvest.png"},
	"summer_fruits": {"name":"Summer Fruits", "description":"Basket of summer fruits", "texture":"res://assets/collectibles/summer_fruits.png"},
	"berry_sweets": {"name":"Berry Sweets", "description":"Bowl of mixed berries", "texture":"res://assets/collectibles/berry_sweets.png"},
	"sugar_sack": {"name":"Sugar Sack", "description":"A large sugar package", "texture":"res://assets/collectibles/sugar_sack.png"},
	"honey_pot": {"name":"Honey Pot", "description":"A golden pot of honey", "texture":"res://assets/collectibles/honey_pot.png"},
	"flour_mill": {"name":"Flour Mill", "description":"A whimsical flour mill", "texture":"res://assets/collectibles/flour_mill.png"},
	"cookie_jar_collectible": {"name":"Cookie Jar", "description":"Jar of assorted cookies", "texture":"res://assets/collectibles/cookie_jar_collectible.png"},
	"waffle_jacks": {"name":"Waffle Jacks", "description":"A stack of waffles", "texture":"res://assets/collectibles/waffle_jacks.png"},
	"smart_tarts": {"name":"Smart Tarts", "description":"Box of assorted tarts", "texture":"res://assets/collectibles/smart_tarts.png"},
	"cinnamon_yums": {"name":"Cinnamon Yums", "description":"Plate of cinnamon buns", "texture":"res://assets/collectibles/cinnamon_yums.png"},
}

func get_collection() -> Dictionary:
	var value: Variant = SaveSystem.get_value(SAVE_SECTION, "items", {})
	return value.duplicate(true) if value is Dictionary else {}

func award_random() -> String:
	var collection := get_collection()
	var candidates: Array[String] = []
	for item_id: String in CATALOG:
		if int(collection.get(item_id, 0)) == 0: candidates.append(item_id)
	if candidates.is_empty(): candidates.assign(CATALOG.keys())
	var awarded: String = candidates.pick_random()
	collection[awarded] = int(collection.get(awarded, 0)) + 1
	SaveSystem.set_value(SAVE_SECTION, "items", collection)
	SaveSystem.save_now()
	return awarded

func play_completion(root: Control, board: Control, message: String) -> void:
	await board.play_completion_clear()
	var item_id := award_random()
	var data: Dictionary = CATALOG[item_id]
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.12, 0.06, 0.12, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var title := Label.new()
	title.text = message
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color("fff0a8"))
	title.position = Vector2(90, 350)
	title.size = Vector2(900, 100)
	shade.add_child(title)
	var image := TextureRect.new()
	image.texture = load(data.texture)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	image.position = Vector2(290, 510)
	image.size = Vector2(500, 500)
	image.pivot_offset = image.size * 0.5
	image.scale = Vector2(0.1, 0.1)
	shade.add_child(image)
	var reward_name := Label.new()
	reward_name.text = "NEW COLLECTIBLE!\n" + str(data.name)
	reward_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_name.add_theme_font_size_override("font_size", 38)
	reward_name.add_theme_color_override("font_color", Color.WHITE)
	reward_name.position = Vector2(90, 1040)
	reward_name.size = Vector2(900, 130)
	shade.add_child(reward_name)
	var pop := root.create_tween()
	pop.tween_property(image, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	await root.get_tree().create_timer(1.1).timeout
	var target := Vector2(root.get_viewport_rect().size.x - 150, 70)
	var collect := root.create_tween().set_parallel(true)
	collect.tween_property(image, "global_position", target, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	collect.tween_property(image, "scale", Vector2(0.18, 0.18), 0.65)
	collect.tween_property(shade, "modulate:a", 0.0, 0.72)
	await collect.finished
	layer.queue_free()

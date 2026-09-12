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
	var receipt := CafeProgress.award_board(root.scene_file_path)
	await board.play_completion_clear()
	var item_id := award_random()
	var overlay := build_completion_overlay(root,message,item_id,receipt)
	var image: TextureRect = overlay.image
	image.scale = Vector2(0.1,0.1)
	var pop := root.create_tween()
	pop.tween_property(image,"scale",Vector2.ONE,0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	await root.get_tree().create_timer(2.0).timeout
	var target := Vector2(root.get_viewport_rect().size.x-150,70)
	var collect := root.create_tween().set_parallel(true)
	collect.tween_property(image,"global_position",target,0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	collect.tween_property(image,"scale",Vector2(0.18,0.18),0.65)
	collect.tween_property(overlay.shade,"modulate:a",0.0,0.72)
	await collect.finished
	overlay.layer.queue_free()

func _reward_texture(index: int, stock: bool) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/cafe/stock_atlas.png" if stock else "res://assets/cafe/menu_atlas.png")
	var columns := 6 if stock else 5
	var rows := 4 if stock else 2
	var tile := Vector2(texture.atlas.get_width()/float(columns),texture.atlas.get_height()/float(rows))
	texture.region = Rect2(Vector2(index%columns,index/columns)*tile,tile)
	texture.filter_clip = true
	return texture

func _reward_label(text: String, p: Vector2, dimensions: Vector2, font_size: int, parent: Node, color := Color("653f50")) -> Label:
	var node := Label.new()
	node.text = text
	node.position = p
	node.size = dimensions
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node

func _reward_icon(id: String, texture: Texture2D, p: Vector2, dimensions: Vector2, parent: Node) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "RewardIcon_"+id
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = texture
	icon.position = p
	icon.size = dimensions
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(icon)
	return icon

func build_completion_overlay(root: Control, message: String, item_id: String, receipt: Dictionary) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "CompletionRewards"
	layer.layer = 100
	root.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.12,0.06,0.12,0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var content := Control.new()
	content.position = Vector2(maxf(0,(root.get_viewport_rect().size.x-1920)*0.5),maxf(0,(root.get_viewport_rect().size.y-1080)*0.5))
	content.size = Vector2(1920,1080)
	shade.add_child(content)
	var title := _reward_label(message,Vector2(60,70),Vector2(1800,120),50,content,Color("fff0a8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var data: Dictionary = CATALOG[item_id]
	var image := _reward_icon(item_id,load(data.texture),Vector2(180,270),Vector2(420,420),content)
	image.pivot_offset = image.size*0.5
	var reward_name := _reward_label("COLLECTIBLE RECEIVED!\n"+str(data.name),Vector2(60,750),Vector2(670,130),36,content,Color.WHITE)
	reward_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not receipt.is_empty():
		var panel := Panel.new()
		panel.name = "PantryRewards"
		panel.position = Vector2(800,280)
		panel.size = Vector2(960,540)
		var background := StyleBoxFlat.new()
		background.bg_color = Color("fff3e6")
		background.set_corner_radius_all(26)
		panel.add_theme_stylebox_override("panel",background)
		content.add_child(panel)
		_reward_icon("coins",_reward_texture(9,false),Vector2(55,25),Vector2(80,80),panel)
		_reward_label("+%d" % int(receipt.coins),Vector2(150,40),Vector2(300,60),37,panel).name = "RewardAmount_coins"
		_reward_icon("xp",load("res://assets/cafe/xp_star.svg"),Vector2(510,25),Vector2(80,80),panel)
		_reward_label("+%d XP" % int(receipt.xp),Vector2(605,40),Vector2(290,60),37,panel).name = "RewardAmount_xp"
		var row := 0
		for id: String in receipt.ingredients:
			_reward_icon(id,_reward_texture(CafeProgress.INGREDIENTS.keys().find(id),true),Vector2(60,130+row*125),Vector2(98,98),panel)
			_reward_label("%s  ×%d" % [CafeProgress.INGREDIENTS[id],receipt.ingredients[id]],Vector2(180,150+row*125),Vector2(720,85),31,panel).name = "RewardAmount_"+id
			row += 1
	return {"layer":layer,"shade":shade,"image":image}

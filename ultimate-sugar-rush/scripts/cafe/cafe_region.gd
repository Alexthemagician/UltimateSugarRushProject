extends "res://scripts/cafe/cafe_hub.gd"

const ORIGINAL_BOARDS := ["res://scenes/merge/merge_game.tscn","res://scenes/merge/cake_merge_game.tscn","res://scenes/merge/cookie_merge_game.tscn","res://scenes/merge/ice_cream_merge_game.tscn","res://scenes/merge/mixed_merge_game.tscn","res://scenes/match3/candy_match_game.tscn","res://scenes/match3/gummy_match_game.tscn","res://scenes/match3/marshmallow_match_game.tscn"]
const ORIGINAL_NAMES := ["Sweet beginnings","Cake delights","Cookie kitchen","Frozen scoops","Mixed treats","Candy match","Gummy garden","Marshmallow magic"]
var positions: Array[Vector2] = [Vector2(290,470),Vector2(630,660),Vector2(350,860),Vector2(680,1080),Vector2(400,1290),Vector2(650,1490)]

func _ready() -> void:
	var region := CafeProgress.region
	# Coordinates follow each painted route, normalized to the landscape canvas.
	var routes := [
		[Vector2(170,630),Vector2(280,450),Vector2(500,455),Vector2(710,531),Vector2(920,514),Vector2(1140,584),Vector2(1370,520),Vector2(1530,370)],
		[Vector2(1290,750),Vector2(1030,733),Vector2(600,698),Vector2(245,500),Vector2(695,424),Vector2(1000,276),Vector2(1310,235),Vector2(1500,390)],
		[Vector2(1280,775),Vector2(800,690),Vector2(300,550),Vector2(320,370),Vector2(790,280),Vector2(1250,300),Vector2(1460,470),Vector2(1510,690)]
	]
	positions.clear()
	for point: Vector2 in routes[region]: positions.append(point * Vector2(1920.0/1672.0,1080.0/941.0))
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture = load(MAP_ART[region])
	art.position = Vector2.ZERO
	art.size = Vector2(1920,1080)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var header := Panel.new()
	header.name = "MapHeader"
	header.position = Vector2(25,20)
	header.size = Vector2(675,125)
	header.add_theme_stylebox_override("panel",style(Color(1.0,0.95,0.89,0.94)))
	add_child(header)
	label(CafeProgress.REGIONS[region].name,Vector2(45,28),Vector2(620,60),40)
	label(CafeProgress.REGIONS[region].subtitle,Vector2(45,87),Vector2(620,45),22)
	button("← Café",Vector2(1680,25),Vector2(210,80),func() -> void: SceneRouter.replace_scene(CafeProgress.HUB)).name = "CafeBackButton"
	for i in positions.size():
		var complete := CafeProgress.stage_complete(region,i)
		var unlocked := CafeProgress.stage_unlocked_for(region,i)
		var played_today := CafeProgress.stage_played_today(region,i)
		var open := unlocked and not played_today
		var node := button("%d%s" % [i+1,"  ✓" if complete else ""],positions[i]-Vector2(53,53),Vector2(106,106),_open_stage.bind(i))
		node.name = "Level%d" % (i+1)
		node.disabled = not open
		node.add_theme_font_size_override("font_size",38)
		node.add_theme_stylebox_override("normal",style(Color("e9759e") if open else Color("bcb4bd")))
		node.add_theme_color_override("font_color",Color.WHITE)
		var honeydew_names := ["Fruit-pie picnic","Ice-cream social","Flavored bakery","Boba & syrup café","Macaron match","Jelly donuts","Glacier ice pops","Chocolate-crust tarts"]
		var cocoa_names := ["Moonlit juice bar","Cream macaron atelier","Chocolate box boutique","Cotton-candy gala","Gelatin moon","Frozen slushies","Layer-cake soirée","Midnight bakery"]
		var region_names: Array = honeydew_names if region==1 else cocoa_names
		var caption_text: String = ORIGINAL_NAMES[i] if region==0 else region_names[i]
		if played_today: caption_text = "Played today"
		elif i==7: caption_text = "Unlimited harvest"
		var caption := label(caption_text,positions[i]+Vector2(-108,58),Vector2(216,48),20)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_stylebox_override("normal",style(Color(1.0,0.96,0.90,0.94)))
	var names: Array[String] = []
	for id: String in CafeProgress.POOLS[region]: names.append(CafeProgress.INGREDIENTS[id])
	var footer := Panel.new()
	footer.name = "IngredientFooter"
	footer.position = Vector2(25,975)
	footer.size = Vector2(1870,85)
	footer.add_theme_stylebox_override("panel",style(Color(1.0,0.95,0.89,0.96)))
	add_child(footer)
	for i in 6:
		var id: String = CafeProgress.POOLS[region][i]
		stock_image(CafeProgress.INGREDIENTS.keys().find(id),Vector2(40+i*310,983),Vector2(65,65),self)
		label(CafeProgress.INGREDIENTS[id],Vector2(112+i*310,992),Vector2(220,58),22)
	for child: Control in get_children(): design_positions[child] = child.position
	resized.connect(_center_map_layout)
	_center_map_layout()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("e1efe0") if CafeProgress.region==1 else Color("e7ddf0"))

func _open_stage(index: int) -> void:
	if CafeProgress.region==0:
		if CafeProgress.claim_daily_entry(0,index):
			CafeProgress.stage = index
			if index == 7: SaveSystem.set_section("marshmallow_match_objectives",{})
			CafeProgress.begin_board(ORIGINAL_BOARDS[index])
			CafeProgress.stage = index
			SceneRouter.go_to_scene(ORIGINAL_BOARDS[index])
	else: CafeProgress.open_stage(index)


func _center_map_layout() -> void:
	var offset := (size - Vector2(1920,1080)) * 0.5
	for child in design_positions:
		if is_instance_valid(child): child.position = design_positions[child] + offset

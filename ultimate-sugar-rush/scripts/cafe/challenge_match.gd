extends "res://scripts/ui/variant_match_game.gd"

const PROFILES := [
	{"name":"First harvest", "targets":[18,12,12,12], "moves":42, "locks":[]},
	{"name":"Corner pockets", "targets":[16,24,14,14], "moves":42, "locks":[Vector2i(1,1),Vector2i(6,1),Vector2i(1,6),Vector2i(6,6)]},
	{"name":"Garden zigzag", "targets":[18,18,30,16], "moves":43, "locks":[Vector2i(1,1),Vector2i(3,2),Vector2i(5,1),Vector2i(2,5),Vector2i(4,6),Vector2i(6,5)]},
	{"name":"Crossed paths", "targets":[22,18,20,34], "moves":44, "locks":[Vector2i(3,1),Vector2i(4,1),Vector2i(2,2),Vector2i(5,2),Vector2i(2,5),Vector2i(5,5),Vector2i(3,6),Vector2i(4,6)]},
	{"name":"Walled orchard", "targets":[32,24,22,26], "moves":45, "locks":[Vector2i(1,2),Vector2i(2,2),Vector2i(5,2),Vector2i(6,2),Vector2i(1,5),Vector2i(2,5),Vector2i(5,5),Vector2i(6,5)]},
	{"name":"Moving market", "targets":[30,36,28,28], "moves":47, "shift":true, "locks":[Vector2i(0,2),Vector2i(2,2),Vector2i(5,2),Vector2i(7,2),Vector2i(1,5),Vector2i(3,5),Vector2i(4,5),Vector2i(6,5)]},
	{"name":"Master recipe", "targets":[40,34,42,34], "moves":49, "shift":true, "locks":[Vector2i(0,1),Vector2i(2,1),Vector2i(5,1),Vector2i(7,1),Vector2i(1,3),Vector2i(3,3),Vector2i(4,3),Vector2i(6,3),Vector2i(0,6),Vector2i(2,6),Vector2i(5,6),Vector2i(7,6)]},
	{"name":"Unlimited harvest", "targets":[95,95,95,95], "moves":55, "shift":true, "locks":[Vector2i(0,1),Vector2i(2,1),Vector2i(4,1),Vector2i(6,1),Vector2i(1,3),Vector2i(3,3),Vector2i(5,3),Vector2i(7,3),Vector2i(0,5),Vector2i(2,5),Vector2i(5,5),Vector2i(7,5)]},
]

func _ready() -> void:
	var region := CafeProgress.region
	var stage := CafeProgress.stage
	var profile: Dictionary = PROFILES[clampi(stage,0,PROFILES.size()-1)]
	objective_requirements.clear()
	for requirement: int in profile.targets:
		objective_requirements.append(requirement + (region-1)*4)
	target = objective_requirements.max()
	move_limit = int(profile.moves)
	save_section = "cafe_challenge_%d_%d" % [region,stage]
	completion_flag = "cafe_region_%d_stage_%d_complete" % [region,stage]
	unlock_flag = "cafe_region_%d_stage_%d_unlocked" % [region,stage+1]
	completion_message = "GARDEN GOODNESS!" if region==1 else "MOONLIGHT MAGIC!"
	initial_locks.assign(profile.locks)
	shift_bottom_row = bool(profile.get("shift",false)) or (region==2 and stage>=4)
	piece_textures.clear()
	piece_names.clear()
	standby_name=""; standby_texture=null; standby_requirement=0
	if region == 1 and stage >= 4:
		_configure_honeydew_match(stage)
	elif region == 2 and stage >= 4:
		_configure_cocoa_match(stage)
	else:
		var ingredient_pool: Array = CafeProgress.POOLS[region]
		for offset in 4:
			var ingredient_id: String = ingredient_pool[(stage+offset)%ingredient_pool.size()]
			piece_textures.append(_ingredient_texture(ingredient_id))
			piece_names.append(CafeProgress.INGREDIENTS[ingredient_id].to_upper())
	target=objective_requirements.max()
	super._ready()
	if region==1 and stage>=5:
		board.set_interaction_enabled(false)
		_show_rule_tutorial.call_deferred(stage)
	for connection in %BackButton.pressed.get_connections(): %BackButton.pressed.disconnect(connection.callable)
	%BackButton.pressed.connect(func() -> void: SceneRouter.replace_scene("res://scenes/map/cafe_region.tscn"))
	var header := get_node("LandscapeLayout/Header/Title") as Label
	var profile_name: String = profile.name
	if region==2 and stage>=4:
		profile_name=["Gelatin moon","Frozen slushies","Layer-cake soirée","Midnight bakery"][stage-4]
	if header: header.text = "%s • %d — %s" % [CafeProgress.REGIONS[region].name,stage+1,profile_name]
	# Regional match boards reserve a real footer beneath the grid for their
	# power hint or board-specific one-line rule.
	board.scale=Vector2.ONE*0.86
	board.position=Vector2(220,175)
	var board_rules := find_child("Rules",true,false) as Label
	board_rules.position=Vector2(220,955); board_rules.size=Vector2(774,75); board_rules.z_index=5
	if moves_remaining > 0:
		if region==2 and stage==4:
			%StatusLabel.text="Clear the four gelatin orders before moves run out."
			board_rules.text="TIP: Match beside the connected jelly chunk to reveal the gelatin underneath."
		elif region==2 and stage==5:
			%StatusLabel.text="Clear the four frozen slushie orders before moves run out."
			board_rules.text="TIP: Match beside the glacier to crack the ice and unlock the slushies."
		elif region==2 and stage>=6: %StatusLabel.text="Make matches of 4 or more to create the special standby dessert."
		else: %StatusLabel.text = "Clear the four ingredient orders. Each board has a different featured ingredient and layout."

func _ingredient_texture(ingredient_id: String) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/cafe/stock_atlas.png")
	var index := CafeProgress.INGREDIENTS.keys().find(ingredient_id)
	var tile := Vector2(texture.atlas.get_width()/6.0,texture.atlas.get_height()/4.0)
	texture.region = Rect2(Vector2(index%6,index/6)*tile,tile)
	texture.filter_clip = true
	return texture

func _configure_honeydew_match(stage_index: int) -> void:
	var sets := {
		4:[["blueberry_macaron","Blueberry macaron"],["lemon_macaron","Lemon macaron"],["strawberry_macaron","Strawberry macaron"],["matcha_macaron","Matcha macaron"]],
		5:[["powdered_donut","Powdered sugar"],["red_velvet_donut","Red velvet"],["vanilla_drizzle_donut","Vanilla drizzle"],["cruller","Cruller"]],
		6:[["mixed_berry_pop","Mixed berry"],["orange_cream_pop","Orange cream"],["watermelon_pop","Watermelon"],["strawberry_banana_pop","Strawberry-banana"]],
		7:[["croissant","Croissant"],["cream_horn","Cream horn"],["chocolate_eclair","Chocolate eclair"],["cream_puff","Cream puff"]],
	}
	for item: Array in sets[stage_index]:
		piece_textures.append(load("res://assets/honeydew/items/board%d_%s_piece.png" % [stage_index+1,item[0]]))
		piece_names.append(str(item[1]).to_upper())
	initial_locks.clear()
	if stage_index==5:
		board.blocker_style="jelly"
		# One connected jelly bank with an uneven edge, covering half the board.
		var jelly_widths := [5,5,4,4,4,4,3,3]
		for y in MatchThreeBoard.ROWS:
			for x in MatchThreeBoard.COLS:
				if x < jelly_widths[y]: initial_locks.append(Vector2i(x,y))
	elif stage_index==6:
		board.blocker_style="ice"
		for y in range(2,6):
			for x in range(2,6): initial_locks.append(Vector2i(x,y))
	elif stage_index==7:
		board.blocker_style="crust"
		for y in MatchThreeBoard.ROWS:
			for x in MatchThreeBoard.COLS:
				if (x<4 and y<4) or (x>=4 and y>=4): initial_locks.append(Vector2i(x,y))


func _configure_cocoa_match(stage_index: int) -> void:
	var sets := {
		4:[["lime_gelatin","Lime gelatin"],["grape_gelatin","Grape gelatin"],["rose_gelatin","Rose gelatin"],["orange_gelatin","Orange gelatin"]],
		5:[["blue_raspberry_slushie","Blue raspberry"],["mango_slushie","Mango"],["pineapple_slushie","Pineapple"],["cola_slushie","Cola"]],
		6:[["party_cake","Party cake"],["tres_leches","Tres leches"],["cherry_truffle","Cherry truffle"],["black_forest","Black forest"]],
		7:[["dinner_roll","Dinner roll"],["bagel","Bagel"],["sourdough","Sourdough"],["brioche","Brioche"]],
	}
	for item: Array in sets[stage_index]:
		piece_textures.append(load("res://assets/cocoa/items/board%d_%s_piece.png" % [stage_index+1,item[0]]))
		piece_names.append(str(item[1]).to_upper())
	initial_locks.clear()
	if stage_index==4:
		board.blocker_style="jelly"
		# A single connected moon-shaped bank, rather than scattered jelly cells.
		var widths := [0,4,5,5,5,4,1,0]
		for y in MatchThreeBoard.ROWS:
			for x in MatchThreeBoard.COLS:
				if x<widths[y]: initial_locks.append(Vector2i(x,y))
		objective_requirements.assign([20,22,24,26]); move_limit=46
	elif stage_index==5:
		board.blocker_style="ice"
		for y in range(1,7):
			for x in range(1,6): initial_locks.append(Vector2i(x,y))
		objective_requirements.assign([24,26,28,30]); move_limit=49
	elif stage_index==6:
		objective_requirements.assign([14,14,14,14]); move_limit=55
		standby_name="CHOCOLATE MOUSSE"; standby_requirement=18
		standby_texture=load("res://assets/cocoa/items/board7_chocolate_mousse_piece.png")
	elif stage_index==7:
		objective_requirements.assign([65,65,65,65]); move_limit=58
		standby_name="ENGLISH MUFFIN"; standby_requirement=78
		standby_texture=load("res://assets/cocoa/items/board8_english_muffin_piece.png")

func _show_rule_tutorial(stage_index: int) -> void:
	var rules := {
		5:["JELLY DONUTS","About half the board is hidden under jelly. Make matches beside jelly squares to clear them and reveal the donuts."],
		6:["GLACIER ICE POPS","Ice blocks seal a geometric group of pops. Make matches beside the ice to crack it and free those pieces."],
		7:["CHOCOLATE-CRUST TARTS","Half the board begins beneath chocolate crust. Match beside crust squares to break them open. This board can be replayed without a daily limit."],
	}
	var layer := CanvasLayer.new(); layer.name="RuleTutorial"; layer.layer=200; add_child(layer)
	var shade := ColorRect.new(); shade.color=Color("3a2030cc"); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(shade)
	var panel := Panel.new(); panel.position=Vector2(500,245); panel.size=Vector2(920,570); shade.add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color=Color("fff7ed"); style.set_corner_radius_all(32); style.border_color=Color("e58bab"); style.set_border_width_all(5); panel.add_theme_stylebox_override("panel",style)
	var title := Label.new(); title.position=Vector2(60,55); title.size=Vector2(800,90); title.text=rules[stage_index][0]; title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",44); title.add_theme_color_override("font_color",Color("74364f")); panel.add_child(title)
	var body := Label.new(); body.position=Vector2(100,170); body.size=Vector2(720,190); body.text=rules[stage_index][1]; body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; body.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; body.add_theme_font_size_override("font_size",29); body.add_theme_color_override("font_color",Color("5a4050")); panel.add_child(body)
	var ok := Button.new(); ok.name="TutorialOkay"; ok.position=Vector2(300,405); ok.size=Vector2(320,100); ok.text="GOT IT"; ok.add_theme_font_size_override("font_size",34); panel.add_child(ok)
	ok.pressed.connect(func() -> void: board.set_interaction_enabled(true); layer.queue_free())

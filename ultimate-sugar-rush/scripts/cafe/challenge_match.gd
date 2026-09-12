extends "res://scripts/ui/variant_match_game.gd"

func _ready() -> void:
	var region := CafeProgress.region
	var stage := CafeProgress.stage
	target = 24 + stage*5 + (region-1)*4
	move_limit = 38 + stage*2
	save_section = "cafe_challenge_%d_%d" % [region,stage]
	completion_flag = "cafe_region_%d_stage_%d_complete" % [region,stage]
	unlock_flag = "cafe_region_%d_stage_%d_unlocked" % [region,stage+1]
	completion_message = "GARDEN GOODNESS!" if region==1 else "MOONLIGHT MAGIC!"
	initial_locks.clear()
	if stage%3 == 1:
		initial_locks.assign([Vector2i(2,2),Vector2i(5,2),Vector2i(2,5),Vector2i(5,5)])
	elif stage%3 == 2:
		initial_locks.assign([Vector2i(1,1),Vector2i(3,1),Vector2i(5,1),Vector2i(2,5),Vector2i(4,5),Vector2i(6,5)])
	shift_bottom_row = region==2 and stage>=2
	var textures := ["gummy_raspberry","gummy_orange","gummy_lime","gummy_blueberry"] if region==1 else ["red_round_candy","green_hard_candy","gold_butterscotch","blue_heart_candy"]
	piece_textures.clear()
	for texture_name: String in textures: piece_textures.append(load("res://assets/match3/"+texture_name+".png"))
	if region==2:
		for kind in [1,2]: piece_textures[kind] = CandyCutout.clean(piece_textures[kind])
	piece_names.assign(["RASPBERRY","ORANGE","LIME","BLUEBERRY"] if region==1 else ["RED","GREEN","GOLD","BLUE"])
	super._ready()
	for connection in %BackButton.pressed.get_connections(): %BackButton.pressed.disconnect(connection.callable)
	%BackButton.pressed.connect(func() -> void: SceneRouter.replace_scene("res://scenes/map/cafe_region.tscn"))
	var header := get_node("LandscapeLayout/Header/Title") as Label
	if header: header.text = "%s • %d" % [CafeProgress.REGIONS[region].name,stage+1]

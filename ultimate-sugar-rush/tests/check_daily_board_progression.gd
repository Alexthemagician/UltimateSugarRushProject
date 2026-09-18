extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func cells_connected(cells: Array[Vector2i]) -> bool:
	if cells.is_empty(): return true
	var remaining: Dictionary = {}
	for cell: Vector2i in cells: remaining[cell]=true
	var queue: Array[Vector2i] = [cells[0]]; remaining.erase(cells[0])
	while not queue.is_empty():
		var current: Vector2i=queue.pop_front()
		for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var neighbor:=current+direction
			if remaining.erase(neighbor): queue.append(neighbor)
	return remaining.is_empty()

func run() -> void:
	var progress := root.get_node("CafeProgress")
	var save := root.get_node("SaveSystem")
	for region_index in 3:
		check(progress.map_scene_for_region(region_index) == ("res://scenes/map/world_map.tscn" if region_index == 0 else "res://scenes/map/cafe_region.tscn"), "Region %d returns board wins to its own map" % region_index)
		check(progress.stage_unlocked_for(region_index,0),"Region %d begins with board 1 unlocked" % region_index)
		check(not progress.stage_unlocked_for(region_index,1),"Region %d locks board 2 before board 1 is cleared" % region_index)
		for stage_index in 7:
			if region_index == 0:
				save.set_value("progression","level_%d_complete" % (stage_index+1),true)
				save.set_value("progression","level_%d_unlocked" % (stage_index+2),true)
			else:
				save.set_value("cafe_completed","region_%d_stage_%d" % [region_index,stage_index],true)
			check(progress.stage_unlocked_for(region_index,stage_index+1),"Region %d unlocks board %d after its predecessor" % [region_index,stage_index+2])
		check(progress.claim_daily_entry(region_index,0),"Region %d allows its first daily entry" % region_index)
		check(progress.can_enter_stage(region_index,0),"Region %d remains open after an abandoned attempt" % region_index)
		progress.mark_stage_cleared_today(region_index,0)
		check(progress.can_enter_stage(region_index,0),"Region %d remains replayable after its daily first clear" % region_index)
		check(progress.can_enter_stage(region_index,7),"Region %d board 8 remains unlimited" % region_index)
		check(progress.claim_daily_entry(region_index,7) and progress.claim_daily_entry(region_index,7),"Region %d board 8 accepts repeated entries" % region_index)
	for region_index in [1,2]:
		progress.region = region_index
		var map = load("res://scenes/map/cafe_region.tscn").instantiate()
		root.add_child(map)
		await process_frame
		check(is_instance_valid(map.find_child("Level7",true,false)) and is_instance_valid(map.find_child("Level8",true,false)),"Region %d map contains boards 7 and 8" % region_index)
		map.queue_free()
		await process_frame
	progress.region = 1
	var merge_item_sets := {}
	for stage_index in 4:
		check(progress.board_scene_for_stage(stage_index)=="res://scenes/merge/regional_merge_game.tscn","Regional board %d uses merge gameplay" % (stage_index+1))
		progress.stage = stage_index
		var merge_board = load("res://scenes/merge/regional_merge_game.tscn").instantiate()
		root.add_child(merge_board)
		await process_frame
		var expected_chains := 3 if stage_index==0 else (8 if stage_index==3 else 4)
		check(merge_board.board.selected_ingredients.size()==expected_chains and merge_board.objectives.size()==expected_chains,"Regional merge board %d uses its complete themed item set" % (stage_index+1))
		check(merge_board.board.regional_objective_ids.size()==expected_chains,"Regional merge board %d exposes every requested final item" % (stage_index+1))
		var every_texture_loaded := true
		for definition: Dictionary in merge_board.board.regional_definitions.values():
			every_texture_loaded = every_texture_loaded and definition.texture != null
		check(every_texture_loaded,"Regional merge board %d loads all of its custom item art" % (stage_index+1))
		var add_button := merge_board.find_child("AddItemButton",true,false) as Button
		check(add_button.text=="ADD ITEMS","Regional merge board %d uses the standard ADD ITEMS control" % (stage_index+1))
		check(add_button.icon!=null,"Regional merge board %d uses the standard source-item icon treatment" % (stage_index+1))
		merge_item_sets[str(merge_board.board.selected_ingredients)] = true
		merge_board.queue_free()
		await process_frame
	check(merge_item_sets.size()==4,"The four Honeydew merge boards use distinct item sets")
	progress.region = 2
	var cocoa_merge_sets := {}
	for stage_index in 4:
		progress.stage = stage_index
		check(progress.board_scene_for_stage(stage_index)=="res://scenes/merge/regional_merge_game.tscn","Cocoa Moon board %d uses merge gameplay" % (stage_index+1))
		var cocoa_merge = load("res://scenes/merge/regional_merge_game.tscn").instantiate()
		root.add_child(cocoa_merge); await process_frame
		var expected_chains := 3 if stage_index==0 else 4
		check(cocoa_merge.board.selected_ingredients.size()==expected_chains and cocoa_merge.objectives.size()==expected_chains,"Cocoa Moon merge board %d has every requested chain" % (stage_index+1))
		check(cocoa_merge.board.regional_definitions.values().all(func(definition): return definition.texture!=null),"Cocoa Moon merge board %d loads all custom art" % (stage_index+1))
		var cocoa_add := cocoa_merge.find_child("AddItemButton",true,false) as Button
		check(cocoa_add.text=="ADD ITEMS" and cocoa_add.icon!=null,"Cocoa Moon merge board %d uses the shared ADD ITEMS button" % (stage_index+1))
		cocoa_merge_sets[str(cocoa_merge.board.selected_ingredients)]=true
		cocoa_merge.queue_free(); await process_frame
	check(cocoa_merge_sets.size()==4,"All four Cocoa Moon merge boards use distinct item sets")
	for stage_index in range(4,8):
		progress.stage=stage_index
		check(progress.board_scene_for_stage(stage_index)=="res://scenes/match3/challenge_match.tscn","Cocoa Moon board %d uses match-3 gameplay" % (stage_index+1))
		var cocoa_match=load("res://scenes/match3/challenge_match.tscn").instantiate()
		root.add_child(cocoa_match); await process_frame
		check(cocoa_match.piece_textures.size()==4 and cocoa_match.piece_textures.all(func(texture): return texture!=null),"Cocoa Moon match board %d loads its four requested pieces" % (stage_index+1))
		if stage_index==4:
			check(cocoa_match.board.blocker_style=="jelly" and cocoa_match.initial_locks.size()==24 and cells_connected(cocoa_match.initial_locks),"Cocoa Moon gelatin board uses one connected jelly chunk")
			check(cocoa_match.find_child("RuleTutorial",true,false)==null and "TIP:" in (cocoa_match.find_child("Rules",true,false) as Label).text,"Cocoa Moon gelatin board uses a one-line tip under the board without a repeated tutorial")
		elif stage_index==5:
			check(cocoa_match.board.blocker_style=="ice" and cocoa_match.initial_locks.size()==30 and cells_connected(cocoa_match.initial_locks),"Cocoa Moon slushie board uses a large connected glacier")
		elif stage_index>=6:
			check(cocoa_match.standby_texture!=null and cocoa_match.standby_requirement>cocoa_match.objective_requirements.max(),"Cocoa Moon board %d has the higher-count standby objective" % (stage_index+1))
			check(is_instance_valid(cocoa_match.standby_icon) and cocoa_match.get_node("LandscapeLayout/RightObjectives").get_child_count()==5,"Cocoa Moon board %d displays the standby objective" % (stage_index+1))
			await cocoa_match._on_large_match_created(Vector2i(0,0))
			check(cocoa_match.standby_progress==1,"A four-plus match animates and collects the standby item on board %d" % (stage_index+1))
		cocoa_match.queue_free(); await process_frame
	progress.region = 1
	var previous_total := 0
	var profile_signatures := {}
	for stage_index in range(4,8):
		check(progress.board_scene_for_stage(stage_index)=="res://scenes/match3/challenge_match.tscn","Regional board %d uses match-3 gameplay" % (stage_index+1))
		progress.stage = stage_index
		var profiled_board = load("res://scenes/match3/challenge_match.tscn").instantiate()
		root.add_child(profiled_board)
		await process_frame
		var total: int = 0
		for requirement: int in profiled_board.objective_requirements: total += requirement
		check(total > previous_total,"Regional board %d increases its objective difficulty" % (stage_index+1))
		check(profiled_board.piece_names[0] in ["BLUEBERRY MACARON","POWDERED SUGAR","MIXED BERRY","CROISSANT"],"Regional match-3 board %d uses its requested dessert pieces" % (stage_index+1))
		check(profiled_board.piece_textures.all(func(texture): return texture != null),"Regional match-3 board %d loads all four dessert images" % (stage_index+1))
		if stage_index>=5:
			var expected_style: String = ["jelly","ice","crust"][stage_index-5]
			var expected_locks: int = [32,16,32][stage_index-5]
			check(profiled_board.board.blocker_style==expected_style and profiled_board.initial_locks.size()==expected_locks,"Regional board %d uses the requested %s layout" % [stage_index+1,expected_style])
			await process_frame
			var tutorial: Node = profiled_board.find_child("RuleTutorial",true,false)
			check(is_instance_valid(tutorial) and not profiled_board.board.interaction_enabled,"Regional board %d opens its rules before play" % (stage_index+1))
			var tutorial_ok := profiled_board.find_child("TutorialOkay",true,false) as Button
			if tutorial_ok:
				tutorial_ok.pressed.emit()
				await process_frame
				check(profiled_board.board.interaction_enabled,"Regional board %d GOT IT button begins play" % (stage_index+1))
		previous_total = total
		var signature := "%s:%s:%s" % [profiled_board.objective_requirements,profiled_board.initial_locks,profiled_board.shift_bottom_row]
		profile_signatures[signature] = true
		profiled_board.queue_free()
		await process_frame
	check(profile_signatures.size()==4,"The four Honeydew match-3 boards use distinct objective and obstacle profiles")
	progress.region = 1
	progress.stage = 7
	var challenge = load("res://scenes/match3/challenge_match.tscn").instantiate()
	root.add_child(challenge)
	await process_frame
	check(challenge.target>=90 and challenge.initial_locks.size()>=12 and challenge.shift_bottom_row,"Board 8 uses the harder unlimited rules")
	challenge.queue_free()
	await process_frame
	var combo_board := MatchThreeBoard.new()
	root.add_child(combo_board)
	await process_frame
	combo_board.locked_cells.clear()
	combo_board.cells[0][0].special=MatchThreeBoard.Special.TARGET
	combo_board.cells[0][1].special=MatchThreeBoard.Special.BOMB
	await combo_board._activate_target_powerup_combo(Vector2i(0,0),Vector2i(1,0),MatchThreeBoard.Special.BOMB)
	var combo_bombs := 0
	for row: Array in combo_board.cells:
		for cell: Dictionary in row:
			if cell.special==MatchThreeBoard.Special.BOMB: combo_bombs += 1
	check(combo_bombs==8,"Disco plus a power-up creates a cluster of eight matching power-ups")
	combo_board.queue_free()
	await process_frame
	var wheel = load("res://scripts/ui/ingredient_wheel.gd").new()
	wheel.region = 1
	wheel.spin_duration = 0.02
	root.get_node("RewardedAds").mock_delay = 0.01
	root.add_child(wheel)
	await process_frame
	check(wheel.get_node("Wheel").get_child_count()>=13,"Wheel displays all six regional ingredients")
	wheel._spin()
	await create_timer(0.12).timeout
	check(wheel.awarded_ids.size()==1 and wheel.awarded_ids[0] in progress.POOLS[1],"Wheel lands on and awards a regional ingredient")
	check(wheel.ad_button.visible and wheel.collect_button.visible,"Wheel offers an ad spin and collect after the result")
	wheel._watch_ad_and_spin()
	await create_timer(0.12).timeout
	check(wheel.awarded_ids.size()==2 and wheel.ad_spin_used,"Completed rewarded ad grants exactly one extra spin")
	check(not wheel.ad_button.visible,"A wheel win cannot claim more than one ad spin")
	print("Daily board progression: %d failures" % failures)
	quit(failures)

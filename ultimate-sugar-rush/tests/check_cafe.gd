extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var progress := root.get_node("CafeProgress")
	var database := root.get_node("GameDatabase")
	var save := root.get_node("SaveSystem")
	# Run with APPDATA redirected to a disposable test directory.
	check(progress.INGREDIENTS.size()==18,"Required ingredient catalog")
	var before: Dictionary = database.get_player_stats()
	var total_coins := 0
	var total_xp := 0
	for attempt in 2:
		for region in 3:
			progress.region = region
			progress.stage = attempt
			progress.begin_board("res://scenes/match3/challenge_match.tscn")
			var reward: Dictionary = progress.award_board("test")
			check(not reward.is_empty(),"New attempt grants a receipt")
			for id in reward.ingredients: check(id in progress.POOLS[region],"Region-exclusive ingredient rewards")
			total_coins += int(reward.coins)
			total_xp += int(reward.xp)
			check(progress.award_board("test").is_empty(),"Same attempt cannot grant twice")
	var stock: Dictionary = progress.pantry()
	for id: String in progress.INGREDIENTS:
		check(int(stock[id])>0,"Unobtainable ingredient: "+id)
	var after: Dictionary = database.get_player_stats()
	check(int(after.coins)==int(before.coins)+total_coins,"Coin rewards must use the existing wallet")
	check(int(after.xp)==int(before.xp)+total_xp,"XP rewards must use existing stats")
	check(progress.can_serve(0),"Collected ingredients enable recipe")
	check(progress.serve(0),"Serving consumes inventory")
	check(int(progress.pantry().ultra_fine_flour)==int(stock.ultra_fine_flour)-2,"Exact recipe consumption")
	while progress.can_serve(0): progress.serve(0)
	var empty_before: Dictionary = progress.pantry()
	check(not progress.serve(0),"Insufficient ingredients cannot serve")
	check(progress.pantry()==empty_before,"Rejected serve must not mutate inventory")
	save.save_now()
	var persisted: Dictionary = progress.pantry()
	save.load_save()
	database._load_player_tables()
	check(progress.pantry()==persisted,"Inventory survives save/load")
	for region in [1,2]:
		progress.region = region
		check(progress.stage_unlocked(0),"First stage unlocked")
		check(progress.stage_unlocked(1),"Completion unlocks next stage")
		check(not progress.stage_unlocked(5),"Later stage gated")
		for stage in 6:
			progress.stage = stage
			var board = load("res://scenes/match3/challenge_match.tscn").instantiate()
			root.add_child(board)
			await process_frame
			await create_timer(0.08).timeout
			check(board.objective_requirements.size()==4 and board.target==board.objective_requirements.max(),"Stage objective configuration")
			check(board.board.cells.size()==8,"Challenge board initialized")
			board.queue_free()
			await process_frame
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	check(hub.world.actors.size()>=3,"Chef and customer NPCs")
	var actor_position: Vector3 = hub.world.actors[0].node.position
	await create_timer(0.3).timeout
	check(hub.world.actors[0].node.position != actor_position,"Chef walk animation advances")
	check(hub.icon_buttons.size()==7,"Seven illustrated menu controls include Items and consolidated Recipes")
	for item in hub.icon_buttons:
		var images := item.find_children("*","TextureRect",true,false)
		var image: TextureRect = images[0] as TextureRect if not images.is_empty() else null
		check(is_instance_valid(image),"Illustrated menu control contains an image")
		if not is_instance_valid(image): continue
		check(image.position.x+image.size.x<=item.size.x and image.position.y+image.size.y<=item.size.y,"Icon stays within its control")
	var zoom_before: float = hub.world.camera.size
	for child in hub.get_children():
		if child is Button and child.text=="+": child.pressed.emit()
	check(hub.world.camera.size<zoom_before,"Visible plus button changes zoom")
	check(hub.wallet.text.is_valid_int(),"Currency uses numeric amount without word")
	check(hub.xp_bar.value==int(database.get_player_stats().xp)%200,"XP bar tracks existing wallet stats")
	check(hub.world.has_node("Neighborhood"),"Surrounding neighborhood exists")
	check(hub.world.has_node("OpenDoorway"),"Doorway frame exists")
	var head: Node3D = hub.portrait.get_node("Head")
	var head_before := head.rotation
	hub._process(0.5)
	check(head.rotation==head_before,"Portrait head remains still")
	hub.portrait_time = 4.19
	hub._process(0.02)
	check(head.get_node("EyeLeft").scale.y<0.1,"Portrait blinks")
	hub.portrait_time = 5.0
	hub._process(0.01)
	check(head.get_node("EyeLeft").scale.y>0.09,"Portrait opens eyes again")
	hub.world.set_zoom(-100)
	check(hub.world.camera.size==hub.world.MIN_ZOOM,"Near zoom limit")
	hub.world.set_zoom(100)
	check(hub.world.camera.size==hub.world.MAX_ZOOM,"Far zoom limit")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	hub.world._unhandled_input(wheel)
	check(hub.world.camera.size<hub.world.MAX_ZOOM,"Mouse wheel zoom works")
	var magnify := InputEventMagnifyGesture.new()
	magnify.factor = 100
	hub.world._unhandled_input(magnify)
	check(hub.world.camera.size==hub.world.MIN_ZOOM,"Gesture zoom clamps")
	hub.world.set_zoom(16)
	for i in 2:
		var touch := InputEventScreenTouch.new()
		touch.index = i
		touch.position = Vector2(i*100,100)
		touch.pressed = true
		hub.world._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(200,100)
	hub.world._unhandled_input(drag)
	check(hub.world.camera.size==hub.world.MIN_ZOOM,"Two finger pinch zoom works")
	hub.world.set_zoom(16)
	hub._quests()
	check(hub.recipe_buttons.is_empty(),"Main recipe book browses recipes without crafting away from a machine")
	check(hub.modal.find_child("RecipeTabs",true,false).get_child_count()==5,"Recipe book includes five horizontal category tabs")
	check(hub.modal.find_child("RecipeCardRow",true,false).get_child_count()==2,"Recipe book shows the selected category as recipe cards")
	var camera_transform: Transform3D = hub.world.camera.transform
	for station in 4:
		hub._select_station(station)
		check(hub.selected==station,"Station recipe selection")
	check(hub.world.camera.transform==camera_transform,"Camera angle remains fixed")
	for method in ["_quests","_maps","_pantry","_collections","_settings"]:
		hub.call(method)
		await process_frame
		check(is_instance_valid(hub.modal),"Café menu "+method)
	var saw_pickup := false
	var saw_release := false
	for frame in 900:
		hub.world._process(0.1)
		if hub.world.actors[1].treat.visible: saw_pickup = true
		elif saw_pickup: saw_release = true
	check(saw_pickup and saw_release,"Customer pickup and return loop")
	hub.queue_free()
	await process_frame
	progress.region = 1
	progress.stage = 2
	progress.begin_board("res://scenes/match3/challenge_match.tscn")
	var final_board = load("res://scenes/match3/challenge_match.tscn").instantiate()
	root.add_child(final_board)
	current_scene = final_board
	await process_frame
	await final_board._complete_level()
	await create_timer(0.6).timeout
	check(current_scene.scene_file_path=="res://scenes/map/cafe_region.tscn","Completed board returns to its regional map")
	check(bool(save.get_value("cafe_completed","region_1_stage_2",false)),"Completion path awards and unlocks")
	progress.open_region(0)
	await create_timer(0.65).timeout
	check(current_scene.scene_file_path=="res://scenes/map/world_map.tscn","Original map remains accessible")
	check(current_scene.has_node("IngredientFooter"),"Original map shares ingredient footer")
	current_scene.get_node("CafeBackButton").pressed.emit()
	await create_timer(0.65).timeout
	check(current_scene.scene_file_path==progress.HUB,"Original map returns to cafe")
	for region in [1,2]:
		progress.open_region(region)
		await create_timer(0.65).timeout
		check(current_scene.get_child_count()>=17,"Illustrated regional map initializes fully")
		progress.open_stage(0)
		await create_timer(0.65).timeout
		check(current_scene.scene_file_path=="res://scenes/merge/regional_merge_game.tscn","Regional map opens its first merge board")
		current_scene.get_node("%BackButton").pressed.emit()
		await create_timer(0.65).timeout
		check(current_scene.scene_file_path=="res://scenes/map/cafe_region.tscn","Challenge returns to correct region")
	print("CAFE CHECKS FINISHED: %d failures" % failures)
	quit(1 if failures else 0)

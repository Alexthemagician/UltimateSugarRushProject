extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var progress := root.get_node("CafeProgress")
	var life := root.get_node("CafeLife")
	var save := root.get_node("SaveSystem")
	var database := root.get_node("GameDatabase")
	for id in progress.INGREDIENTS:
		database.upsert_record("inventory",{"id":"ingredient_"+id,"quantity":100})
	for i in range(5,10):
		check(not progress.recipe_unlocked(i),"New recipe starts locked")
		check(not progress.start_craft(i),"Ingredients cannot bypass discovery")
	for regular in ["mint","berry","coco"]:
		for visit in 3:
			var request: Dictionary = life.new_regular_request(regular)
			check(request.recipe_index < 5,"Only discovered recipes requested")
			check(life.fulfill_regular(request,request.recipe_index),"Matching request earns friendship")
			check(not life.fulfill_regular(request,request.recipe_index),"Same request cannot earn friendship twice")
	for i in range(7,10): check(progress.recipe_unlocked(i),"Friendship discovers recipe")
	save.set_value("cafe","boards_won",3)
	check(progress.recipe_unlocked(5) and not progress.recipe_unlocked(6),"Board thresholds differ")
	save.set_value("cafe","boards_won",5)
	check(progress.recipe_unlocked(6),"Mocha milestone reached")
	seed(317)
	for regular in ["mint","berry","coco"]:
		var seen := {}
		for visit in 100:
			var request: Dictionary = life.new_regular_request(regular)
			seen[request.recipe_index] = true
			check(progress.RECIPES[request.recipe_index].category == life.REGULARS[regular].category,"Requests stay in preferred category")
		check(seen.size()==2,"Regular requests both discovered recipes")
	check(progress.start_craft(5),"Variant starts at bread oven")
	check(not progress.start_craft(0),"Original cannot overlap variant on same oven")
	check(progress.start_craft(6),"Separate coffee machine remains available")
	save.save_now()
	save.load_save()
	check(progress.recipe_unlocked(9),"Friendship discovery persists")
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	check(hub.world.display_products.size()==10,"All recipes have display positions")
	check(hub.world.display_products[0].get_parent()==hub.world.display_products[5].get_parent(),"Variants share a physical case")
	check(hub.world.batch_icons.size()==10,"All recipes have collection markers")
	hub._quests(0,true)
	check(hub.recipe_buttons.size()==2 and hub.recipe_buttons.all(func(button: Button) -> bool: return button.disabled),"Every recipe keeps its Craft button while all matching stations are busy")
	print("Recipe discovery: %d failures" % failures)
	quit(failures)

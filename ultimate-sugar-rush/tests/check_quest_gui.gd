extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func click(control: Control) -> void:
	# Newly created containers settle their minimum sizes over deferred layout passes.
	await process_frame
	await process_frame
	var position := root.get_final_transform() * control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
func run() -> void:
	var progress := root.get_node("CafeProgress")
	var save := root.get_node("SaveSystem")
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	for i in progress.RECIPES.size():
		save.set_value("cafe_jobs",progress.RECIPES[i].id,{"ready_at":0,"quantity":progress.RECIPES[i].batch})
		hub.world._process(0)
		hub._process(0)
		await click(hub.batch_collect_buttons[i])
		check(progress.product_stock(i)==progress.RECIPES[i].batch,"Actual GUI click collects batch %d" % i)
		check(hub.world.display_products[i].visible,"Collected batch appears in its display")
	var customer: Dictionary = hub.world.actors[1]
	customer.state = "shop"
	var requested: int = customer.regular_request.recipe_index
	customer.product_choice = requested
	var stock_before: int = progress.product_stock(requested)
	var expected_coins: int = progress.RECIPES[requested].price + root.get_node("CafeLife").event_sale_bonus(requested)
	customer.node.position = Vector3(-3.6,0.14,5.5)
	customer.wait = 0.0
	var database := root.get_node("GameDatabase")
	var coins_before: int = database.get_player_stats().coins
	for frame in 1200:
		hub.world._animate_customer(customer,1.0/60.0)
		if customer.state == "pickup": break
	check(customer.state == "pickup","Customer buys GUI-collected stock")
	check(progress.product_stock(requested)==stock_before-1,"Sale removes one requested recipe")
	check(database.get_player_stats().coins==coins_before+expected_coins,"Sale pays recipe price plus event bonus")
	check(int(save.get_value("quest_progress","coins",0))==expected_coins,"Sale advances coin quest")
	check(int(save.get_value("quest_progress","butter_cloud_buns",0))==50,"Collection advances crafting quest")
	save.save_now()
	save.load_save()
	check(int(save.get_value("quest_progress","coins",0))==expected_coins,"Quest progress persists")
	await click(hub.get_node("QuestsButton"))
	check(is_instance_valid(hub.modal),"Quest button opens journal")
	if is_instance_valid(hub.modal):
		check(hub.modal.find_child("QuestObjective",true,false).text.begins_with("Make 3"),"First quest opens by default")
		for i in 6:
			await click(hub.modal.find_child("QuestTab%d" % i,true,false))
			check(hub.modal.find_child("QuestObjective",true,false).text==load("res://scripts/cafe/quest_journal.gd").QUESTS[i].title,"Quest tab changes full view")
			if DisplayServer.get_name()=="headless": continue
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../tmp/quest_tab_%d.png" % i)
	var colors: Array = []
	for method in ["_quests","_pantry","_maps","_collections","_settings"]:
		hub.call(method)
		await process_frame
		var panel: Panel = hub.modal.get_child(0)
		var color: Color = panel.get_theme_stylebox("panel").bg_color
		check(color not in colors,"Menu has distinct palette")
		colors.append(color)
		if DisplayServer.get_name()=="headless": continue
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../tmp/menu"+method+".png")
	print("Quest GUI: %d failures" % failures)
	quit(failures)

extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var progress := root.get_node("CafeProgress")
	var database := root.get_node("GameDatabase")
	var save := root.get_node("SaveSystem")
	for id in progress.INGREDIENTS:
		database.upsert_record("inventory",{"id":"ingredient_"+id,"quantity":100})
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	hub._quests(0)
	check(hub.recipe_buttons.size() >= 1,"Recipe book provides direct Craft actions")
	hub.recipe_buttons[0].pressed.emit()
	var picker: Control=hub.get_node_or_null("RecipeCraftPickerShade")
	check(is_instance_valid(picker),"Craft action opens station selector before starting")
	(picker.find_child("ConfirmRecipeCraft",true,false) as Button).pressed.emit()
	check(not progress.craft_job(0).is_empty(),"Craft button starts saved job")
	check(progress.product_stock(0) == 0,"Uncollected batch is not displayed")
	var job: Dictionary = progress.craft_job(0)
	job.ready_at = Time.get_unix_time_from_system()-1
	save.set_value("cafe_jobs",progress.RECIPES[0].id,job)
	hub.world._process(0)
	check(hub.world.batch_icons[0].visible,"Finished batch shows collection icon")
	hub._select_station(0)
	hub.world._process(0)
	check(progress.product_stock(0) == 50,"Collection moves the whole batch")
	check(hub.world.display_products[0].visible,"Stock appears in display case")
	check(not hub.world.batch_icons[0].visible,"Collected icon disappears")
	var customer: Dictionary = hub.world.actors[1]
	# This check stocks recipe 0, so make it the regular's requested item.
	customer.regular_request.recipe_index = 0
	customer.state = "shop"
	customer.node.position = hub.world._customer_shop_position(customer,0)+Vector3(-2.0,0,0)
	customer.base_y = customer.node.position.y
	customer.wait = 0.0
	var coins: int = database.get_player_stats().coins
	for frame in 2400:
		hub.world._animate_customer(customer,1.0/60.0)
		if customer.state == "pickup": break
	check(customer.state == "pickup","Regular reaches pickup counter and collects the requested item")
	check(customer.node.position.distance_to(hub.world._customer_shop_position(customer,0)) < 0.05,"Purchase happens at movable pickup counter")
	check(progress.product_stock(0) == 49,"Purchase consumes one item")
	check(database.get_player_stats().coins == coins,"Coins wait until the customer finishes pickup")
	for frame in 90: hub.world._animate_customer(customer,1.0/60.0)
	check(database.get_player_stats().coins == coins+4,"Purchase pays listed price")
	check(customer.treat.visible,"Customer carries purchased item")
	print("Cafe machine flow: %d failures" % failures)
	quit(failures)

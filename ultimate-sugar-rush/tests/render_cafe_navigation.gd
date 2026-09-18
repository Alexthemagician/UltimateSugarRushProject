extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/"+file+".png")
func run() -> void:
	var database := root.get_node("GameDatabase")
	var progress := root.get_node("CafeProgress")
	for recipe in progress.RECIPES:
		database.upsert_record("inventory",{"id":"product_"+recipe.id,"quantity":100})
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	var diner: Dictionary = hub.world.actors.filter(func(actor: Dictionary) -> bool: return not actor.chef and not actor.has("regular_id"))[0]
	diner.state = "shop"
	diner.product_choice = 0
	diner.node.position = hub.world._entry_steps()[-1]
	diner.base_y = diner.node.position.y
	diner.wait = 0.0
	diner.sales = 0
	hub.world._reset_actor_navigation(diner)
	for frame in 7200:
		hub.world._animate_customer(diner,1.0/60.0)
		if diner.state=="eat": break
	await capture("cafe_customer_dining")
	quit()

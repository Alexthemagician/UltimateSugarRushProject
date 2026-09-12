extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/"+file+".png")
func run() -> void:
	var database := root.get_node("GameDatabase")
	var progress := root.get_node("CafeProgress")
	for id in progress.INGREDIENTS: database.upsert_record("inventory",{"id":"ingredient_"+id,"quantity":12})
	for i in 4: progress.serve(i)
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	for frame in 900: hub.world._process(1.0/60)
	await capture("cafe_chibi_customers")
	hub.world.camera.size = 12
	await capture("cafe_chibi_close")
	hub.world.camera.size = 22
	for frame in 500: hub.world._process(1.0/60)
	await capture("cafe_customer_road")
	hub.world.camera.size = 16
	for method in ["_quests","_maps","_pantry"]:
		hub.call(method)
		await create_timer(0.1).timeout
		await capture("chibi"+method)
		var scroll: ScrollContainer = hub.modal.get_child(0).get_child(2)
		scroll.scroll_vertical = 10000
		await capture("chibi"+method+"_bottom")
	quit()

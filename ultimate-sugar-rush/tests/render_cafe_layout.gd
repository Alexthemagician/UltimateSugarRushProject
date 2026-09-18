extends SceneTree
func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/"+file+".png")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var database := root.get_node("GameDatabase")
	var progress := root.get_node("CafeProgress")
	for recipe in progress.RECIPES:
		database.upsert_record("inventory",{"id":"product_"+recipe.id,"quantity":0})
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	for frame in 4200: hub.world._process(1.0/60.0)
	await capture("cafe_pickup_waiting")
	var move_entry: Dictionary = hub.world.movable_objects.filter(func(entry: Dictionary) -> bool: return entry.id=="station_0")[0]
	hub.world.begin_object_placement(move_entry)
	await capture("cafe_direct_move_indicator")
	hub.world.cancel_object_placement()
	hub.world.set_zoom(22)
	hub.world.set_pan(Vector2(12,10))
	await capture("cafe_expansion_plot")
	hub.world.camera.size = 42
	hub.world.camera.position = Vector3(12,30,16)
	hub.world.camera.look_at(Vector3.ZERO)
	await capture("cafe_corner_plot")
	quit()

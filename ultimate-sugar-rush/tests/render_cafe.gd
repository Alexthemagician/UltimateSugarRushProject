extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name_text: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/"+name_text+".png")
func run() -> void:
	var progress := root.get_node("CafeProgress")
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await create_timer(2.0).timeout
	await capture("cafe_hub_final")
	hub.world.set_zoom(-100)
	await capture("cafe_zoom_in")
	hub.world.set_zoom(100)
	await capture("cafe_zoom_out")
	hub.world.set_zoom(16)
	await capture("cafe_portrait_expression")
	for menu in ["_quests","_maps","_pantry","_collections","_settings"]:
		hub.call(menu)
		await capture("cafe"+menu)
	hub.queue_free()
	await process_frame
	for region in [1,2]:
		progress.region = region
		var map = load("res://scenes/map/cafe_region.tscn").instantiate()
		root.add_child(map)
		await capture("cafe_region_"+str(region))
		map.queue_free()
		await process_frame
	quit()

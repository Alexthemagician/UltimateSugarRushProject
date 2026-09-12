extends SceneTree

func _initialize() -> void: call_deferred("run")

func capture(file: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/landscape_" + file + ".png")

func run() -> void:
	var progress := root.get_node("CafeProgress")
	for region in 3:
		progress.region = region
		var map = load("res://scenes/map/world_map.tscn" if region == 0 else "res://scenes/map/cafe_region.tscn").instantiate()
		root.add_child(map)
		await capture("map%d" % region)
		map.queue_free()
		await process_frame
	for scene in ["merge/merge_game", "match3/candy_match_game", "cafe/cafe_hub"]:
		var screen = load("res://scenes/" + scene + ".tscn").instantiate()
		root.add_child(screen)
		await capture(scene.get_file())
		screen.queue_free()
		await process_frame
	quit()

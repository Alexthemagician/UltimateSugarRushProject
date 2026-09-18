extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/%s.png" % name)

func run() -> void:
	var progress := root.get_node("CafeProgress")
	progress.region = 1
	for stage_index in 8:
		progress.stage = stage_index
		var scene_path: String = progress.board_scene_for_stage(stage_index)
		var game = load(scene_path).instantiate()
		root.add_child(game)
		await process_frame
		await capture("honeydew_board_%d" % (stage_index+1))
		game.queue_free()
		await process_frame
	quit()

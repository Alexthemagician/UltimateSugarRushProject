extends SceneTree

func _initialize() -> void: call_deferred("run")

func capture(name: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/%s.png" % name)

func run() -> void:
	var progress := root.get_node("CafeProgress")
	progress.region=2
	for stage_index in 8:
		progress.stage=stage_index
		var game=load(progress.board_scene_for_stage(stage_index)).instantiate()
		root.add_child(game); await process_frame
		await capture("cocoa_board_%d" % (stage_index+1))
		game.queue_free(); await process_frame
	quit()

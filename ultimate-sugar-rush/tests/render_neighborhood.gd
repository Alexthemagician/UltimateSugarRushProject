extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/"+name+".png")
func run() -> void:
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	for i in 480: hub.world._process(1.0/60)
	await capture("neighborhood_home")
	hub.world.set_zoom(22)
	await capture("neighborhood_wide")
	for corner in [Vector2(-6,-6),Vector2(-6,6),Vector2(6,-6),Vector2(6,6)]:
		hub.world.set_pan(corner)
		await capture("neighborhood_pan_%d_%d" % [corner.x,corner.y])
	hub.world.reset_view()
	for i in 3:
		var actor: Node3D = hub.world.actors[i].node
		actor.position = Vector3(-0.7+i*1.3,0.14,3.1)
		actor.rotation.y = 0.4
	hub.world.set_zoom(10.5)
	await capture("neighborhood_characters")
	quit()

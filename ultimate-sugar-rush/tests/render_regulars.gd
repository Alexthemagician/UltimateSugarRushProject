extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	hub._regulars()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/regulars_page.png")
	quit()

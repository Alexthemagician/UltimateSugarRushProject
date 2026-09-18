extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("e8d5df")
	root.add_child(background)
	var wheel = load("res://scripts/ui/ingredient_wheel.gd").new()
	wheel.region = 2
	root.add_child(wheel)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/ingredient_wheel.png")
	quit()

extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var screen = load("res://scenes/app/boot_screen.tscn").instantiate()
	root.add_child(screen)
	await create_timer(5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/landscape_boot.png")
	var button: Button = screen.get_node("SafeArea/Layout/ContinueButton")
	var fits := button.visible and Rect2(Vector2.ZERO,Vector2(1920,1080)).encloses(button.get_global_rect())
	print("Boot continue button visible and in bounds: ",fits)
	quit(0 if fits else 1)

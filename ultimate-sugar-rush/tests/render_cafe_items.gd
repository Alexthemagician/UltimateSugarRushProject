extends SceneTree
func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/"+file+".png")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	await capture("cafe_items_button")
	var cupcake: Dictionary = hub.world.movable_objects.filter(func(entry: Dictionary) -> bool: return entry.id=="cupcake_counter")[0]
	hub.world.store_object(cupcake)
	hub._items("storage")
	await create_timer(0.2).timeout
	await capture("cafe_items_storage")
	hub._items("shop")
	await create_timer(0.2).timeout
	await capture("cafe_items_shop")
	hub.modal.queue_free()
	await process_frame
	hub.world.restore_object(cupcake)
	hub._show_object_actions(cupcake)
	await capture("cafe_object_actions")
	quit()

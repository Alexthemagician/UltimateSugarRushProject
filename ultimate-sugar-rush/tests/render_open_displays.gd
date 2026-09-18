extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var database:=root.get_node("GameDatabase")
	var progress:=root.get_node("CafeProgress")
	for index in 5:
		var recipe: Dictionary=progress.RECIPES[index]
		database.upsert_record("inventory",{"id":"product_"+recipe.id,"quantity":20})
	var hub=load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	hub.world._process(0)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/open_product_displays.png")
	quit()

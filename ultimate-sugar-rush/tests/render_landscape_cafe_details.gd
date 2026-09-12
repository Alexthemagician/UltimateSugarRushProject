extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(file: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/landscape_"+file+".png")
func run() -> void:
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await capture("cafe_final")
	hub._select_station(4)
	await capture("tea_recipe")
	hub.modal.queue_free()
	await process_frame
	hub.world.set_zoom(hub.world.MAX_ZOOM)
	for corner in [Vector2(-6,-6),Vector2(6,-6),Vector2(-6,6),Vector2(6,6)]:
		hub.world.set_pan(corner)
		await capture("pan_%d_%d" % [corner.x,corner.y])
	hub.queue_free()
	await process_frame
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	root.get_node("CollectibleRewards").build_completion_overlay(host,"SWEET MATCH COMPLETE!","honey_pot",{"coins":120,"xp":45,"ingredients":{"edible_flowers":2,"honey_glob":2,"spring_water":2}})
	await capture("reward_final")
	quit()

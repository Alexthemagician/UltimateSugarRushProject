extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/"+name+".png")
func run() -> void:
	var progress := root.get_node("CafeProgress")
	for region in 3:
		progress.region = region
		var map = load("res://scenes/map/world_map.tscn" if region==0 else "res://scenes/map/cafe_region.tscn").instantiate()
		root.add_child(map)
		await capture("consistent_map_%d" % region)
		map.queue_free()
		await process_frame
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var rewards := root.get_node("CollectibleRewards")
	var overlay: Dictionary = rewards.build_completion_overlay(host,"SWEET MATCH COMPLETE!","honey_pot",{"coins":120,"xp":45,"ingredients":{"edible_flowers":2,"honey_glob":2,"spring_water":2}})
	await capture("board_reward_icons")
	host.queue_free()
	await process_frame
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	hub.world.camera.position = Vector3(4,2.8,10)
	hub.world.camera.look_at(Vector3(0.5,0.8,3.1))
	hub.world.camera.size = 5
	for pose in 3:
		for i in 3:
			var actor: Dictionary = hub.world.actors[i]
			actor.node.position = Vector3(-0.6+i*1.25,0.14,3.1)
			actor.node.rotation = Vector3.ZERO
			actor.base_y = 0.14
			actor.walk_distance = pose*0.13+i*0.06
			actor.speed = 0.72
			hub.world._walk_actor(actor,actor.node.position+Vector3(0,0,5),0.01)
			hub.world._pose_legs(actor)
		await capture("clothing_clearance_pose_%d" % pose)
	quit()

extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	var world = hub.world
	world.set_process(false)
	var basis: Basis = world.camera.basis
	var houses := 0
	var trees := 0
	var animals := 0
	var heights := {}
	for child in world.get_node("Neighborhood").get_children():
		if child.name.begins_with("NeighborhoodHouse"):
			houses += 1
			check(child.basis.z.dot(child.get_meta("road_direction"))>0.99,"Every facade faces nearest road")
			heights[child.get_meta("building_height")] = true
		elif child.name.begins_with("Tree"): trees += 1
		elif child.name.begins_with("GardenAnimal"): animals += 1
	check(houses>40 and trees>15 and animals==6 and heights.size()==3,"Populated varied neighborhood")
	world.set_zoom(22)
	var plane := Plane(Vector3.UP,-0.7)
	for x in [-6.0,0.0,6.0]:
		for z in [-6.0,0.0,6.0]:
			world.set_pan(Vector2(x,z))
			for uv in [Vector2.ZERO,Vector2(1,0),Vector2(0,1),Vector2.ONE]:
				var pixel: Vector2 = uv*Vector2(world.get_viewport().size)
				var ground: Vector3 = plane.intersects_ray(world.camera.project_ray_origin(pixel),world.camera.project_ray_normal(pixel))
				check(absf(ground.x)<49 and absf(ground.z)<49,"Ground covers every corner at all zoom-out pan extrema")
				var closest := INF
				for child in world.get_node("Neighborhood").get_children():
					if child.name.begins_with("NeighborhoodHouse") or child.name.begins_with("Tree"):
						closest = minf(closest,Vector2(child.position.x-ground.x,child.position.z-ground.z).length())
				check(closest<12,"Visible boundary remains populated")
	check(world.camera.basis==basis,"Panning cannot rotate camera")
	world.set_pan(Vector2(100,-100))
	check(world.pan_offset==Vector2(6,-6),"Pan limits clamp")
	world.reset_view()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	world._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(90,30)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	world._unhandled_input(motion)
	check(world.pan_offset.length()>0,"Mouse drag pans")
	press.pressed = false
	world._unhandled_input(press)
	check(not is_instance_valid(hub.modal),"Dragging does not activate a station")
	world.reset_view()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(100,100)
	touch.pressed = true
	world._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(170,120)
	drag.relative = Vector2(70,20)
	world._unhandled_input(drag)
	check(world.pan_offset.length()>0,"Single finger pans")
	world.reset_view()
	check(world.pan_offset==Vector2.ZERO and world.camera.size==16,"Home resets framing")
	var actor: Dictionary = world.actors[1]
	check(actor.node.position.z<2.8,"First arrival starts behind entrance")
	actor.state = "away"
	actor.cooldown = 0
	world._animate_customer(actor,0.01)
	check(actor.node.position.z==-17,"Repeat arrivals enter from far road")
	actor.state = "exit"
	check(world._customer_path(actor)[-1].z==12.5,"Departures continue toward front road")
	actor.node.position = Vector3(0,0.14,0)
	actor.node.rotation = Vector3.ZERO
	actor.base_y = 0.14
	actor.speed = world.WALK_SPEED
	actor.walk_distance = 0.08
	world._walk_actor(actor,Vector3(0,0.14,20),0.01)
	var foot: Node3D = actor.limbs[0].get_child(0)
	var planted := foot.global_position
	var distance_before: float = actor.walk_distance
	world._walk_actor(actor,Vector3(0,0.14,20),0.1)
	check(foot.global_position.distance_to(planted)<0.002,"Stance foot stays planted while body advances")
	check(is_equal_approx(float(actor.walk_distance)-distance_before,world.WALK_SPEED*0.1),"Gait tracks actual ground distance")
	var stationary_distance: float = actor.walk_distance
	world._rest_actor(actor,0.1)
	check(actor.walk_distance==stationary_distance,"Standing cannot advance gait")
	world._pose_legs(actor)
	for pair in actor.leg_segments:
		check(pair[0].scale.y<0.21 and pair[1].scale.y<0.21,"Connected knees preserve limb lengths")
	check(is_equal_approx(world.actors[0].limbs[2].position.y,0.615),"Chef shoulders sit lower and level")
	check(world.actors[0].limbs[2].position.y==world.actors[0].limbs[3].position.y,"Chef shoulder line is straight")
	var head: Node3D = hub.portrait.get_node("Head")
	var pose := head.transform
	hub._process(2.0)
	check(head.transform==pose,"Portrait remains fixed")
	check(head.get_node("Mouth").get_meta("closed_smile",false),"Pronounced smile is closed")
	hub.queue_free()
	await process_frame
	print("NEIGHBORHOOD CHECKS: %d failures" % failures)
	quit(1 if failures else 0)

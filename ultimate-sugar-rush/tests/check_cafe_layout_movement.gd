extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var save := root.get_node("SaveSystem")
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	var world = hub.world
	world.set_process(false)
	check(is_instance_valid(world.pickup_counter),"Dedicated pickup counter exists")
	await physics_frame
	var station_zero: Node3D = world.stations[0].node
	var precise_point: Vector2 = world.camera.unproject_position(station_zero.global_position+Vector3(0,1.4,0))
	var precise_pick: Dictionary = world._nearest_movable(precise_point)
	check(not precise_pick.is_empty() and precise_pick.id=="station_0","3D hit target selects the exact object under pointer")
	check(station_zero.get_node("MovePickArea").get_child_count()>1,"Complex furniture uses separate fitted pick shapes instead of one broad box")
	check(world.pickup_counter.position.z<0,"Pickup counter is toward the back of the café")
	check(world.movable_objects.size()>=13,"Stations, displays, counter, table, and plants are movable")
	var regular: Dictionary = world.actors[1]
	var regular_destination: Vector3 = world._customer_shop_position(regular,int(regular.regular_request.recipe_index))
	check(regular_destination.distance_to(world.pickup_counter.position)<2.5,"Regular waits beside pickup counter")
	check(regular_destination.z<2.0,"Regular waiting area stays away from front displays")
	for actor: Dictionary in world.actors:
		if actor.chef or not actor.has("regular_request"): continue
		var waiting: Vector3 = world._customer_shop_position(actor,int(actor.regular_request.recipe_index))
		check(absf(waiting.x-world.CAFE_ORIGIN.x)<6.25 and absf(waiting.z-world.CAFE_ORIGIN.z)<6.0,"Regular waiting place stays inside café floor")
	var pickup_entry: Dictionary = world.movable_objects.filter(func(entry: Dictionary) -> bool: return entry.id=="pickup_counter")[0]
	world.pickup_counter.position = Vector3(8,0,-7)
	var moved_destination: Vector3 = world._customer_shop_position(regular,int(regular.regular_request.recipe_index))
	check(moved_destination.distance_to(world.pickup_counter.position)<2.5,"Regular destination follows moved pickup counter")
	var display_entry: Dictionary = world.movable_objects.filter(func(entry: Dictionary) -> bool: return entry.id=="display_0")[0]
	display_entry.node.position = Vector3(-8,0,8)
	var ordinary := regular.duplicate()
	ordinary.erase("regular_id")
	ordinary.erase("regular_request")
	var display_destination: Vector3 = world._customer_shop_position(ordinary,0)
	check(display_destination.distance_to(display_entry.node.position)<1.3,"Ordinary customer destination follows moved display")
	check(world._customer_path(ordinary)[-1].distance_to(display_destination)<0.01,"Ordinary customer route ends at moved display")
	check(world._customer_path(regular)[-1].distance_to(moved_destination)<0.01,"Regular route ends at moved pickup counter")
	var station_entry: Dictionary = world.movable_objects.filter(func(entry: Dictionary) -> bool: return entry.id=="station_0")[0]
	station_entry.node.position = Vector3(-10,0,-8)
	world._process(0.0)
	check(Vector2(world.batch_icons[0].position.x+10,world.batch_icons[0].position.z+8).length()<0.01,"Craft marker follows moved station")
	world.hold_target = display_entry
	world.hold_elapsed = 0.0
	world.hold_triggered = false
	world.drag_distance = 0.0
	world._process(0.7)
	check(is_instance_valid(hub.object_action_popup),"Tap-and-hold opens persistent object action palette")
	check(world.placement_target.is_empty(),"Long press does not require continued holding to keep move choices open")
	if is_instance_valid(hub.object_action_popup): hub.object_action_popup.queue_free()
	await process_frame
	var overlay_press := InputEventMouseButton.new()
	overlay_press.button_index = MOUSE_BUTTON_LEFT
	overlay_press.pressed = true
	hub._display_hold_input(overlay_press,0)
	await create_timer(0.7).timeout
	check(is_instance_valid(hub.object_action_popup),"Stocked display overlay also opens object action palette")
	if is_instance_valid(hub.object_action_popup): hub.object_action_popup.queue_free()
	await process_frame
	world.begin_object_placement(display_entry)
	check(is_instance_valid(world.placement_marker),"Move action shows floor-position box")
	check(world.placement_marker.has_node("FourWayArrow"),"Move action shows four-way arrow")
	var target_world := Vector3(-5.17,0,-5.32)
	var target_screen: Vector2 = world.camera.unproject_position(target_world)
	check(world._place_object_at_screen(target_screen),"Move mode places object on open plot")
	check(Vector2(display_entry.node.position.x+5,display_entry.node.position.z+5.5).length()<0.01,"Moved object snaps to shared 3D floor grid")
	var saved: Array = save.get_value("cafe_layout","display_0",[])
	check(saved.size()==2 and absf(float(saved[0])-display_entry.node.position.x)<0.01,"Moved location persists")
	var valid_origin: Vector3 = display_entry.node.position
	world.begin_object_placement(display_entry)
	var occupied_screen: Vector2 = world.camera.unproject_position(station_entry.node.position)
	check(not world.preview_object_at_screen(occupied_screen),"Occupied floor space is marked invalid without stopping drag motion")
	check(display_entry.node.position.distance_to(station_entry.node.position)<0.01,"Preview can move freely through an occupied grid cell")
	check(not world.finish_object_placement() and display_entry.node.position==valid_origin,"Invalid release restores last valid saved position")
	var second_hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(second_hub)
	await process_frame
	check(second_hub.world.get_node("ProductDisplay0").position.distance_to(display_entry.node.position)<0.01,"Saved object position restores in a new café scene")
	print("Cafe layout movement: %d failures" % failures)
	quit(failures)

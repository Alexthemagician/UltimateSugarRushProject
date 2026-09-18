extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var database := root.get_node("GameDatabase")
	var progress := root.get_node("CafeProgress")
	for recipe in progress.RECIPES:
		database.upsert_record("inventory",{"id":"product_"+recipe.id,"quantity":100})
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	var world = hub.world
	world.set_process(false)
	var ordinary: Array = world.actors.filter(func(actor: Dictionary) -> bool: return not actor.chef and not actor.has("regular_id"))
	check(ordinary.size()>=2,"Café includes ordinary customers as well as regulars")
	var table: Node3D = world.get_node("CafeTable")
	check(int(table.get_meta("seat_count",0))==2,"Table capacity is derived from its two chairs")
	check((table.get_meta("seat_offsets",[]) as Array).size()==2,"Each chair supplies one reservable seat")
	world._table(world.CAFE_ORIGIN+Vector3(12,0,12),4)
	var four_seat_table: Node3D = world.get_node("TerraceTable")
	check(int(four_seat_table.get_meta("seat_count",0))==4 and (four_seat_table.get_meta("seat_offsets",[]) as Array).size()==4,"Four-chair table sets expose four seats")
	four_seat_table.queue_free()
	await process_frame
	# A moved plant blocks the direct display approach, and A* must route around it.
	var obstacle: Dictionary = world.movable_objects.filter(func(entry: Dictionary) -> bool: return str(entry.id).begins_with("cafe_plant"))[0]
	var saved_position: Vector3 = obstacle.node.position
	var start: Vector3 = world._entry_steps()[-1]
	var probe_customer: Dictionary = ordinary[0]
	var destination: Vector3 = world._customer_shop_position(probe_customer,0)
	obstacle.node.position = start.lerp(destination,0.5)
	obstacle.node.position.y = saved_position.y
	world.navigation_revision += 1
	var route: Array = world._navigation_path(start,destination)
	check(route.size()>2,"Navigation finds a floor route around moved furniture")
	check(route.size()<=15,"Navigation collapses grid steps into longer steady walking segments")
	for point: Vector3 in route:
		check(not world._entry_blocks_characters(obstacle,point,null),"Navigation route never enters the blocking station footprint")
	obstacle.node.position = saved_position
	world.navigation_revision += 1
	# Pip's first purchase takes the dining branch and reserves one chair.
	var diner: Dictionary = ordinary[0]
	diner.state = "shop"
	diner.product_choice = 0
	diner.node.position = world._entry_steps()[-1]
	diner.base_y = diner.node.position.y
	diner.wait = 0.0
	diner.sales = 0
	var dining_coins_before := int(database.get_player_stats().coins)
	world._reset_actor_navigation(diner)
	for frame in 7200:
		world._animate_customer(diner,1.0/60.0)
		if diner.state=="eat": break
	check(diner.state=="eat","Ordinary customer can take a treat to an available seat")
	check(not str(diner.seat_key).is_empty(),"Dining customer reserves a specific chair")
	check(int(database.get_player_stats().coins)==dining_coins_before,"Dining customer has not paid before finishing the meal")
	var second_seat: Dictionary = world._available_customer_seat(ordinary[1])
	check(not second_seat.is_empty() and str(second_seat.key)!=str(diner.seat_key),"A second chair remains independently available")
	for frame in int((world.CUSTOMER_EAT_SECONDS+0.5)*60): world._animate_customer(diner,1.0/60.0)
	check(diner.state in ["leave_seat","exit"],"Customer leaves the chair after eating for the configured duration")
	check(str(diner.seat_key).is_empty(),"Leaving customer releases the chair")
	check(int(database.get_player_stats().coins)>dining_coins_before,"Dining customer pays after finishing the meal")
	# Lulu's alternating visit branch pays and leaves without occupying a seat.
	var takeaway: Dictionary = ordinary[1]
	takeaway.state = "shop"
	takeaway.product_choice = 0
	takeaway.node.position = world._customer_shop_position(takeaway,0)
	takeaway.base_y = takeaway.node.position.y
	takeaway.wait = 1.61
	takeaway.sales = 0
	world._animate_customer(takeaway,0.02)
	check(takeaway.state=="pickup","Ordinary customer can choose takeaway instead of seating")
	check(str(takeaway.seat_key).is_empty(),"Takeaway customer does not reserve a chair")
	var takeaway_coins_before := int(database.get_player_stats().coins)
	for frame in 90: world._animate_customer(takeaway,1.0/60.0)
	check(takeaway.state=="exit" and int(database.get_player_stats().coins)>takeaway_coins_before,"Takeaway customer pays before leaving")
	# Character overlap must not stop movement.
	var overlap_start: Vector3 = world.CAFE_ORIGIN+Vector3(-3,0.14,3)
	diner.node.position = overlap_start
	diner.base_y = overlap_start.y
	diner.node.rotation.y = PI/2.0
	diner.speed = world.WALK_SPEED
	takeaway.node.position = overlap_start+Vector3(0.05,0,0)
	var before: Vector3 = diner.node.position
	world._walk_actor(diner,overlap_start+Vector3(1,0,0),0.5)
	check(diner.node.position.distance_to(before)>0.01,"Characters do not act as navigation obstacles")
	var turn_start := overlap_start+Vector3(0,0,1.5)
	diner.node.position = turn_start
	diner.base_y = turn_start.y
	diner.node.rotation.y = 0.0
	diner.speed = world.WALK_SPEED
	world._walk_actor(diner,turn_start+Vector3(1,0,0),0.1)
	check(diner.node.position.distance_to(turn_start)<0.001 and diner.node.rotation.y>0.0,"Character turns toward a new segment before walking forward")
	# Run a fresh café population through arrivals, shopping, dining, and exits.
	hub.queue_free()
	await process_frame
	var live_hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(live_hub)
	await process_frame
	var live_world = live_hub.world
	live_world.set_process(false)
	var ordinary_slot := 0
	for actor: Dictionary in live_world.actors:
		if actor.chef or actor.has("regular_id"): continue
		actor.state = "shop"
		actor.product_choice = ordinary_slot
		actor.node.position = live_world._entry_steps()[-1]+Vector3(0,0,ordinary_slot*0.4)
		actor.base_y = actor.node.position.y
		actor.wait = 0.0
		actor.sales = 0
		live_world._reset_actor_navigation(actor)
		ordinary_slot += 1
	var furniture_penetrations := 0
	var saw_dining := false
	for frame in 3000:
		live_world._animate_actors(1.0/60.0)
		if frame%8!=0: continue
		for actor: Dictionary in live_world.actors:
			if actor.chef or not actor.node.visible or actor.node.position.y<0: continue
			if actor.state=="eat": saw_dining = true
			for entry: Dictionary in live_world.movable_objects:
				if actor.state in ["to_seat","eat","leave_seat"] and actor.get("seat_table")==entry.node: continue
				if live_world._entry_blocks_characters(entry,actor.node.position,null):
					if furniture_penetrations<5: print("Furniture penetration: ",actor.display_name," ",actor.state," / ",entry.id," at ",actor.node.position)
					furniture_penetrations += 1
	check(furniture_penetrations==0,"Characters complete live visits without entering furniture footprints")
	check(saw_dining,"Live customer cycle includes seated dining")
	print("Cafe navigation: %d failures" % failures)
	quit(failures)

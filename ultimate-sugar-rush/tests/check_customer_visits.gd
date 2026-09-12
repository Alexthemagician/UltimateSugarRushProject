extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var database := root.get_node("GameDatabase")
	var progress := root.get_node("CafeProgress")
	for recipe in progress.RECIPES:
		database.upsert_record("inventory",{"id":"product_"+recipe.id,"quantity":100})
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	var minimum_distance := 100.0
	var case_collisions := 0
	for frame in 18000:
		for customer in hub.world.actors:
			if not customer.chef: hub.world._animate_customer(customer,1.0/60.0)
		var a: Dictionary = hub.world.actors[1]
		var b: Dictionary = hub.world.actors[2]
		if a.node.visible and b.node.visible:
			minimum_distance = minf(minimum_distance,a.node.position.distance_to(b.node.position))
		for customer in [a,b]:
			var p: Vector3 = customer.node.position
			if customer.node.visible and absf(p.z-4.6)<0.6 and p.x > -2.75 and p.x < 5.1: case_collisions += 1
	var failures := 0
	if minimum_distance < 0.5:
		push_error("Customers overlap during repeated visits")
		failures += 1
	for customer in [hub.world.actors[1],hub.world.actors[2]]:
		if customer.sales < 2:
			push_error("Customer did not complete repeated purchases")
			failures += 1
	if case_collisions > 0:
		push_error("Customer route intersects display cases")
		failures += 1
	print("Customer visits: %d failures; closest separation %.3f; case intersections %d" % [failures,minimum_distance,case_collisions])
	quit(failures)

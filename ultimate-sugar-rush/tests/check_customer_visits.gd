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
	var failures := 0
	var regular: Dictionary = hub.world.actors[1]
	var details: Dictionary = hub.world.customer_request_details(regular)
	if int(details.recipe_index) < 0 or str(details.item).is_empty():
		push_error("Clickable customer details do not include the requested item")
		failures += 1
	hub._show_customer_request(regular)
	if not is_instance_valid(hub.modal):
		push_error("Clicking a customer does not open an order popup")
		failures += 1
	hub.modal.queue_free()
	await process_frame
	for recipe in progress.RECIPES:
		database.upsert_record("inventory",{"id":"product_"+recipe.id,"quantity":0})
	regular.state = "shop"
	regular.wait = 0.0
	for frame in 900:
		hub.world._animate_customer(regular,1.0/60.0)
	if regular.state != "shop":
		push_error("Regular left while waiting for an exact request")
		failures += 1
	var ordinary := regular.duplicate()
	ordinary.erase("regular_id")
	ordinary.erase("regular_request")
	ordinary.state = "shop"
	ordinary.wait = 0.0
	ordinary.patience = 0.02
	hub.world._animate_customer(ordinary,0.03)
	if ordinary.state != "exit":
		push_error("Ordinary customer did not leave after patience expired with empty displays")
		failures += 1
	var minimum_distance := 100.0
	var case_collisions := 0
	for recipe in progress.RECIPES:
		database.upsert_record("inventory",{"id":"product_"+recipe.id,"quantity":100})
	for customer: Dictionary in hub.world.actors:
		if customer.chef: continue
		customer.state = "shop"
		customer.node.position = hub.world._entry_steps()[-1]
		customer.base_y = customer.node.position.y
		customer.product_choice = 0
		customer.wait = 0.0
		customer.patience = hub.world.CUSTOMER_PATIENCE_SECONDS
		hub.world._reset_actor_navigation(customer)
	for frame in 2400:
		for customer in hub.world.actors:
			if not customer.chef: hub.world._animate_customer(customer,1.0/60.0)
		var customers: Array = hub.world.actors.filter(func(actor: Dictionary) -> bool: return not actor.chef)
		for i in customers.size():
			for j in range(i+1,customers.size()):
				if customers[i].node.visible and customers[j].node.visible:
					var distance: float = customers[i].node.position.distance_to(customers[j].node.position)
					minimum_distance = minf(minimum_distance,distance)
		for customer in customers:
			var p: Vector3 = customer.node.position
			if customer.node.visible and absf(p.z-4.6)<0.6 and p.x > -2.75 and p.x < 5.1: case_collisions += 1
	# Customers may overlap one another; furniture, rather than other characters,
	# defines the navigation obstacles.
	for customer in hub.world.actors:
		if customer.chef: continue
		if customer.sales < 1:
			push_error("Customer did not complete a purchase cycle: %s state=%s nav=%d" % [customer.display_name,customer.state,customer.get("nav_path",[]).size()])
			failures += 1
	if case_collisions > 0:
		push_error("Customer route intersects display cases")
		failures += 1
	print("Customer visits: %d failures; closest separation %.3f; case intersections %d" % [failures,minimum_distance,case_collisions])
	quit(failures)

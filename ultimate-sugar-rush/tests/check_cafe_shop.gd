extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result
func run() -> void:
	var progress := root.get_node("CafeProgress")
	var database := root.get_node("GameDatabase")
	var save := root.get_node("SaveSystem")
	for id in progress.INGREDIENTS:
		database.upsert_record("inventory",{"id":"ingredient_"+id,"quantity":100})
	for i in 4:
		var recipe: Dictionary = progress.RECIPES[i]
		var before: Dictionary = database.get_player_stats().duplicate(true)
		check(progress.serve(i),"Recipe makes a batch")
		check(progress.product_stock(i)==recipe.batch,"Exact product batch count")
		check(int(database.get_player_stats().coins)==int(before.coins),"Making a batch does not prepay customer sales")
		var receipt: Dictionary = progress.purchase(i)
		check(receipt.coins==recipe.price,"Listed price matches sale")
		check(progress.product_stock(i)==recipe.batch-1,"Sale consumes exactly one item")
		check(int(database.get_player_stats().coins)==int(before.coins)+int(recipe.price),"Sale deposits exact price")
	check(progress.product_stock(0)==49,"Butter-cloud buns start at 50 per batch")
	save.save_now()
	save.load_save()
	database._load_player_tables()
	check(progress.product_stock(0)==49,"Product stock persists")
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	var house: Node3D = hub.world.get_node("Neighborhood/NeighborhoodHouse0")
	check(house.position.x+1.9 < -9.5,"House fully clears road on left grass")
	check(house.basis.z.dot(house.get_meta("road_direction"))>0.99,"House front faces road")
	var head: Node3D = hub.portrait.get_node("Head")
	var initial_head := head.transform
	var smile: Vector3 = head.get_node("Mouth").scale
	for frame in 120: hub._process(0.016)
	check(head.transform==initial_head,"No portrait head movement over animation")
	check(head.get_node("Mouth").scale==smile,"Portrait smile stays still")
	for method in ["_quests","_pantry","_maps"]:
		hub.call(method)
		await process_frame
		var item_count := 0
		var thumbnail_count := 0
		for node in descendants(hub.modal):
			if node.name.begins_with("ItemImage"):
				item_count += 1
				check(node.texture!=null,"Inventory icon has image")
			if node.name.begins_with("MapThumbnail"): thumbnail_count += 1
		check(item_count>=([16,22,18][["_quests","_pantry","_maps"].find(method)]),"Images accompany each listed item in "+method)
		if method=="_maps": check(thumbnail_count==3,"All maps have landscape thumbnails")
	var before_sales: int = int(database.get_player_stats().coins)
	var expected_sales := 0
	var previous: Dictionary = {}
	for i in 4: previous[i] = progress.product_stock(i)
	var customer: Dictionary = hub.world.actors[1]
	var purchased := false
	var crossed_door := false
	var vanished := false
	var last_position: Vector3 = customer.node.position
	for frame in 4500:
		hub.world._process(1.0/60.0)
		var p: Vector3 = customer.node.position
		if customer.state not in ["away","enter"]: check(p.distance_to(last_position)<0.08,"Fluid movement without teleporting")
		if customer.treat.visible: purchased = true
		if purchased and p.x < -4.4 and absf(p.z-2.8)<0.3: crossed_door = true
		if purchased and not customer.node.visible:
			check(p.z>=12.4,"Customer disappears only after reaching down-road endpoint")
			vanished = true
			break
		last_position = p
	check(purchased and crossed_door and vanished,"Customer buys, exits doorway, walks down road, disappears")
	for i in 4: expected_sales += (int(previous[i])-progress.product_stock(i))*int(progress.RECIPES[i].price)
	check(int(database.get_player_stats().coins)==before_sales+expected_sales,"Customer animation credits exactly sold inventory")
	check(int(hub.wallet.text)==int(database.get_player_stats().coins),"Header coin amount updates after customer purchase")
	for i in 4: database.upsert_record("inventory",{"id":"product_"+progress.RECIPES[i].id,"quantity":0})
	var empty_coins: int = int(database.get_player_stats().coins)
	for i in 4: check(progress.purchase(i).is_empty(),"Sold-out item cannot be purchased")
	check(int(database.get_player_stats().coins)==empty_coins,"Sold-out purchases cannot mint coins")
	hub.queue_free()
	await process_frame
	print("CAFE SHOP CHECKS: %d failures" % failures)
	quit(1 if failures else 0)


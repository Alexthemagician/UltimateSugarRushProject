extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var database := root.get_node("GameDatabase")
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	var world = hub.world
	world.set_process(false)
	check(not world.has_node("WelcomeRug"),"Display-area floor mat is removed")
	for index in 5:
		var display: Node3D=world.get_node("ProductDisplay%d" % index)
		var overhead_covers: Array=display.get_children().filter(func(child: Node) -> bool: return child is MeshInstance3D and child.has_meta("display_finish") and child.position.y>1.2)
		check(overhead_covers.is_empty(),"Product display %d has no overhead cover blocking its treats" % index)
		var front_panels: Array=display.get_children().filter(func(child: Node) -> bool: return child is MeshInstance3D and child.position.z>0.35 and child.position.y>1.05)
		check(front_panels.is_empty(),"Product display %d has no front panel blocking its treats" % index)
	var cupcake_matches: Array = world.movable_objects.filter(func(entry: Dictionary) -> bool: return entry.id=="cupcake_counter")
	check(cupcake_matches.size()==1,"Little cupcake counter is movable")
	var cupcake: Dictionary = cupcake_matches[0]
	check(cupcake.node.has_node("MovePickArea"),"Cupcake counter has precise 3D move target")
	var semantic_decor := 0
	for child in world.get_children():
		if child is Node3D and child.has_meta("movable_decor"):
			semantic_decor += 1
			check(world.movable_objects.any(func(entry: Dictionary) -> bool: return entry.node==child),"Every freestanding or wall décor object is movable: "+child.name)
	check(semantic_decor>=9,"Café décor is separated from structural walls and floor")
	check(world.stations.all(func(station: Dictionary) -> bool: return world.movable_objects.any(func(entry: Dictionary) -> bool: return entry.node==station.node)),"Every crafting station is movable")
	for i in 5: check(world.movable_objects.any(func(entry: Dictionary) -> bool: return entry.node==world.get_node("ProductDisplay%d" % i)),"Every product display is movable")
	hub._show_object_actions(cupcake)
	check(is_instance_valid(hub.object_action_popup),"Long press action palette remains open")
	check(hub.object_action_popup.has_node("MoveObjectButton"),"Action palette has four-way Move button")
	check("↕" in hub.object_action_popup.get_node("MoveObjectButton").text and "↔" in hub.object_action_popup.get_node("MoveObjectButton").text,"Move button shows vertical and horizontal arrows")
	check(hub.object_action_popup.has_node("RotateObjectButton"),"Action palette has Rotate button")
	check(hub.object_action_popup.has_node("StoreObjectButton"),"Action palette has Store button")
	var move_press := InputEventMouseButton.new()
	move_press.button_index = MOUSE_BUTTON_LEFT
	move_press.pressed = true
	move_press.position = Vector2(79,40)
	var drag_origin: Vector3 = cupcake.node.position
	hub.object_action_popup.get_node("MoveObjectButton").gui_input.emit(move_press)
	check(not world.placement_target.is_empty(),"Holding the Move button starts object movement")
	check(cupcake.node.position==drag_origin,"Pressing Move keeps the object at its current position")
	var move_drag := InputEventMouseMotion.new()
	move_drag.position = Vector2(99,40)
	move_drag.relative = Vector2(20,0)
	move_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	hub.object_action_popup.get_node("MoveObjectButton").gui_input.emit(move_drag)
	check(cupcake.node.position.distance_to(drag_origin)<3.0,"Move drag follows the cursor without jumping across the café")
	var move_release := InputEventMouseButton.new()
	move_release.button_index = MOUSE_BUTTON_LEFT
	move_release.pressed = false
	move_release.position = Vector2(99,40)
	hub.object_action_popup.get_node("MoveObjectButton").gui_input.emit(move_release)
	check(world.placement_target.is_empty(),"Releasing the Move button completes object movement")
	await process_frame
	hub._show_object_actions(cupcake)
	var start_rotation: float = cupcake.node.rotation.y
	hub.object_action_popup.get_node("RotateObjectButton").pressed.emit()
	check(is_equal_approx(cupcake.node.rotation.y,start_rotation+PI/2.0),"Single rotate tap advances 90 degrees")
	for i in 3: hub.object_action_popup.get_node("RotateObjectButton").pressed.emit()
	check(is_equal_approx(cupcake.node.rotation.y,start_rotation),"Four rotate taps complete 360 degrees")
	hub.object_action_popup.get_node("StoreObjectButton").pressed.emit()
	await process_frame
	check(not cupcake.node.visible and cupcake in world.stored_items(),"Store action hides item and adds it to storage")
	var reloaded = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(reloaded)
	await process_frame
	var reloaded_cupcake: Dictionary = reloaded.world.movable_objects.filter(func(entry: Dictionary) -> bool: return entry.id=="cupcake_counter")[0]
	check(not reloaded_cupcake.node.visible and reloaded_cupcake in reloaded.world.stored_items(),"Stored items remain in Storage after reopening the café")
	reloaded.queue_free()
	await process_frame
	hub._show_object_actions(cupcake)
	check(is_instance_valid(hub.object_action_dismiss_layer),"Action palette creates a click-away dismissal area")
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	hub.object_action_dismiss_layer.gui_input.emit(outside_click)
	await process_frame
	check(not is_instance_valid(hub.object_action_popup),"Clicking empty space closes the object action palette")
	hub._items()
	await process_frame
	var panel: Panel = hub.modal.get_child(0)
	var storage_tab: Button = panel.get_node("StorageTab")
	var shop_tab: Button = panel.get_node("ShopTab")
	check(storage_tab.position.x==shop_tab.position.x and shop_tab.position.y<storage_tab.position.y,"Shop and Storage tabs sit on left edge with Shop on top")
	check(panel.get_node("ItemsHorizontalScroll") is ScrollContainer,"Items use horizontal scrolling")
	check(panel.get_node("ItemsHorizontalScroll/ItemCards").get_child_count()>0,"Storage shows item cards")
	var items_button: Button = hub.get_node("ItemsButton")
	var recipes_button: Button = hub.get_node("RecipesButton")
	check(items_button.position.x<recipes_button.position.x,"Items button is left of Recipes")
	check(items_button.find_child("ItemsStovePlantIcon",true,false) is TextureRect,"Items button uses stove-and-plant artwork")
	var templates: Array = world.shop_templates()
	check(not templates.is_empty(),"Shop has purchasable café items")
	check(templates.all(func(entry: Dictionary) -> bool: return str(entry.id)!="welcome_rug"),"Removed floor mat is not offered in the Shop")
	var coins_before := int(database.get_player_stats().coins)
	var purchased: Dictionary = world.purchase_item(templates[0])
	check(not purchased.is_empty(),"Shop purchase creates a repeatable item")
	check(int(database.get_player_stats().coins)==coins_before-int(templates[0].value),"Shop purchase charges displayed price")
	check(purchased in world.stored_items(),"Purchased item is delivered to Storage")
	world.restore_object(cupcake)
	check(cupcake.node.visible and cupcake not in world.stored_items(),"Storage Place action restores item")
	print("Cafe items: %d failures" % failures)
	quit(failures)

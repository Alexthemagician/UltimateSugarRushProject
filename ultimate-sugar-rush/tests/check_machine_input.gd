extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func tap(world: Node3D, point: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.pressed = true
	world._unhandled_input(press)
	press.pressed = false
	world._unhandled_input(press)
func run() -> void:
	var progress := root.get_node("CafeProgress")
	var save := root.get_node("SaveSystem")
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	save.set_value("cafe","boards_won",10)
	for id in ["mint","berry","coco"]: save.set_value("regular_friendship",id,3)
	for i in progress.RECIPES.size():
		var machine: int = progress.machine_for_recipe(i)
		hub.world._process(0)
		var position: Vector3 = hub.world.stations[machine].node.position + Vector3(0,1.1,0)
		tap(hub.world,hub.world.camera.unproject_position(position))
		check(hub.selected == machine,"Machine tap selects recipe %d" % i)
		check(hub.recipe_buttons.size() == progress.recipes_for_machine(machine).size(),"Machine has crafting control")
		if is_instance_valid(hub.modal): hub.modal.queue_free()
		await process_frame
		save.set_value("cafe_jobs",progress.RECIPES[i].id,{"ready_at":0,"quantity":progress.RECIPES[i].batch})
		hub.world._process(0)
		tap(hub.world,hub.world.camera.unproject_position(hub.world.batch_icons[i].global_position))
		check(progress.product_stock(i) == progress.RECIPES[i].batch,"Hover icon collects correct batch")
		hub.world._process(0)
	print("Machine input: %d failures" % failures)
	quit(failures)

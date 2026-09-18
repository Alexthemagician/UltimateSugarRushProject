extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var save := root.get_node("SaveSystem")
	save.set_value("cafe_layout","position_version",1)
	save.set_value("cafe_layout","display_0",[2.0,3.0])
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	var world = hub.world
	var expected := Vector3(world.CAFE_ORIGIN.x+2.0,0,world.CAFE_ORIGIN.z+3.0)
	check(world.get_node("ProductDisplay0").position.distance_to(expected)<0.01,"Old saved layout migrates with café corner offset")
	check(int(save.get_value("cafe_layout","position_version",0))==2,"Corner migration is versioned")
	var doorway: Node3D = world.get_node("OpenDoorway")
	var outer_step_x := INF
	for child in doorway.get_children():
		if child is MeshInstance3D: outer_step_x = minf(outer_step_x,child.global_position.x)
	check(absf(outer_step_x-(-26.1))<1.0,"Café steps meet the inner edge of the street")
	check(world.CAFE_ORIGIN.x<0 and world.CAFE_ORIGIN.z<0,"Café occupies the far expansion corner")
	var second = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(second)
	await process_frame
	check(second.world.get_node("ProductDisplay0").position.distance_to(expected)<0.01,"Migrated layout offset applies only once")
	print("Cafe corner: %d failures" % failures)
	quit(failures)

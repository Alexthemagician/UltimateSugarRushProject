extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var life := root.get_node("CafeLife")
	var save := root.get_node("SaveSystem")
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	var table: Node3D = hub.world.get_node("CafeTable")
	var local_positions: Array = []
	for child in table.get_children(): local_positions.append(child.transform)
	check(table.get_child_count()>10,"Table, chairs and props grouped together")
	check(life.move_table(Vector2(5,1)),"Valid seating move accepted")
	check(table.position.is_equal_approx(Vector3(5,0,1)),"Scene follows saved placement")
	for i in table.get_child_count(): check(table.get_child(i).transform==local_positions[i],"Furniture arrangement retained")
	check(not life.move_table(Vector2(-6,4)),"Entrance placement rejected")
	check(not life.move_table(Vector2(4,5)),"Display aisle placement rejected")
	check(not life.move_table(Vector2(INF,0)),"Non-finite placement rejected")
	save.load_save()
	check(life.table_position()==Vector2(5,1),"Furniture position survives reload")
	print("Furniture placement: %d failures" % failures)
	quit(failures)

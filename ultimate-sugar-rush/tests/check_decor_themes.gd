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
	for id in life.DECOR_THEMES:
		check(life.set_decor_theme(id),"Theme applies")
		var floors := 0
		var walls := 0
		for node in hub.world.get_children():
			if node is MeshInstance3D and node.has_meta("decor_surface"):
				var surface: String = node.get_meta("decor_surface")
				check(node.material_override.albedo_color.is_equal_approx(Color(life.DECOR_THEMES[id][surface])),"Room material matches theme")
				if surface.begins_with("floor"): floors += 1
				else: walls += 1
		check(floors==132 and walls==4,"All floor tiles and wall sections themed")
		save.load_save()
		check(life.decor_theme()==id,"Theme survives reload")
	check(not life.set_decor_theme("invalid"),"Unknown theme rejected")
	for id in life.DISPLAY_STYLES:
		check(life.set_display_style(id),"Display finish applies")
		var count := 0
		for index in 5:
			for mesh in hub.world.get_node("ProductDisplay%d" % index).get_children():
				if mesh is MeshInstance3D and mesh.has_meta("display_finish"):
					count += 1
					check(mesh.material_override.albedo_color.is_equal_approx(Color(life.DISPLAY_STYLES[id][mesh.get_meta("display_finish")])),"Display material matches finish")
		check(count==15,"All five display bodies and counters updated")
		save.load_save()
		check(life.display_style()==id,"Display finish survives reload")
	check(not life.set_display_style("invalid"),"Unknown display finish rejected")
	print("Decor themes: %d failures" % failures)
	quit(failures)

extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var scene = load("res://cafe.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.stations.size() == 4, "Four separate stations must be present")
	assert(scene.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	var camera_transform: Transform3D = scene.camera.transform
	for index in 4:
		scene.station_buttons[index].pressed.emit()
		await create_timer(0.45).timeout
		assert(scene.selected_station == index)
		assert(scene.status_label.text == scene.stations[index].name)
		assert(scene.detail.text == scene.stations[index].description)
		assert(scene.stations[index].node.scale.is_equal_approx(Vector3.ONE))
		assert(scene.camera.transform == camera_transform, "Station selection must retain the fixed view")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = scene.camera.unproject_position(scene.stations[0].node.position + Vector3(0,1.1,0))
	scene._unhandled_input(tap)
	assert(scene.selected_station == 0, "World station selection must work")
	await create_timer(0.5).timeout
	print("PASS: four stations, buttons, world selection, fixed camera, animation settles")
	quit()


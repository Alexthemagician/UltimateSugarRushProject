extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var router := root.get_node("SceneRouter")
	var save := root.get_node("SaveSystem")
	for i in 8:
		for level in range(2,9): save.set_value("progression","level_%d_unlocked" % level,true)
		router.replace_scene("res://scenes/map/world_map.tscn")
		await create_timer(0.7).timeout
		var target: String = current_scene.ORIGINAL_BOARDS[i]
		current_scene.get_node("Level%d" % (i+1)).pressed.emit()
		await create_timer(0.7).timeout
		if current_scene.scene_file_path!=target:
			failures += 1
			push_error("Sugar Blossom board route failed: "+target)
			continue
		current_scene.get_node("%BackButton").pressed.emit()
		await create_timer(0.7).timeout
		if current_scene.scene_file_path!="res://scenes/map/world_map.tscn":
			failures += 1
			push_error("Original board back route failed")
	print("SUGAR MAP ROUTES: %d failures" % failures)
	quit(1 if failures else 0)

extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.get_node("SaveSystem").set_value("cafe_profile","name","Moonbeam Sweets")
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	var banner: Label = hub.find_child("CharacterCafeName",true,false)
	var sign: Label3D = hub.world.find_child("CafeWallSign",true,false)
	check(is_instance_valid(banner) and banner.text=="Moonbeam Sweets","Character banner uses the saved café name")
	check(is_instance_valid(sign) and sign.text=="MOONBEAM SWEETS","Wall sign uses the saved café name")
	print("Café name labels: %d failures" % failures)
	quit(failures)

extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var script = load("res://scripts/cafe/cafe_visit.gd")
	var data := {"display_name":"Mint","layout":{"version":1,"theme":"mint","table_position":[5,1],"upgrades":{"garden":true,"oven":true,"seating":false}}}
	check(script.valid_snapshot(data),"Valid published layout accepted")
	var broken: Dictionary = data.duplicate(true)
	broken.layout.table_position = [INF,0]
	check(not script.valid_snapshot(broken),"Nonfinite coordinates rejected")
	broken.layout.table_position = [5,1]
	broken.layout.upgrades = {"garden":"true"}
	check(not script.valid_snapshot(broken),"Untrusted upgrade types rejected")
	var database := root.get_node("GameDatabase")
	var save := root.get_node("SaveSystem")
	var stats: Dictionary = database.get_player_stats().duplicate(true)
	var pantry: Dictionary = root.get_node("CafeProgress").pantry()
	var theme: String = root.get_node("CafeLife").decor_theme()
	var visit = script.new()
	visit.snapshot = data
	root.add_child(visit)
	await process_frame
	check(visit.world.actors.is_empty(),"Visitor never runs customer sales")
	check(visit.world.batch_icons.is_empty(),"Visitor has no collectable batches")
	check(visit.world.has_node("GardenUpgrade"),"Owner's garden rendered")
	check(visit.world.get_node("CafeTable").position==Vector3(5,0,1),"Owner's furniture position rendered")
	visit.world._select_station(0)
	visit.world._process(120)
	check(database.get_player_stats()==stats,"Visit leaves local wallet and progression untouched")
	check(root.get_node("CafeProgress").pantry()==pantry,"Visit leaves ingredients untouched")
	check(root.get_node("CafeLife").decor_theme()==theme,"Visit does not overwrite local decoration")
	check(not bool(save.get_value("cafe_upgrades","garden",false)),"Owner's upgrade not granted locally")
	visit.queue_free()
	await process_frame
	print("Cafe visit: %d failures" % failures)
	quit(failures)

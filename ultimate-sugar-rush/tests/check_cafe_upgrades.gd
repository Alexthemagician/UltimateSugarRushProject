extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var life := root.get_node("CafeLife")
	var database := root.get_node("GameDatabase")
	var save := root.get_node("SaveSystem")
	var stats: Dictionary = database.get_player_stats()
	stats.coins = 0
	database.upsert_record("player_stats",stats)
	check(not life.buy_upgrade("oven"),"Insufficient funds rejected")
	check(not life.buy_upgrade("unknown"),"Unknown upgrade rejected")
	stats.coins = 3000
	database.upsert_record("player_stats",stats)
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	for id in life.UPGRADES:
		var coins: int = database.get_player_stats().coins
		check(life.buy_upgrade(id),"Upgrade purchase succeeds")
		check(database.get_player_stats().coins==coins-life.UPGRADES[id].cost,"Exact upgrade price charged")
		check(not life.buy_upgrade(id),"Owned upgrade cannot be bought twice")
	check(life.craft_duration(0,16)==12,"Bread oven is 25 percent faster")
	check(life.craft_duration(3,20)==15,"Cake oven is 25 percent faster")
	check(life.craft_duration(4,10)==10,"Tea duration unaffected")
	check(hub.world.has_node("GardenUpgrade"),"Garden visible")
	check(hub.world.has_meta("seating_upgrade"),"Seating built")
	check(hub.world.stations[0].node.has_node("UpgradeBadge"),"Oven badge visible")
	for index in 5: check(hub.world.get_node("ProductDisplay%d" % index).has_node("ShowcaseUpgrade"),"Display lighting upgrade visible")
	var progress := root.get_node("CafeProgress")
	database.upsert_record("inventory",{"id":"product_butter_cloud_buns","quantity":1})
	var receipt: Dictionary = progress.purchase(0)
	check(receipt.coins==5,"Showcase adds one coin to sale")
	check(progress.purchase(0).is_empty(),"Empty showcase awards no coins")
	var count: int = hub.world.get_child_count()
	hub.world._refresh_upgrades()
	check(hub.world.get_child_count()==count,"Refresh does not duplicate upgrades")
	save.load_save()
	for id in life.UPGRADES: check(life.has_upgrade(id),"Upgrade persists")
	print("Cafe upgrades: %d failures" % failures)
	quit(failures)

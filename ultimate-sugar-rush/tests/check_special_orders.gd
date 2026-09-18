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
	check(not life.deliver_order(0),"Empty pantry cannot fulfill order")
	check(not life.deliver_order(-1),"Invalid order rejected")
	for recipe in root.get_node("CafeProgress").RECIPES:
		database.upsert_record("inventory",{"id":"stored_"+recipe.id,"quantity":100})
	check(not life.deliver_order(1),"Later order remains gated with enough stock")
	for i in life.SPECIAL_ORDERS.size():
		var order: Dictionary = life.SPECIAL_ORDERS[i]
		var quantities := {}
		for id in order.needs: quantities[id] = database.get_record("inventory","stored_"+id,{}).quantity
		var stats: Dictionary = database.get_player_stats().duplicate(true)
		check(life.deliver_order(i),"Available order delivers")
		for id in order.needs:
			check(database.get_record("inventory","stored_"+id,{}).quantity==quantities[id]-order.needs[id],"Exact order quantity consumed")
		check(database.get_player_stats().coins==stats.coins+order.coins,"Exact coin reward")
		check(database.get_player_stats().xp==stats.xp+order.xp,"Exact XP reward")
		check(not life.deliver_order(i),"Completed order cannot be rewarded twice")
		save.load_save()
		check(life.order_complete(i),"Order completion persists")
	print("Special orders: %d failures" % failures)
	quit(failures)

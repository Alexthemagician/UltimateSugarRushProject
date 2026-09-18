extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var life := root.get_node("CafeLife")
	var progress := root.get_node("CafeProgress")
	var database := root.get_node("GameDatabase")
	var save := root.get_node("SaveSystem")
	for wins in [0,2,3,5,6,8,9]:
		save.set_value("cafe","boards_won",wins)
		var event: Dictionary = life.current_event()
		check(event.id==life.EVENTS[(wins/3)%3].id,"Events rotate every three board victories")
		check(event.boards_remaining==3-wins%3,"Correct next-event countdown")
		for i in progress.RECIPES.size():
			var recipe: Dictionary = progress.RECIPES[i]
			database.upsert_record("inventory",{"id":"product_"+recipe.id,"quantity":1})
			var before: int = database.get_player_stats().coins
			var bonus: int = event.bonus if recipe.category==event.category else 0
			var receipt: Dictionary = progress.purchase(i)
			check(receipt.coins==recipe.price+bonus,"Only featured category gets bonus")
			check(database.get_player_stats().coins==before+receipt.coins,"Wallet matches advertised receipt")
			check(progress.purchase(i).is_empty(),"Empty display cannot produce extra event rewards")
		save.save_now()
		save.load_save()
		check(life.current_event().id==event.id,"Event persists without time expiration")
	print("Cafe events: %d failures" % failures)
	quit(failures)

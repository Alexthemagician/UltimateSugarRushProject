extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var progress := root.get_node("CafeProgress")
	var database := root.get_node("GameDatabase")
	var save := root.get_node("SaveSystem")
	for id in progress.INGREDIENTS:
		database.upsert_record("inventory", {"id": "ingredient_" + id, "quantity": 100})
	for i in progress.RECIPES.size():
		var recipe: Dictionary = progress.RECIPES[i]
		var before: Dictionary = progress.pantry()
		check(progress.start_craft(i), "Machine starts with ingredients")
		check(not progress.start_craft(i), "Busy machine rejects another batch")
		check(progress.product_stock(i) == 0, "Crafting does not stock display")
		check(progress.purchase(i).is_empty(), "Customers cannot buy uncollected items")
		check(not progress.collect_batch(i), "Unfinished batch cannot be collected")
		for id in recipe.needs:
			check(progress.pantry()[id] == before[id] - recipe.needs[id], "Ingredients consumed exactly once")
		save.save_now()
		save.load_save()
		check(not progress.craft_job(i).is_empty(), "Machine job survives reload")
		var job: Dictionary = progress.craft_job(i)
		job.ready_at = Time.get_unix_time_from_system() - 1
		save.set_value("cafe_jobs", recipe.id, job)
		check(progress.collect_batch(i), "Ready batch can be collected")
		check(progress.product_stock(i) == recipe.batch, "Collection stocks entire batch")
		check(not progress.collect_batch(i), "Batch cannot be collected twice")
		check(not progress.purchase(i).is_empty(), "Displayed product can be purchased")
		check(progress.product_stock(i) == recipe.batch - 1, "Customer buys exactly one")
	print("Machine jobs: %d failures" % failures)
	quit(failures)

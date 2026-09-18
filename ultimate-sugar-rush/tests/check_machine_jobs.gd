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
	save.set_value("cafe","boards_won",10)
	for regular in ["mint","berry","coco"]: save.set_value("regular_friendship",regular,3)
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
	# Duplicate stations run and collect independent batches from one atomic action.
	var recipe: Dictionary=progress.RECIPES[0]
	for id: String in recipe.needs:
		database.upsert_record("inventory",{"id":"ingredient_"+id,"quantity":100})
	var product_before: int=progress.product_stock(0)
	var stats_before: Dictionary=database.get_player_stats().duplicate(true)
	check(progress.start_craft_batches(0,2,2)==2,"Two selected stations start two jobs together")
	check(progress.active_machine_job_count(0)==2 and progress.max_craft_batches(0,2)==0,"Running jobs occupy both matching stations")
	var parallel_jobs: Array=progress.craft_jobs(0)
	for job: Dictionary in parallel_jobs: job.ready_at=Time.get_unix_time_from_system()-1
	save.set_value("cafe_jobs",recipe.id,parallel_jobs)
	check(progress.collect_batch(0),"All ready parallel jobs collect together")
	check(progress.active_machine_job_count(0)==0 and progress.max_craft_batches(0,2)==2,"Collecting finished recipes frees their stations immediately")
	check(progress.product_stock(0)==product_before+int(recipe.batch)*2,"Parallel station collection adds both batches")
	check(int(database.get_player_stats().batches_made)==int(stats_before.batches_made)+2,"Parallel crafting counts both completed batches")
	print("Machine jobs: %d failures" % failures)
	quit(failures)

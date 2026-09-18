extends Node

signal rewards_changed
const HUB := "res://scenes/cafe/cafe_hub.tscn"
const INGREDIENTS := {
 "sugar_cubes":"Sugar Cubes", "ultra_fine_flour":"Ultra-fine Flour",
 "edible_flowers":"Edible Flowers", "caramel_syrup":"Caramel Syrup",
 "chocolate_syrup":"Chocolate Syrup", "strawberry_syrup":"Strawberry Syrup",
 "honey_glob":"Honey Glob", "spring_water":"Spring Water",
 "creamy_butter":"Creamy Butter", "fondant":"Fondant", "sugar_syrup":"Sugar Syrup",
 "coffee_beans":"Coffee Beans", "oolong_leaves":"Oolong Leaves", "peppermint_leaves":"Peppermint Leaves",
 "vanilla_frosting":"Vanilla Frosting", "strawberry_frosting":"Strawberry Frosting",
 "chocolate_frosting":"Chocolate Frosting", "eggs":"Eggs"
}
const REGIONS := [
 {"name":"Sugar Blossom", "subtitle":"The original merge and candy journey", "color":"e96c8c"},
 {"name":"Honeydew Gardens", "subtitle":"Flower-filled puzzles and fresh tea ingredients", "color":"63b9a7"},
 {"name":"Cocoa Moon", "subtitle":"Chocolate, frosting and evening café treats", "color":"9980c8"}
]
const POOLS := [
 ["sugar_cubes","ultra_fine_flour","creamy_butter","eggs","fondant","sugar_syrup"],
 ["edible_flowers","honey_glob","spring_water","oolong_leaves","peppermint_leaves","strawberry_syrup"],
 ["coffee_beans","caramel_syrup","chocolate_syrup","vanilla_frosting","strawberry_frosting","chocolate_frosting"]
]
var region := 0
var stage := 0
var board_ticket := ""
var board_source := ""

func begin_board(source: String) -> void:
	if source.contains("challenge_match") or source.contains("regional_merge_game"):
		board_source = "region_%d_stage_%d" % [region,stage]
	else:
		region = 0
		stage = 0
		board_source = source.get_file().get_basename()
	var serial := int(SaveSystem.get_value("cafe", "attempt_serial", 0)) + 1
	SaveSystem.set_value("cafe", "attempt_serial", serial)
	board_ticket = "%s:%d" % [board_source,serial]

func pantry() -> Dictionary:
	var result := {}
	for id: String in INGREDIENTS:
		var record: Dictionary = GameDatabase.get_record("inventory", "ingredient_"+id, {})
		result[id] = int(record.get("quantity",0))
	return result

func award_board(source: String) -> Dictionary:
	if board_ticket.is_empty(): begin_board(source)
	var claimed: Dictionary = SaveSystem.get_value("cafe", "claimed", {})
	if claimed.has(board_ticket): return {}
	var pool: Array = POOLS[region]
	var found := {}
	var count := int(SaveSystem.get_value("cafe", "boards_won",0))
	var regional_count := int(SaveSystem.get_value("cafe", "region_wins_%d" % region,0))
	# Independent regional rotation prevents visits elsewhere from skipping ingredients.
	for offset in 3:
		var id: String = pool[(regional_count*3+offset) % pool.size()]
		var quantity := 2 + (stage % 3)
		var record: Dictionary = GameDatabase.get_record("inventory", "ingredient_"+id, {"id":"ingredient_"+id,"item_id":id,"quantity":0})
		record.quantity = int(record.quantity) + quantity
		GameDatabase.upsert_record("inventory",record)
		found[id] = quantity
	var coins := 90 + region*30 + stage*10
	var xp := 35 + region*10 + stage*5
	var stats := GameDatabase.get_player_stats()
	stats.coins = int(stats.get("coins",0)) + coins
	stats.xp = int(stats.get("xp",0)) + xp
	SaveSystem.set_value("quest_progress","xp",int(SaveSystem.get_value("quest_progress","xp",0))+xp)
	stats.level = 1 + int(stats.xp)/200
	GameDatabase.upsert_record("player_stats",stats)
	claimed[board_ticket] = true
	SaveSystem.set_value("cafe","claimed",claimed)
	SaveSystem.set_value("cafe","boards_won",count+1)
	SaveSystem.set_value("cafe","region_wins_%d" % region,regional_count+1)
	SaveSystem.set_value("cafe_completed",board_source,true)
	var receipt := {"coins":coins,"xp":xp,"ingredients":found,"source":board_source}
	SaveSystem.set_value("cafe","last_reward",receipt)
	SaveSystem.save_now()
	rewards_changed.emit()
	return receipt

func reward_text(receipt: Dictionary) -> String:
	if receipt.is_empty(): return ""
	var names: Array[String] = []
	for id: String in receipt.ingredients:
		names.append("%s ×%d" % [INGREDIENTS[id],receipt.ingredients[id]])
	return "+%d coins   +%d XP\n%s" % [receipt.coins,receipt.xp,"  •  ".join(names)]

func stage_unlocked(index: int) -> bool:
	return stage_unlocked_for(region,index)

func stage_complete(region_index: int, index: int) -> bool:
	if region_index == 0:
		if index == 0:
			return bool(SaveSystem.get_value("progression","level_1_complete",false)) or bool(SaveSystem.get_value("progression","level_2_unlocked",false))
		return bool(SaveSystem.get_value("progression","level_%d_complete" % (index+1),false))
	return bool(SaveSystem.get_value("cafe_completed","region_%d_stage_%d" % [region_index,index],false))

func stage_unlocked_for(region_index: int, index: int) -> bool:
	return index == 0 or stage_complete(region_index,index-1)

func stage_played_today(region_index: int, index: int) -> bool:
	if index == 7: return false
	var key := "region_%d_stage_%d" % [region_index,index]
	return str(SaveSystem.get_value("cafe_daily_clears",key,"")) == Time.get_date_string_from_system()

func can_enter_stage(region_index: int, index: int) -> bool:
	return index >= 0 and index < 8 and stage_unlocked_for(region_index,index)

func claim_daily_entry(region_index: int, index: int) -> bool:
	# Entering or abandoning a board does not consume its daily clear.
	return can_enter_stage(region_index,index)

func mark_stage_cleared_today(region_index: int = region, index: int = stage) -> void:
	if index == 7:
		return
	SaveSystem.set_value("cafe_daily_clears","region_%d_stage_%d" % [region_index,index],Time.get_date_string_from_system())
	SaveSystem.save_now()
	CafeRetention.board_first_win_bonus(region_index,index)
	CafeRetention.record_board_result(true)

func open_region(index: int) -> void:
	region = index
	SceneRouter.go_to_scene(map_scene_for_region(index))

func map_scene_for_region(region_index: int = region) -> String:
	return "res://scenes/map/world_map.tscn" if region_index == 0 else "res://scenes/map/cafe_region.tscn"

func open_stage(index: int) -> void:
	if not claim_daily_entry(region,index): return
	stage = index
	var scene := board_scene_for_stage(index)
	if scene.contains("regional_merge_game"):
		SaveSystem.set_section("regional_merge_objectives_%d_%d" % [region,stage],{})
		SaveSystem.set_section("regional_merge_board_%d_%d" % [region,stage],{})
	else:
		SaveSystem.set_section("cafe_challenge_%d_%d" % [region,stage],{})
	SceneRouter.go_to_scene(scene)

func board_scene_for_stage(index: int, region_index: int = region) -> String:
	var merge_board_count := 4 if region_index in [1,2] else 5
	return "res://scenes/merge/regional_merge_game.tscn" if index < merge_board_count else "res://scenes/match3/challenge_match.tscn"

func add_ingredient(id: String, quantity: int) -> bool:
	if id not in INGREDIENTS or quantity <= 0: return false
	var record: Dictionary = GameDatabase.get_record("inventory","ingredient_"+id,{"id":"ingredient_"+id,"item_id":id,"quantity":0})
	record.quantity = int(record.get("quantity",0))+quantity
	GameDatabase.upsert_record("inventory",record)
	SaveSystem.save_now()
	rewards_changed.emit()
	return true

func is_unlimited_board(source: String) -> bool:
	return (source.contains("challenge_match") and stage == 7) or source.contains("marshmallow_match_game")

const RECIPES := [
 {"id":"butter_cloud_buns", "machine":0, "duration":16, "icon":18, "category":"bakery", "batch":50, "price":4, "name":"Butter-cloud buns", "needs":{"ultra_fine_flour":2,"creamy_butter":1,"sugar_cubes":1}},
 {"id":"vanilla_latte", "machine":1, "duration":10, "icon":19, "category":"coffee", "batch":20, "price":9, "name":"Vanilla café latte", "needs":{"coffee_beans":2,"spring_water":1,"vanilla_frosting":1}},
 {"id":"petal_bonbons", "machine":2, "duration":12, "icon":20, "category":"candy", "batch":30, "price":6, "name":"Petal bonbons", "needs":{"fondant":2,"sugar_syrup":1,"edible_flowers":1}},
 {"id":"strawberry_cake", "machine":3, "duration":20, "icon":21, "category":"cake", "batch":12, "price":18, "name":"Strawberry celebration cake", "needs":{"ultra_fine_flour":2,"eggs":2,"strawberry_frosting":1}},
 {"id":"honey_mint_tea", "machine":4, "duration":10, "icon":19, "category":"tea", "batch":20, "price":7, "name":"Honey mint tea", "needs":{"peppermint_leaves":2,"oolong_leaves":1,"spring_water":1,"honey_glob":1}},
 {"id":"caramel_cloud_buns", "machine":0, "duration":18, "icon":18, "category":"bakery", "batch":40, "price":6, "name":"Caramel cloud buns", "wins":3, "needs":{"ultra_fine_flour":2,"creamy_butter":1,"caramel_syrup":2}},
 {"id":"mocha_latte", "machine":1, "duration":12, "icon":19, "category":"coffee", "batch":20, "price":11, "name":"Moonlight mocha", "wins":5, "needs":{"coffee_beans":2,"spring_water":1,"chocolate_syrup":2}},
 {"id":"honey_truffles", "machine":2, "duration":15, "icon":20, "category":"candy", "batch":24, "price":9, "name":"Honey chocolate truffles", "friend":"coco", "visits":3, "needs":{"fondant":2,"honey_glob":1,"chocolate_syrup":2}},
 {"id":"cocoa_cake", "machine":3, "duration":22, "icon":21, "category":"cake", "batch":12, "price":22, "name":"Cocoa moon cake", "friend":"berry", "visits":3, "needs":{"ultra_fine_flour":2,"eggs":2,"chocolate_frosting":2}},
 {"id":"blossom_oolong", "machine":4, "duration":12, "icon":19, "category":"tea", "batch":20, "price":10, "name":"Blossom oolong tea", "friend":"mint", "visits":3, "needs":{"oolong_leaves":2,"edible_flowers":1,"spring_water":2}}
]

func machine_for_recipe(index: int) -> int:
	if index < 0 or index >= RECIPES.size(): return -1
	return int(RECIPES[index].machine)

func recipes_for_machine(machine: int) -> Array[int]:
	var result: Array[int] = []
	for index in RECIPES.size():
		if machine_for_recipe(index) == machine: result.append(index)
	return result

func active_machine_recipe(machine: int) -> int:
	for index in recipes_for_machine(machine):
		if not craft_jobs(index).is_empty(): return index
	return -1

func active_machine_job_count(machine: int) -> int:
	var count := 0
	for index in recipes_for_machine(machine): count += craft_jobs(index).size()
	return count

func recipe_unlocked(index: int) -> bool:
	if index < 0 or index >= RECIPES.size(): return false
	var recipe: Dictionary = RECIPES[index]
	if int(SaveSystem.get_value("cafe","boards_won",0)) < int(recipe.get("wins",0)): return false
	if recipe.has("friend"):
		return int(SaveSystem.get_value("regular_friendship",recipe.friend,0)) >= int(recipe.visits)
	return true

func discovery_hint(index: int) -> String:
	var recipe: Dictionary = RECIPES[index]
	if recipe.has("friend"):
		return "Serve %s %d times to discover this recipe (%d / %d)." % [str(recipe.friend).capitalize(),recipe.visits,SaveSystem.get_value("regular_friendship",recipe.friend,0),recipe.visits]
	return "Win %d boards to discover this recipe (%d / %d)." % [recipe.get("wins",0),SaveSystem.get_value("cafe","boards_won",0),recipe.get("wins",0)]

func can_serve(index: int, station_capacity := 1) -> bool:
	if index < 0 or index >= RECIPES.size(): return false
	return max_craft_batches(index,station_capacity)>0

func serve(index: int) -> bool:
	return start_craft(index)

func craft_jobs(index: int) -> Array:
	if index < 0 or index >= RECIPES.size(): return []
	var saved: Variant = SaveSystem.get_value("cafe_jobs", RECIPES[index].id, [])
	if saved is Array: return (saved as Array).duplicate(true)
	if saved is Dictionary and not (saved as Dictionary).is_empty(): return [(saved as Dictionary).duplicate(true)]
	return []

func craft_job(index: int) -> Dictionary:
	var jobs := craft_jobs(index)
	return jobs[0] if not jobs.is_empty() else {}

func craft_seconds_left(index: int) -> int:
	var job := craft_job(index)
	if job.is_empty(): return 0
	return maxi(0, int(ceil(float(job.ready_at) - Time.get_unix_time_from_system())))

func batch_ready(index: int) -> bool:
	for job: Dictionary in craft_jobs(index):
		if float(job.get("ready_at",0)) <= Time.get_unix_time_from_system(): return true
	return false

func ingredient_batch_limit(index: int) -> int:
	if index < 0 or index >= RECIPES.size() or not recipe_unlocked(index): return 0
	var stock := pantry()
	var limit := 999999
	for id: String in RECIPES[index].needs:
		var needed := int(RECIPES[index].needs[id])
		if needed > 0: limit = mini(limit,int(stock.get(id,0))/needed)
	return maxi(0,limit if limit<999999 else 0)

func max_craft_batches(index: int, station_capacity := 1) -> int:
	if index < 0 or index >= RECIPES.size() or not recipe_unlocked(index): return 0
	var free_stations := maxi(0,station_capacity-active_machine_job_count(machine_for_recipe(index)))
	return mini(free_stations,ingredient_batch_limit(index))

func start_craft(index: int) -> bool:
	return start_craft_batches(index,1,1)==1

func start_craft_batches(index: int, count: int, station_capacity: int) -> int:
	if count <= 0 or count > max_craft_batches(index,station_capacity): return 0
	for id: String in RECIPES[index].needs:
		var record: Dictionary = GameDatabase.get_record("inventory","ingredient_"+id,{})
		record.quantity = int(record.quantity)-int(RECIPES[index].needs[id])*count
		GameDatabase.upsert_record("inventory",record)
	# Wall-clock completion survives leaving the café and restarting the game.
	var jobs := craft_jobs(index)
	var ready_at := Time.get_unix_time_from_system() + CafeLife.craft_duration(index,float(RECIPES[index].duration))
	for _slot in count: jobs.append({"ready_at":ready_at,"quantity":int(RECIPES[index].batch)})
	SaveSystem.set_value("cafe_jobs", RECIPES[index].id, jobs)
	SaveSystem.save_now()
	rewards_changed.emit()
	return count

func collect_batch(index: int) -> bool:
	if not batch_ready(index): return false
	var jobs := craft_jobs(index)
	var remaining: Array = []
	var ready_jobs: Array = []
	var now := Time.get_unix_time_from_system()
	for job: Dictionary in jobs:
		if float(job.get("ready_at",0)) <= now: ready_jobs.append(job)
		else: remaining.append(job)
	if ready_jobs.is_empty(): return false
	var stats := GameDatabase.get_player_stats()
	var product: Dictionary = GameDatabase.get_record("inventory","product_"+RECIPES[index].id,{"id":"product_"+RECIPES[index].id,"quantity":0})
	var collected_quantity := 0
	for job: Dictionary in ready_jobs: collected_quantity += int(job.get("quantity",0))
	product.quantity = int(product.quantity)+collected_quantity
	GameDatabase.upsert_record("inventory",product)
	SaveSystem.set_value("cafe_jobs", RECIPES[index].id, remaining)
	SaveSystem.set_value("quest_progress", RECIPES[index].id, int(SaveSystem.get_value("quest_progress",RECIPES[index].id,0))+collected_quantity)
	var xp_reward := 20*ready_jobs.size()
	SaveSystem.set_value("quest_progress","xp",int(SaveSystem.get_value("quest_progress","xp",0))+xp_reward)
	stats.xp = int(stats.xp)+xp_reward
	stats.level = 1+int(stats.xp)/200
	stats.batches_made = int(stats.get("batches_made",0))+ready_jobs.size()
	GameDatabase.upsert_record("player_stats",stats)
	SaveSystem.save_now()
	CafeRetention.add_progress("craft",ready_jobs.size())
	rewards_changed.emit()
	return true

func product_stock(index: int) -> int:
	return int(GameDatabase.get_record("inventory","product_"+RECIPES[index].id,{}).get("quantity",0))

func stored_stock(index: int) -> int:
	if index < 0 or index >= RECIPES.size(): return 0
	return int(GameDatabase.get_record("inventory","stored_"+RECIPES[index].id,{}).get("quantity",0))

func move_product_stock(index: int, to_display: bool) -> bool:
	if index < 0 or index >= RECIPES.size(): return false
	var source_id: String = ("stored_" if to_display else "product_") + RECIPES[index].id
	var target_id: String = ("product_" if to_display else "stored_") + RECIPES[index].id
	var source: Dictionary = GameDatabase.get_record("inventory",source_id,{})
	var quantity := int(source.get("quantity",0))
	if quantity <= 0: return false
	var target: Dictionary = GameDatabase.get_record("inventory",target_id,{"id":target_id,"quantity":0})
	source.quantity = 0
	target.quantity = int(target.quantity)+quantity
	GameDatabase.upsert_record("inventory",source)
	GameDatabase.upsert_record("inventory",target)
	SaveSystem.save_now()
	rewards_changed.emit()
	return true

func sale_price(index: int) -> int:
	if index < 0 or index >= RECIPES.size(): return 0
	return int(RECIPES[index].price) + CafeLife.event_sale_bonus(index) + (1 if CafeLife.has_upgrade("display") else 0)

func take_product(index: int) -> Dictionary:
	if index < 0 or index >= RECIPES.size() or product_stock(index) <= 0: return {}
	var recipe: Dictionary = RECIPES[index]
	var product: Dictionary = GameDatabase.get_record("inventory","product_"+recipe.id,{})
	product.quantity = int(product.quantity)-1
	GameDatabase.upsert_record("inventory",product)
	SaveSystem.save_now()
	rewards_changed.emit()
	return {"index":index,"name":recipe.name,"coins":sale_price(index)}

func complete_purchase(ticket: Dictionary) -> Dictionary:
	if ticket.is_empty(): return {}
	var sale_coins := int(ticket.get("coins",0))
	var stats := GameDatabase.get_player_stats()
	SaveSystem.set_value("quest_progress","coins",int(SaveSystem.get_value("quest_progress","coins",0))+sale_coins)
	stats.coins = int(stats.coins)+sale_coins
	stats.orders_completed = int(stats.get("orders_completed",0))+1
	GameDatabase.upsert_record("player_stats",stats)
	CafeRetention.add_progress("sales",1)
	CafeRetention.add_progress("coins",sale_coins)
	SaveSystem.save_now()
	rewards_changed.emit()
	return ticket.duplicate(true)

func purchase(index: int) -> Dictionary:
	return complete_purchase(take_product(index))

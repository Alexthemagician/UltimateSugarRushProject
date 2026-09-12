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
	if source.contains("challenge_match"):
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
	return index == 0 or bool(SaveSystem.get_value("cafe_completed","region_%d_stage_%d" % [region,index-1],false))

func open_region(index: int) -> void:
	region = index
	SceneRouter.go_to_scene("res://scenes/map/world_map.tscn" if index==0 else "res://scenes/map/cafe_region.tscn")

func open_stage(index: int) -> void:
	if not stage_unlocked(index): return
	stage = index
	# Each new visit is a playable attempt; retained completion controls map unlocks.
	SaveSystem.set_section("cafe_challenge_%d_%d" % [region,stage],{})
	SceneRouter.go_to_scene("res://scenes/match3/challenge_match.tscn")

const RECIPES := [
 {"id":"butter_cloud_buns", "batch":50, "price":4, "name":"Butter-cloud buns", "needs":{"ultra_fine_flour":2,"creamy_butter":1,"sugar_cubes":1}},
 {"id":"vanilla_latte", "batch":20, "price":9, "name":"Vanilla café latte", "needs":{"coffee_beans":2,"spring_water":1,"vanilla_frosting":1}},
 {"id":"petal_bonbons", "batch":30, "price":6, "name":"Petal bonbons", "needs":{"fondant":2,"sugar_syrup":1,"edible_flowers":1}},
 {"id":"strawberry_cake", "batch":12, "price":18, "name":"Strawberry celebration cake", "needs":{"ultra_fine_flour":2,"eggs":2,"strawberry_frosting":1}},
 {"id":"honey_mint_tea", "batch":20, "price":7, "name":"Honey mint tea", "needs":{"peppermint_leaves":2,"oolong_leaves":1,"spring_water":1,"honey_glob":1}}
]

func can_serve(index: int) -> bool:
	if index < 0 or index >= RECIPES.size() or not craft_job(index).is_empty(): return false
	var stock := pantry()
	for id: String in RECIPES[index].needs:
		if int(stock[id]) < int(RECIPES[index].needs[id]): return false
	return true

func serve(index: int) -> bool:
	return start_craft(index)

func craft_job(index: int) -> Dictionary:
	if index < 0 or index >= RECIPES.size(): return {}
	return SaveSystem.get_value("cafe_jobs", RECIPES[index].id, {}).duplicate(true)

func craft_seconds_left(index: int) -> int:
	var job := craft_job(index)
	if job.is_empty(): return 0
	return maxi(0, int(ceil(float(job.ready_at) - Time.get_unix_time_from_system())))

func batch_ready(index: int) -> bool:
	return not craft_job(index).is_empty() and craft_seconds_left(index) == 0

func start_craft(index: int) -> bool:
	if not can_serve(index): return false
	for id: String in RECIPES[index].needs:
		var record: Dictionary = GameDatabase.get_record("inventory","ingredient_"+id,{})
		record.quantity = int(record.quantity)-int(RECIPES[index].needs[id])
		GameDatabase.upsert_record("inventory",record)
	# Wall-clock completion survives leaving the café and restarting the game.
	SaveSystem.set_value("cafe_jobs", RECIPES[index].id, {
		"ready_at": Time.get_unix_time_from_system() + [16, 10, 12, 20, 10][index],
		"quantity": int(RECIPES[index].batch)
	})
	SaveSystem.save_now()
	rewards_changed.emit()
	return true

func collect_batch(index: int) -> bool:
	if not batch_ready(index): return false
	var job := craft_job(index)
	var stats := GameDatabase.get_player_stats()
	var product: Dictionary = GameDatabase.get_record("inventory","product_"+RECIPES[index].id,{"id":"product_"+RECIPES[index].id,"quantity":0})
	product.quantity = int(product.quantity)+int(job.quantity)
	GameDatabase.upsert_record("inventory",product)
	SaveSystem.set_value("cafe_jobs", RECIPES[index].id, {})
	SaveSystem.set_value("quest_progress", RECIPES[index].id, int(SaveSystem.get_value("quest_progress",RECIPES[index].id,0))+int(job.quantity))
	SaveSystem.set_value("quest_progress","xp",int(SaveSystem.get_value("quest_progress","xp",0))+20)
	stats.xp = int(stats.xp)+20
	stats.level = 1+int(stats.xp)/200
	stats.batches_made = int(stats.get("batches_made",0))+1
	GameDatabase.upsert_record("player_stats",stats)
	SaveSystem.save_now()
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

func purchase(index: int) -> Dictionary:
	if index < 0 or index >= RECIPES.size() or product_stock(index) <= 0: return {}
	var recipe: Dictionary = RECIPES[index]
	var product: Dictionary = GameDatabase.get_record("inventory","product_"+recipe.id,{})
	product.quantity = int(product.quantity)-1
	GameDatabase.upsert_record("inventory",product)
	var stats := GameDatabase.get_player_stats()
	SaveSystem.set_value("quest_progress","coins",int(SaveSystem.get_value("quest_progress","coins",0))+int(recipe.price))
	stats.coins = int(stats.coins)+int(recipe.price)
	stats.orders_completed = int(stats.get("orders_completed",0))+1
	GameDatabase.upsert_record("player_stats",stats)
	SaveSystem.save_now()
	rewards_changed.emit()
	return {"index":index,"name":recipe.name,"coins":recipe.price}

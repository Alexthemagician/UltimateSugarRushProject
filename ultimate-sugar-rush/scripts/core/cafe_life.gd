extends Node

signal life_changed

func table_position() -> Vector2:
	var value: Array = SaveSystem.get_value("cafe_design","table_position",[4.5,-1.5])
	return Vector2(float(value[0]),float(value[1]))

func move_table(position: Vector2) -> bool:
	if not position.is_finite() or position.x < 3.5 or position.x > 5.5 or position.y < -1.5 or position.y > 1.5: return false
	SaveSystem.set_value("cafe_design","table_position",[position.x,position.y])
	SaveSystem.save_now()
	life_changed.emit()
	return true

const DECOR_THEMES := {
	"strawberry":{"name":"Strawberry cream","floor_a":"f8e9d1","floor_b":"e6b6aa","wall":"f7ddc6"},
	"mint":{"name":"Mint conservatory","floor_a":"f0f5df","floor_b":"9bcebb","wall":"dcefe5"},
	"cocoa":{"name":"Cocoa evening","floor_a":"d6bbab","floor_b":"8d6575","wall":"c9bbdf"}
}

func decor_theme() -> String:
	var id := str(SaveSystem.get_value("cafe_design","theme","strawberry"))
	return id if DECOR_THEMES.has(id) else "strawberry"

func set_decor_theme(id: String) -> bool:
	if not DECOR_THEMES.has(id): return false
	SaveSystem.set_value("cafe_design","theme",id)
	SaveSystem.save_now()
	CafeRetention.add_progress("decorate",1)
	life_changed.emit()
	return true

const EVENTS := [
	{"id":"rainy_reading","name":"Rainy reading afternoon","category":"tea","description":"The reading club is settling in. Display tea for a little extra appreciation.","bonus":3},
	{"id":"blossom_festival","name":"Blossom sweet festival","category":"candy","description":"Flower sweets are the neighborhood favorite today. Stock the candy display.","bonus":3},
	{"id":"birthday_weekend","name":"Birthday gathering","category":"cake","description":"Everyone is celebrating something. Make room for cake on your displays.","bonus":4}
]

func current_event() -> Dictionary:
	var wins := int(SaveSystem.get_value("cafe","boards_won",0))
	var result: Dictionary = EVENTS[(wins/3)%EVENTS.size()].duplicate(true)
	result.boards_remaining = 3-wins%3
	return result

func event_sale_bonus(recipe_index: int) -> int:
	if recipe_index < 0 or recipe_index >= CafeProgress.RECIPES.size(): return 0
	var event := current_event()
	return int(event.bonus) if CafeProgress.RECIPES[recipe_index].get("category","")==event.category else 0

const UPGRADES := {
	"display":{"name":"Patisserie showcase","cost":600,"description":"Gold-lit display cases make every treat shine. Earn 1 extra coin per customer purchase."},
	"oven":{"name":"Efficient ovens","cost":650,"description":"Bread and cake batches finish 25% sooner. Adds a brass upgrade badge to both ovens."},
	"garden":{"name":"Blossom garden corner","cost":450,"description":"Add a flowering garden beside the café entrance."},
	"seating":{"name":"Garden seating","cost":500,"description":"Add a table and stools outside for a welcoming café terrace."}
}

func has_upgrade(id: String) -> bool:
	return UPGRADES.has(id) and bool(SaveSystem.get_value("cafe_upgrades",id,false))

func buy_upgrade(id: String) -> bool:
	if not UPGRADES.has(id) or has_upgrade(id): return false
	var stats := GameDatabase.get_player_stats()
	if int(stats.coins) < int(UPGRADES[id].cost): return false
	stats.coins = int(stats.coins)-int(UPGRADES[id].cost)
	GameDatabase.upsert_record("player_stats",stats)
	SaveSystem.set_value("cafe_upgrades",id,true)
	SaveSystem.save_now()
	life_changed.emit()
	return true

func craft_duration(index: int, base_seconds: float) -> float:
	var category: String = CafeProgress.RECIPES[index].get("category","")
	return base_seconds * 0.75 if category in ["bakery","cake","cupcake"] and has_upgrade("oven") else base_seconds

const SPECIAL_ORDERS := [
	{"id":"birthday_picnic","name":"Berry’s birthday picnic","description":"Cake and tea for a small birthday in the park.","needs":{"strawberry_cake":3,"honey_mint_tea":5},"coins":160,"xp":50},
	{"id":"sketch_club","name":"Mint’s sketch club","description":"A cozy afternoon of drawing, warm drinks and cloud buns.","needs":{"butter_cloud_buns":10,"honey_mint_tea":8},"coins":220,"xp":65},
	{"id":"delivery_thanks","name":"A sweet thank-you","description":"Coco wants to thank the neighborhood delivery crew.","needs":{"petal_bonbons":12,"vanilla_latte":6},"coins":260,"xp":80}
]

func recipe_index(id: String) -> int:
	for i in CafeProgress.RECIPES.size():
		if CafeProgress.RECIPES[i].id == id: return i
	return -1

func order_complete(index: int) -> bool:
	return index >= 0 and index < SPECIAL_ORDERS.size() and bool(SaveSystem.get_value("special_orders",SPECIAL_ORDERS[index].id,false))

func can_deliver_order(index: int) -> bool:
	if index < 0 or index >= SPECIAL_ORDERS.size() or order_complete(index): return false
	if index > 0 and not order_complete(index-1): return false
	for id in SPECIAL_ORDERS[index].needs:
		var recipe := recipe_index(id)
		if recipe < 0 or CafeProgress.stored_stock(recipe) < int(SPECIAL_ORDERS[index].needs[id]): return false
	return true

func deliver_order(index: int) -> bool:
	if not can_deliver_order(index): return false
	var order: Dictionary = SPECIAL_ORDERS[index]
	for id in order.needs:
		var stock: Dictionary = GameDatabase.get_record("inventory","stored_"+id,{})
		stock.quantity = int(stock.quantity)-int(order.needs[id])
		GameDatabase.upsert_record("inventory",stock)
	var stats := GameDatabase.get_player_stats()
	stats.coins = int(stats.coins)+int(order.coins)
	stats.xp = int(stats.xp)+int(order.xp)
	stats.level = 1+int(stats.xp)/200
	GameDatabase.upsert_record("player_stats",stats)
	SaveSystem.set_value("special_orders",order.id,true)
	SaveSystem.set_value("quest_progress","xp",int(SaveSystem.get_value("quest_progress","xp",0))+int(order.xp))
	SaveSystem.save_now()
	life_changed.emit()
	return true

const REGULARS := {
	"mint":{"name":"Mint", "category":"tea", "intro":"A quiet cup helps me finish my sketches.", "story":["I found this café on my way to class.","Your tea makes this my favorite sketching spot.","I drew a little garden for your café!"]},
	"berry":{"name":"Berry", "category":"cake", "intro":"There is always a reason for a slice of cake.", "story":["I am planning a birthday picnic.","Everyone keeps asking where I buy these cakes.","Could we celebrate our next birthday here?"]},
	"coco":{"name":"Coco", "category":"candy", "intro":"A sweet treat for the end of my delivery route.", "story":["One last delivery, then a bonbon.","I have started telling my route about your sweets.","This café feels like the neighborhood's meeting place."]}
}

func recipes_in_category(category: String) -> Array[int]:
	var result: Array[int] = []
	for i in CafeProgress.RECIPES.size():
		if CafeProgress.RECIPES[i].get("category","") == category: result.append(i)
	return result

func new_regular_request(regular_id: String) -> Dictionary:
	if not REGULARS.has(regular_id): return {}
	var regular: Dictionary = REGULARS[regular_id]
	var choices := recipes_in_category(regular.category).filter(func(index: int) -> bool: return CafeProgress.recipe_unlocked(index))
	if choices.is_empty(): return {}
	return {"regular_id":regular_id,"category":regular.category,"recipe_index":choices.pick_random(),"fulfilled":false}

func fulfill_regular(request: Dictionary, recipe_index: int) -> bool:
	if request.is_empty() or bool(request.get("fulfilled",false)): return false
	if recipe_index != int(request.get("recipe_index",-1)): return false
	var regular_id := str(request.get("regular_id",""))
	if not REGULARS.has(regular_id) or recipe_index not in recipes_in_category(REGULARS[regular_id].category): return false
	request.fulfilled = true
	var visits := int(SaveSystem.get_value("regular_friendship",regular_id,0))+1
	SaveSystem.set_value("regular_friendship",regular_id,visits)
	SaveSystem.save_now()
	CafeRetention.add_progress("regular",1)
	life_changed.emit()
	return true

func regular_story(regular_id: String) -> String:
	if not REGULARS.has(regular_id): return ""
	var visits := int(SaveSystem.get_value("regular_friendship",regular_id,0))
	return REGULARS[regular_id].story[mini(visits/3,2)]

const DISPLAY_STYLES := {
	"rose":{"name":"Rose enamel", "body":"e96c8c", "top":"fff0d5"},
	"sage":{"name":"Sage porcelain", "body":"63b9a7", "top":"f0f5df"},
	"walnut":{"name":"Walnut patisserie", "body":"795341", "top":"ecd5ad"}
}
func display_style() -> String:
	var id := str(SaveSystem.get_value("cafe_design","display_style","rose"))
	return id if DISPLAY_STYLES.has(id) else "rose"
func set_display_style(id: String) -> bool:
	if not DISPLAY_STYLES.has(id): return false
	SaveSystem.set_value("cafe_design","display_style",id)
	SaveSystem.save_now()
	life_changed.emit()
	return true

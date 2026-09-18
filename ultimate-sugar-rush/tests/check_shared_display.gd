extends "res://tests/check_quest_gui.gd"

func run() -> void:
	var database := root.get_node("GameDatabase")
	var progress := root.get_node("CafeProgress")
	for index in [0,5]:
		database.upsert_record("inventory",{"id":"product_"+progress.RECIPES[index].id,"quantity":20})
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	hub.world._process(0)
	hub._process(0)
	check(hub.display_stock_buttons[0].visible,"Shared display has one clickable target")
	check(not hub.display_stock_buttons[5].visible,"Variant does not overlap the case target")
	await click(hub.display_stock_buttons[0])
	check(is_instance_valid(hub.modal.find_child("StoreDisplay0",true,false)),"Original has a storage choice")
	check(is_instance_valid(hub.modal.find_child("StoreDisplay5",true,false)),"Variant has a storage choice")
	await click(hub.modal.find_child("StoreDisplay5",true,false))
	check(progress.product_stock(0)==20,"Selecting variant preserves original display stock")
	check(progress.product_stock(5)==0 and progress.stored_stock(5)==20,"Selecting variant stores only its stock")
	await process_frame
	hub._process(0)
	await click(hub.display_stock_buttons[0])
	await click(hub.modal.find_child("StoreDisplay",true,false))
	check(progress.product_stock(0)==0 and progress.stored_stock(0)==20,"Remaining original opens direct storage menu")
	check(progress.stored_stock(5)==20,"Original transfer preserves stored variant")
	print("Shared display: %d failures" % failures)
	quit(failures)

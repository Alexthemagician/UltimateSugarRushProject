extends SceneTree

var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)

func run() -> void:
	var progress:=root.get_node("CafeProgress")
	var database:=root.get_node("GameDatabase")
	var save:=root.get_node("SaveSystem")
	var hub=load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub); await process_frame; hub.world.set_process(false)
	var recipes_button:=hub.find_child("RecipesButton",true,false) as Button
	check(is_instance_valid(recipes_button),"Cafe has one Recipes button")
	check(hub.find_child("BakeryButton",true,false)==null and hub.find_child("CoffeeButton",true,false)==null and hub.find_child("CandyButton",true,false)==null and hub.find_child("CakesButton",true,false)==null,"Old separate recipe buttons are removed")
	check(recipes_button.find_child("RecipePotIcon",true,false)!=null,"Recipes button uses the steaming pot icon")
	recipes_button.pressed.emit(); await process_frame
	check(hub.modal.find_child("MallowMascot",true,false)!=null,"Mallow appears in the recipe book")
	var tabs:=hub.modal.find_child("RecipeTabs",true,false) as HBoxContainer
	check(is_instance_valid(tabs) and tabs.get_child_count()==5,"Five recipe types run horizontally across the top")
	var scroll:=hub.modal.find_child("RecipeCardScroll",true,false) as ScrollContainer
	var row:=hub.modal.find_child("RecipeCardRow",true,false) as HBoxContainer
	check(is_instance_valid(scroll) and is_instance_valid(row),"Recipes appear in a horizontal scrollable list")
	check(row.get_child_count()==progress.recipes_for_machine(0).size(),"Bakery tab contains every bakery recipe")
	for card: Control in row.get_children():
		check(card.custom_minimum_size.x==card.custom_minimum_size.y,"Every recipe is presented in a square card")
		check(not card.find_children("*","TextureRect",true,false).is_empty(),"Each recipe card includes artwork")
		if not card.find_children("CraftRecipe*","Button",true,false).is_empty(): check(true,"Unlocked recipe includes a Craft button")
	hub._quests(1); await process_frame
	row=hub.modal.find_child("RecipeCardRow",true,false)
	check(row.get_child_count()==progress.recipes_for_machine(1).size(),"Coffee tab swaps in the full coffee recipe view")
	for index in 5:
		hub._quests(index); await process_frame
		check(hub.modal.find_child("RecipeTab%s" % ["Bakery","Coffee","Candy","Cakes","Tea"][index],true,false)!=null,"Category tab %d remains available" % index)
		for recipe_index in progress.recipes_for_machine(index):
			if progress.recipe_unlocked(recipe_index): check(hub.modal.find_child("CraftRecipe%d" % recipe_index,true,false)!=null,"Unlocked recipe %d links to its station with Craft" % recipe_index)
	# The book links recipes to every matching station, including purchased copies.
	for id: String in progress.INGREDIENTS:
		database.upsert_record("inventory",{"id":"ingredient_"+id,"quantity":100})
	var bakery_template: Dictionary=hub.world.movable_objects.filter(func(entry: Dictionary) -> bool: return str(entry.id)=="station_0")[0]
	hub.world._create_purchased_item(bakery_template,"purchased_station_0_recipe_test")
	check(hub.world.crafting_station_count(0)==2,"Recipe book counts every visible matching station")
	hub._select_station(0); await process_frame
	check(hub.recipe_buttons.size()>=1 and hub.recipe_buttons[0].name.begins_with("CraftRecipe"),"Station opens the shared recipe book with Craft actions")
	var craft:=hub.modal.find_child("CraftRecipe0",true,false) as Button
	check(is_instance_valid(craft) and not craft.disabled,"Recipe can be crafted directly from its card")
	var recipe: Dictionary=progress.RECIPES[0]
	var pantry_before: Dictionary=progress.pantry()
	craft.pressed.emit(); await process_frame
	var picker: Control=hub.get_node_or_null("RecipeCraftPickerShade")
	check(is_instance_valid(picker),"Craft opens a station-count popup before starting")
	var count_label:=picker.find_child("CraftStationCount",true,false) as Label
	var minus:=picker.find_child("CraftMinus",true,false) as Button
	var plus:=picker.find_child("CraftPlus",true,false) as Button
	check(count_label.text=="1 / 2","Popup starts at one and shows the total matching stations")
	check(minus.disabled,"Minus is clamped at one")
	plus.pressed.emit()
	check(count_label.text=="2 / 2" and plus.disabled,"Plus is clamped at the station total")
	var confirm:=picker.find_child("ConfirmRecipeCraft",true,false) as Button
	confirm.pressed.emit(); await process_frame
	check(progress.craft_jobs(0).size()==2,"Confirm starts one saved crafting job on each selected station")
	for id: String in recipe.needs:
		check(progress.pantry()[id]==int(pantry_before[id])-int(recipe.needs[id])*2,"Multi-station craft consumes ingredients for every selected batch")
	# Ingredient supply can be the tighter clamp even when more stations exist.
	save.set_value("cafe_jobs",recipe.id,[])
	for id: String in recipe.needs:
		database.upsert_record("inventory",{"id":"ingredient_"+id,"quantity":int(recipe.needs[id])})
	hub._quests(0); await process_frame
	craft=hub.modal.find_child("CraftRecipe0",true,false)
	craft.pressed.emit(); await process_frame
	picker=hub.get_node_or_null("RecipeCraftPickerShade")
	count_label=picker.find_child("CraftStationCount",true,false)
	plus=picker.find_child("CraftPlus",true,false)
	check(count_label.text=="1 / 2" and plus.disabled,"Plus is clamped by ingredients when only one batch can be made")
	print("Recipe book: %d failures" % failures)
	quit(failures)

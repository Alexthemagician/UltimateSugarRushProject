extends RefCounted

const CATEGORIES := [
	{"name":"Bakery","machine":0,"color":"f6d2ad"},
	{"name":"Coffee","machine":1,"color":"dfc0aa"},
	{"name":"Candy","machine":2,"color":"f5c4d7"},
	{"name":"Cakes","machine":3,"color":"e5c7ee"},
	{"name":"Tea","machine":4,"color":"c8e4d0"},
]
const MACHINE_NAMES := ["bread oven","coffee machine","candy maker","cake oven","tea brewer"]
const MALLOW_MASCOT=preload("res://assets/cafe/mallow_bunny.png")

static func show(hub: Control, selected_category := 0, at_machine := false) -> void:
	selected_category=clampi(selected_category,0,CATEGORIES.size()-1)
	hub.recipe_buttons.clear()
	if is_instance_valid(hub.modal): hub.modal.queue_free()
	var shade:=ColorRect.new(); shade.color=Color(0.13,0.10,0.22,0.8); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hub.add_child(shade); hub.modal=shade
	var panel:=Panel.new(); panel.position=Vector2((hub.size.x-1500)*0.5,70); panel.size=Vector2(1500,940); panel.add_theme_stylebox_override("panel",hub.style(Color("fff0cf"))); shade.add_child(panel)
	hub.label("Mallow’s recipe book",Vector2(40,24),Vector2(1140,65),42,panel).name="RecipeBookTitle"
	hub.label("Choose a category, then swipe sideways through its recipes.",Vector2(42,82),Vector2(1140,42),23,panel)
	var mascot_frame:=Control.new(); mascot_frame.position=Vector2(1208,10); mascot_frame.size=Vector2(145,140); mascot_frame.clip_contents=true; mascot_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.add_child(mascot_frame)
	var mascot:=TextureRect.new(); mascot.name="MallowMascot"; mascot.texture=MALLOW_MASCOT; mascot.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; mascot.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; mascot.mouse_filter=Control.MOUSE_FILTER_IGNORE; mascot_frame.add_child(mascot); mascot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub.button("×",Vector2(1385,22),Vector2(80,70),shade.queue_free,panel)

	var tabs:=HBoxContainer.new(); tabs.name="RecipeTabs"; tabs.position=Vector2(35,135); tabs.size=Vector2(1430,82); tabs.add_theme_constant_override("separation",12); panel.add_child(tabs)
	for index in CATEGORIES.size():
		var category: Dictionary=CATEGORIES[index]
		var tab: Button=hub.button(str(category.name),Vector2.ZERO,Vector2.ZERO,show.bind(hub,index,at_machine),tabs)
		tab.name="RecipeTab%s" % category.name
		tab.custom_minimum_size=Vector2(276,78)
		tab.add_theme_stylebox_override("normal",hub.style(Color(category.color) if index==selected_category else Color("fffaf0")))
		tab.add_theme_stylebox_override("hover",hub.style(Color(category.color).lightened(0.08)))

	var scroll:=ScrollContainer.new(); scroll.name="RecipeCardScroll"; scroll.position=Vector2(35,240); scroll.size=Vector2(1430,650); panel.add_child(scroll)
	var row:=HBoxContainer.new(); row.name="RecipeCardRow"; row.custom_minimum_size=Vector2(1430,525); row.add_theme_constant_override("separation",24); row.alignment=BoxContainer.ALIGNMENT_BEGIN; scroll.add_child(row)
	var recipe_indices: Array[int]=CafeProgress.recipes_for_machine(int(CATEGORIES[selected_category].machine))
	for recipe_index in recipe_indices:
		_build_card(hub,row,recipe_index,selected_category,at_machine)

static func _build_card(hub: Control, row: HBoxContainer, recipe_index: int, category: int, at_machine: bool) -> void:
	var recipe: Dictionary=CafeProgress.RECIPES[recipe_index]
	var card:=Panel.new(); card.name="RecipeCard%d" % recipe_index; card.custom_minimum_size=Vector2(525,525); card.size_flags_vertical=Control.SIZE_SHRINK_BEGIN; card.add_theme_stylebox_override("panel",hub.style(Color("fffaf2"))); row.add_child(card)
	var unlocked:=CafeProgress.recipe_unlocked(recipe_index)
	var title: Label=hub.label(str(recipe.name) if unlocked else "Undiscovered recipe",Vector2(24,18),Vector2(477,58),30,card); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var picture: TextureRect=hub.stock_image(int(recipe.icon),Vector2(188,78),Vector2(150,132),card); picture.name="RecipePicture%d" % recipe_index
	if not unlocked: picture.modulate=Color(0.12,0.10,0.14,0.72)
	if not unlocked:
		var hint: Label=hub.label(CafeProgress.discovery_hint(recipe_index),Vector2(38,225),Vector2(449,120),22,card); hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		hub.label("Keep playing to reveal its ingredients and rewards.",Vector2(45,380),Vector2(435,58),20,card).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		return
	var info: Label=hub.label("Makes %d  •  %d coins each  •  %ds" % [recipe.batch,CafeProgress.sale_price(recipe_index),recipe.duration],Vector2(30,210),Vector2(465,38),21,card); info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var stock:=CafeProgress.pantry()
	var ingredient_y:=258.0
	for ingredient_id: String in recipe.needs:
		hub.stock_image(CafeProgress.INGREDIENTS.keys().find(ingredient_id),Vector2(34,ingredient_y),Vector2(40,40),card)
		hub.label("%s   %d / %d" % [CafeProgress.INGREDIENTS[ingredient_id],stock[ingredient_id],recipe.needs[ingredient_id]],Vector2(82,ingredient_y),Vector2(405,40),19,card)
		ingredient_y+=43
	var machine:=int(CATEGORIES[category].machine)
	var station_total: int=hub._recipe_station_capacity(recipe_index)
	var craft_limit: int=hub._recipe_craft_limit(recipe_index)
	var availability_text := "%d %s%s  •  ingredients for %d" % [station_total,MACHINE_NAMES[machine],"s" if station_total!=1 else "",CafeProgress.ingredient_batch_limit(recipe_index)]
	var availability: Label=hub.label(availability_text,Vector2(24,432),Vector2(477,26),16,card); availability.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var action_text := "Craft"
	if craft_limit<=0: action_text="Stations busy" if station_total>0 and CafeProgress.ingredient_batch_limit(recipe_index)>0 else "Need ingredients"
	var make: Button=hub.button(action_text,Vector2(34,462),Vector2(457,54),hub._show_recipe_craft_picker.bind(recipe_index,category),card)
	make.name="CraftRecipe%d" % recipe_index
	make.add_theme_font_size_override("font_size",22)
	make.disabled=craft_limit<=0
	hub.recipe_buttons.append(make)

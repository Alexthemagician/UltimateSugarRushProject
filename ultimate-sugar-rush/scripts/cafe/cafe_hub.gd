extends Control

const CREAM := Color("fff3e6")
const INK := Color("653f50")
const PINK := Color("e96c8c")
var wallet: Label
var xp_label: Label
var xp_bar: ProgressBar
var portrait: Node3D
var portrait_time := 0.0
var stock_labels: Dictionary = {}
var sale_notice: Label
var sale_time := 0.0
const STOCK_ATLAS = preload("res://assets/cafe/stock_atlas.png")
const MAP_ART := ["res://assets/map/sugar_landscape_v3.png","res://assets/map/honeydew_landscape_v2.png","res://assets/map/cocoa_landscape_v3.png"]
var icon_buttons: Array[Button] = []
var recipe_buttons: Array[Button] = []
const ICON_ATLAS = preload("res://assets/cafe/menu_atlas.png")
const RECIPE_POT_ICON = preload("res://assets/cafe/recipes_steam_pot.png")
const ITEMS_ICON = preload("res://assets/cafe/items_stove_plant.png")
var order_title: Label
var order_detail: Label
var serve_button: Button
var modal: Control
var selected := 0
var world: Node3D
var design_positions: Dictionary = {}
var batch_collect_buttons: Array[Button] = []
var display_stock_buttons: Array[Button] = []
var display_hold_active: Dictionary = {}
var display_hold_generation: Dictionary = {}
var display_long_pressed: Dictionary = {}
var object_action_popup: Panel
var object_action_dismiss_layer: Control
var world_container: SubViewportContainer

func style(color: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(24)
	result.set_border_width_all(2)
	result.border_color = Color("e7bdbe")
	return result

func label(text: String, point: Vector2, dimensions: Vector2, font_size: int, parent: Node = self) -> Label:
	var node := Label.new()
	node.text = text
	node.position = point
	node.size = dimensions
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",INK)
	parent.add_child(node)
	return node

func button(text: String, point: Vector2, dimensions: Vector2, action: Callable, parent: Node = self) -> Button:
	var node := Button.new()
	node.text = text
	node.position = point
	node.size = dimensions
	node.add_theme_font_size_override("font_size",27)
	node.add_theme_color_override("font_color",INK)
	node.add_theme_stylebox_override("normal",style(CREAM))
	node.add_theme_stylebox_override("hover",style(Color("f4c6d0")))
	node.add_theme_stylebox_override("pressed",style(PINK))
	node.add_theme_stylebox_override("disabled",style(Color("e4d8d6")))
	node.add_theme_color_override("font_disabled_color",Color("9b838d"))
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func icon(index: int, point: Vector2, dimensions: Vector2, parent: Node) -> TextureRect:
	var texture := AtlasTexture.new()
	texture.atlas = ICON_ATLAS
	var tile := Vector2(ICON_ATLAS.get_width()/5.0,ICON_ATLAS.get_height()/2.0)
	texture.region = Rect2(Vector2(index%5,index/5)*tile,tile)
	texture.filter_clip = true
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = texture
	image.position = point
	image.size = dimensions
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func icon_button(caption: String, index: int, point: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var node := button("",point,dimensions,action)
	node.tooltip_text = caption
	node.name = caption.replace(" ","")+"Button"
	icon(index,Vector2(20,10),Vector2(dimensions.x-40,dimensions.y-65),node)
	var text := label(caption,Vector2(4,dimensions.y-49),Vector2(dimensions.x-8,43),26,node)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_buttons.append(node)
	return node

func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("f8e9e4")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var container := SubViewportContainer.new()
	world_container = container
	container.position = Vector2(0,0)
	container.size = Vector2(1920,1080)
	container.stretch = true
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	container.add_child(viewport)
	world = Node3D.new()
	world.set_script(load("res://scripts/cafe/cafe_scene.gd"))
	viewport.add_child(world)
	world.station_selected.connect(_select_station)
	world.customer_purchased.connect(_on_customer_purchase)
	world.customer_selected.connect(_show_customer_request)
	world.object_actions_requested.connect(_show_object_actions)
	world.object_moved.connect(_on_object_moved)
	# Route scene gestures from the GUI container; its mouse filter consumes
	# them before the world's unhandled-input callback can receive them.
	container.gui_input.connect(func(event: InputEvent) -> void:
		if not is_instance_valid(modal):
			world._unhandled_input(event)
			container.accept_event()
	)
	var header := Panel.new()
	header.name = "CafeHeader"
	header.position = Vector2(20,20)
	header.scale = Vector2(0.7,0.7)
	header.size = Vector2(1020,240)
	header.add_theme_stylebox_override("panel",style(CREAM))
	add_child(header)
	var cafe_name_label := label(str(SaveSystem.get_value("cafe_profile","name","Sugar & Sunshine")),Vector2(208,20),Vector2(780,68),46,header)
	cafe_name_label.name = "CharacterCafeName"
	cafe_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_make_portrait(header)
	xp_label = label("",Vector2(220,112),Vector2(470,40),25,header)
	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(220,162)
	xp_bar.size = Vector2(460,16)
	xp_bar.max_value = 200
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("background",style(Color("ebdcd3")))
	xp_bar.add_theme_stylebox_override("fill",style(Color("82b7a6")))
	header.add_child(xp_bar)
	icon(9,Vector2(727,116),Vector2(65,65),header)
	wallet = label("",Vector2(798,126),Vector2(210,52),32,header)
	icon_button("Quests",8,Vector2(20,210),Vector2(120,120),_quest_journal)
	button("+",Vector2(1800,210),Vector2(96,85),func() -> void: world.set_zoom(world.camera.size-0.8))
	button("−",Vector2(1800,310),Vector2(96,85),func() -> void: world.set_zoom(world.camera.size+0.8))
	button("Home",Vector2(1770,410),Vector2(130,65),world.reset_view)
	_items_button(Vector2(20,935),Vector2(160,125))
	_recipe_button(Vector2(200,935),Vector2(230,125))
	for i in 4:
		icon_button(["Explore maps","Pantry","Collections","Settings"][i],[4,5,6,7][i],Vector2(940+i*235,935),Vector2(220,125),[_maps,_pantry,_collections,_settings][i])
	sale_notice = label("Tap a machine to craft; collect its finished batch for display.",Vector2(780,30),Vector2(1080,42),22)
	button("Special orders",Vector2(1510,95),Vector2(360,80),_special_orders).name = "SpecialOrdersButton"
	button("Upgrades",Vector2(1150,95),Vector2(330,80),_upgrades).name = "UpgradesButton"
	button("Café event",Vector2(790,95),Vector2(330,80),_cafe_event).name = "CafeEventButton"
	button("Decorate",Vector2(20,350),Vector2(170,80),_decorate).name = "DecorateButton"
	button("Friends",Vector2(20,450),Vector2(170,80),_friends).name = "FriendsButton"
	button("Regulars",Vector2(20,550),Vector2(170,80),_regulars).name = "RegularsButton"
	button("Daily Café",Vector2(20,650),Vector2(170,80),_daily_cafe).name = "DailyCafeButton"
	button("Weekly",Vector2(20,750),Vector2(170,80),_weekly_cafe).name = "WeeklyCafeButton"
	for child: Node in get_children():
		if child is Control and child != backdrop: design_positions[child] = child.position
	resized.connect(_center_layout)
	_center_layout()
	GameDatabase.record_changed.connect(func(_table: String,_id: String) -> void: _refresh_wallet())
	_refresh_wallet()
	for i in CafeProgress.RECIPES.size():
		var collect := button("",Vector2.ZERO,Vector2(150,150),_collect_batch.bind(i))
		collect.name = "CollectBatchButton%d" % i
		collect.tooltip_text = "Collect %s for display" % CafeProgress.RECIPES[i].name
		collect.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		collect.add_theme_stylebox_override("hover",style(Color(1,0.94,0.68,0.25)))
		batch_collect_buttons.append(collect)
		var display_button := button("",Vector2.ZERO,Vector2(130,120),_display_case_deferred.bind(i))
		display_button.name = "DisplayStockButton%d" % i
		display_button.tooltip_text = "Manage %s display" % CafeProgress.RECIPES[i].name
		display_button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		display_button.add_theme_stylebox_override("hover",style(Color(1,0.94,0.68,0.25)))
		display_button.gui_input.connect(_display_hold_input.bind(i))
		display_stock_buttons.append(display_button)
	if "--capture-cafe" in OS.get_cmdline_user_args():
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://../tmp/cafe_hub.png")
		get_tree().quit()

func _make_portrait(header: Control) -> void:
	var container := SubViewportContainer.new()
	container.position = Vector2(15,15)
	container.size = Vector2(175,205)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(350,410)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	portrait = world.actors[0].node.duplicate()
	portrait.name = "PlayerPortrait"
	viewport.add_child(portrait)
	portrait.position = Vector3.ZERO
	portrait.rotation = Vector3.ZERO
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.23
	camera.position = Vector3(0,1.19,4)
	viewport.add_child(camera)
	camera.look_at(Vector3(0,1.19,0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25,-30,0)
	light.light_energy = 0.65
	viewport.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = CREAM
	environment.environment.ambient_light_energy = 0.25
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.tonemap_exposure = 0.94
	viewport.add_child(environment)

func _process(delta: float) -> void:
	for i in display_stock_buttons.size():
		var display_button := display_stock_buttons[i]
		display_button.visible = i < 5 and world.display_products[i].get_parent().visible and CafeProgress.recipes_for_machine(i).any(func(recipe_index: int) -> bool: return CafeProgress.product_stock(recipe_index)>0) and not is_instance_valid(modal)
		display_button.position = world.camera.unproject_position(world.display_products[i].get_parent().global_position + Vector3(0,1.18,0)) - display_button.size*0.5
	for i in batch_collect_buttons.size():
		var collect := batch_collect_buttons[i]
		collect.visible = CafeProgress.batch_ready(i) and not is_instance_valid(modal)
		collect.position = world.camera.unproject_position(world.batch_icons[i].global_position) - collect.size * 0.5
	if not is_instance_valid(portrait): return
	portrait_time += delta
	var head: Node3D = portrait.get_node("Head")
	# Portrait pose and closed smile are fixed; only eyelids animate.
	head.rotation = Vector3.ZERO
	var blink := 0.08 if fmod(portrait_time,4.2) < 0.14 else 1.0
	for side in ["Left","Right"]: head.get_node("Eye"+side).scale.y = blink
	if sale_time>0:
		sale_time -= delta
		if sale_time<=0: sale_notice.text = "Customers buy your stocked treats. Bake more in Quests."

func _on_customer_purchase(receipt: Dictionary) -> void:
	sale_notice.text = "%s sold   +%d" % [receipt.name,receipt.coins]
	sale_time = 4.0
	_refresh_stock_labels()

func _show_customer_request(customer: Dictionary) -> void:
	var details: Dictionary = world.customer_request_details(customer)
	var column := _open_modal("%s's order" % str(details.name))
	if int(details.recipe_index) >= 0:
		item_row(int(details.recipe_index),"I'd love a %s, please!" % str(details.item),column,120,30)
	else:
		_row("I'd like %s." % str(details.item),column,30)
	if bool(customer.get("regular_request",{}).get("fulfilled",false)):
		_row("Thank you! This was exactly what I wanted.",column,27)
	elif bool(details.waiting):
		_row("I'm waiting by the display. If my favorite is unavailable, I may choose another treat.",column,27)
	else:
		_row("I'm heading to the display now.",column,27)

func _on_object_moved(entry: Dictionary) -> void:
	sale_notice.text = "%s moved!" % str(entry.name)
	sale_time = 4.0

func _show_object_actions(entry: Dictionary) -> void:
	_close_object_actions()
	object_action_dismiss_layer = Control.new()
	object_action_dismiss_layer.name = "ObjectActionDismissLayer"
	object_action_dismiss_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	object_action_dismiss_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	object_action_dismiss_layer.gui_input.connect(_dismiss_object_actions_input)
	add_child(object_action_dismiss_layer)
	object_action_popup = Panel.new()
	object_action_popup.name = "ObjectActionPalette"
	object_action_popup.size = Vector2(510,104)
	var screen: Vector2 = world.camera.unproject_position(entry.node.global_position+Vector3(0,2.2,0))
	object_action_popup.position = Vector2(clampf(screen.x-255,10,1400),clampf(screen.y-122,105,820))
	object_action_popup.add_theme_stylebox_override("panel",style(Color("fff3e6")))
	add_child(object_action_popup)
	var move := button("↕↔  Move",Vector2(12,12),Vector2(158,80),func() -> void: pass,object_action_popup)
	move.name = "MoveObjectButton"
	move.gui_input.connect(_move_action_input.bind(entry,move))
	var rotate := button("↻  Rotate",Vector2(176,12),Vector2(158,80),func() -> void:
		world.rotate_object(entry),object_action_popup)
	rotate.name = "RotateObjectButton"
	var store := button("Store",Vector2(340,12),Vector2(158,80),func() -> void:
		world.store_object(entry)
		_close_object_actions()
		sale_notice.text = "%s moved to Storage." % str(entry.name)
		sale_time = 4.0,object_action_popup)
	store.name = "StoreObjectButton"

func _close_object_actions() -> void:
	if is_instance_valid(object_action_popup): object_action_popup.queue_free()
	if is_instance_valid(object_action_dismiss_layer): object_action_dismiss_layer.queue_free()
	object_action_popup = null
	object_action_dismiss_layer = null

func _dismiss_object_actions_input(event: InputEvent) -> void:
	var pressed_outside: bool = event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed
	pressed_outside = pressed_outside or (event is InputEventScreenTouch and event.pressed)
	if not pressed_outside: return
	world.hold_target = {}
	world.hold_triggered = false
	_close_object_actions()

func _control_point_in_world_view(source: Control, local_point: Vector2) -> Vector2:
	var canvas_point := source.get_global_transform_with_canvas()*local_point
	return world_container.get_global_transform_with_canvas().affine_inverse()*canvas_point

func _move_action_input(event: InputEvent, entry: Dictionary, source: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			world.begin_object_placement(entry,_control_point_in_world_view(source,event.position))
		else:
			world.finish_object_placement()
			_close_object_actions()
	elif event is InputEventScreenTouch:
		if event.pressed:
			world.begin_object_placement(entry,_control_point_in_world_view(source,event.position))
		else:
			world.finish_object_placement()
			_close_object_actions()
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		world.preview_object_at_screen(_control_point_in_world_view(source,event.position))

func _refresh_stock_labels() -> void:
	for index in stock_labels:
		if is_instance_valid(stock_labels[index]):
			var recipe: Dictionary = CafeProgress.RECIPES[index]
			stock_labels[index].text = "%d ready to sell  ·  %d coins each" % [CafeProgress.product_stock(index),CafeProgress.sale_price(index)]

func stock_image(index: int, point: Vector2, dimensions: Vector2, parent: Node) -> TextureRect:
	var texture := AtlasTexture.new()
	texture.atlas = STOCK_ATLAS
	var tile := Vector2(STOCK_ATLAS.get_width()/6.0,STOCK_ATLAS.get_height()/4.0)
	texture.region = Rect2(Vector2(index%6,index/6)*tile,tile)
	texture.filter_clip = true
	var image := TextureRect.new()
	image.name = "ItemImage%d" % index
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = texture
	image.position = point
	image.size = dimensions
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func item_row(index: int, text: String, column: VBoxContainer, height := 85.0, font_size := 26) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(860,height)
	column.add_child(row)
	stock_image(index,Vector2(0,4),Vector2(height-8,height-8),row)
	label(text,Vector2(height+12,8),Vector2(845-height,height-8),font_size,row)
	return row

func _refresh_wallet() -> void:
	if not is_instance_valid(wallet): return
	var stats := GameDatabase.get_player_stats()
	wallet.text = str(int(stats.get("coins",0)))
	var xp := int(stats.get("xp",0))
	xp_label.text = "Level %d    ·    %d / 200 XP" % [1+xp/200,xp%200]
	xp_bar.value = xp%200

func _select_station(index: int) -> void:
	selected = index
	for recipe_index in CafeProgress.recipes_for_machine(index):
		if CafeProgress.batch_ready(recipe_index):
			CafeProgress.collect_batch(recipe_index)
			return
	_quests(index, true)

func _collect_batch(index: int) -> void:
	if CafeProgress.collect_batch(index):
		sale_notice.text = "%s placed on display!" % CafeProgress.RECIPES[index].name
		sale_time = 4.0
		world._process(0)

func _quests(filter_index := -1, at_machine := false) -> void:
	preload("res://scripts/cafe/recipe_book.gd").show(self,maxi(filter_index,0),at_machine)

func _recipe_button(point: Vector2, dimensions: Vector2) -> void:
	var node:=button("",point,dimensions,_quests)
	node.name="RecipesButton"; node.tooltip_text="Recipes"
	icon_buttons.append(node)
	var pot_frame:=Control.new(); pot_frame.position=Vector2(45,1); pot_frame.size=Vector2(140,82); pot_frame.clip_contents=true; pot_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE; node.add_child(pot_frame)
	var pot:=TextureRect.new(); pot.name="RecipePotIcon"; pot.texture=RECIPE_POT_ICON; pot.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; pot.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pot.mouse_filter=Control.MOUSE_FILTER_IGNORE; pot_frame.add_child(pot); pot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var caption:=label("Recipes",Vector2(4,dimensions.y-49),Vector2(dimensions.x-8,43),26,node); caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; caption.mouse_filter=Control.MOUSE_FILTER_IGNORE

func _items_button(point: Vector2, dimensions: Vector2) -> void:
	var node := button("",point,dimensions,_items)
	node.name = "ItemsButton"
	node.tooltip_text = "Items"
	icon_buttons.append(node)
	var frame := Control.new()
	frame.position = Vector2(22,0)
	frame.size = Vector2(116,83)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(frame)
	var artwork := TextureRect.new()
	artwork.name = "ItemsStovePlantIcon"
	artwork.texture = ITEMS_ICON
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(artwork)
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var caption := label("Items",Vector2(4,dimensions.y-49),Vector2(dimensions.x-8,43),25,node)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _serve_recipe(index: int, filter_index: int) -> void:
	if CafeProgress.start_craft(index): _quests(filter_index, true)

func _recipe_station_capacity(recipe_index: int) -> int:
	return world.crafting_station_count(CafeProgress.machine_for_recipe(recipe_index))

func _recipe_craft_limit(recipe_index: int) -> int:
	return CafeProgress.max_craft_batches(recipe_index,_recipe_station_capacity(recipe_index))

func _show_recipe_craft_picker(recipe_index: int, category: int) -> void:
	var existing := get_node_or_null("RecipeCraftPickerShade")
	if is_instance_valid(existing): existing.queue_free()
	var total := _recipe_station_capacity(recipe_index)
	var ingredient_limit := CafeProgress.ingredient_batch_limit(recipe_index)
	var active := CafeProgress.active_machine_job_count(CafeProgress.machine_for_recipe(recipe_index))
	var free := maxi(0,total-active)
	var maximum := mini(free,ingredient_limit)
	if maximum<=0: return
	var state := {"count":1}
	var shade:=ColorRect.new(); shade.name="RecipeCraftPickerShade"; shade.color=Color(0.13,0.10,0.22,0.58); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var panel:=Panel.new(); panel.name="RecipeCraftPicker"; panel.position=Vector2((size.x-650)*0.5,(size.y-470)*0.5); panel.size=Vector2(650,470); panel.add_theme_stylebox_override("panel",style(Color("fff0cf"))); shade.add_child(panel)
	var recipe: Dictionary=CafeProgress.RECIPES[recipe_index]
	var title:=label("Craft %s" % recipe.name,Vector2(35,28),Vector2(580,55),30,panel); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var detail:=label("Choose how many matching stations should start this recipe.",Vector2(42,88),Vector2(566,45),20,panel); detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var count_label:=label("",Vector2(205,151),Vector2(240,70),38,panel); count_label.name="CraftStationCount"; count_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; count_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var minus:=button("−",Vector2(75,151),Vector2(115,70),func() -> void: pass,panel); minus.name="CraftMinus"
	var plus:=button("+",Vector2(460,151),Vector2(115,70),func() -> void: pass,panel); plus.name="CraftPlus"
	var limits:=label("",Vector2(50,237),Vector2(550,75),19,panel); limits.name="CraftLimits"; limits.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; limits.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var update:=func() -> void:
		state.count=clampi(int(state.count),1,maximum)
		count_label.text="%d / %d" % [state.count,total]
		limits.text="%d station%s available  •  ingredients allow %d batch%s\n%d batch%s will make %d items" % [free,"s" if free!=1 else "",ingredient_limit,"es" if ingredient_limit!=1 else "",state.count,"es" if int(state.count)!=1 else "",int(state.count)*int(recipe.batch)]
		minus.disabled=int(state.count)<=1
		plus.disabled=int(state.count)>=maximum
	minus.pressed.connect(func() -> void: state.count=int(state.count)-1; update.call())
	plus.pressed.connect(func() -> void: state.count=int(state.count)+1; update.call())
	button("Cancel",Vector2(55,352),Vector2(245,72),shade.queue_free,panel)
	var craft:=button("Craft",Vector2(350,352),Vector2(245,72),_craft_recipe_from_book.bind(recipe_index,category,state,shade),panel); craft.name="ConfirmRecipeCraft"
	update.call()

func _craft_recipe_from_book(recipe_index: int, category: int, state: Dictionary, popup: Control) -> void:
	var started:=CafeProgress.start_craft_batches(recipe_index,int(state.get("count",1)),_recipe_station_capacity(recipe_index))
	if started<=0: return
	if is_instance_valid(popup): popup.queue_free()
	sale_notice.text="Started %d batch%s of %s." % [started,"es" if started!=1 else "",CafeProgress.RECIPES[recipe_index].name]
	sale_time=4.0
	_quests(category,false)

func _serve() -> void:
	_serve_recipe(selected,selected)

func _items(tab := "storage") -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal = ColorRect.new()
	modal.color = Color(0.2,0.09,0.15,0.65)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var panel := Panel.new()
	panel.position = Vector2((size.x-1240)*0.5,90)
	panel.size = Vector2(1240,900)
	panel.add_theme_stylebox_override("panel",style(Color("fff0cf")))
	modal.add_child(panel)
	label("Items",Vector2(245,28),Vector2(760,62),42,panel)
	button("×",Vector2(1125,20),Vector2(85,75),func() -> void: modal.queue_free(),panel)
	var storage_tab := button("Storage",Vector2(18,224),Vector2(205,82),func() -> void: _items("storage"),panel)
	storage_tab.name = "StorageTab"
	var shop_tab := button("Shop",Vector2(18,130),Vector2(205,82),func() -> void: _items("shop"),panel)
	shop_tab.name = "ShopTab"
	(storage_tab if tab=="storage" else shop_tab).add_theme_stylebox_override("normal",style(Color("f4c6d0")))
	var heading := "Stored café items" if tab=="storage" else "Café item shop"
	label(heading,Vector2(245,96),Vector2(900,52),30,panel)
	var scroll := ScrollContainer.new()
	scroll.name = "ItemsHorizontalScroll"
	scroll.position = Vector2(242,155)
	scroll.size = Vector2(950,700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var row := HBoxContainer.new()
	row.name = "ItemCards"
	row.add_theme_constant_override("separation",20)
	scroll.add_child(row)
	var entries: Array = world.stored_items() if tab=="storage" else world.shop_templates()
	if entries.is_empty():
		var empty := label("Your storage is empty. Long-press café furniture and choose Store to keep it here.",Vector2.ZERO,Vector2(850,120),27,row)
		empty.custom_minimum_size = Vector2(850,120)
	for entry: Dictionary in entries:
		_item_card(entry,tab,row)

func _item_card(entry: Dictionary, tab: String, row: HBoxContainer) -> void:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(300,640)
	card.add_theme_stylebox_override("panel",style(CREAM))
	row.add_child(card)
	_item_preview(entry,Vector2(20,18),Vector2(260,255),card)
	var title_label := label(str(entry.name),Vector2(18,285),Vector2(264,70),29,card)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var description := label(_wrap_item_description(str(entry.description)),Vector2(26,356),Vector2(248,122),20,card)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_OFF
	var price_text := "%d coin value" % int(entry.value) if tab=="storage" else "%d coins" % int(entry.value)
	var value_label := label(price_text,Vector2(18,482),Vector2(264,45),25,card)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var action_text := "Place" if tab=="storage" else "Buy"
	var action := button(action_text,Vector2(25,545),Vector2(250,72),_place_stored_item.bind(entry) if tab=="storage" else _buy_shop_item.bind(entry),card)
	action.name = "%sItemButton" % action_text
	if tab=="shop": action.disabled = int(GameDatabase.get_player_stats().coins)<int(entry.value)

func _wrap_item_description(text: String, line_length := 24) -> String:
	var lines: Array[String] = []
	var current := ""
	for word in text.split(" ",false):
		var candidate := word if current.is_empty() else current+" "+word
		if candidate.length()>line_length and not current.is_empty():
			lines.append(current)
			current = word
		else:
			current = candidate
	if not current.is_empty(): lines.append(current)
	return "\n".join(lines)

func _item_preview(entry: Dictionary, point: Vector2, dimensions: Vector2, parent: Control) -> void:
	var frame := SubViewportContainer.new()
	frame.position = point
	frame.size = dimensions
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(520,510)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(viewport)
	var copy: Node3D = entry.node.duplicate()
	copy.visible = true
	if copy.has_node("MovePickArea"):
		var pick := copy.get_node("MovePickArea")
		copy.remove_child(pick)
		pick.queue_free()
	var bounds: AABB = world._movable_visual_bounds(entry.node)
	copy.position = -bounds.get_center()
	copy.rotation = Vector3(0,-0.45,0)
	viewport.add_child(copy)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(1.8,maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))*1.45)
	camera.position = Vector3(3,2.7,4)
	viewport.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-35,0)
	light.light_energy = 1.0
	viewport.add_child(light)
	var ambient := WorldEnvironment.new()
	ambient.environment = Environment.new()
	ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambient.environment.ambient_light_color = CREAM
	ambient.environment.ambient_light_energy = 0.5
	viewport.add_child(ambient)

func _place_stored_item(entry: Dictionary) -> void:
	world.restore_object(entry)
	modal.queue_free()
	sale_notice.text = "%s placed. Long-press it to move or rotate." % str(entry.name)
	sale_time = 5.0

func _buy_shop_item(entry: Dictionary) -> void:
	var purchased: Dictionary = world.purchase_item(entry)
	if purchased.is_empty(): return
	_refresh_wallet()
	_items("storage")

func _open_modal(title_text: String) -> VBoxContainer:
	if is_instance_valid(modal): modal.queue_free()
	modal = ColorRect.new()
	modal.color = Color(0.2,0.09,0.15,0.65)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var panel := Panel.new()
	panel.position = Vector2((size.x-1100)*0.5,100)
	panel.size = Vector2(1100,880)
	var tint := Color("fff3e6")
	if title_text.contains("Pantry"): tint = Color("e0f3e4")
	elif title_text.contains("collection"): tint = Color("e9e1f8")
	elif title_text.contains("adventure"): tint = Color("dff0fb")
	elif title_text.contains("comfortable"): tint = Color("f0ece8")
	elif title_text.contains("Recipes"): tint = Color("fff0cf")
	panel.add_theme_stylebox_override("panel",style(tint))
	modal.add_child(panel)
	label(title_text,Vector2(35,26),Vector2(760,70),42,panel)
	button("×",Vector2(985,20),Vector2(85,75),func() -> void: modal.queue_free(),panel)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30,125)
	scroll.size = Vector2(1040,710)
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",22)
	scroll.add_child(column)
	return column

func _row(text: String, column: VBoxContainer, font_size := 29) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(860,62)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",INK)
	column.add_child(node)
	return node

func _maps() -> void:
	var column := _open_modal("Choose your next adventure")
	for i in 3:
		var data: Dictionary = CafeProgress.REGIONS[i]
		var thumbnail := TextureRect.new()
		thumbnail.name = "MapThumbnail%d" % i
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.texture = load(MAP_ART[i])
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumbnail.custom_minimum_size = Vector2(860,240)
		column.add_child(thumbnail)
		_row(data.name,column,38)
		_row(data.subtitle,column,25)
		var ingredients := Control.new()
		ingredients.custom_minimum_size = Vector2(860,190)
		column.add_child(ingredients)
		for j in 6:
			var id: String = CafeProgress.POOLS[i][j]
			var point := Vector2((j%3)*285,(j/3)*92)
			stock_image(CafeProgress.INGREDIENTS.keys().find(id),point,Vector2(68,68),ingredients)
			label(CafeProgress.INGREDIENTS[id],point+Vector2(76,5),Vector2(204,78),22,ingredients)
		var launch := button("Explore "+str(data.name),Vector2.ZERO,Vector2(850,92),CafeProgress.open_region.bind(i),column)
		launch.custom_minimum_size = Vector2(850,92)

func _pantry() -> void:
	var column := _open_modal("Pantry & ready-to-sell treats")
	stock_labels.clear()
	_row("Saved treats",column,33)
	_row("Sell places saved treats on display for customers. Stored treats stay safe for later.",column,25)
	for i in CafeProgress.RECIPES.size():
		var recipe: Dictionary = CafeProgress.RECIPES[i]
		item_row(int(recipe.icon),recipe.name,column,95,29)
		_row("%d stored  ·  %d on display  ·  %d coins each" % [CafeProgress.stored_stock(i),CafeProgress.product_stock(i),CafeProgress.sale_price(i)],column,25)
		var sell := button("Sell · put on display",Vector2.ZERO,Vector2(850,75),_sell_stored.bind(i),column)
		sell.name = "SellStored%d" % i
		sell.custom_minimum_size = Vector2(850,75)
		sell.disabled = CafeProgress.stored_stock(i)<=0
	_row("Ingredients",column,33)
	var stock := CafeProgress.pantry()
	for id: String in CafeProgress.INGREDIENTS:
		item_row(CafeProgress.INGREDIENTS.keys().find(id),"%s   ×%d" % [CafeProgress.INGREDIENTS[id],stock[id]],column)

func _sell_stored(index: int) -> void:
	if CafeProgress.move_product_stock(index,true):
		world._process(0)
		_pantry()

func _display_case(machine: int) -> void:
	var stocked := CafeProgress.recipes_for_machine(machine).filter(func(index: int) -> bool: return CafeProgress.product_stock(index)>0)
	if stocked.size()==1:
		_display_stock(stocked[0])
		return
	var column := _open_modal("Display treats")
	for index: int in stocked:
		item_row(int(CafeProgress.RECIPES[index].icon),"%s · %d left" % [CafeProgress.RECIPES[index].name,CafeProgress.product_stock(index)],column,115,30)
		var store_button := button("Store",Vector2.ZERO,Vector2(850,85),_store_display.bind(index),column)
		store_button.name = "StoreDisplay%d" % index
		store_button.custom_minimum_size = Vector2(850,85)

func _display_case_deferred(machine: int) -> void:
	await get_tree().process_frame
	if bool(display_long_pressed.get(machine,false)):
		display_long_pressed.erase(machine)
		return
	_display_case(machine)

func _display_hold_input(event: InputEvent, machine: int) -> void:
	var pressed := false
	var released := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if not world.placement_target.is_empty(): world.preview_object_at_screen(event.position)
		return
	if pressed:
		display_hold_active[machine] = true
		var generation := int(display_hold_generation.get(machine,0))+1
		display_hold_generation[machine] = generation
		_wait_for_display_hold(machine,generation)
	elif released:
		display_hold_active[machine] = false
		if not world.placement_target.is_empty(): world.finish_object_placement()

func _wait_for_display_hold(machine: int, generation: int) -> void:
	await get_tree().create_timer(0.65).timeout
	if not bool(display_hold_active.get(machine,false)) or int(display_hold_generation.get(machine,0)) != generation: return
	var matches: Array = world.movable_objects.filter(func(entry: Dictionary) -> bool: return str(entry.id)=="display_%d" % machine)
	if matches.is_empty(): return
	display_long_pressed[machine] = true
	_show_object_actions(matches[0])

func _display_stock(index: int) -> void:
	var column := _open_modal("Display · " + str(CafeProgress.RECIPES[index].name))
	item_row(int(CafeProgress.RECIPES[index].icon),CafeProgress.RECIPES[index].name,column,160,34)
	_row("Store the remaining displayed items in your pantry for later. Customers cannot buy stored treats.",column,28)
	var store_button := button("Store",Vector2.ZERO,Vector2(850,85),_store_display.bind(index),column)
	store_button.name = "StoreDisplay"
	store_button.custom_minimum_size = Vector2(850,85)
	store_button.disabled = CafeProgress.product_stock(index)<=0

func _store_display(index: int) -> void:
	if CafeProgress.move_product_stock(index,false):
		world._process(0)
		modal.queue_free()
		sale_notice.text = "%s stored in the pantry." % CafeProgress.RECIPES[index].name
		sale_time = 4.0

func _collections() -> void:
	var column := _open_modal("Your sweet collection")
	var collection := CollectibleRewards.get_collection()
	_row("Duplicates become sprinkles. Trade 50 sprinkles for a collectible you are missing.",column,24)
	var exchange := button("Sprinkles: %d · Find a missing collectible" % CollectibleRewards.sprinkles(),Vector2.ZERO,Vector2(850,75),_exchange_sprinkles,column)
	exchange.custom_minimum_size=Vector2(850,75); exchange.disabled=CollectibleRewards.sprinkles()<50
	for set_id: String in CollectibleRewards.ALBUM_SETS:
		var set_data: Dictionary = CollectibleRewards.ALBUM_SETS[set_id]
		_row(set_data.name,column,36)
		for id: String in set_data.items:
			var data: Dictionary = CollectibleRewards.CATALOG[id]
			_row("%s   %s" % [data.name,("Collected ×%d" % int(collection.get(id,0))) if int(collection.get(id,0))>0 else "Silhouette"],column,26)
		var claimed := bool(SaveSystem.get_value("collections","set_"+set_id,false))
		var claim := button("Collected" if claimed else "Complete set · claim %d coins" % int(set_data.reward),Vector2.ZERO,Vector2(850,68),_claim_album_set.bind(set_id),column)
		claim.custom_minimum_size=Vector2(850,68); claim.disabled=claimed or not CollectibleRewards.set_complete(set_id)

func _exchange_sprinkles() -> void:
	var awarded := CollectibleRewards.exchange_sprinkles()
	if not awarded.is_empty(): sale_notice.text="Sprinkles revealed %s!" % CollectibleRewards.CATALOG[awarded].name
	_collections()

func _claim_album_set(set_id: String) -> void:
	var reward := CollectibleRewards.claim_set_reward(set_id)
	if reward > 0: sale_notice.text="Album set complete! +%d coins" % reward
	_collections()

func _settings() -> void:
	var column := _open_modal("Make yourself comfortable")
	for kind in ["Music","Sound effects"]:
		_row(kind,column,32)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.01
		slider.custom_minimum_size = Vector2(850,75)
		slider.value = GameSettings.music_volume if kind=="Music" else GameSettings.sfx_volume
		slider.value_changed.connect(GameSettings.set_music_volume if kind=="Music" else GameSettings.set_sfx_volume)
		column.add_child(slider)
	var notifications := CheckButton.new()
	notifications.text = "Notifications preference"
	notifications.button_pressed = GameSettings.notifications_enabled
	notifications.add_theme_font_size_override("font_size",28)
	notifications.add_theme_color_override("font_color",INK)
	notifications.custom_minimum_size = Vector2(850,80)
	notifications.toggled.connect(GameSettings.set_notifications_enabled)
	column.add_child(notifications)
	_row("Notification preference is saved; device reminders are not enabled yet.",column,23)
	_row("Changes are saved automatically.",column,25)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(modal):
		modal.queue_free()
		get_viewport().set_input_as_handled()


func _center_layout() -> void:
	var offset := Vector2(maxf(0,(size.x-1920)*0.5),maxf(0,(size.y-1080)*0.5))
	for child: Control in design_positions:
		if is_instance_valid(child): child.position = design_positions[child]+offset

func _quest_journal() -> void:
	preload("res://scripts/cafe/quest_journal.gd").show(self)

func _daily_cafe() -> void:
	var state := CafeRetention.daily_state()
	var column := _open_modal("Mallow's Daily Café")
	_row("Complete three gentle goals whenever you play. Missing a day never resets your stamp card.",column,26)
	for goal: Dictionary in state.goals:
		var progress := mini(int(goal.get("progress",0)),int(goal.target))
		_row(("✓ " if progress >= int(goal.target) else "○ ") + (str(goal.label) % int(goal.target)),column,31)
		var bar := ProgressBar.new(); bar.max_value=int(goal.target); bar.value=progress; bar.show_percentage=false; bar.custom_minimum_size=Vector2(850,22); column.add_child(bar)
		_row("%d / %d" % [progress,goal.target],column,23)
	var stamps := CafeRetention.stamp_count()
	_row("Stamp card  " + "● ".repeat(stamps) + "○ ".repeat(7-stamps),column,30)
	var claim := button("Claim Perfect Café Day",Vector2.ZERO,Vector2(850,80),_claim_daily,column)
	claim.custom_minimum_size=Vector2(850,80); claim.disabled=bool(state.claimed) or not CafeRetention.daily_complete()
	if bool(state.claimed): claim.text="Today's reward collected"

func _claim_daily() -> void:
	var reward := CafeRetention.claim_perfect_day()
	if not reward.is_empty(): sale_notice.text="Perfect Café Day! +%d coins%s" % [reward.coins,reward.bonus]
	_daily_cafe()

func _weekly_cafe() -> void:
	var state := CafeRetention.weekly_state()
	var column := _open_modal("Mallow's Weekly Menu")
	_row("Featured menu: %s treats" % str(state.category).capitalize(),column,32)
	_row("Boards, batches, sales and regular requests fill this week's reward path.",column,25)
	_row("Weekly points: %d    Puzzle streak: %d" % [state.score,state.streak],column,29)
	for index in CafeRetention.WEEKLY_MILESTONES.size():
		var target: int = CafeRetention.WEEKLY_MILESTONES[index]
		var claimed: bool = index in state.claimed
		var action := button("Collected" if claimed else ("Claim %d coins" % (100*(index+1))),Vector2.ZERO,Vector2(850,72),_claim_weekly.bind(index),column)
		action.custom_minimum_size=Vector2(850,72); action.disabled=claimed or int(state.score)<target
		_row("Milestone %d / %d" % [mini(int(state.score),target),target],column,23)

func _claim_weekly(index: int) -> void:
	var reward := CafeRetention.claim_weekly_milestone(index)
	if reward > 0: sale_notice.text="Weekly reward collected: +%d coins" % reward
	_weekly_cafe()

func _special_orders() -> void:
	var column := _open_modal("Special orders")
	_row("Store treats in the pantry to reserve them for these neighborhood requests.",column,26)
	for i in CafeLife.SPECIAL_ORDERS.size():
		var order: Dictionary = CafeLife.SPECIAL_ORDERS[i]
		_row(order.name,column,36)
		_row(order.description,column,26)
		for id in order.needs:
			var recipe := CafeLife.recipe_index(id)
			item_row(int(CafeProgress.RECIPES[recipe].icon),"%s · %d / %d stored" % [CafeProgress.RECIPES[recipe].name,CafeProgress.stored_stock(recipe),order.needs[id]],column,90,26)
		_row("Reward: %d coins · %d XP" % [order.coins,order.xp],column,26)
		var caption := "Completed" if CafeLife.order_complete(i) else ("Complete the previous order first" if i>0 and not CafeLife.order_complete(i-1) else "Deliver order")
		var deliver := button(caption,Vector2.ZERO,Vector2(850,80),_deliver_special_order.bind(i),column)
		deliver.name = "DeliverSpecialOrder%d" % i
		deliver.custom_minimum_size = Vector2(850,80)
		deliver.disabled = not CafeLife.can_deliver_order(i)

func _deliver_special_order(index: int) -> void:
	if CafeLife.deliver_order(index): _special_orders()

func _upgrades() -> void:
	var column := _open_modal("Grow your café")
	for id in CafeLife.UPGRADES:
		var upgrade: Dictionary = CafeLife.UPGRADES[id]
		_row(upgrade.name,column,36)
		_row(upgrade.description,column,27)
		var buy := button("Owned" if CafeLife.has_upgrade(id) else "Buy · %d coins" % upgrade.cost,Vector2.ZERO,Vector2(850,80),_buy_upgrade.bind(id),column)
		buy.custom_minimum_size = Vector2(850,80)
		buy.disabled = CafeLife.has_upgrade(id) or int(GameDatabase.get_player_stats().coins)<int(upgrade.cost)

func _buy_upgrade(id: String) -> void:
	if CafeLife.buy_upgrade(id): _upgrades()

func _cafe_event() -> void:
	var event := CafeLife.current_event()
	var column := _open_modal(event.name)
	_row(event.description,column,32)
	_row("+%d bonus coins for each %s purchase" % [event.bonus,event.category],column,30)
	for index in CafeLife.recipes_in_category(event.category):
		item_row(int(CafeProgress.RECIPES[index].icon),CafeProgress.RECIPES[index].name,column,150,32)
	_row("Next event after %d board wins. Play whenever you like—events do not expire while you are away." % event.boards_remaining,column,27)

func _decorate() -> void:
	var column := _open_modal("Decorate your café")
	_row("Table & chairs",column,36)
	_row("Move the seating group within the open seating area. The entrance and serving aisle stay clear.",column,25)
	var movement := HBoxContainer.new()
	column.add_child(movement)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var names := {Vector2.LEFT:"←",Vector2.RIGHT:"→",Vector2.UP:"↑",Vector2.DOWN:"↓"}
		var move := button(names[direction],Vector2.ZERO,Vector2(180,80),_move_table.bind(direction),movement)
		move.custom_minimum_size = Vector2(180,80)
	_row("Floor & wallpaper",column,36)
	for id in CafeLife.DECOR_THEMES:
		var theme: Dictionary = CafeLife.DECOR_THEMES[id]
		var choose := button(theme.name + (" · Selected" if CafeLife.decor_theme()==id else ""),Vector2.ZERO,Vector2(850,110),_choose_decor.bind(id),column)
		choose.custom_minimum_size = Vector2(850,110)
		choose.add_theme_stylebox_override("normal",style(Color(theme.floor_b)))

	_row("Display finishes",column,36)
	for id in CafeLife.DISPLAY_STYLES:
		var finish: Dictionary = CafeLife.DISPLAY_STYLES[id]
		var choose := button(finish.name + (" · Selected" if CafeLife.display_style()==id else ""),Vector2.ZERO,Vector2(850,110),_choose_display.bind(id),column)
		choose.custom_minimum_size = Vector2(850,110)
		choose.add_theme_stylebox_override("normal",style(Color(finish.body)))

func _choose_display(id: String) -> void:
	if CafeLife.set_display_style(id): _decorate()

func _choose_decor(id: String) -> void:
	if CafeLife.set_decor_theme(id): _decorate()

func _move_table(direction: Vector2) -> void:
	CafeLife.move_table(CafeLife.table_position()+direction*0.5)

func _friend_button(text: String, callback: Callable, column: VBoxContainer) -> void:
	var control := button(text,Vector2.ZERO,Vector2(850,80),callback,column)
	control.custom_minimum_size = Vector2(850,80)

func _chef_card(entry: Dictionary, column: VBoxContainer, allow_add := true) -> void:
	var card := HBoxContainer.new()
	card.custom_minimum_size = Vector2(850,150)
	card.add_theme_constant_override("separation",24)
	column.add_child(card)
	var portrait_box := SubViewportContainer.new()
	portrait_box.custom_minimum_size = Vector2(150,150)
	portrait_box.stretch = true
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(portrait_box)
	var view := SubViewport.new()
	view.size = Vector2i(300,300)
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	portrait_box.add_child(view)
	var chef: Node3D = world.actors[0].node.duplicate()
	view.add_child(chef)
	chef.position = Vector3.ZERO
	chef.rotation = Vector3.ZERO
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.3
	camera.position = Vector3(0,1.18,4)
	view.add_child(camera)
	camera.look_at(Vector3(0,1.18,0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25,-30,0)
	light.light_energy = 0.8
	view.add_child(light)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(actions)
	var name_label := Label.new()
	name_label.text = str(entry.get("display_name","A visiting chef"))
	name_label.add_theme_font_size_override("font_size",31)
	actions.add_child(name_label)
	var code := str(entry.get("code",""))
	var visit := Button.new()
	visit.text = "Visit café"
	visit.custom_minimum_size = Vector2(0,52)
	visit.disabled = not bool(entry.get("visits_enabled",true))
	visit.pressed.connect(_friend_action.bind("visit",{"code":code}))
	actions.add_child(visit)
	var status := str(entry.get("status","none"))
	if allow_add and status == "none":
		var add := Button.new()
		add.text = "Add friend"
		add.custom_minimum_size = Vector2(0,52)
		add.pressed.connect(_friend_action.bind("request",{"code":code}))
		actions.add_child(add)
	elif status == "outgoing":
		var sent := Label.new()
		sent.text = "Friend request sent"
		actions.add_child(sent)

func _friends() -> void:
	var column := _open_modal("Friends & café visits")
	if not CafeOnline.configured():
		_row("Online visits are not connected yet. Your café is saved on this device; sharing will become available when the hosted service is connected.",column)
		return
	var loading := _row("Connecting…",column)
	var cafe_name := str(SaveSystem.get_value("cafe_profile","name","My Café")).strip_edges()
	var result: Dictionary = await CafeOnline.call_service("profile")
	if not is_instance_valid(column): return
	if not result.ok and str(result.error)=="Create your cafe profile first":
		result = await CafeOnline.call_service("register",{"display_name":cafe_name})
	elif result.ok and str(result.data.get("display_name","")) != cafe_name:
		result = await CafeOnline.call_service("register",{"display_name":cafe_name})
	if not is_instance_valid(column): return
	loading.queue_free()
	if not result.ok:
		_row(str(result.error),column)
		_friend_button("Try again",_friends,column)
		return
	_row(str(result.data.display_name),column,36)
	_row("Save your latest décor so other chefs can visit while you are away.",column,26)
	_friend_button("Save",func() -> void: _friend_action("publish",{"layout":CafeOnline.public_layout()}),column)
	if bool(result.data.get("visits_enabled",false)):
		_friend_button("Close my café to visits",func() -> void: _friend_action("hide"),column)
	_row("Meet other chefs",column,34)
	var discovery: Dictionary = await CafeOnline.call_service("discover")
	if not is_instance_valid(column): return
	if discovery.ok:
		var meet_count := 0
		for cafe: Dictionary in discovery.data.cafes:
			if str(cafe.get("status","none")) == "friend": continue
			_chef_card(cafe,column,true)
			meet_count += 1
		if meet_count == 0: _row("You have met every chef currently online.",column,26)
	else: _row(str(discovery.error),column)
	_row("Your friends",column,34)
	var list: Dictionary = await CafeOnline.call_service("friends")
	if not is_instance_valid(column): return
	if not list.ok:
		_row(str(list.error),column)
		return
	if list.data.friends.is_empty(): _row("Chefs you add will appear here.",column,26)
	for friend: Dictionary in list.data.friends:
		var friend_code := str(friend.code)
		if friend.status=="incoming":
			_row("%s would like to be friends." % friend.display_name,column,30)
			_friend_button("Accept request",_friend_action.bind("accept",{"code":friend_code}),column)
		elif friend.status=="friend": _chef_card(friend,column,false)
		_friend_button("Remove friend" if friend.status=="friend" else "Decline / cancel request",_friend_action.bind("remove",{"code":friend_code}),column)

func _friend_action(action: String, payload: Dictionary = {}) -> void:
	var column := _open_modal("Friends & café visits")
	_row("Connecting…",column)
	var result: Dictionary = await CafeOnline.call_service(action,payload)
	if not is_instance_valid(column): return
	if not result.ok:
		_row(str(result.error),column)
		_friend_button("Back to friends",_friends,column)
		return
	if action=="visit":
		var visit_script = load("res://scripts/cafe/cafe_visit.gd")
		if not visit_script.valid_snapshot(result.data):
			_row("This café layout needs a newer version of the game.",column)
			return
		_open_visit(result.data)
		return
	_friends()

func _open_visit(snapshot: Dictionary) -> void:
	var visit_script = load("res://scripts/cafe/cafe_visit.gd")
	if not visit_script.valid_snapshot(snapshot): return
	if is_instance_valid(modal): modal.queue_free()
	modal = null
	var visitor = visit_script.new()
	visitor.name = "CafeVisitor"
	visitor.snapshot = snapshot
	world.set_process(false)
	world.set_process_unhandled_input(false)
	set_process(false)
	add_child(visitor)
	CafeRetention.add_progress("visit",1)
	visitor.visit_closed.connect(func() -> void:
		world.set_process(true)
		world.set_process_unhandled_input(true)
		set_process(true))

func _regulars() -> void:
	var column := _open_modal("Your café regulars")
	_row("Each visit brings a request from their favorite category. Serve the requested treat to grow your friendship.",column,26)
	for id in CafeLife.REGULARS:
		var regular: Dictionary = CafeLife.REGULARS[id]
		var visits := int(SaveSystem.get_value("regular_friendship",id,0))
		_row("%s · Loves %s" % [regular.name,regular.category],column,36)
		_row(CafeLife.regular_story(id),column,28)
		_row("%d happy visits" % visits,column,25)
		for index in CafeProgress.RECIPES.size():
			var recipe: Dictionary = CafeProgress.RECIPES[index]
			if recipe.get("friend","") != id: continue
			if CafeProgress.recipe_unlocked(index):
				item_row(int(recipe.icon),"Discovered: "+str(recipe.name),column,105,28)
			else:
				var mystery := item_row(int(recipe.icon),CafeProgress.discovery_hint(index),column,105,26)
				mystery.get_child(0).modulate = Color(0.1,0.1,0.1)
			var meter := ProgressBar.new()
			meter.custom_minimum_size = Vector2(850,32)
			meter.max_value = int(recipe.visits)
			meter.value = mini(visits,int(recipe.visits))
			meter.show_percentage = false
			column.add_child(meter)

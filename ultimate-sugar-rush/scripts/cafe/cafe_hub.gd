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
var order_title: Label
var order_detail: Label
var serve_button: Button
var modal: Control
var selected := 0
var world: Node3D
var design_positions: Dictionary = {}
var batch_collect_buttons: Array[Button] = []
var display_stock_buttons: Array[Button] = []

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
	label("Sugar & Sunshine",Vector2(208,20),Vector2(780,68),46,header)
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
	for i in 4:
		icon_button(["Bakery","Coffee","Candy","Cakes"][i],i,Vector2(200+i*180,935),Vector2(165,125),_quests.bind(i))
	for i in 4:
		icon_button(["Explore maps","Pantry","Collections","Settings"][i],[4,5,6,7][i],Vector2(940+i*235,935),Vector2(220,125),[_maps,_pantry,_collections,_settings][i])
	sale_notice = label("Tap a machine to craft; collect its finished batch for display.",Vector2(780,30),Vector2(1080,42),22)
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
		var display_button := button("",Vector2.ZERO,Vector2(130,120),_display_stock.bind(i))
		display_button.name = "DisplayStockButton%d" % i
		display_button.tooltip_text = "Manage %s display" % CafeProgress.RECIPES[i].name
		display_button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		display_button.add_theme_stylebox_override("hover",style(Color(1,0.94,0.68,0.25)))
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
		display_button.visible = CafeProgress.product_stock(i)>0 and not is_instance_valid(modal)
		display_button.position = world.camera.unproject_position(world.display_products[i].global_position) - display_button.size*0.5
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

func _refresh_stock_labels() -> void:
	for index in stock_labels:
		if is_instance_valid(stock_labels[index]):
			var recipe: Dictionary = CafeProgress.RECIPES[index]
			stock_labels[index].text = "%d ready to sell  ·  %d coins each" % [CafeProgress.product_stock(index),recipe.price]

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
	if CafeProgress.batch_ready(index):
		CafeProgress.collect_batch(index)
		return
	_quests(index, true)

func _collect_batch(index: int) -> void:
	if CafeProgress.collect_batch(index):
		sale_notice.text = "%s placed on display!" % CafeProgress.RECIPES[index].name
		sale_time = 4.0
		world._process(0)

func _quests(filter_index := -1, at_machine := false) -> void:
	var column := _open_modal("Recipes & rewards")
	recipe_buttons.clear()
	_row("Collect finished batches at their machines to stock the displays.",column,25)
	stock_labels.clear()
	for i in CafeProgress.RECIPES.size():
		if filter_index >= 0 and i != filter_index: continue
		var recipe: Dictionary = CafeProgress.RECIPES[i]
		item_row(19 if i == 4 else 18+i,recipe.name,column,115,33)
		stock_labels[i] = _row("%d ready to sell  ·  %d coins each" % [CafeProgress.product_stock(i),recipe.price],column,26)
		var stock := CafeProgress.pantry()
		for id: String in recipe.needs:
			var region_name := ""
			for region in 3:
				if id in CafeProgress.POOLS[region]: region_name = CafeProgress.REGIONS[region].name
			item_row(CafeProgress.INGREDIENTS.keys().find(id),"%s   %d / %d\n%s" % [CafeProgress.INGREDIENTS[id],stock[id],recipe.needs[id],region_name],column,85,25)
		var machine_name: String = ["bread oven", "coffee machine", "candy maker", "cake oven", "tea brewer"][i]
		if not at_machine:
			_row("Tap the %s in the café to craft this recipe." % machine_name,column,26)
		elif not CafeProgress.craft_job(i).is_empty():
			_row("Batch in progress · return to the machine to collect it.",column,26)
		else:
			var serve := button("Make %d   ·   +20 XP on collection" % recipe.batch,Vector2.ZERO,Vector2(850,85),_serve_recipe.bind(i,filter_index),column)
			serve.custom_minimum_size = Vector2(850,85)
			serve.disabled = not CafeProgress.can_serve(i)
			recipe_buttons.append(serve)
	var find := button("Explore ingredient maps",Vector2.ZERO,Vector2(850,85),_maps,column)
	find.custom_minimum_size = Vector2(850,85)
	if filter_index >= 0:
		var all_recipes := button("All recipes",Vector2.ZERO,Vector2(850,85),_quests,column)
		all_recipes.custom_minimum_size = Vector2(850,85)

func _serve_recipe(index: int, filter_index: int) -> void:
	if CafeProgress.start_craft(index): _quests(filter_index, true)

func _serve() -> void:
	_serve_recipe(selected,selected)

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
		item_row(19 if i == 4 else 18+i,recipe.name,column,95,29)
		_row("%d stored  ·  %d on display  ·  %d coins each" % [CafeProgress.stored_stock(i),CafeProgress.product_stock(i),recipe.price],column,25)
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

func _display_stock(index: int) -> void:
	var column := _open_modal("Display · " + str(CafeProgress.RECIPES[index].name))
	item_row(19 if index==4 else 18+index,CafeProgress.RECIPES[index].name,column,160,34)
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
	for id: String in CollectibleRewards.CATALOG:
		var data: Dictionary = CollectibleRewards.CATALOG[id]
		var image := TextureRect.new()
		image.custom_minimum_size = Vector2(860,240)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture = load(data.texture)
		if int(collection.get(id,0)) == 0: image.modulate = Color(0.5,0.5,0.5,0.4)
		column.add_child(image)
		_row("%s   ×%d" % [data.name,int(collection.get(id,0))],column)

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

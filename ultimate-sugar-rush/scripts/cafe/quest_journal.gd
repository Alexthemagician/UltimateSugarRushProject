extends RefCounted

const MALLOW_MASCOT=preload("res://assets/cafe/mallow_bunny.png")

const QUESTS := [
	{"title":"Make 3 butter-cloud buns", "icon":18, "target":3, "key":"butter_cloud_buns", "description":"Give your café its first comforting bakery aroma. Bake a batch and collect it onto the display.", "tip":"Find flour, butter and sugar on Sugar Blossom boards. One oven batch makes 50 buns."},
	{"title":"Collect 100 coins from sales", "icon":9, "target":100, "key":"coins", "description":"Keep your displays stocked and let visiting customers buy your freshly made treats.", "tip":"Coins count when customers purchase an item. Finished batches must be collected first."},
	{"title":"Gain 100 XP", "icon":-1, "target":100, "key":"xp", "description":"Grow as a café keeper by completing boards and collecting finished batches.", "tip":"Each collected batch gives 20 XP. Board victories also award XP."},
	{"title":"Make 20 beverages", "icon":19, "target":20, "key":"drinks", "description":"Brew a comforting round of vanilla lattes or honey mint tea for your visitors.", "tip":"Coffee beans come from Cocoa Moon. Tea leaves and honey come from Honeydew Gardens."},
	{"title":"Make 12 strawberry cakes", "icon":21, "target":12, "key":"strawberry_cake", "description":"Fill a display with celebration cakes. Start the recipe at the cake oven and collect the finished batch.", "tip":"Strawberry frosting comes from Cocoa Moon. Revisit its boards to cycle through the region’s ingredients."},
	{"title":"Make 30 petal bonbons", "icon":20, "target":30, "key":"petal_bonbons", "description":"Turn delicate edible flowers into a colorful candy batch at the candy maker.", "tip":"Collect edible flowers in Honeydew Gardens, and fondant and sugar syrup in Sugar Blossom."}
]

static func amount(index: int) -> int:
	var key: String = QUESTS[index].key
	if key == "drinks": return int(SaveSystem.get_value("quest_progress","vanilla_latte",0)) + int(SaveSystem.get_value("quest_progress","honey_mint_tea",0))
	return int(SaveSystem.get_value("quest_progress",key,0))

static func show(hub: Control, selected := 0) -> void:
	if is_instance_valid(hub.modal): hub.modal.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.13,0.10,0.22,0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub.add_child(shade)
	hub.modal = shade
	var panel := Panel.new()
	panel.position = Vector2((hub.size.x-1400)*0.5,90)
	panel.size = Vector2(1400,900)
	panel.add_theme_stylebox_override("panel",hub.style(Color("ede5fa")))
	shade.add_child(panel)
	hub.label("Mallow’s quest journal",Vector2(35,20),Vector2(1100,70),42,panel)
	var mascot_frame:=Control.new(); mascot_frame.position=Vector2(1135,8); mascot_frame.size=Vector2(145,145); mascot_frame.clip_contents=true; mascot_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.add_child(mascot_frame)
	var mascot:=TextureRect.new(); mascot.name="MallowMascot"; mascot.texture=MALLOW_MASCOT; mascot.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; mascot.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; mascot.mouse_filter=Control.MOUSE_FILTER_IGNORE; mascot_frame.add_child(mascot); mascot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub.button("×",Vector2(1295,20),Vector2(75,70),shade.queue_free,panel)
	for i in QUESTS.size():
		var tab: Button = hub.button("",Vector2(25,115+i*125),Vector2(180,112),show.bind(hub,i),panel)
		tab.name = "QuestTab%d" % i
		tab.tooltip_text = QUESTS[i].title
		tab.add_theme_stylebox_override("normal",hub.style(Color("d2b5ee") if i==selected else Color("faf5ff")))
		art(hub,i,Vector2(48,8),Vector2(84,84),tab)
	var quest: Dictionary = QUESTS[selected]
	hub.label(quest.title,Vector2(255,115),Vector2(1070,100),42,panel).name = "QuestObjective"
	art(hub,selected,Vector2(600,230),Vector2(320,270),panel)
	hub.label(quest.description,Vector2(275,535),Vector2(1030,105),29,panel)
	var value := mini(amount(selected),int(quest.target))
	var progress := ProgressBar.new()
	progress.position = Vector2(280,665)
	progress.size = Vector2(1010,30)
	progress.max_value = quest.target
	progress.value = value
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background",hub.style(Color("d6c9e3")))
	progress.add_theme_stylebox_override("fill",hub.style(Color("83b79e")))
	panel.add_child(progress)
	hub.label("%d / %d%s" % [value,quest.target," · Complete!" if value==quest.target else ""],Vector2(280,705),Vector2(1010,45),28,panel)
	hub.label("Mallow’s tip: " + quest.tip,Vector2(280,770),Vector2(1010,105),25,panel)

static func art(hub: Control, index: int, point: Vector2, dimensions: Vector2, parent: Control) -> void:
	if QUESTS[index].icon == -1:
		var bar := ProgressBar.new()
		bar.position = point + Vector2(0,dimensions.y*0.4)
		bar.size = Vector2(dimensions.x,dimensions.y*0.25)
		bar.value = 60
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background",hub.style(Color("d6c9e3")))
		bar.add_theme_stylebox_override("fill",hub.style(Color("a77acd")))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(bar)
		var caption: Label = hub.label("XP",point,dimensions,28,parent)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif QUESTS[index].key == "coins": hub.icon(9,point,dimensions,parent)
	else: hub.stock_image(QUESTS[index].icon,point,dimensions,parent)

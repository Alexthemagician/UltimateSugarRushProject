extends Control

const OBJECTIVE_LABELS := ["ChocolateObjective","StrawberryObjective","VanillaObjective","BlueberryObjective"]
const LEVEL_NAMES := ["Gathering","Bundling","Market baskets","Preserves","Grand harvest"]

@onready var board: MergeBoard = %MergeBoard
@onready var status_label: Label = %StatusLabel
var objectives := {}
var progress := {}
var finishing := false
var held := false
var hold_time := 0.0
var spawn_count := 0


func _ready() -> void:
	preload("res://scripts/ui/landscape_layout.gd").apply(self)
	_build_objectives()
	%BackButton.pressed.connect(_go_back)
	%AddItemButton.button_down.connect(_start_adding)
	%AddItemButton.button_up.connect(func() -> void: held=false)
	%ResetButton.pressed.connect(_reset)
	board.board_changed.connect(_update_status)
	board.item_merged.connect(_on_item_merged)
	board.item_discarded.connect(func(item_id: String) -> void: status_label.text="%s discarded." % item_id.replace("_"," ").capitalize())
	board.set_discard_target(%TrashDrop)
	_load_progress()
	_update_objectives()
	_update_stats()
	_update_status()
	var level_name: String = LEVEL_NAMES[CafeProgress.stage]
	if CafeProgress.region==2:
		level_name=["Moonlit juice bar","Cream macaron atelier","Chocolate box boutique","Cotton-candy gala"][CafeProgress.stage]
	get_node("LandscapeLayout/Header/Title").text = "%s • %s" % [CafeProgress.REGIONS[CafeProgress.region].name,level_name]
	_decorate_add_items_button()


func _build_objectives() -> void:
	var objective_ids: Array[String] = board.regional_objective_ids
	var container: Container = get_node("LandscapeLayout/RightObjectives")
	container.add_theme_constant_override("separation",4 if objective_ids.size()>4 else 24)
	var cards: Array = container.get_children()
	while cards.size() < objective_ids.size():
		var duplicate: Control = cards[cards.size()%4].duplicate()
		container.add_child(duplicate)
		cards.append(duplicate)
	for index in cards.size():
		cards[index].visible = index < objective_ids.size()
		if objective_ids.size()>4: cards[index].custom_minimum_size = Vector2(460,48)
	for index in objective_ids.size():
		var item_id: String = objective_ids[index]
		var requirement := 2+CafeProgress.stage if objective_ids.size()<=4 else 2
		var label: Label = cards[index].find_children("*","Label",true,false)[0]
		var icon: TextureRect = cards[index].find_children("*","TextureRect",true,false)[0]
		icon.texture = board._item_definitions()[item_id].texture
		if objective_ids.size()>4: icon.custom_minimum_size=Vector2(38,38); label.add_theme_font_size_override("font_size",13)
		objectives[item_id] = {"name":str(board.regional_objective_names[item_id]),"target":requirement,"label_node":label}


func _process(delta: float) -> void:
	if not held: return
	hold_time += delta
	while held and hold_time >= 0.42 + float(spawn_count-1)*0.22:
		if not _add_item(): held=false; return


func _start_adding() -> void:
	held=true; hold_time=0.0; spawn_count=0
	if not _add_item(): held=false


func _add_item() -> bool:
	var item_ids: Array[String] = board.add_random_base_items_burst(%AddItemButton.get_global_rect().get_center(),randi_range(4,6))
	if item_ids.is_empty(): status_label.text="The board is full. Merge something first!"; return false
	spawn_count += 1
	status_label.text="%d regional ingredients burst onto the board!" % item_ids.size()
	return true


func _save_section() -> String:
	return "regional_merge_objectives_%d_%d" % [CafeProgress.region,CafeProgress.stage]


func _load_progress() -> void:
	for item_id: String in objectives:
		progress[item_id] = int(SaveSystem.get_value(_save_section(),item_id,0))


func _on_item_merged(item_id: String) -> void:
	if not objectives.has(item_id): return
	progress[item_id] = mini(int(progress.get(item_id,0))+1,int(objectives[item_id].target))
	SaveSystem.set_value(_save_section(),item_id,progress[item_id])
	GameDatabase.grant_xp("xp_small")
	GameDatabase.grant_currency("coins_small")
	_update_objectives(); _update_stats()
	if _complete(): _complete_board()


func _complete() -> bool:
	for item_id: String in objectives:
		if int(progress.get(item_id,0)) < int(objectives[item_id].target): return false
	return true


func _update_objectives() -> void:
	for item_id: String in objectives:
		var data: Dictionary = objectives[item_id]
		var count := int(progress.get(item_id,0)); var required := int(data.target)
		(data.label_node as Label).text = "%s\n%d / %d%s" % [str(data.name).to_upper(),count,required,"  ✓" if count>=required else ""]


func _update_stats() -> void:
	var stats := GameDatabase.get_player_stats(); %XpAmount.text=str(int(stats.get("xp",0))); %CoinAmount.text=str(int(stats.get("coins",0)))


func _update_status() -> void:
	status_label.text="Merge matching items through every stage to finish each order."


func _decorate_add_items_button() -> void:
	# Keep the exact Sugar Blossom button treatment: one centered label and one
	# built-in icon. The icon is a compact collage of this board's source items.
	%AddItemButton.text = "ADD ITEMS"
	%AddItemButton.alignment = HORIZONTAL_ALIGNMENT_CENTER
	%AddItemButton.expand_icon = true
	%AddItemButton.icon = _build_add_items_icon()


func _build_add_items_icon() -> ImageTexture:
	var canvas := Image.create(96,96,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var item_ids: Array = board.regional_pool
	var definitions: Dictionary = board._item_definitions()
	var count := item_ids.size()
	var size := 48 if count<=4 else 34
	var positions: Array[Vector2i] = []
	if count==3:
		positions.assign([Vector2i(2,34),Vector2i(25,5),Vector2i(47,35)])
	elif count==4:
		positions.assign([Vector2i(2,4),Vector2i(45,4),Vector2i(2,45),Vector2i(45,45)])
	else:
		for index in count:
			positions.append(Vector2i(2+(index%4)*20,12+(index/4)*40))
	for index in count:
		var source: Image = (definitions[item_ids[index]].texture as Texture2D).get_image()
		source.convert(Image.FORMAT_RGBA8)
		source.resize(size,size,Image.INTERPOLATE_LANCZOS)
		canvas.blend_rect(source,Rect2i(Vector2i.ZERO,source.get_size()),positions[index])
	return ImageTexture.create_from_image(canvas)


func _reset() -> void:
	finishing=false; held=false; %AddItemButton.disabled=false
	SaveSystem.set_section(_save_section(),{}); SaveSystem.set_section(board._save_section(),{})
	progress.clear(); board.reset_board(); _load_progress(); _update_objectives(); SaveSystem.save_now()


func _go_back() -> void:
	SaveSystem.save_now(); SceneRouter.replace_scene(CafeProgress.map_scene_for_region())


func _complete_board() -> void:
	if finishing: return
	finishing=true; held=false; %AddItemButton.disabled=true
	var rewards: Node = get_node("/root/CollectibleRewards")
	await rewards.play_completion(self,board,"REGIONAL HARVEST COMPLETE!")
	SceneRouter.replace_scene(CafeProgress.map_scene_for_region())

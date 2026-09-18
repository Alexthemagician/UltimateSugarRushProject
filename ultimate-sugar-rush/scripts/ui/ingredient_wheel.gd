extends Control

signal wheel_closed
const COLORS := [Color("e96c8c"),Color("f0b95d"),Color("67b9a7"),Color("78a8d8"),Color("a887cf"),Color("d88072")]
const STOCK_ATLAS = preload("res://assets/cafe/stock_atlas.png")
var region := 0
var wheel: Node2D
var spin_button: Button
var ad_button: Button
var collect_button: Button
var result_label: Label
var spinning := false
var spin_duration := 3.2
var awarded_ids: Array[String] = []
var ad_spin_used := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.18,0.07,0.14,0.86)
	add_child(shade)
	var title := Label.new()
	title.text = "UNLIMITED HARVEST WHEEL"
	title.position = Vector2(410,36)
	title.size = Vector2(1100,70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",44)
	add_child(title)
	wheel = Node2D.new()
	wheel.name = "Wheel"
	wheel.position = Vector2(960,500)
	add_child(wheel)
	var pool: Array = CafeProgress.POOLS[region]
	for index in 6:
		_add_slice(index,str(pool[index]))
	var hub := Polygon2D.new()
	hub.polygon = _circle_points(74,32)
	hub.color = Color("fff3dc")
	wheel.add_child(hub)
	var pointer := Polygon2D.new()
	pointer.name = "Pointer"
	pointer.polygon = PackedVector2Array([Vector2(960,118),Vector2(927,174),Vector2(993,174)])
	pointer.color = Color("fff3dc")
	add_child(pointer)
	result_label = Label.new()
	result_label.position = Vector2(410,875)
	result_label.size = Vector2(1100,52)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size",30)
	result_label.text = "Tap spin to win an ingredient from this map"
	add_child(result_label)
	spin_button = _button("SPIN",Vector2(725,940),Vector2(470,90))
	spin_button.name = "SpinButton"
	spin_button.pressed.connect(_spin.bind(false))
	ad_button = _button("Watch ad & spin again",Vector2(480,940),Vector2(460,90))
	ad_button.name = "AdSpinButton"
	ad_button.visible = false
	ad_button.disabled = not RewardedAds.is_available()
	ad_button.tooltip_text = "Rewarded ad unavailable" if ad_button.disabled else "Watch a rewarded ad for one extra spin"
	ad_button.pressed.connect(_watch_ad_and_spin)
	collect_button = _button("Collect",Vector2(980,940),Vector2(460,90))
	collect_button.name = "CollectButton"
	collect_button.visible = false
	collect_button.pressed.connect(func() -> void: wheel_closed.emit(); queue_free())

func _add_slice(index: int, ingredient_id: String) -> void:
	var start := -PI*0.5 + index*TAU/6.0
	var points := PackedVector2Array([Vector2.ZERO])
	for step in 13: points.append(Vector2.from_angle(start+step*(TAU/6.0)/12.0)*330.0)
	var slice := Polygon2D.new()
	slice.polygon = points
	slice.color = COLORS[index]
	wheel.add_child(slice)
	var angle := start+TAU/12.0
	var icon := TextureRect.new()
	icon.texture = _ingredient_texture(ingredient_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2.from_angle(angle)*205.0-Vector2(45,72)
	icon.size = Vector2(90,90)
	wheel.add_child(icon)
	var name := Label.new()
	name.text = str(CafeProgress.INGREDIENTS[ingredient_id])
	name.position = Vector2.from_angle(angle)*245.0-Vector2(105,-18)
	name.size = Vector2(210,42)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size",16)
	name.add_theme_color_override("font_color",Color.WHITE)
	name.add_theme_color_override("font_outline_color",Color("4c3040"))
	name.add_theme_constant_override("outline_size",5)
	wheel.add_child(name)

func _ingredient_texture(id: String) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = STOCK_ATLAS
	var index := CafeProgress.INGREDIENTS.keys().find(id)
	var tile := Vector2(STOCK_ATLAS.get_width()/6.0,STOCK_ATLAS.get_height()/4.0)
	texture.region = Rect2(Vector2(index%6,index/6)*tile,tile)
	texture.filter_clip = true
	return texture

func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in count: points.append(Vector2.from_angle(index*TAU/count)*radius)
	return points

func _button(text: String, point: Vector2, dimensions: Vector2) -> Button:
	var control := Button.new()
	control.text = text
	control.position = point
	control.size = dimensions
	control.add_theme_font_size_override("font_size",28)
	add_child(control)
	return control

func _spin(from_ad: bool = false) -> void:
	if spinning: return
	if from_ad: ad_spin_used = true
	spinning = true
	spin_button.disabled = true
	ad_button.disabled = true
	collect_button.visible = false
	result_label.text = "Spinning…"
	var winner := randi_range(0,5)
	var target_rotation := wheel.rotation + TAU*5.0 - winner*TAU/6.0
	var tween := create_tween()
	tween.tween_property(wheel,"rotation",target_rotation,spin_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tween.finished
	var ingredient_id: String = CafeProgress.POOLS[region][winner]
	var quantity := 5+region
	CafeProgress.add_ingredient(ingredient_id,quantity)
	awarded_ids.append(ingredient_id)
	result_label.text = "%s ×%d added to your pantry!" % [CafeProgress.INGREDIENTS[ingredient_id],quantity]
	spin_button.visible = false
	ad_button.visible = not ad_spin_used
	collect_button.visible = true
	spinning = false

func _watch_ad_and_spin() -> void:
	if ad_spin_used or spinning: return
	ad_button.disabled = true
	ad_button.text = "Playing rewarded ad…"
	var earned: bool = await RewardedAds.show_rewarded_spin_ad()
	ad_button.text = "Watch ad & spin again"
	if not earned:
		ad_button.disabled = not RewardedAds.is_available()
		result_label.text = "The ad did not finish. Your extra spin is still available."
		return
	_spin(true)

from pathlib import Path
p=Path('prototypes/fixed_cafe/cafe.gd');s=p.read_text()
s=s.replace('var time := 0.0','var time := 0.0\nvar station_buttons: Array[Button] = []\nvar selected_station := -1\nvar selection_tween: Tween\nvar status_label: Label')
s=s.replace('material.metallic = metal','material.metallic = 0.58 if color.is_equal_approx(GOLD) else metal')
s=s.replace('environment.tonemap_exposure = 0.85','environment.tonemap_exposure = 1.0\n\tvar sky := Sky.new()\n\tvar sky_material := ProceduralSkyMaterial.new()\n\tsky_material.sky_top_color = Color("aecbd8")\n\tsky_material.sky_horizon_color = Color("fff1db")\n\tsky_material.ground_bottom_color = Color("ae7883")\n\tsky_material.ground_horizon_color = Color("ffe6d1")\n\tsky.sky_material = sky_material\n\tenvironment.sky = sky\n\tenvironment.reflected_light_source = Environment.REFLECTED_SOURCE_SKY\n\tget_viewport().use_taa = true')
s=s.replace('key.shadow_blur = 3','key.shadow_blur = 3\n\tkey.light_angular_distance = 2.5\n\tkey.shadow_bias = 0.04\n\tkey.shadow_normal_bias = 1.5')
s=s.replace('\t_build_ui()','\t_add_finishing_details()\n\t_build_ui()')
s=s.replace('pass_02.png','pass_03.png')
a=s.index('func _build_ui()');b=s.index('func _process(',a)
s=s[:a]+'''func _style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(20)
	style.set_border_width_all(2)
	style.border_color = border
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	title = Label.new()
	title.text = "Sugar & Sunshine"
	title.position = Vector2(55,35)
	title.add_theme_font_size_override("font_size",44)
	title.add_theme_color_override("font_color",COCOA)
	ui.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "THE PATISSERIE COLLECTION   /   CAFÉ No. 01"
	subtitle.position = Vector2(58,94)
	subtitle.add_theme_font_size_override("font_size",16)
	subtitle.add_theme_color_override("font_color",ROSE)
	ui.add_child(subtitle)
	var badge := Label.new()
	badge.text = "•  FRESH FROM THE OVEN"
	badge.position = Vector2(749,57)
	badge.add_theme_font_size_override("font_size",14)
	badge.add_theme_color_override("font_color",ROSE)
	ui.add_child(badge)
	var card := Panel.new()
	card.position = Vector2(55,1010)
	card.size = Vector2(970,148)
	card.add_theme_stylebox_override("panel",_style(Color("fff5e9"),Color("e9c6bf")))
	ui.add_child(card)
	status_label = Label.new()
	status_label.text = "Make yourself at home"
	status_label.position = Vector2(26,17)
	status_label.add_theme_font_size_override("font_size",23)
	status_label.add_theme_color_override("font_color",COCOA)
	card.add_child(status_label)
	detail = Label.new()
	detail.text = "Choose a station to take a closer look at its little details."
	detail.position = Vector2(26,52)
	detail.add_theme_font_size_override("font_size",16)
	detail.add_theme_color_override("font_color",COCOA.lightened(0.15))
	card.add_child(detail)
	var names := ["01   Bakery", "02   Coffee", "03   Candy", "04   Cakes"]
	for i in 4:
		var button := Button.new()
		button.text = names[i]
		button.position = Vector2(26+i*231,91)
		button.size = Vector2(220,39)
		button.add_theme_font_size_override("font_size",16)
		button.add_theme_color_override("font_color",COCOA)
		button.add_theme_color_override("font_hover_color",ROSE)
		button.add_theme_stylebox_override("normal",_style(Color("f6e4d9")))
		button.add_theme_stylebox_override("hover",_style(Color("efd0ca")))
		button.add_theme_stylebox_override("focus",_style(Color("f6e4d9"),ROSE))
		button.pressed.connect(_select_station.bind(i))
		card.add_child(button)
		station_buttons.append(button)

func _select_station(index: int) -> void:
	selected_station = index
	status_label.text = stations[index].name
	detail.text = stations[index].description
	for i in 4:
		station_buttons[i].add_theme_stylebox_override("normal",_style(Color("e7b6bd") if i == index else Color("f6e4d9")))
	var station: Node3D = stations[index].node
	if selection_tween and selection_tween.is_running():
		selection_tween.kill()
	for entry in stations:
		entry.node.scale = Vector3.ONE
	selection_tween = create_tween()
	selection_tween.tween_property(station,"scale",Vector3.ONE*1.025,0.16).set_trans(Tween.TRANS_SINE)
	selection_tween.tween_property(station,"scale",Vector3.ONE,0.22).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	else: return
	var closest := -1
	var distance := 110.0
	for i in stations.size():
		var screen := camera.unproject_position(stations[i].node.position + Vector3(0,1.1,0))
		if point.distance_to(screen) < distance:
			distance = point.distance_to(screen)
			closest = i
	if closest >= 0: _select_station(closest)

func _add_finishing_details() -> void:
	# A tiled backsplash gives the equipment a shared architectural setting.
	for row in 4:
		for col in 20:
			box(Vector3(-4.05+col*0.31,1.44+row*0.19,-3.915),Vector3(0.298,0.178,0.055),CREAM if (col+row)%3 else Color("f2c9c0"),0.014)
	# Open pastry shelf: brackets, stacked plates, jam pots and flour bags.
	box(Vector3(-2.93,2.61,-3.59),Vector3(2.0,0.11,0.64),CREAM)
	for x in [-3.69,-2.15]:
		rod(Vector3(x,2.6,-3.37),Vector3(x,2.27,-3.91),0.024,GOLD)
	for i in 4:
		cylinder(Vector3(-3.53,2.7+i*0.045,-3.5),0.2,0.04,MINT)
	for i in 2:
		box(Vector3(-2.92+i*0.45,2.9,-3.55),Vector3(0.32,0.44,0.24),CREAM if i==0 else PINK,0.045)
		box(Vector3(-2.92+i*0.45,3.12,-3.55),Vector3(0.32,0.055,0.23),GOLD,0.015)
		label3("FLOUR" if i==0 else "SUGAR",Vector3(-2.92+i*0.45,2.92,-3.42),12,COCOA)
	# Cabinet joinery and tiny brass feet, consistent across every station.
	for entry in stations:
		var station: Node3D = entry.node
		for x in [-0.9,0.9]:
			for z in [-0.38,0.38]: cylinder(Vector3(x,0.13,z),0.055,0.21,GOLD,-1,station)
		for x in [-0.78,-0.63,-0.48,0.48,0.63,0.78]:
			box(Vector3(x,0.62,0.641),Vector3(0.014,0.47,0.014),Color("df9e9e") if entry.name != "Cloud nine coffee" else Color("559b8a"),0.005,station)
	# A prep board with a rolling pin and dough makes the bakery feel used.
	var bakery: Node3D = stations[0].node
	box(Vector3(0.58,1.383,0.30),Vector3(0.87,0.05,0.42),Color("d8a465"),0.045,bakery)
	rod(Vector3(0.22,1.49,0.51),Vector3(0.93,1.49,0.51),0.05,GOLD,bakery)
	# Pastry stand in the open floor area, balanced against the serving counter.
	cylinder(Vector3(-1.25,0.74,1.78),0.72,0.10,CREAM)
	cylinder(Vector3(-1.25,0.4,1.78),0.10,0.64,GOLD)
	cylinder(Vector3(-1.25,0.13,1.78),0.37,0.06,GOLD)
	for i in 6:
		var angle := i*TAU/6
		var p := Vector3(-1.25+cos(angle)*0.42,0.86,1.78+sin(angle)*0.42)
		var bun := ball(p,Vector3(0.31,0.16,0.23),Color("d99042"))
		bun.rotation.y = angle
		for j in 3:
			var stripe := box(p+Vector3((j-1)*0.06,0.075,0),Vector3(0.022,0.02,0.13),CREAM,0.006)
			stripe.rotation.y = angle
	cylinder(Vector3(-1.25,1.12,1.78),0.32,0.07,GOLD)
	rod(Vector3(-1.25,0.8,1.78),Vector3(-1.25,1.12,1.78),0.035,GOLD)
	for i in 3: _cupcake(Vector3(-1.45+i*0.20,1.16,1.78),self)
	# Welcome rug and a handwritten shop tag.
	box(Vector3(1.35,0.125,3.24),Vector3(2.3,0.025,0.75),ROSE,0.10)
	for x in range(11):
		box(Vector3(0.35+x*0.20,0.143,3.24),Vector3(0.008,0.01,0.6),PINK,0.003)
	var welcome := label3("hello, sweet thing",Vector3(1.35,0.16,3.24),25,CREAM)
	welcome.rotation_degrees.x = -90
	# Soft oven glow stays local to the baking station.
	var oven_light := OmniLight3D.new()
	oven_light.position = Vector3(-2.34,0.61,-1.97)
	oven_light.light_color = Color("ffb857")
	oven_light.light_energy = 0.3
	oven_light.omni_range = 0.9
	add_child(oven_light)

''' + s[b:]
p.write_text(s)

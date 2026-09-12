extends Node3D

const CREAM = Color("fff0d5")
const PINK = Color("e96c8c")
const ROSE = Color("b74765")
const MINT = Color("63b9a7")
const GOLD = Color("dba451")
const COCOA = Color("63414a")
var camera: Camera3D
var materials: Dictionary = {}
var steam: Array[MeshInstance3D] = []
var time := 0.0
var station_buttons: Array[Button] = []
var selected_station := -1
var selection_tween: Tween
var status_label: Label
var title: Label
var detail: Label
var stations: Array[Dictionary] = []

func mat(color: Color, metal := 0.0, rough := 0.12) -> StandardMaterial3D:
	var key := str(color) + str(metal) + str(rough)
	if materials.has(key): return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	# Keep broad cartoon light bands with a glazed, softly reflective finish.
	material.metallic = 0.25 if color.is_equal_approx(GOLD) else 0.0
	material.roughness = rough
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	material.metallic_specular = 0.85
	material.clearcoat_enabled = true
	material.clearcoat = 0.85
	material.clearcoat_roughness = 0.08
	materials[key] = material
	return material

func mesh_at(mesh: Mesh, p: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color)
	node.position = p
	parent.add_child(node)
	# Separate ink hulls must never cast shadows onto the painted surface.
	var outline := MeshInstance3D.new()
	outline.mesh = mesh
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://soft_ink.gdshader")
	ink.set_shader_parameter("ink_color", Color(color.r*0.55, color.g*0.48, color.b*0.53))
	outline.material_override = ink
	node.add_child(outline)
	return node

func box(p: Vector3, s: Vector3, color: Color, radius := 0.06, parent: Node3D = self) -> MeshInstance3D:
	# Bevel all faces using the same rounded-cube surface construction.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := s * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.95)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var us: Array[float] = [-half[u], -half[u]+r*0.3, -half[u]+r*0.7, -half[u]+r, half[u]-r, half[u]-r*0.7, half[u]-r*0.3, half[u]]
			var vs: Array[float] = [-half[v], -half[v]+r*0.3, -half[v]+r*0.7, -half[v]+r, half[v]-r, half[v]-r*0.7, half[v]-r*0.3, half[v]]
			for i in 7:
				for j in 7:
					var corners: Array[Vector2i] = [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i+1,j+1), Vector2i(i,j), Vector2i(i+1,j+1), Vector2i(i,j+1)]
					if sign_value > 0: corners.reverse()
					for corner in corners:
						var point := Vector3.ZERO
						point[axis] = half[axis] * sign_value
						point[u] = us[corner.x]
						point[v] = vs[corner.y]
						var inner := point.clamp(-half + Vector3.ONE*r, half - Vector3.ONE*r)
						var normal := (point-inner).normalized()
						surface.set_normal(normal)
						surface.add_vertex(inner + normal*r)
	return mesh_at(surface.commit(), p, color, parent)

func ball(p: Vector3, s: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 12
	var node := mesh_at(mesh, p, color, parent)
	node.scale = s
	return node

func cylinder(p: Vector3, radius: float, height: float, color: Color, top := -1.0, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 32
	return mesh_at(mesh, p, color, parent)

func ring(p: Vector3, outer: float, inner: float, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 12
	return mesh_at(mesh, p, color, parent)

func rod(a: Vector3, b: Vector3, radius: float, color: Color, parent: Node3D = self) -> void:
	var node := cylinder((a+b)*0.5, radius, a.distance_to(b), color, -1, parent)
	var direction := (b-a).normalized()
	node.quaternion = Quaternion(Vector3.UP, direction)

func label3(text: String, p: Vector3, font_size: int, color: Color, parent: Node3D = self) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = p
	label.font_size = font_size
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)
	return label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("f3dedb"))
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("f3dedb")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ffe8d9")
	environment.ambient_light_energy = 0.28
	environment.ssao_enabled = false
	environment.ssao_radius = 0.65
	environment.ssao_intensity = 0.65
	environment.ssao_detail = 0.2
	environment.tonemap_exposure = 0.94
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("aecbd8")
	sky_material.sky_horizon_color = Color("fff1db")
	sky_material.ground_bottom_color = Color("ae7883")
	sky_material.ground_horizon_color = Color("ffe6d1")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.reflected_light_source = 1
	get_viewport().use_taa = true
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -30, 0)
	key.light_color = Color("fff1d9")
	key.light_energy = 0.9
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 30
	key.shadow_blur = 1.0
	key.light_angular_distance = 0.0
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.5
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 140, 0)
	fill.light_color = Color("c9e9ef")
	fill.light_energy = 0.3
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.8
	camera.position = Vector3(12, 13, 16)
	add_child(camera)
	camera.look_at(Vector3(0, 0.7, 0))
	camera.current = true
	_build_room()
	_build_bakery(Vector3(-2.9, 0, -2.75))
	_build_coffee(Vector3(0.35, 0, -2.75))
	_build_candy(Vector3(-3.15, 0, 0.05))
	_build_display(Vector3(1.75, 0, 1.6))
	_table(Vector3(3.0, 0, -1.0))
	_plant(Vector3(3.6, 0, -3.2))
	_plant(Vector3(-3.7, 0, 3.4))
	_add_finishing_details()
	_decorate_stations()
	_build_ui()
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://pass_09.png")
		get_tree().quit()

func _build_room() -> void:
	box(Vector3(0,-0.35,0), Vector3(9,0.65,8.6), ROSE, 0.2)
	box(Vector3(0,-0.04,0), Vector3(8.85,0.15,8.45), GOLD)
	for x in 12:
		for z in 11:
			box(Vector3(-4.02+x*0.73,0.06,-3.66+z*0.73), Vector3(0.718,0.10,0.718), Color("f8e9d1") if (x+z)%2 == 0 else Color("e6b6aa"), 0.02)
	box(Vector3(0,1.8,-4.05), Vector3(8.9,3.6,0.2), Color("f7ddc6"))
	box(Vector3(-4.35,1.8,0), Vector3(0.2,3.6,8.3), Color("f9e3ce"))
	for x in 18:
		box(Vector3(-4.2+x*0.49,0.62,-3.91), Vector3(0.45,1.12,0.06), MINT, 0.025)
	for z in 16:
		box(Vector3(-4.21,0.62,-3.77+z*0.5), Vector3(0.06,1.12,0.46), MINT, 0.025)
	box(Vector3(0,1.26,-3.9),Vector3(8.8,0.12,0.13),CREAM)
	box(Vector3(-4.18,1.26,0),Vector3(0.13,0.12,8.25),CREAM)
	box(Vector3(0,3.6,-4.03),Vector3(9.05,0.17,0.32),PINK)
	box(Vector3(-4.34,3.6,0),Vector3(0.32,0.17,8.4),PINK)
	# Framed menu and a confectionery sign share the room's palette.
	box(Vector3(-0.9,2.75,-3.88),Vector3(3.0,0.72,0.14),ROSE)
	label3("SUGAR & SUNSHINE",Vector3(-0.9,2.77,-3.795),48,CREAM)
	label3("BAKED WITH A LITTLE MAGIC",Vector3(-0.9,2.51,-3.79),18,CREAM)
	box(Vector3(2.35,2.38,-3.85),Vector3(1.4,1.7,0.15),GOLD)
	box(Vector3(2.35,2.38,-3.75),Vector3(1.25,1.55,0.06),COCOA)
	label3("TODAY'S TREATS\n\nBerry cloud cake\nHoney butter bun\nRose milk latte\n\nMade with love",Vector3(2.35,2.42,-3.71),24,CREAM)
	# Left wall window, face into the room.
	box(Vector3(-4.19,2.35,0.5),Vector3(0.12,1.8,2.65),GOLD)
	box(Vector3(-4.10,2.35,0.5),Vector3(0.08,1.63,2.49),Color("bfe8e3"))
	for z in [-0.73,0.5,1.73]: box(Vector3(-4.02,2.35,z),Vector3(0.1,1.72,0.08),CREAM)
	box(Vector3(-4.02,2.35,0.5),Vector3(0.1,0.08,2.55),CREAM)
	box(Vector3(-3.98,1.43,0.5),Vector3(0.47,0.13,2.9),CREAM)
	for x in [-2.6,0.5,3.05]:
		rod(Vector3(x,4.3,-1.75),Vector3(x,3.63,-1.75),0.025,GOLD)
		cylinder(Vector3(x,3.5,-1.75),0.38,0.28,PINK,0.16)
		cylinder(Vector3(x,3.37,-1.75),0.34,0.035,CREAM)

func _cabinet(parent: Node3D, width: float, color: Color) -> void:
	box(Vector3(0,0.65,0),Vector3(width,1.12,1.12),color,0.10,parent)
	box(Vector3(0,0.16,0),Vector3(width+0.03,0.13,1.13),ROSE,0.025,parent)
	box(Vector3(0,1.27,0),Vector3(width+0.18,0.18,1.28),CREAM,0.07,parent)
	box(Vector3(0,1.15,0.57),Vector3(width,0.045,0.04),GOLD,0.01,parent)
	for x in [-width*0.25,width*0.25]:
		box(Vector3(x,0.68,0.575),Vector3(width*0.45,0.8,0.055),CREAM,0.04,parent)
		box(Vector3(x,0.68,0.61),Vector3(width*0.45-0.075,0.72,0.04),color.lightened(0.12),0.03,parent)
		rod(Vector3(x-0.15,0.94,0.67),Vector3(x+0.15,0.94,0.67),0.025,GOLD,parent)

func _station(p: Vector3, name_text: String, description: String) -> Node3D:
	var station := Node3D.new()
	station.position = p
	station.name = name_text.replace(" ", "")
	add_child(station)
	stations.append({"node":station,"name":name_text,"description":description})
	return station

func _build_bakery(p: Vector3) -> void:
	var station := _station(p,"The little bakery","Warm ovens, berry cupcakes and a strawberry-pink mixer.")
	_cabinet(station,2.45,PINK)
	box(Vector3(0.56,0.65,0.65),Vector3(0.92,0.85,0.12),COCOA,0.08,station)
	box(Vector3(0.56,0.59,0.73),Vector3(0.71,0.51,0.05),Color("b77b47"),0.06,station)
	rod(Vector3(0.21,0.99,0.76),Vector3(0.91,0.99,0.76),0.04,GOLD,station)
	for x in [0.26,0.56,0.86]: ball(Vector3(x,0.52,0.78),Vector3(0.19,0.12,0.1),Color("e9ad50"),station)
	# Mixer has a foot, upright, overhanging head, whisk and nested bowl.
	box(Vector3(-0.6,1.42,0),Vector3(0.7,0.1,0.8),PINK,0.05,station)
	box(Vector3(-0.77,1.75,-0.23),Vector3(0.23,0.65,0.27),PINK,0.1,station)
	box(Vector3(-0.6,2.04,-0.03),Vector3(0.45,0.3,0.7),PINK,0.14,station)
	box(Vector3(-0.6,2.11,-0.03),Vector3(0.4,0.08,0.59),CREAM,0.035,station)
	cylinder(Vector3(-0.55,1.6,0.15),0.23,0.28,MINT,0.32,station)
	ring(Vector3(-0.55,1.75,0.15),0.325,0.28,CREAM,station)
	cylinder(Vector3(-0.55,1.73,0.15),0.28,0.025,Color("ffe5ac"),-1,station)
	rod(Vector3(-0.55,1.77,0.15),Vector3(-0.55,1.93,0.15),0.025,GOLD,station)
	for x in [0.1,0.52,0.94]:
		cylinder(Vector3(x,1.54,-0.2),0.15,0.34,CREAM,-1,station)
		cylinder(Vector3(x,1.73,-0.2),0.17,0.07,PINK,-1,station)
		ball(Vector3(x,1.79,-0.2),Vector3.ONE*0.07,GOLD,station)
	for x in [0.1,0.5,0.9]: _cupcake(Vector3(x,1.39,0.34),station)

func _cupcake(p: Vector3, parent: Node3D) -> void:
	cylinder(p+Vector3(0,0.075,0),0.11,0.15,Color("d9a066"),0.15,parent)
	for i in 9:
		var angle := i*TAU/9
		rod(p+Vector3(cos(angle)*0.12,0.015,sin(angle)*0.12),p+Vector3(cos(angle)*0.15,0.14,sin(angle)*0.15),0.009,CREAM,parent)
	for i in 3:
		ball(p+Vector3(0,0.18+i*0.055,0),Vector3(0.31-i*0.065,0.13,0.31-i*0.065),PINK.lightened(0.15),parent)
	ball(p+Vector3(0,0.34,0),Vector3.ONE*0.085,Color("b93254"),parent)

func _build_coffee(p: Vector3) -> void:
	var station := _station(p,"Cloud nine coffee","A mint espresso machine and a quiet moment between sweets.")
	_cabinet(station,2.7,MINT)
	box(Vector3(-0.35,1.78,-0.12),Vector3(1.25,0.8,0.65),MINT,0.13,station)
	box(Vector3(-0.35,1.83,0.25),Vector3(1.05,0.42,0.07),CREAM,0.04,station)
	box(Vector3(-0.35,1.44,0.38),Vector3(1.12,0.07,0.45),GOLD,0.03,station)
	for x in [-0.68,-0.11]:
		ball(Vector3(x,1.92,0.31),Vector3.ONE*0.1,GOLD,station)
		rod(Vector3(x,1.7,0.25),Vector3(x,1.63,0.38),0.035,COCOA,station)
		_cup(Vector3(x,1.48,0.38),station)
	for x in [-0.68,-0.35,-0.02]: _cup(Vector3(x,2.2,-0.12),station)
	cylinder(Vector3(0.72,1.65,-0.05),0.23,0.5,COCOA,-1,station)
	cylinder(Vector3(0.72,1.92,-0.05),0.25,0.08,GOLD,-1,station)
	_cup(Vector3(0.8,1.4,0.38),station)
	for i in 4:
		var puff := ball(p+Vector3(-0.68,1.83+i*0.11,0.38),Vector3.ONE*(0.06+i*0.016),CREAM)
		steam.append(puff)

func _cup(p: Vector3, parent: Node3D) -> void:
	cylinder(p+Vector3(0,0.09,0),0.095,0.18,CREAM,0.12,parent)
	cylinder(p+Vector3(0,0.18,0),0.096,0.006,COCOA,-1,parent)
	cylinder(p,0.17,0.025,CREAM,-1,parent)
	var handle := ring(p+Vector3(0.12,0.1,0),0.07,0.045,CREAM,parent)
	handle.rotation_degrees.x = 90

func _build_candy(p: Vector3) -> void:
	var station := _station(p,"Sugar workshop","Swirled lollipops, candy jars and tiny hand-made treasures.")
	station.rotation_degrees.y = 90
	_cabinet(station,2.2,PINK)
	for i in 3:
		var x := -0.65+i*0.65
		var jar := cylinder(Vector3(x,1.7,-0.15),0.22,0.58,Color("cbe4d4"),-1,station)
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.8, 0.98, 0.96, 0.16)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness = 0.22
		glass.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		jar.material_override = glass
		jar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring(Vector3(x,1.44,-0.15),0.23,0.21,CREAM,station)
		for layer in 4:
			for candy_index in 5:
				var angle := candy_index * TAU/5 + layer*0.7
				ball(Vector3(x+cos(angle)*0.13,1.5+layer*0.115,-0.15+sin(angle)*0.13),Vector3(0.11,0.09,0.11),[Color("e54479"),Color("efad3c"),Color("78bd52")][i],station)
		cylinder(Vector3(x,2.02,-0.15),0.25,0.08,GOLD,-1,station)
		ball(Vector3(x,2.09,-0.15),Vector3.ONE*0.1,GOLD,station)
		for j in 5:
			ball(Vector3(x-0.07+(j%2)*0.13,1.49+(j/2)*0.14,-0.08),Vector3.ONE*0.14,[PINK,CREAM,MINT][i],station)
	box(Vector3(0,1.4,0.28),Vector3(1.6,0.08,0.45),GOLD,0.06,station)
	for i in 5:
		var x := -0.62+i*0.31
		rod(Vector3(x,1.42,0.25),Vector3(x,1.86,0.25),0.018,CREAM,station)
		var sweet := cylinder(Vector3(x,1.92,0.25),0.14,0.08,PINK if i%2 == 0 else MINT,-1,station)
		sweet.rotation_degrees.x = 90
		var swirl := ring(Vector3(x,1.92,0.30),0.11,0.07,CREAM,station)
		swirl.rotation_degrees.x = 90

func _build_display(p: Vector3) -> void:
	var station := _station(p,"The cake atelier","A celebration cake takes centre stage. Every recipe deserves a little ceremony.")
	_cabinet(station,3.0,PINK)
	for x in [-1.02,1.02]:
		cylinder(Vector3(x,1.42,0),0.32,0.08,GOLD,-1,station)
		for z in [-0.15,0.15]: _cupcake(Vector3(x,1.47,z),station)
	cylinder(Vector3(0,1.48,0),0.46,0.07,GOLD,-1,station)
	cylinder(Vector3(0,1.7,0),0.4,0.4,CREAM,-1,station)
	cylinder(Vector3(0,1.91,0),0.415,0.075,PINK,-1,station)
	cylinder(Vector3(0,2.07,0),0.27,0.27,CREAM,-1,station)
	cylinder(Vector3(0,2.21,0),0.28,0.07,PINK,-1,station)
	for i in 12:
		var angle := i*TAU/12
		ball(Vector3(cos(angle)*0.38,1.85,sin(angle)*0.38),Vector3(0.085,0.14,0.085),PINK,station)
	for i in 7:
		var angle := i*TAU/7
		ball(Vector3(cos(angle)*0.21,2.28,sin(angle)*0.21),Vector3(0.1,0.12,0.1),Color("b93254"),station)
	# Candy-striped awning with a scalloped edge over the serving counter.
	for i in 12:
		var x := -1.54+i*0.28
		box(Vector3(x,3.0,-0.36),Vector3(0.285,0.1,0.88),CREAM if i%2 else PINK,0.04,station)
		ball(Vector3(x,2.93,0.06),Vector3(0.285,0.21,0.11),CREAM if i%2 else PINK,station)
	for x in [-1.6,1.6]: rod(Vector3(x,0.2,-0.54),Vector3(x,2.97,-0.54),0.045,GOLD,station)

func _table(p: Vector3) -> void:
	cylinder(p+Vector3(0,0.87,0),0.64,0.12,CREAM)
	cylinder(p+Vector3(0,0.44,0),0.075,0.8,GOLD)
	cylinder(p+Vector3(0,0.13,0),0.35,0.05,GOLD)
	_cup(p+Vector3(0.17,0.94,0.15),self)
	cylinder(p+Vector3(-0.16,1.06,-0.12),0.10,0.23,PINK)
	for i in 3:
		var end := p+Vector3(-0.2+i*0.05,1.39,-0.12)
		rod(p+Vector3(-0.16,1.13,-0.12),end,0.013,MINT)
		ball(end,Vector3.ONE*0.12,PINK)
	for z in [-0.87,0.87]:
		cylinder(p+Vector3(0,0.52,z),0.3,0.13,MINT)
		for x in [-0.19,0.19]:
			for dz in [-0.15,0.15]: rod(p+Vector3(x,0.1,z+dz),p+Vector3(x,0.47,z+dz),0.028,GOLD)

func _plant(p: Vector3) -> void:
	cylinder(p+Vector3(0,0.28,0),0.23,0.43,CREAM,0.32)
	ring(p+Vector3(0,0.5,0),0.34,0.28,GOLD)
	for i in 8:
		var angle := i*TAU/8
		var leaf := ball(p+Vector3(cos(angle)*0.19,0.73+(i%3)*0.12,sin(angle)*0.19),Vector3(0.18,0.65,0.18),MINT.darkened((i%3)*0.08))
		leaf.rotation_degrees = Vector3(sin(angle)*25,0,cos(angle)*25)

func _style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
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
	# Window curtains: repeat the same cream-and-rose stripes as the awning.
	for i in 10:
		var z := -0.85+i*0.29
		box(Vector3(-3.99,3.23,z),Vector3(0.17,0.26,0.29),PINK if i%2==0 else CREAM,0.045)
		ball(Vector3(-3.93,3.1,z),Vector3(0.12,0.16,0.28),PINK if i%2==0 else CREAM)
	# Medallion on the left wall, with an oversized sculpted strawberry.
	var plate := cylinder(Vector3(-4.12,2.5,2.83),0.48,0.08,CREAM)
	plate.rotation_degrees.z = 90
	var frame := ring(Vector3(-4.06,2.5,2.83),0.49,0.44,GOLD)
	frame.rotation_degrees.z = 90
	ball(Vector3(-3.99,2.46,2.83),Vector3(0.12,0.49,0.39),PINK)
	for i in 3:
		var leaf := ball(Vector3(-3.96,2.72,2.74+i*0.09),Vector3(0.07,0.14,0.18),MINT)
		leaf.rotation_degrees.x = (i-1)*30
	for i in 3:
		for j in 2:
			ball(Vector3(-3.918,2.35+i*0.10,2.76+j*0.13),Vector3(0.024,0.036,0.02),GOLD)
	# Tidy folded towels and a recipe card add useful scale cues.
	var coffee: Node3D = stations[1].node
	for i in 3: box(Vector3(1.07,1.4+i*0.035,-0.08),Vector3(0.3,0.04,0.34),CREAM if i%2==0 else PINK,0.015,coffee)
	var recipe := box(Vector3(-0.04,1.42,0.49),Vector3(0.21,0.24,0.035),CREAM,0.01,bakery)
	recipe.rotation_degrees.x = -15
	label3("RECIPE",Vector3(-0.04,1.48,0.515),9,COCOA,bakery)
	# Soft oven glow stays local to the baking station.
	var oven_light := OmniLight3D.new()
	oven_light.position = Vector3(-2.34,0.61,-1.97)
	oven_light.light_color = Color("ffb857")
	oven_light.light_energy = 0.3
	oven_light.omni_range = 0.9
	add_child(oven_light)

func _process(delta: float) -> void:
	time += delta
	for i in steam.size():
		steam[i].position.y = 1.83+fmod(time*0.18+i*0.11,0.5)
		steam[i].position.x = -0.33 + sin(time*1.7+i)*0.04



func _decorate_stations() -> void:
	var bakery: Node3D = stations[0].node
	# Ceramic utensil crock, spatula, wooden spoon and a looped whisk.
	cylinder(Vector3(-1.01,1.53,0.34),0.12,0.31,MINT,0.15,bakery)
	ring(Vector3(-1.01,1.69,0.34),0.155,0.13,CREAM,bakery)
	rod(Vector3(-1.08,1.6,0.32),Vector3(-1.17,2.03,0.31),0.019,GOLD,bakery)
	ball(Vector3(-1.18,2.05,0.31),Vector3(0.1,0.17,0.045),GOLD,bakery)
	rod(Vector3(-0.99,1.6,0.34),Vector3(-0.95,2.04,0.34),0.018,CREAM,bakery)
	box(Vector3(-0.95,2.04,0.34),Vector3(0.10,0.17,0.04),PINK,0.025,bakery)
	rod(Vector3(-0.93,1.6,0.3),Vector3(-0.85,1.91,0.3),0.018,GOLD,bakery)
	for angle in [0.0,60.0,120.0]:
		var wire := ring(Vector3(-0.84,1.98,0.30),0.09,0.079,CREAM,bakery)
		wire.rotation_degrees = Vector3(90,angle,0)
		wire.scale = Vector3(0.75,1,1.3)
	var coffee: Node3D = stations[1].node
	# A pair of syrup bottles with pump tops and contrasting labels.
	for i in 2:
		var x := 1.03+i*0.23
		cylinder(Vector3(x,1.59,-0.4),0.08,0.39,PINK if i==0 else GOLD,-1,coffee)
		cylinder(Vector3(x,1.59,-0.4),0.083,0.13,CREAM,-1,coffee)
		cylinder(Vector3(x,1.81,-0.4),0.036,0.09,COCOA,-1,coffee)
		rod(Vector3(x,1.86,-0.4),Vector3(x,1.86,-0.28),0.016,COCOA,coffee)
	# Hand-painted milk jug with a rounded handle.
	cylinder(Vector3(0.34,1.53,0.25),0.10,0.28,PINK,0.075,coffee)
	var jug_handle := ring(Vector3(0.45,1.54,0.25),0.075,0.047,CREAM,coffee)
	jug_handle.rotation_degrees.x = 90
	var candy: Node3D = stations[2].node
	# Wrapped bonbons, each with two pinched wrapper ends.
	for i in 3:
		var p := Vector3(-0.69+i*0.67,1.44,0.48)
		var tint: Color = [MINT,PINK,Color("efbf65")][i]
		ball(p,Vector3(0.16,0.10,0.12),tint,candy)
		for direction in [-1,1]:
			var wrapper := cylinder(p+Vector3(direction*0.12,0,0),0.066,0.09,tint.lightened(0.2),0.015,candy)
			wrapper.rotation_degrees.z = direction*90
	var cakes: Node3D = stations[3].node
	# Strawberry dish and a stack of colourful macarons on the front edge.
	cylinder(Vector3(0.58,1.39,0.41),0.18,0.028,MINT,-1,cakes)
	for i in 3:
		var p := Vector3(0.49+i*0.08,1.46,0.41+(i%2)*0.04)
		ball(p,Vector3(0.10,0.13,0.09),Color("e9557d"),cakes)
		ball(p+Vector3(0,0.07,0),Vector3(0.09,0.025,0.08),MINT,cakes)
	for i in 3:
		var p := Vector3(-0.62,1.43+i*0.11,0.4)
		var tint: Color = [MINT,PINK,Color("b2a0d9")][i]
		cylinder(p,0.11,0.05,tint,-1,cakes)
		cylinder(p+Vector3(0,0.036,0),0.105,0.03,CREAM,-1,cakes)
		cylinder(p+Vector3(0,0.069,0),0.11,0.04,tint,-1,cakes)


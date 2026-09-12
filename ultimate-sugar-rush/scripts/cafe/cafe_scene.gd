extends Node3D

signal station_selected(index: int)
signal customer_purchased(receipt: Dictionary)
var actors: Array[Dictionary] = []

const CREAM = Color("fff0d5")
const PINK = Color("e96c8c")
const ROSE = Color("b74765")
const MINT = Color("63b9a7")
const GOLD = Color("dba451")
const COCOA = Color("63414a")
const MIN_ZOOM := 10.5
const MAX_ZOOM := 22.0
const PAN_LIMIT := 6.0
const WALK_SPEED := 0.72
const STRIDE_LENGTH := 0.40
var pan_offset := Vector2.ZERO
var camera_home := Vector3(12,13,16)
var mouse_down := false
var drag_distance := 0.0
var touches: Dictionary = {}
var pinching := false
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
var batch_icons: Array[Sprite3D] = []
var batch_labels: Array[Label3D] = []
var display_products: Array[Node3D] = []
var display_counts: Array[Label3D] = []
const ROOM_SPREAD := Vector3(1.5, 1.0, 1.5)

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
	ink.shader = preload("res://scripts/cafe/soft_ink.gdshader")
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
	get_viewport().use_taa = RenderingServer.get_current_rendering_method() == "forward_plus"
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
	camera.size = 16.0
	camera.position = Vector3(12, 13, 16)
	add_child(camera)
	camera.look_at(Vector3(0, 0.7, 0))
	camera.current = true
	_build_neighborhood()
	get_node("Neighborhood").scale = ROOM_SPREAD
	var before_room := get_children()
	_build_room()
	for child in get_children():
		if child is Node3D and child not in before_room:
			child.position *= ROOM_SPREAD
			child.scale *= ROOM_SPREAD
	var before_furniture := get_children()
	_build_bakery(Vector3(-2.9, 0, -2.75))
	_build_coffee(Vector3(0.35, 0, -2.75))
	_build_candy(Vector3(-3.15, 0, 0.05))
	_build_display(Vector3(1.75, 0, 1.6))
	_table(Vector3(3.0, 0, -1.0))
	_plant(Vector3(3.6, 0, -3.2))
	_plant(Vector3(-3.2, 0, 3.65))
	_add_finishing_details()
	_decorate_stations()
	for child in get_children():
		if child is Node3D and child not in before_furniture:
			child.position *= ROOM_SPREAD
	_build_tea_machine()
	_build_product_displays()
	_build_actors()
	_build_batch_indicators()

func _build_product_displays() -> void:
	for i in CafeProgress.RECIPES.size():
		var display := Node3D.new()
		display.name = "ProductDisplay%d" % i
		display.position = Vector3(-1.9 + i * 1.55, 0, 4.6)
		add_child(display)
		box(Vector3(0,0.48,0),Vector3(1.35,0.96,0.8),PINK,0.06,display)
		box(Vector3(0,1.0,0),Vector3(1.45,0.12,0.9),CREAM,0.04,display)
		for x in [-0.64,0.64]:
			for z in [-0.35,0.35]: rod(Vector3(x,1.04,z),Vector3(x,1.7,z),0.025,GOLD,display)
		box(Vector3(0,1.72,0),Vector3(1.4,0.07,0.85),CREAM,0.03,display)
		var glass := box(Vector3(0,1.39,0.4),Vector3(1.3,0.6,0.02),Color("b7e7ec"),0.0,display)
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.7,0.93,1,0.18)
		material.roughness = 0.08
		glass.material_override = material
		var products := Node3D.new()
		products.position = Vector3(0,1.18,0)
		products.scale = Vector3.ONE * 2.2
		display.add_child(products)
		_set_carried_product(products,i)
		display_products.append(products)
		var count := Label3D.new()
		count.position = Vector3(0,0.7,0.44)
		count.font_size = 40
		count.pixel_size = 0.004
		display.add_child(count)
		display_counts.append(count)

func _build_batch_indicators() -> void:
	var atlas := load("res://assets/cafe/stock_atlas.png") as Texture2D
	for i in stations.size():
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		var cell := Vector2(atlas.get_width() / 6.0, atlas.get_height() / 4.0)
		var icon_index := 19 if i == 4 else 18+i
		texture.region = Rect2(Vector2(icon_index%6, icon_index/6) * cell, cell)
		var marker := Sprite3D.new()
		marker.name = "CollectBatch%d" % i
		marker.texture = texture
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.pixel_size = 0.003
		marker.no_depth_test = true
		marker.position = stations[i].node.position + Vector3(0, 2.8, 0)
		add_child(marker)
		batch_icons.append(marker)
		var caption := Label3D.new()
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.no_depth_test = true
		caption.font_size = 40
		caption.pixel_size = 0.005
		caption.position = marker.position + Vector3(0, 0.55, 0)
		add_child(caption)
		batch_labels.append(caption)

func _build_room() -> void:
	box(Vector3(0,-0.35,0), Vector3(9,0.65,8.6), ROSE, 0.2)
	box(Vector3(0,-0.04,0), Vector3(8.85,0.15,8.45), GOLD)
	for x in 12:
		for z in 11:
			box(Vector3(-4.02+x*0.73,0.06,-3.66+z*0.73), Vector3(0.718,0.10,0.718), Color("f8e9d1") if (x+z)%2 == 0 else Color("e6b6aa"), 0.02)
	box(Vector3(0,1.8,-4.05), Vector3(8.9,3.6,0.2), Color("f7ddc6"))
	# Real opening: z 2.05..3.55, floor to lintel at y 2.7.
	box(Vector3(-4.35,1.8,-1.05),Vector3(0.2,3.6,6.2),Color("f9e3ce"))
	box(Vector3(-4.35,1.8,3.85),Vector3(0.2,3.6,0.6),Color("f9e3ce"))
	box(Vector3(-4.35,3.15,2.8),Vector3(0.2,0.9,1.5),Color("f9e3ce"))
	var doorway := Node3D.new()
	doorway.name = "OpenDoorway"
	add_child(doorway)
	for z in [2.05,3.55]: box(Vector3(-4.28,1.4,z),Vector3(0.32,2.8,0.12),CREAM,0.025,doorway)
	box(Vector3(-4.28,2.76,2.8),Vector3(0.32,0.15,1.62),CREAM,0.025,doorway)
	for i in 3: box(Vector3(-4.55-i*0.3,-0.07-i*0.22,2.8),Vector3(0.42,0.22,1.6),CREAM,0.025,doorway)
	for x in 18:
		box(Vector3(-4.2+x*0.49,0.62,-3.91), Vector3(0.45,1.12,0.06), MINT, 0.025)
	for z in 16:
		if -3.77+z*0.5 > 1.8 and -3.77+z*0.5 < 3.79: continue
		box(Vector3(-4.21,0.62,-3.77+z*0.5), Vector3(0.06,1.12,0.46), MINT, 0.025)
	box(Vector3(0,1.26,-3.9),Vector3(8.8,0.12,0.13),CREAM)
	box(Vector3(-4.18,1.26,-1.05),Vector3(0.13,0.12,6.2),CREAM)
	box(Vector3(-4.18,1.26,3.88),Vector3(0.13,0.12,0.55),CREAM)
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

	# A separate heated mixing vessel makes this a working candy station.
	var maker := Node3D.new()
	maker.name = "CandyMaker"
	maker.position = Vector3(1.65,0,0)
	station.add_child(maker)
	box(Vector3(0,0.42,0),Vector3(0.82,0.84,0.8),MINT,0.06,maker)
	cylinder(Vector3(0,1.06,0),0.48,0.56,GOLD,0.36,maker)
	ring(Vector3(0,1.35,0),0.49,0.42,CREAM,maker)
	cylinder(Vector3(0,1.32,0),0.41,0.04,PINK,-1,maker)
	rod(Vector3(0,1.31,0),Vector3(0,1.98,0),0.04,COCOA,maker)
	box(Vector3(0,1.97,0),Vector3(0.65,0.13,0.24),CREAM,0.04,maker)
	rod(Vector3(-0.28,1.97,0),Vector3(-0.28,1.28,0),0.035,GOLD,maker)

func _build_display(p: Vector3) -> void:
	var station := _station(p,"Cake oven","Bake celebration cakes, then collect the batch for display.")
	box(Vector3(0,0.85,0),Vector3(1.8,1.7,1.1),PINK,0.10,station)
	box(Vector3(0,0.87,0.58),Vector3(1.48,1.0,0.08),COCOA,0.06,station)
	box(Vector3(0,0.87,0.63),Vector3(1.23,0.74,0.03),Color("d78944"),0.05,station)
	for y in [0.65,0.98]:
		box(Vector3(0,y,0.65),Vector3(1.18,0.025,0.02),GOLD,0.01,station)
	rod(Vector3(-0.52,1.45,0.68),Vector3(0.52,1.45,0.68),0.045,CREAM,station)
	for x in [-0.56,0.56]:
		var dial := cylinder(Vector3(x,1.65,0.59),0.11,0.07,GOLD,-1,station)
		dial.rotation_degrees.x = 90
	box(Vector3(0,1.77,0),Vector3(1.95,0.12,1.22),CREAM,0.05,station)

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
	station_selected.emit(index)
	if not is_instance_valid(status_label): return
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

func set_zoom(value: float) -> void:
	camera.size = clampf(value,MIN_ZOOM,MAX_ZOOM)

func set_pan(value: Vector2) -> void:
	pan_offset = value.clamp(Vector2.ONE*-PAN_LIMIT,Vector2.ONE*PAN_LIMIT)
	camera.position = camera_home+Vector3(pan_offset.x,0,pan_offset.y)

func reset_view() -> void:
	set_pan(Vector2.ZERO)
	set_zoom(16)

func pan_screen(relative: Vector2) -> void:
	var center := Vector2(get_viewport().size)*0.5
	var ground := Plane(Vector3.UP,-0.7)
	var before: Vector3 = ground.intersects_ray(camera.project_ray_origin(center),camera.project_ray_normal(center))
	var after: Vector3 = ground.intersects_ray(camera.project_ray_origin(center+relative),camera.project_ray_normal(center+relative))
	var shift := before-after
	set_pan(pan_offset+Vector2(shift.x,shift.z))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		set_zoom(camera.size / maxf(event.factor,0.01))
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		set_zoom(camera.size + (-0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8))
		return
	if event is InputEventMouseMotion and mouse_down:
		if event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE) == 0:
			mouse_down = false
			return
		drag_distance += event.relative.length()
		if drag_distance > 6: pan_screen(event.relative)
		return
	if event is InputEventScreenDrag and touches.has(event.index):
		drag_distance += event.relative.length()
		if touches.size() == 2:
			var ids := touches.keys()
			var before: float = touches[ids[0]].distance_to(touches[ids[1]])
			touches[event.index] = event.position
			var after: float = touches[ids[0]].distance_to(touches[ids[1]])
			if before > 1 and after > 1: set_zoom(camera.size * before / after)
			pan_screen(event.relative*0.5)
		else:
			touches[event.index] = event.position
			if drag_distance > 6: pan_screen(event.relative)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if touches.is_empty(): drag_distance = 0
			touches[event.index] = event.position
			if touches.size() > 1: pinching = true
			return
		touches.erase(event.index)
		if pinching:
			if touches.is_empty(): pinching = false
			return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
		mouse_down = event.pressed
		if event.pressed:
			drag_distance = 0
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE: return
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and not event.pressed:
		point = event.position
	else: return
	if drag_distance > 6: return
	for i in batch_icons.size():
		if batch_icons[i].visible and point.distance_to(camera.unproject_position(batch_icons[i].global_position)) < 65:
			_select_station(i)
			return
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
	var plate := cylinder(Vector3(-4.12,2.5,-2.83),0.48,0.08,CREAM)
	plate.rotation_degrees.z = 90
	var frame := ring(Vector3(-4.06,2.5,-2.83),0.49,0.44,GOLD)
	frame.rotation_degrees.z = 90
	ball(Vector3(-3.99,2.46,-2.83),Vector3(0.12,0.49,0.39),PINK)
	for i in 3:
		var leaf := ball(Vector3(-3.96,2.72,-2.92+i*0.09),Vector3(0.07,0.14,0.18),MINT)
		leaf.rotation_degrees.x = (i-1)*30
	for i in 3:
		for j in 2:
			ball(Vector3(-3.918,2.35+i*0.10,-2.9+j*0.13),Vector3(0.024,0.036,0.02),GOLD)
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
	for i in display_products.size():
		var stock := CafeProgress.product_stock(i)
		display_products[i].visible = stock > 0
		display_counts[i].text = "%d left" % stock
	for i in batch_icons.size():
		var job := CafeProgress.craft_job(i)
		batch_icons[i].visible = CafeProgress.batch_ready(i)
		batch_icons[i].position.y = 2.8 + sin(time * 2.5) * 0.08
		batch_labels[i].visible = not job.is_empty()
		batch_labels[i].text = "Tap to display ×%d" % int(job.get("quantity", 0)) if batch_icons[i].visible else "%ds" % CafeProgress.craft_seconds_left(i)
	_animate_actors(delta)
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



func _build_actors() -> void:
	_make_actor("Chef Mallow",Color("f6e8ce"),true,[Vector3(-1.45,0.14,-1.7),Vector3(-1.45,0.14,-0.85),Vector3(0,0.14,-0.85),Vector3(0,0.14,-1.73)],0)
	_make_actor("Berry",PINK,false,[],2)
	_make_actor("Mint",MINT,false,[],4)

func _make_actor(actor_name: String, outfit: Color, chef: bool, route: Array, phase: float) -> void:
	for i in route.size(): route[i] *= ROOM_SPREAD
	var actor := Node3D.new()
	actor.name = actor_name.replace(" ","")
	add_child(actor)
	actor.position = route[0] if chef else (Vector3(-6.1,-0.63,-3.5) if phase==2 else Vector3(-6.1,-0.63,-8.5))
	if not chef: actor.position *= ROOM_SPREAD
	actor.scale = Vector3.ONE*1.12
	var skin := Color("ffe0cb")
	var hair := Color("69404b") if chef else (Color("984d68") if actor_name=="Berry" else Color("4b6562"))
	# Soft, short silhouette with an oversized anime head and tiny rounded shoes.
	ball(Vector3(0,0.5,0),Vector3(0.43,0.43,0.30),outfit,actor)
	if not chef: cylinder(Vector3(0,0.38,0),0.26,0.28,outfit,0.17,actor)
	ball(Vector3(0,0.47,0.13),Vector3(0.27,0.32,0.055),CREAM,actor)
	for side in [-1.0,1.0]:
		ball(Vector3(side*0.105,0.04,0.04),Vector3(0.17,0.13,0.22),hair,actor).name = "FootLeft" if side<0 else "FootRight"
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 0.99
	actor.add_child(head)
	ball(Vector3(0,0.055,-0.04),Vector3(0.83,0.77,0.68),hair,head)
	ball(Vector3(0,-0.005,0.08),Vector3(0.76,0.64,0.59),skin,head)
	for side in [-1.0,1.0]:
		var side_name := "Left" if side < 0 else "Right"
		ball(Vector3(side*0.365,-0.025,0.07),Vector3(0.11,0.16,0.12),skin,head)
		var eye := Node3D.new()
		eye.name = "Eye"+side_name
		eye.position = Vector3(side*0.15,0.005,0.347)
		head.add_child(eye)
		ball(Vector3.ZERO,Vector3(0.18,0.23,0.042),Color("55394e"),eye)
		ball(Vector3(0,-0.015,0.023),Vector3(0.128,0.17,0.025),Color("b0789e") if chef else (Color("ca7799") if actor_name=="Berry" else Color("77b8ac")),eye)
		ball(Vector3(0,0.005,0.038),Vector3(0.069,0.13,0.012),COCOA,eye)
		ball(Vector3(-0.035,0.053,0.042),Vector3(0.052,0.063,0.015),Color.WHITE,eye)
		ball(Vector3(0.028,-0.052,0.044),Vector3(0.021,0.025,0.014),CREAM,eye)
		rod(Vector3(side*0.10,0.095,0.358),Vector3(side*0.23,0.09,0.33),0.016,hair,head)
		ball(Vector3(side*0.26,-0.12,0.307),Vector3(0.12,0.053,0.025),Color("efa0ad"),head)
	# Temporary rounded hair restored until custom character models are supplied.
	head.set_meta("hair_style","rounded_placeholder")
	for side in [-1.0,1.0]:
		var lock := ball(Vector3(side*0.33,0.01,0.08),Vector3(0.16,0.50,0.38),hair,head)
		lock.rotation.z = side*-0.13
	for i in 5:
		var fringe := ball(Vector3(-0.27+i*0.135,0.225,0.245),Vector3(0.22,0.34,0.22),hair,head)
		fringe.rotation.z = -0.35+i*0.10
	ball(Vector3(-0.20,0.28,0.32),Vector3(0.14,0.035,0.018),hair.lightened(0.2),head)
	if not chef:
		for side in [-1.0,1.0]:
			ball(Vector3(side*0.4,-0.12,-0.1),Vector3(0.26,0.43,0.29),hair,head)
			ball(Vector3(side*0.36,0.10,0.04),Vector3(0.18,0.12,0.09),outfit.lightened(0.2),head)
	var mouth := Node3D.new()
	mouth.name = "Mouth"
	mouth.position = Vector3(0,-0.16,0.361)
	head.add_child(mouth)
	# A pronounced, closed curved smile. The portrait keeps this geometry still.
	mouth.set_meta("closed_smile",true)
	for i in 10:
		var x0 := -0.075+i*0.015
		var x1 := x0+0.015
		rod(Vector3(x0,6*x0*x0-0.025,0),Vector3(x1,6*x1*x1-0.025,0),0.010,ROSE,mouth)
	if chef:
		cylinder(Vector3(0,0.39,0),0.30,0.13,CREAM,-1,head)
		for x in [-0.19,0.0,0.19]: ball(Vector3(x,0.50,0),Vector3(0.34,0.27,0.35),CREAM,head)
	var limbs: Array[Node3D] = []
	var leg_segments: Array = []
	# Separate leg pivots animate the rounded feet without rigid block joints.
	for side in [-1.0,1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side*0.105,0.28,0)
		actor.add_child(leg)
		for child in actor.get_children():
			if child is MeshInstance3D and child.position.y < 0.3 and signf(child.position.x)==side: child.reparent(leg,true)
		limbs.append(leg)
		leg_segments.append([cylinder(Vector3.ZERO,0.052,1.0,skin,-1,actor),cylinder(Vector3.ZERO,0.048,1.0,skin,-1,actor)])
	for side in [-1.0,1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side*0.205,0.615,0)
		actor.add_child(arm)
		ball(Vector3(0,-0.09,0),Vector3(0.135,0.22,0.14),outfit,arm)
		ball(Vector3(0,-0.22,0),Vector3(0.12,0.14,0.12),skin,arm)
		limbs.append(arm)
	var treat := Node3D.new()
	limbs[3].add_child(treat)
	treat.position = Vector3(0,-0.25,0.10)
	_cupcake(Vector3.ZERO,treat)
	treat.scale = Vector3.ONE*0.65
	treat.visible = false
	actors.append({"node":actor,"route":route,"target":1,"direction":1,"wait":phase,"limbs":limbs,"treat":treat,"phase":phase,"chef":chef,"state":"enter","path_index":0,"cooldown":0.0,"base_y":actor.position.y,"sales":0,"walk_distance":0.0,"speed":0.0,"leg_segments":leg_segments})
	_pose_legs(actors[-1])

func _customer_path(actor: Dictionary) -> Array:
	var counter := Vector3(-1.9 + int(actor.get("product_choice",0))*1.55,0.14,5.5) / ROOM_SPREAD
	var path: Array = [Vector3(-6.1,-0.63,2.8),Vector3(-5.2,-0.372,2.8),Vector3(-4.85,-0.152,2.8),Vector3(-4.52,0.068,2.8),Vector3(-4.05,0.14,2.8),Vector3(-2.4,0.14,3.67),counter]
	if actor.state == "exit":
		path.reverse()
		path.append(Vector3(-6.1,-0.63,12.5))
	for i in path.size(): path[i] *= ROOM_SPREAD
	if actor.state == "exit":
		for i in path.size():
			path[i].z += 0.65
			if path[i].x < -8.5: path[i].x -= 0.65
	return path

func _animate_actors(delta: float) -> void:
	for actor: Dictionary in actors:
		if actor.chef:
			_animate_chef(actor,delta)
		else:
			_animate_customer(actor,delta)
		_pose_legs(actor)
		var head: Node3D = actor.node.get_node("Head")
		var blink := 0.08 if fmod(time+float(actor.phase),4.6)<0.13 else 1.0
		for side in ["Left","Right"]: head.get_node("Eye"+side).scale.y = blink

func _rest_actor(actor: Dictionary, delta: float) -> void:
	actor.speed = move_toward(float(actor.speed),0,delta*3)
	actor.node.position.y = float(actor.base_y)
	for i in 4:
		var limb: Node3D = actor.limbs[i]
		limb.position.z = lerpf(limb.position.z,0,1-exp(-delta*12))
		if i<2: limb.position.y = lerpf(limb.position.y,0.28,1-exp(-delta*12))
		limb.rotation.x = lerpf(limb.rotation.x,-1.1 if i==3 and actor.treat.visible else 0.0,1-exp(-delta*10))

func _walk_actor(actor: Dictionary, destination: Vector3, delta: float) -> bool:
	var node: Node3D = actor.node
	var base := Vector3(node.position.x,float(actor.base_y),node.position.z)
	var difference := destination-base
	if difference.length() < 0.012:
		node.position = destination
		actor.base_y = destination.y
		_rest_actor(actor,delta)
		return true
	var desired_angle := atan2(difference.x,difference.z)
	var turn := absf(wrapf(desired_angle-node.rotation.y,-PI,PI))
	node.rotation.y = lerp_angle(node.rotation.y,desired_angle,1-exp(-delta*12))
	var desired_speed := WALK_SPEED * clampf(1-turn/PI,0.25,1)
	actor.speed = move_toward(float(actor.speed),desired_speed,delta*2.8)
	var next := base.move_toward(destination,float(actor.speed)*delta)
	var moved := next.distance_to(base)
	actor.walk_distance = float(actor.walk_distance)+moved
	actor.base_y = next.y
	# One gait cycle travels two measured foot strokes, independent of frame/time rate.
	var cycle := fmod(float(actor.walk_distance)/(STRIDE_LENGTH*2),1.0)
	node.position = next
	for i in 2:
		var phase := fmod(cycle+i*0.5,1.0)
		var foot_z: float
		var lift := 0.0
		if phase<0.5:
			# Stance: local foot retreats at exactly the actor's ground speed.
			foot_z = STRIDE_LENGTH*0.5-phase*2*STRIDE_LENGTH
		else:
			var swing := (phase-0.5)*2
			foot_z = -STRIDE_LENGTH*0.5+smoothstep(0,1,swing)*STRIDE_LENGTH
			lift = sin(swing*PI)*0.07
		var leg: Node3D = actor.limbs[i]
		leg.position = Vector3((-1 if i==0 else 1)*0.105,0.28+lift,foot_z/1.12)
		leg.rotation.x = 0.0
	for i in [2,3]:
		var target := sin(cycle*TAU+(i-2)*PI)*0.18
		if i==3 and actor.treat.visible: target = -1.1
		actor.limbs[i].rotation.x = target
	return false

func _animate_chef(actor: Dictionary, delta: float) -> void:
	if float(actor.wait)>0:
		actor.wait = maxf(0,float(actor.wait)-delta)
		_rest_actor(actor,delta)
		return
	if _walk_actor(actor,actor.route[int(actor.target)],delta):
		if int(actor.target)==actor.route.size()-1 or int(actor.target)==0:
			actor.direction = -int(actor.direction)
			actor.wait = 2.0
		actor.target = int(actor.target)+int(actor.direction)

func _animate_customer(actor: Dictionary, delta: float) -> void:
	if actor.state == "away":
		actor.cooldown = float(actor.cooldown)-delta
		if float(actor.cooldown)<=0:
			actor.node.position = Vector3(-6.1,-0.63,-17.0) * ROOM_SPREAD
			actor.base_y = -0.63
			actor.node.visible = true
			actor.speed = 0.0
			actor.state = "enter"
			actor.path_index = 0
		return
	if actor.state == "shop":
		var choice := int(actor.get("product_choice", -1))
		if choice < 0 or CafeProgress.product_stock(choice) == 0:
			choice = -1
			for offset in CafeProgress.RECIPES.size():
				var candidate := (int(actor.phase)+int(actor.sales)+offset) % CafeProgress.RECIPES.size()
				if CafeProgress.product_stock(candidate) > 0:
					choice = candidate
					break
			actor.product_choice = choice
		if choice >= 0:
			var destination := Vector3(-1.9 + choice*1.55,0.14,5.5)
			if actor.node.position.distance_to(destination) > 0.04:
				actor.wait = 0.0
				_walk_actor(actor,destination,delta)
				return
		actor.wait = float(actor.wait)+delta
		actor.node.rotation.y = lerp_angle(actor.node.rotation.y,PI,minf(1,delta*5))
		_rest_actor(actor,delta)
		if float(actor.wait)<1.6: return
		for index in ([choice] if choice >= 0 else []):
			var receipt: Dictionary = CafeProgress.purchase(index)
			if receipt.is_empty(): continue
			_set_carried_product(actor.treat,index)
			actor.treat.visible = true
			actor.sales = int(actor.sales)+1
			actor.state = "pickup"
			actor.wait = 0.0
			customer_purchased.emit(receipt)
			return
		if float(actor.wait)>12.0:
			actor.state = "exit"
			actor.path_index = 0
		return
	if actor.state == "pickup":
		actor.wait = float(actor.wait)+delta
		actor.limbs[3].rotation.x = lerpf(actor.limbs[3].rotation.x,-1.1,minf(1,delta*5))
		if float(actor.wait)>1.2:
			actor.state = "exit"
			actor.path_index = 0
		return
	var path := _customer_path(actor)
	if _walk_actor(actor,path[int(actor.path_index)],delta):
		actor.path_index = int(actor.path_index)+1
		if int(actor.path_index)>=path.size():
			if actor.state == "enter":
				actor.state = "shop"
				actor.wait = 0.0
			else:
				actor.node.visible = false
				actor.treat.visible = false
				actor.state = "away"
				actor.cooldown = 5.0+float(actor.phase)

func _build_neighborhood() -> void:
	var neighborhood := Node3D.new()
	neighborhood.name = "Neighborhood"
	add_child(neighborhood)
	var ground := box(Vector3(0,-0.85,0),Vector3(100,0.25,100),Color("bfd4b0"),0.1,neighborhood)
	ground.name = "Ground"
	# A continuous street/sidewalk grid covers the whole visible camera envelope.
	for x in [-8.0,12.0]:
		box(Vector3(x,-0.71,0),Vector3(5.2,0.08,100),Color("e6d2bb"),0.02,neighborhood)
		box(Vector3(x,-0.66,0),Vector3(3,0.04,100),Color("b5aeb7"),0.01,neighborhood)
	for z in [-12.0,8.0,28.0]:
		box(Vector3(0,-0.71,z),Vector3(100,0.08,5.2),Color("e6d2bb"),0.02,neighborhood)
		box(Vector3(0,-0.655,z),Vector3(100,0.04,3),Color("b5aeb7"),0.01,neighborhood)
	for i in range(-16,17):
		for x in [-8.0,12.0]:
			if absf(i*3+12)<2 or absf(i*3-8)<2 or absf(i*3-28)<2: continue
			box(Vector3(x,-0.62,i*3),Vector3(0.07,0.01,1.1),CREAM,0.005,neighborhood)
		for z in [-12.0,8.0,28.0]:
			if absf(i*3+8)<2 or absf(i*3-12)<2: continue
			box(Vector3(i*3,-0.615,z),Vector3(1.1,0.01,0.07),CREAM,0.005,neighborhood)
	box(Vector3(0,-0.69,0),Vector3(11.5,0.1,11.5),Color("e3cdb6"),0.1,neighborhood)
	var serial := 0
	# Different lot sizes and roof profiles avoid a repeated miniature-house grid.
	for z in [-35.0,-26.0,-19.0,-5.0,1.0,17.0,23.0,35.0]:
		for x in [-35.0,-26.0,-18.0,-13.0,-2.0,5.0,18.0,25.0,34.0]:
			if absf(x)<6 and z>-7 and z<6: continue
			# Two park lots remain building-free but are populated below.
			if (x==5 and z==17) or (x==-18 and z==1): continue
			_build_house(Vector3(x,-0.68,z),serial,neighborhood)
			serial += 1
	_build_house(Vector3(-2,-0.68,-7.8),serial,neighborhood)
	_build_house(Vector3(7,-0.68,-3),serial+1,neighborhood)
	var tree_index := 0
	for z in range(-34,38,6):
		for x in range(-33,39,7):
			if absf(x+8)<3 or absf(x-12)<3 or absf(z+12)<3 or absf(z-8)<3 or absf(z-28)<3: continue
			if absf(x)<6 and absf(z)<6: continue
			_tree(Vector3(x+0.6,-0.66,z+1.2),tree_index,neighborhood)
			tree_index += 1
	for p in [Vector3(7,-0.66,2),Vector3(3,-0.66,12),Vector3(-12,-0.66,3),Vector3(18,-0.66,11),Vector3(-2,-0.66,-7),Vector3(7,-0.66,20)]:
		_tree(p,tree_index,neighborhood)
		tree_index += 1
	# Populated little gardens: paths, benches, flower beds and small animals.
	for index in 6:
		var p: Vector3 = [Vector3(5,-0.66,17),Vector3(-18,-0.66,1),Vector3(6,-0.66,-7),Vector3(-12,-0.66,4),Vector3(20,-0.66,-8),Vector3(-3,-0.66,13)][index]
		box(p+Vector3(0,0.01,0),Vector3(3.3,0.08,2.4),Color("d4ddbc"),0.15,neighborhood)
		box(p+Vector3(0,0.48,-0.8),Vector3(1.5,0.12,0.45),Color("bc936e"),0.04,neighborhood)
		box(p+Vector3(0,0.80,-1),Vector3(1.5,0.48,0.1),Color("bc936e"),0.03,neighborhood)
		for x in [-0.6,0.6]: cylinder(p+Vector3(x,0.22,-0.8),0.055,0.45,COCOA,-1,neighborhood)
		_animal(p+Vector3(0.65,0.07,0.45),index,neighborhood)
		for flower in 5:
			var f := p+Vector3(-1.3+flower*0.27,0.1,0.75)
			ball(f,Vector3(0.20,0.16,0.2),MINT,neighborhood)
			ball(f+Vector3(0,0.12,0),Vector3(0.12,0.08,0.12),PINK if index%2==0 else CREAM,neighborhood)

func _build_house(p: Vector3, index: int, parent: Node3D) -> void:
	var home := Node3D.new()
	home.name = "NeighborhoodHouse%d" % index
	home.position = p
	parent.add_child(home)
	var direction := Vector3.ZERO
	var distance := INF
	for road_x in [-8.0,12.0]:
		if absf(road_x-p.x)<distance:
			distance = absf(road_x-p.x)
			direction = Vector3(signf(road_x-p.x),0,0)
	for road_z in [-12.0,8.0,28.0]:
		if absf(road_z-p.z)<distance:
			distance = absf(road_z-p.z)
			direction = Vector3(0,0,signf(road_z-p.z))
	home.rotation.y = atan2(direction.x,direction.z)
	home.set_meta("road_direction",direction)
	var width := 2.5+(index%4)*0.32
	var height := 1.65+(index%3)*0.65
	var depth := 2.25+(index%2)*0.35
	home.set_meta("building_height",height)
	var tint: Color = [Color("d4b8d4"),Color("e9bfac"),Color("a9cec7"),Color("e9d29e"),Color("b4c5df")][index%5]
	box(Vector3(0,height/2,0),Vector3(width,height,depth),tint,0.08,home)
	box(Vector3(0,0.08,0),Vector3(width+0.25,0.16,depth+0.25),CREAM,0.04,home)
	if index%3==0:
		box(Vector3(0,height+0.12,0),Vector3(width+0.3,0.24,depth+0.4),ROSE,0.08,home)
	else:
		_gabled_roof(width+0.4,depth+0.4,height,Color("ba788a") if index%2 else Color("839caa"),home)
	box(Vector3(0,0.66,depth/2+0.03),Vector3(0.62,1.32,0.08),COCOA,0.025,home)
	ball(Vector3(0.19,0.64,depth/2+0.10),Vector3.ONE*0.06,GOLD,home)
	for x in [-width*0.32,width*0.32]:
		for floor_index in (2 if height>2.7 else 1):
			var y := 1.0+floor_index*1.25
			box(Vector3(x,y,depth/2+0.04),Vector3(0.61,0.75,0.11),CREAM,0.025,home)
			box(Vector3(x,y,depth/2+0.11),Vector3(0.45,0.57,0.03),Color("a4d6df"),0.015,home)
			box(Vector3(x,y,depth/2+0.14),Vector3(0.035,0.57,0.015),CREAM,0.005,home)
	if index%4==0:
		box(Vector3(0,1.5,depth/2+0.36),Vector3(width*0.9,0.12,0.85),PINK,0.035,home)
		for j in 4: box(Vector3(-width*0.33+j*width*0.22,1.51,depth/2+0.36),Vector3(width*0.11,0.13,0.85),CREAM,0.015,home)
	# Each entrance has a short path pointing toward its street.
	box(Vector3(0,0.02,depth/2+0.65),Vector3(0.85,0.035,1.15),Color("e6d2bb"),0.04,home)

func _tree(p: Vector3, index: int, parent: Node3D) -> void:
	for child in parent.get_children():
		if child.name.begins_with("NeighborhoodHouse") and Vector2(child.position.x-p.x,child.position.z-p.z).length()<3.1: return
	var tree := Node3D.new()
	tree.name = "Tree%d" % index
	tree.position = p
	parent.add_child(tree)
	var size := 0.7+(index%4)*0.18
	tree.scale = Vector3.ONE*size
	cylinder(Vector3(0,0.65,0),0.10,1.3,Color("aa856a"),-1,tree)
	if index%3==0:
		for i in 3: cylinder(Vector3(0,1.2+i*0.42,0),0.72-i*0.14,0.95,Color("7da99c"),0,tree)
	else:
		var tint := Color("e9b4c1") if index%4==0 else Color("91b887")
		ball(Vector3(0,1.55,0),Vector3(1.6,1.7,1.5),tint,tree)
		ball(Vector3(0.42,1.8,0.10),Vector3(1.1,1.2,1.1),tint.lightened(0.08),tree)

func _animal(p: Vector3, index: int, parent: Node3D) -> void:
	var animal := Node3D.new()
	animal.name = "GardenAnimal%d" % index
	animal.position = p
	animal.rotation.y = PI*0.22
	parent.add_child(animal)
	var tint := CREAM if index%2 else Color("bd977d")
	ball(Vector3(0,0.22,0),Vector3(0.40,0.37,0.62),tint,animal)
	ball(Vector3(0,0.43,0.24),Vector3(0.36,0.35,0.33),tint,animal)
	for side in [-1,1]:
		if index%2:
			ball(Vector3(side*0.09,0.70,0.24),Vector3(0.09,0.36,0.10),tint,animal)
			ball(Vector3(side*0.09,0.70,0.293),Vector3(0.04,0.26,0.015),PINK,animal)
		else: cylinder(Vector3(side*0.12,0.62,0.23),0.095,0.20,tint,0,animal)
		ball(Vector3(side*0.095,0.46,0.39),Vector3.ONE*0.035,COCOA,animal)
		for z in [-0.15,0.2]: ball(Vector3(side*0.13,0.06,z),Vector3(0.12,0.1,0.17),tint,animal)
	ball(Vector3(0,0.40,0.405),Vector3(0.04,0.025,0.02),PINK,animal)
	var tail := ball(Vector3(0,0.28,-0.35),Vector3(0.11,0.13,0.12) if index%2 else Vector3(0.1,0.45,0.1),tint,animal)
	tail.rotation.x = -0.6

func _set_carried_product(treat: Node3D, index: int) -> void:
	for child in treat.get_children():
		treat.remove_child(child)
		child.queue_free()
	match index:
		0:
			ball(Vector3.ZERO,Vector3(0.24,0.16,0.2),GOLD,treat)
			for i in 3: box(Vector3(-0.06+i*0.06,0.07,0),Vector3(0.014,0.014,0.1),CREAM,0.005,treat)
		1, 4:
			cylinder(Vector3.ZERO,0.10,0.18,MINT,0.12,treat)
			cylinder(Vector3(0,0.095,0),0.10,0.015,CREAM,-1,treat)
			var handle := ring(Vector3(0.11,0,0),0.07,0.045,MINT,treat)
			handle.rotation_degrees.x = 90
		2:
			for i in 3: ball(Vector3(-0.06+i*0.06,0,0),Vector3(0.10,0.10,0.10),PINK,treat)
		3:
			cylinder(Vector3.ZERO,0.12,0.18,PINK,-1,treat)
			cylinder(Vector3(0,0.07,0),0.125,0.03,CREAM,-1,treat)
			ball(Vector3(0,0.14,0),Vector3(0.09,0.12,0.09),ROSE,treat)

func _pose_legs(actor: Dictionary) -> void:
	for i in 2:
		var foot: Vector3 = actor.limbs[i].position+Vector3(0,-0.24,0.04)
		var hip := Vector3((-1 if i==0 else 1)*0.105,0.32,0)
		var line := foot-hip
		var bend := Vector3(0,line.z,-line.y).normalized()
		var knee := (hip+foot)*0.5+bend*sqrt(maxf(0,0.205*0.205-line.length_squared()*0.25))
		# Keep the complete knee/shin below the skirt hem (y=.24), including radius.
		# Upper legs stay inside the garment silhouette as they meet the hips.
		knee.y = minf(knee.y,0.16)
		knee.z = clampf(knee.z,-0.13,0.13)
		for j in 2:
			var start: Vector3 = hip if j==0 else knee
			var end: Vector3 = knee if j==0 else foot
			var segment: Node3D = actor.leg_segments[i][j]
			segment.position = (start+end)*0.5
			segment.quaternion = Quaternion(Vector3.UP,(end-start).normalized())
			segment.scale = Vector3(1,start.distance_to(end),1)

func _gabled_roof(width: float, depth: float, y: float, color: Color, parent: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [Vector3(-width/2,y,-depth/2),Vector3(width/2,y,-depth/2),Vector3(0,y+0.8,-depth/2),Vector3(-width/2,y,depth/2),Vector3(width/2,y,depth/2),Vector3(0,y+0.8,depth/2)]
	for face in [[0,1,2],[3,5,4],[0,2,5],[0,5,3],[2,1,4],[2,4,5],[0,3,4],[0,4,1]]:
		for index in face: surface.add_vertex(points[index])
	surface.generate_normals()
	mesh_at(surface.commit(),Vector3.ZERO,color,parent)

func _build_tea_machine() -> void:
	var station := _station(Vector3(4.0,0,-4.1),"Tea brewer","Brew honey mint tea, then collect the batch for display.")
	station.name = "TeaBrewer"
	_cabinet(station,1.6,MINT)
	cylinder(Vector3(0,1.8,0),0.4,0.85,CREAM,-1,station)
	ring(Vector3(0,2.23,0),0.43,0.35,GOLD,station)
	cylinder(Vector3(0,2.25,0),0.42,0.07,MINT,-1,station)
	ball(Vector3(0,2.34,0),Vector3.ONE*0.13,GOLD,station)
	rod(Vector3(0,1.68,0.35),Vector3(0,1.68,0.58),0.065,GOLD,station)
	rod(Vector3(0,1.68,0.58),Vector3(0,1.52,0.58),0.065,GOLD,station)
	_cup(Vector3(0,1.4,0.56),station)

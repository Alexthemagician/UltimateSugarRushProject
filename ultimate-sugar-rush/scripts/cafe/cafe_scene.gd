extends Node3D

signal station_selected(index: int)
signal customer_purchased(receipt: Dictionary)
signal customer_selected(customer: Dictionary)
signal object_actions_requested(entry: Dictionary)
signal object_moved(entry: Dictionary)
var actors: Array[Dictionary] = []
var visiting := false
var visit_layout: Dictionary = {}
var cafe_display_name := ""

const CREAM = Color("fff0d5")
const PINK = Color("e96c8c")
const ROSE = Color("b74765")
const MINT = Color("63b9a7")
const GOLD = Color("dba451")
const COCOA = Color("63414a")
const MIN_ZOOM := 10.5
const MAX_ZOOM := 22.0
const PAN_LIMIT := 18.0
const WALK_SPEED := 0.72
const STRIDE_LENGTH := 0.40
const CUSTOMER_PATIENCE_SECONDS := 12.0
const PLACEMENT_GRID_SIZE := 0.5
const PLACEABLE_PLOT_LIMIT := 25.5
const MOVABLE_PICK_LAYER := 128
const CAFE_ORIGIN := Vector3(-18.5,0,-18.5)
const NAV_CELL_SIZE := 0.38
const NAV_LOCAL_MIN := Vector2(-6.7,-6.2)
const NAV_LOCAL_MAX := Vector2(6.7,6.2)
const CUSTOMER_RADIUS := 0.30
const CUSTOMER_EAT_SECONDS := 4.0
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
var movable_objects: Array[Dictionary] = []
var pickup_counter: Node3D
var cupcake_counter: Node3D
var hold_target: Dictionary = {}
var hold_elapsed := 0.0
var hold_triggered := false
var hold_point := Vector2.ZERO
var placement_target: Dictionary = {}
var placement_marker: Node3D
var placement_origin := Vector3.ZERO
var placement_valid := true
var placement_footprint_material: StandardMaterial3D
var placement_pointer_offset := Vector2.ZERO
var navigation_revision := 0
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

func _cafe_name() -> String:
	if visiting and not cafe_display_name.strip_edges().is_empty(): return cafe_display_name.strip_edges()
	return str(SaveSystem.get_value("cafe_profile","name","Sugar & Sunshine")).strip_edges()

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
	_build_pickup_counter(Vector3(2.5,0,-2.67))
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
	if not visiting:
		_build_actors()
		_build_batch_indicators()
	else:
		for product in display_products: product.visible = false
		for count in display_counts: count.visible = false
	_move_cafe_to_plot_corner()
	_setup_movable_objects()
	_restore_purchased_items()
	_refresh_upgrades()
	if not visiting: CafeLife.life_changed.connect(_refresh_upgrades)
	_apply_decor_theme()
	if not visiting: CafeLife.life_changed.connect(_apply_decor_theme)

func _move_cafe_to_plot_corner() -> void:
	for child in get_children():
		if not child is Node3D or child == camera or child.name == "Neighborhood" or child is DirectionalLight3D: continue
		child.position += CAFE_ORIGIN
	for actor: Dictionary in actors:
		actor.base_y = actor.node.position.y
		if actor.chef:
			for i in actor.route.size(): actor.route[i] += CAFE_ORIGIN
	camera_home = Vector3(12,13,16)+CAFE_ORIGIN
	camera.position = camera_home
	camera.look_at(CAFE_ORIGIN+Vector3(0,0.7,0))

func _apply_decor_theme() -> void:
	var finish_id := str(visit_layout.get("display_style","rose")) if visiting else CafeLife.display_style()
	var finish: Dictionary = CafeLife.DISPLAY_STYLES[finish_id]
	for index in 5:
		for mesh in get_node("ProductDisplay%d" % index).get_children():
			if mesh is MeshInstance3D and mesh.has_meta("display_finish"):
				mesh.material_override = mat(Color(finish[mesh.get_meta("display_finish")]))
	if has_node("CafeTable"):
		var saved_table: Array = SaveSystem.get_value("cafe_layout","cafe_table",[])
		var point := (Vector2(float(visit_layout.table_position[0]),float(visit_layout.table_position[1]))+Vector2(CAFE_ORIGIN.x,CAFE_ORIGIN.z)) if visiting else (Vector2(float(saved_table[0]),float(saved_table[1])) if saved_table.size()==2 else CafeLife.table_position()+Vector2(CAFE_ORIGIN.x,CAFE_ORIGIN.z))
		get_node("CafeTable").position = Vector3(point.x,0,point.y)
	var theme: Dictionary = CafeLife.DECOR_THEMES[str(visit_layout.theme) if visiting else CafeLife.decor_theme()]
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("decor_surface"):
			child.material_override = mat(Color(theme[child.get_meta("decor_surface")]))

func _has_upgrade(id: String) -> bool:
	return bool(visit_layout.get("upgrades",{}).get(id,false)) if visiting else CafeLife.has_upgrade(id)

func _refresh_upgrades() -> void:
	if _has_upgrade("display"):
		for index in 5:
			var display := get_node("ProductDisplay%d" % index)
			if display.has_node("ShowcaseUpgrade"): continue
			var upgrade := Node3D.new()
			upgrade.name = "ShowcaseUpgrade"
			display.add_child(upgrade)
			# Keep the premium trim around the open counter instead of rebuilding
			# the old overhead cover that hid products from the gameplay camera.
			box(Vector3(0,1.035,0),Vector3(1.27,0.035,0.68),GOLD,0.01,upgrade)
			var glow := OmniLight3D.new()
			glow.position = Vector3(0,1.32,0)
			glow.light_color = Color("ffe4a0")
			glow.light_energy = 0.45
			glow.omni_range = 1.0
			upgrade.add_child(glow)
	if _has_upgrade("garden") and not has_node("GardenUpgrade"):
		var garden := Node3D.new()
		garden.name = "GardenUpgrade"
		garden.position = CAFE_ORIGIN+Vector3(-5.7,-0.2,6.1)
		garden.set_meta("movable_decor",true)
		garden.set_meta("display_name","Flower garden")
		garden.set_meta("placement_radius",1.0)
		add_child(garden)
		box(Vector3.ZERO,Vector3(1.6,0.45,0.65),CREAM,0.08,garden)
		for i in 5:
			var flower := Vector3(-0.6+i*0.3,0.6,0)
			rod(Vector3(flower.x,0.15,0),flower,0.025,MINT,garden)
			for petal in 5:
				var angle := petal*TAU/5
				ball(flower+Vector3(cos(angle)*0.12,sin(angle)*0.12,0),Vector3.ONE*0.17,PINK,garden)
			ball(flower,Vector3.ONE*0.13,GOLD,garden)
		if not visiting: _register_movable(garden,"garden_upgrade","Flower garden",1.0)
	if _has_upgrade("seating") and not has_meta("seating_upgrade"):
		set_meta("seating_upgrade",true)
		_table(CAFE_ORIGIN+Vector3(6.6,-0.65,0),4)
		if not visiting and has_node("TerraceTable"): _register_movable(get_node("TerraceTable"),"terrace_table","Terrace table",1.1)
	if _has_upgrade("oven"):
		for index in [0,3]:
			var station: Node3D = stations[index].node
			if station.has_node("UpgradeBadge"): continue
			var badge := ball(Vector3(0.65,1.5,0.72),Vector3(0.18,0.18,0.04),GOLD,station)
			badge.name = "UpgradeBadge"

func _build_product_displays() -> void:
	for i in CafeProgress.RECIPES.size():
		var display: Node3D
		if i >= 5:
			display = get_node("ProductDisplay%d" % CafeProgress.machine_for_recipe(i))
		else:
			display = Node3D.new()
			display.name = "ProductDisplay%d" % i
			display.position = Vector3(-1.9 + CafeProgress.machine_for_recipe(i) * 1.55, 0, 4.6)
			add_child(display)
			box(Vector3(0,0.48,0),Vector3(1.35,0.96,0.8),PINK,0.06,display).set_meta("display_finish","body")
			box(Vector3(0,1.0,0),Vector3(1.45,0.12,0.9),CREAM,0.04,display).set_meta("display_finish","top")
		var products := Node3D.new()
		products.position = Vector3(-0.34 if i < 5 else 0.34,1.18,0)
		products.scale = Vector3.ONE * 1.65
		display.add_child(products)
		_set_carried_product(products,i)
		display_products.append(products)
		var count := Label3D.new()
		count.position = Vector3(-0.34 if i < 5 else 0.34,0.7,0.44)
		count.font_size = 40
		count.pixel_size = 0.004
		display.add_child(count)
		display_counts.append(count)

func _build_pickup_counter(p: Vector3) -> void:
	pickup_counter = Node3D.new()
	pickup_counter.name = "OrderPickupCounter"
	pickup_counter.position = p
	add_child(pickup_counter)
	box(Vector3(0,0.62,0),Vector3(4.15,1.24,0.78),MINT,0.10,pickup_counter)
	box(Vector3(0,1.28,0),Vector3(4.35,0.14,0.96),CREAM,0.05,pickup_counter)
	box(Vector3(0,1.57,0.43),Vector3(2.65,0.48,0.08),ROSE,0.04,pickup_counter)
	label3("ORDER PICKUP",Vector3(0,1.58,0.485),27,CREAM,pickup_counter)
	for x in [-1.35,0.0,1.35]:
		_cupcake(Vector3(x,1.36,0.04),pickup_counter)

func _register_movable(node: Node3D, id: String, display_name: String, radius: float) -> void:
	if not is_instance_valid(node): return
	if movable_objects.any(func(entry: Dictionary) -> bool: return str(entry.id)==id): return
	node.set_meta("movable_id",id)
	node.set_meta("movable_name",display_name)
	var saved: Array = SaveSystem.get_value("cafe_layout",id,[])
	if saved.size() == 2:
		var migrated := Vector2(float(saved[0]),float(saved[1]))
		if int(SaveSystem.get_value("cafe_layout","position_version",1))<2:
			migrated += Vector2(CAFE_ORIGIN.x,CAFE_ORIGIN.z)
			SaveSystem.set_value("cafe_layout",id,[migrated.x,migrated.y])
		node.position.x = snappedf(clampf(migrated.x,-PLACEABLE_PLOT_LIMIT,PLACEABLE_PLOT_LIMIT),PLACEMENT_GRID_SIZE)
		node.position.z = snappedf(clampf(migrated.y,-PLACEABLE_PLOT_LIMIT,PLACEABLE_PLOT_LIMIT),PLACEMENT_GRID_SIZE)
	var rotation_steps := int(SaveSystem.get_value("cafe_layout",id+"_rotation",0))%4
	node.rotation.y = rotation_steps*PI/2.0
	node.visible = not bool(SaveSystem.get_value("cafe_item_storage",id,false))
	var pick_area := Area3D.new()
	pick_area.name = "MovePickArea"
	pick_area.collision_layer = 0 if not node.visible else MOVABLE_PICK_LAYER
	pick_area.collision_mask = 0
	pick_area.monitoring = false
	pick_area.set_meta("movable_id",id)
	node.add_child(pick_area)
	_add_precise_pick_shapes(node,pick_area)
	var item_info := _item_information(id,display_name)
	movable_objects.append({"node":node,"id":id,"name":display_name,"radius":radius,"bounds":_movable_visual_bounds(node),"description":item_info.description,"value":item_info.value})

func _add_precise_pick_shapes(node: Node3D, pick_area: Area3D) -> void:
	# Fit each visible mesh independently. A single combined AABB selects empty
	# gaps between legs, shelves, and neighboring counter pieces.
	var node_inverse := node.global_transform.affine_inverse()
	for descendant in node.find_children("*","MeshInstance3D",true,false):
		var mesh_instance := descendant as MeshInstance3D
		if not is_instance_valid(mesh_instance.mesh): continue
		var bounds := mesh_instance.get_aabb()
		if bounds.size.length_squared()<0.0001: continue
		var local_transform: Transform3D = node_inverse*mesh_instance.global_transform
		var pick_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = bounds.size.max(Vector3(0.08,0.08,0.08))
		pick_shape.shape = box_shape
		pick_shape.transform = local_transform*Transform3D(Basis.IDENTITY,bounds.get_center())
		pick_area.add_child(pick_shape)
	if pick_area.get_child_count()==0:
		var fallback := CollisionShape3D.new()
		var fallback_shape := BoxShape3D.new()
		fallback_shape.size = Vector3(0.18,0.18,0.18)
		fallback.shape = fallback_shape
		fallback.position = Vector3(0,0.09,0)
		pick_area.add_child(fallback)

func _setup_movable_objects() -> void:
	if visiting: return
	for i in stations.size():
		_register_movable(stations[i].node,"station_%d" % i,str(stations[i].name),1.45)
	for i in 5:
		_register_movable(get_node("ProductDisplay%d" % i),"display_%d" % i,"%s display" % ["Bakery","Coffee","Candy","Cake","Tea"][i],0.9)
	_register_movable(pickup_counter,"pickup_counter","Order pickup counter",1.5)
	if has_node("CafeTable"): _register_movable(get_node("CafeTable"),"cafe_table","Café table",1.1)
	for child in get_children():
		if child is Node3D and child.name.begins_with("CafePlant"):
			_register_movable(child,str(child.name).to_snake_case(),"Potted plant",0.65)
		elif child is Node3D and child.has_meta("movable_decor"):
			_register_movable(child,str(child.name).to_snake_case(),str(child.get_meta("display_name",child.name)),float(child.get_meta("placement_radius",0.8)))
	SaveSystem.set_value("cafe_layout","position_version",2)
	SaveSystem.save_now()

func _movable_visual_bounds(node: Node3D) -> AABB:
	var result := AABB(Vector3(-0.1,0,-0.1),Vector3(0.2,0.2,0.2))
	var found := false
	var inverse := node.global_transform.affine_inverse()
	for descendant in node.find_children("*","MeshInstance3D",true,false):
		var mesh_instance := descendant as MeshInstance3D
		if not is_instance_valid(mesh_instance.mesh): continue
		var local_transform: Transform3D = inverse*mesh_instance.global_transform
		var bounds: AABB = local_transform*mesh_instance.get_aabb()
		result = bounds if not found else result.merge(bounds)
		found = true
	return result

func _item_information(id: String, display_name: String) -> Dictionary:
	if id.begins_with("station_"): return {"description":"A working café station for crafting fresh treats.","value":650}
	if id.begins_with("display_"): return {"description":"A showcase where customers can browse finished treats.","value":420}
	match id:
		"pickup_counter": return {"description":"A cheerful counter where regulars collect their orders.","value":520}
		"cupcake_counter": return {"description":"A little tiered counter filled with tiny cupcakes and buns.","value":280}
		"cafe_table": return {"description":"A cozy café table with seating for visiting guests.","value":220}
	return {"description":"A decorative %s for your café." % display_name.to_lower(),"value":140}

func rotate_object(entry: Dictionary) -> void:
	if entry.is_empty() or not is_instance_valid(entry.node): return
	var steps := (int(round(entry.node.rotation.y/(PI/2.0)))+1)%4
	entry.node.rotation.y = steps*PI/2.0
	navigation_revision += 1
	SaveSystem.set_value("cafe_layout",str(entry.id)+"_rotation",steps)
	SaveSystem.save_now()

func store_object(entry: Dictionary) -> void:
	if entry.is_empty() or not is_instance_valid(entry.node): return
	entry.node.visible = false
	if entry.node.has_node("MovePickArea"):
		entry.node.get_node("MovePickArea").collision_layer = 0
	SaveSystem.set_value("cafe_item_storage",str(entry.id),true)
	SaveSystem.save_now()
	navigation_revision += 1

func restore_object(entry: Dictionary) -> void:
	if entry.is_empty() or not is_instance_valid(entry.node): return
	entry.node.visible = true
	if entry.node.has_node("MovePickArea"):
		entry.node.get_node("MovePickArea").collision_layer = MOVABLE_PICK_LAYER
	SaveSystem.set_value("cafe_item_storage",str(entry.id),false)
	SaveSystem.save_now()
	navigation_revision += 1

func stored_items() -> Array:
	return movable_objects.filter(func(entry: Dictionary) -> bool: return bool(SaveSystem.get_value("cafe_item_storage",str(entry.id),false)))

func crafting_station_count(machine: int) -> int:
	var count := 0
	for entry: Dictionary in movable_objects:
		if not is_instance_valid(entry.node) or not entry.node.visible: continue
		var id := str(entry.id)
		if id == "station_%d" % machine or id.begins_with("purchased_station_%d_" % machine): count += 1
	return count

func shop_templates() -> Array:
	var wanted := ["cupcake_counter","cafe_table","station_0"]
	return movable_objects.filter(func(entry: Dictionary) -> bool: return str(entry.id) in wanted or str(entry.id).begins_with("cafe_plant"))

func purchase_item(template: Dictionary) -> Dictionary:
	var cost := int(template.get("value",0))
	var stats: Dictionary = GameDatabase.get_player_stats()
	if int(stats.get("coins",0))<cost: return {}
	stats.coins = int(stats.coins)-cost
	GameDatabase.upsert_record(&"player_stats",stats)
	var records: Array = SaveSystem.get_value("cafe_purchases","items",[])
	var serial := int(SaveSystem.get_value("cafe_purchases","serial",0))+1
	var id := "purchased_%s_%d" % [str(template.id),serial]
	records.append({"id":id,"template":str(template.id)})
	SaveSystem.set_value("cafe_purchases","serial",serial)
	SaveSystem.set_value("cafe_purchases","items",records)
	SaveSystem.set_value("cafe_item_storage",id,true)
	var entry := _create_purchased_item(template,id)
	SaveSystem.save_now()
	return entry

func _restore_purchased_items() -> void:
	var records: Array = SaveSystem.get_value("cafe_purchases","items",[])
	for record in records:
		var matches := movable_objects.filter(func(entry: Dictionary) -> bool: return str(entry.id)==str(record.get("template","")))
		if not matches.is_empty(): _create_purchased_item(matches[0],str(record.get("id","")))

func _create_purchased_item(template: Dictionary, id: String) -> Dictionary:
	if id.is_empty(): return {}
	var existing := movable_objects.filter(func(entry: Dictionary) -> bool: return str(entry.id)==id)
	if not existing.is_empty(): return existing[0]
	var copy: Node3D = template.node.duplicate()
	copy.name = id.to_pascal_case()
	if copy.has_node("MovePickArea"):
		var old_pick := copy.get_node("MovePickArea")
		copy.remove_child(old_pick)
		old_pick.free()
	copy.position = CAFE_ORIGIN+Vector3(9,0,9)
	copy.rotation = Vector3.ZERO
	copy.visible = false
	add_child(copy)
	_register_movable(copy,id,str(template.name),float(template.radius))
	var entry: Dictionary = movable_objects[-1]
	entry.description = str(template.description)
	entry.value = int(template.value)
	return entry

func _build_batch_indicators() -> void:
	var atlas := load("res://assets/cafe/stock_atlas.png") as Texture2D
	for i in CafeProgress.RECIPES.size():
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		var cell := Vector2(atlas.get_width() / 6.0, atlas.get_height() / 4.0)
		var icon_index := int(CafeProgress.RECIPES[i].icon)
		texture.region = Rect2(Vector2(icon_index%6, icon_index/6) * cell, cell)
		var marker := Sprite3D.new()
		marker.name = "CollectBatch%d" % i
		marker.texture = texture
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.pixel_size = 0.003
		marker.no_depth_test = true
		marker.position = stations[CafeProgress.machine_for_recipe(i)].node.position + Vector3(0, 2.8, 0)
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
			box(Vector3(-4.02+x*0.73,0.06,-3.66+z*0.73), Vector3(0.718,0.10,0.718), Color("f8e9d1") if (x+z)%2 == 0 else Color("e6b6aa"), 0.02).set_meta("decor_surface", "floor_a" if (x+z)%2==0 else "floor_b")
	box(Vector3(0,1.8,-4.05), Vector3(8.9,3.6,0.2), Color("f7ddc6")).set_meta("decor_surface","wall")
	# Real opening: z 2.05..3.55, floor to lintel at y 2.7.
	box(Vector3(-4.35,1.8,-1.05),Vector3(0.2,3.6,6.2),Color("f9e3ce")).set_meta("decor_surface","wall")
	box(Vector3(-4.35,1.8,3.85),Vector3(0.2,3.6,0.6),Color("f9e3ce")).set_meta("decor_surface","wall")
	box(Vector3(-4.35,3.15,2.8),Vector3(0.2,0.9,1.5),Color("f9e3ce")).set_meta("decor_surface","wall")
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
	var cafe_sign := _decor_root("CafeNameSign",Vector3(-0.9,0,-3.88),"Café name sign",1.55)
	box(Vector3(0,2.75,0),Vector3(3.0,0.72,0.14),ROSE,0.06,cafe_sign)
	var wall_sign := label3(_cafe_name().to_upper(),Vector3(0,2.77,0.085),36 if _cafe_name().length()>20 else 48,CREAM,cafe_sign)
	wall_sign.name = "CafeWallSign"
	label3("BAKED WITH A LITTLE MAGIC",Vector3(0,2.51,0.09),18,CREAM,cafe_sign)
	var menu_board := _decor_root("TreatMenuBoard",Vector3(2.35,0,-3.85),"Treat menu board",0.9)
	box(Vector3(0,2.38,0),Vector3(1.4,1.7,0.15),GOLD,0.06,menu_board)
	box(Vector3(0,2.38,0.10),Vector3(1.25,1.55,0.06),COCOA,0.06,menu_board)
	label3("TODAY'S TREATS\n\nBerry cloud cake\nHoney butter bun\nRose milk latte\n\nMade with love",Vector3(0,2.42,0.14),24,CREAM,menu_board)
	# Left wall window, face into the room.
	box(Vector3(-4.19,2.35,0.5),Vector3(0.12,1.8,2.65),GOLD)
	box(Vector3(-4.10,2.35,0.5),Vector3(0.08,1.63,2.49),Color("bfe8e3"))
	for z in [-0.73,0.5,1.73]: box(Vector3(-4.02,2.35,z),Vector3(0.1,1.72,0.08),CREAM)
	box(Vector3(-4.02,2.35,0.5),Vector3(0.1,0.08,2.55),CREAM)
	box(Vector3(-3.98,1.43,0.5),Vector3(0.47,0.13,2.9),CREAM)
	for x in [-2.6,0.5,3.05]:
		var pendant := _decor_root("PendantLight%d" % int((x+3)*10),Vector3(x,0,-1.75),"Pendant light",0.45)
		rod(Vector3(0,4.3,0),Vector3(0,3.63,0),0.025,GOLD,pendant)
		cylinder(Vector3(0,3.5,0),0.38,0.28,PINK,0.16,pendant)
		cylinder(Vector3(0,3.37,0),0.34,0.035,CREAM,-1,pendant)

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
		var puff := ball(Vector3(-0.68,1.83+i*0.11,0.38),Vector3.ONE*(0.06+i*0.016),CREAM,station)
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

func _table(p: Vector3, chair_count := 2) -> void:
	var previous := get_children()
	var seat_offsets: Array[Vector3] = []
	cylinder(p+Vector3(0,0.87,0),0.64,0.12,CREAM)
	cylinder(p+Vector3(0,0.44,0),0.075,0.8,GOLD)
	cylinder(p+Vector3(0,0.13,0),0.35,0.05,GOLD)
	_cup(p+Vector3(0.17,0.94,0.15),self)
	cylinder(p+Vector3(-0.16,1.06,-0.12),0.10,0.23,PINK)
	for i in 3:
		var end := p+Vector3(-0.2+i*0.05,1.39,-0.12)
		rod(p+Vector3(-0.16,1.13,-0.12),end,0.013,MINT)
		ball(end,Vector3.ONE*0.12,PINK)
	var chair_positions: Array[Vector3] = [Vector3(0,0,-0.87),Vector3(0,0,0.87)]
	if chair_count>=4: chair_positions.append_array([Vector3(-0.87,0,0),Vector3(0.87,0,0)])
	for chair_position in chair_positions:
		seat_offsets.append(chair_position+Vector3(0,0.14,0))
		cylinder(p+chair_position+Vector3(0,0.52,0),0.3,0.13,MINT)
		for x in [-0.19,0.19]:
			for dz in [-0.15,0.15]: rod(p+chair_position+Vector3(x,0.1,dz),p+chair_position+Vector3(x,0.47,dz),0.028,GOLD)
	var furniture := Node3D.new()
	furniture.name = "CafeTable" if not has_node("CafeTable") else "TerraceTable"
	furniture.set_meta("seat_count",seat_offsets.size())
	furniture.set_meta("seat_offsets",seat_offsets)
	add_child(furniture)
	furniture.position = p
	for child in get_children():
		if child is Node3D and child not in previous and child != furniture:
			child.reparent(furniture,true)

func _plant(p: Vector3) -> void:
	var plant := Node3D.new()
	plant.name = "CafePlant%d" % get_children().filter(func(child: Node) -> bool: return child.name.begins_with("CafePlant")).size()
	plant.position = p
	add_child(plant)
	cylinder(Vector3(0,0.28,0),0.23,0.43,CREAM,0.32,plant)
	ring(Vector3(0,0.5,0),0.34,0.28,GOLD,plant)
	for i in 8:
		var angle := i*TAU/8
		var leaf := ball(Vector3(cos(angle)*0.19,0.73+(i%3)*0.12,sin(angle)*0.19),Vector3(0.18,0.65,0.18),MINT.darkened((i%3)*0.08),plant)
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
	title.name = "CafeTitle"
	title.text = _cafe_name()
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
	if visiting: return
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

func _nearest_movable(point: Vector2) -> Dictionary:
	# Use a real 3D ray first. This resolves overlapping screen silhouettes by
	# depth and selects only the object's own footprint instead of a broad radius.
	var origin := camera.project_ray_origin(point)
	var ray := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(point)*200.0,MOVABLE_PICK_LAYER)
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var collider: Object = hit.collider
		if collider.has_meta("movable_id"):
			var id := str(collider.get_meta("movable_id"))
			for entry: Dictionary in movable_objects:
				if str(entry.id)==id: return entry
	# The fallback is footprint-scaled for the first frame before physics sync.
	var closest: Dictionary = {}
	var best := 1.0
	for entry: Dictionary in movable_objects:
		var node: Node3D = entry.node
		if not is_instance_valid(node) or not node.visible: continue
		var screen := camera.unproject_position(node.global_position+Vector3(0,1.0,0))
		var edge := camera.unproject_position(node.global_position+Vector3(float(entry.radius),1.0,0))
		var screen_radius := maxf(18.0,screen.distance_to(edge))
		var distance := point.distance_to(screen)/screen_radius
		if distance < best:
			best = distance
			closest = entry
	return closest

func begin_object_placement(entry: Dictionary, pointer_screen: Variant = null) -> void:
	if visiting or entry.is_empty() or not is_instance_valid(entry.get("node")): return
	placement_target = entry
	placement_origin = entry.node.position
	placement_valid = true
	placement_pointer_offset = Vector2.ZERO
	if pointer_screen is Vector2:
		var ground := Plane(Vector3.UP,0.0)
		var hit = ground.intersects_ray(camera.project_ray_origin(pointer_screen),camera.project_ray_normal(pointer_screen))
		if hit != null:
			placement_pointer_offset = Vector2(entry.node.position.x-float(hit.x),entry.node.position.z-float(hit.z))
	_show_placement_marker()

func cancel_object_placement() -> void:
	if not placement_target.is_empty() and is_instance_valid(placement_target.get("node")):
		placement_target.node.position = placement_origin
		navigation_revision += 1
	placement_target = {}
	placement_pointer_offset = Vector2.ZERO
	if is_instance_valid(placement_marker): placement_marker.queue_free()

func _show_placement_marker() -> void:
	if is_instance_valid(placement_marker): placement_marker.queue_free()
	placement_marker = Node3D.new()
	placement_marker.name = "MovePositionIndicator"
	add_child(placement_marker)
	var radius := float(placement_target.get("radius",1.0))
	var footprint := MeshInstance3D.new()
	var footprint_mesh := BoxMesh.new()
	footprint_mesh.size = Vector3(radius*2.0,0.035,radius*2.0)
	footprint.mesh = footprint_mesh
	placement_footprint_material = StandardMaterial3D.new()
	placement_footprint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	placement_footprint_material.albedo_color = Color(0.38,0.82,0.61,0.38)
	placement_footprint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	footprint.material_override = placement_footprint_material
	footprint.position.y = 0.035
	placement_marker.add_child(footprint)
	var arrows := Label3D.new()
	arrows.name = "FourWayArrow"
	arrows.text = "     ^\n<  MOVE  >\n     v"
	arrows.font_size = 42
	arrows.pixel_size = 0.006
	arrows.modulate = CREAM
	arrows.outline_modulate = ROSE
	arrows.outline_size = 10
	arrows.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrows.no_depth_test = true
	arrows.position.y = 2.5
	placement_marker.add_child(arrows)
	placement_marker.position = Vector3(placement_target.node.position.x,0,placement_target.node.position.z)

func _position_is_open(node: Node3D, destination: Vector3) -> bool:
	var radius := float(placement_target.get("radius",1.0))
	if absf(destination.x)+radius>PLACEABLE_PLOT_LIMIT or absf(destination.z)+radius>PLACEABLE_PLOT_LIMIT:
		return false
	for entry: Dictionary in movable_objects:
		if entry.node == node: continue
		var other: Node3D = entry.node
		var minimum := float(entry.radius)+float(placement_target.radius)
		if Vector2(other.position.x-destination.x,other.position.z-destination.z).length()<minimum:
			return false
	return true

func preview_object_at_screen(point: Vector2) -> bool:
	if placement_target.is_empty(): return false
	var ground := Plane(Vector3.UP,0.0)
	var hit = ground.intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
	if hit == null: return false
	var node: Node3D = placement_target.node
	# Every placeable object shares the same world-space grid, independent of
	# the direction it approaches furniture or the camera angle.
	var destination := Vector3(snappedf(float(hit.x)+placement_pointer_offset.x,PLACEMENT_GRID_SIZE),node.position.y,snappedf(float(hit.z)+placement_pointer_offset.y,PLACEMENT_GRID_SIZE))
	node.position = destination
	navigation_revision += 1
	if is_instance_valid(placement_marker): placement_marker.position = Vector3(destination.x,0,destination.z)
	placement_valid = _position_is_open(node,destination)
	if is_instance_valid(placement_footprint_material):
		placement_footprint_material.albedo_color = Color(0.38,0.82,0.61,0.38) if placement_valid else Color(0.93,0.28,0.38,0.42)
	return placement_valid

func finish_object_placement() -> bool:
	if placement_target.is_empty(): return false
	var entry := placement_target
	var node: Node3D = entry.node
	if not placement_valid:
		node.position = placement_origin
		navigation_revision += 1
		placement_target = {}
		placement_pointer_offset = Vector2.ZERO
		if is_instance_valid(placement_marker): placement_marker.queue_free()
		return false
	SaveSystem.set_value("cafe_layout",str(entry.id),[node.position.x,node.position.z])
	SaveSystem.save_now()
	navigation_revision += 1
	placement_target = {}
	placement_pointer_offset = Vector2.ZERO
	if is_instance_valid(placement_marker): placement_marker.queue_free()
	object_moved.emit(entry)
	return true

func _place_object_at_screen(point: Vector2) -> bool:
	preview_object_at_screen(point)
	return finish_object_placement()

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
		if not placement_target.is_empty():
			preview_object_at_screen(event.position)
			return
		drag_distance += event.relative.length()
		if drag_distance > 6:
			hold_target = {}
			pan_screen(event.relative)
		return
	if event is InputEventScreenDrag and touches.has(event.index):
		if not placement_target.is_empty():
			preview_object_at_screen(event.position)
			return
		drag_distance += event.relative.length()
		if drag_distance > 6: hold_target = {}
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
			if touches.size() == 1:
				hold_point = event.position
				hold_target = _nearest_movable(event.position)
				hold_elapsed = 0.0
				hold_triggered = false
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
			if event.button_index == MOUSE_BUTTON_LEFT:
				hold_point = event.position
				hold_target = _nearest_movable(event.position)
				hold_elapsed = 0.0
				hold_triggered = false
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE: return
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and not event.pressed:
		point = event.position
	else: return
	if hold_triggered:
		if not placement_target.is_empty(): finish_object_placement()
		hold_target = {}
		return
	hold_target = {}
	if drag_distance > 6: return
	if not placement_target.is_empty(): return
	var selected_customer: Dictionary = {}
	var customer_distance := 95.0
	for actor: Dictionary in actors:
		if actor.chef or not actor.node.visible or actor.state in ["away","exit"]: continue
		var customer_screen := camera.unproject_position(actor.node.global_position + Vector3(0,1.05,0))
		var hit_distance := point.distance_to(customer_screen)
		if hit_distance < customer_distance:
			customer_distance = hit_distance
			selected_customer = actor
	if not selected_customer.is_empty():
		customer_selected.emit(selected_customer)
		return
	for i in batch_icons.size():
		if batch_icons[i].visible and point.distance_to(camera.unproject_position(batch_icons[i].global_position)) < 65:
			_select_station(CafeProgress.machine_for_recipe(i))
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
	var pastry_shelf := _decor_root("PastryShelf",Vector3(-2.93,0,-3.59),"Pastry shelf",1.1)
	box(Vector3(0,2.61,0),Vector3(2.0,0.11,0.64),CREAM,0.06,pastry_shelf)
	for x in [-3.69,-2.15]:
		rod(Vector3(x+2.93,2.6,0.22),Vector3(x+2.93,2.27,-0.32),0.024,GOLD,pastry_shelf)
	for i in 4:
		cylinder(Vector3(-0.60,2.7+i*0.045,0.09),0.2,0.04,MINT,-1,pastry_shelf)
	for i in 2:
		box(Vector3(0.01+i*0.45,2.9,0.04),Vector3(0.32,0.44,0.24),CREAM if i==0 else PINK,0.045,pastry_shelf)
		box(Vector3(0.01+i*0.45,3.12,0.04),Vector3(0.32,0.055,0.23),GOLD,0.015,pastry_shelf)
		label3("FLOUR" if i==0 else "SUGAR",Vector3(0.01+i*0.45,2.92,0.17),12,COCOA,pastry_shelf)
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
	cupcake_counter = _decor_root("CupcakeCounter",Vector3(-1.25,0,1.78),"Little cupcake counter",0.9)
	cylinder(Vector3(0,0.74,0),0.72,0.10,CREAM,-1,cupcake_counter)
	cylinder(Vector3(0,0.4,0),0.10,0.64,GOLD,-1,cupcake_counter)
	cylinder(Vector3(0,0.13,0),0.37,0.06,GOLD,-1,cupcake_counter)
	for i in 6:
		var angle := i*TAU/6
		var p := Vector3(cos(angle)*0.42,0.86,sin(angle)*0.42)
		var bun := ball(p,Vector3(0.31,0.16,0.23),Color("d99042"),cupcake_counter)
		bun.rotation.y = angle
		for j in 3:
			var stripe := box(p+Vector3((j-1)*0.06,0.075,0),Vector3(0.022,0.02,0.13),CREAM,0.006,cupcake_counter)
			stripe.rotation.y = angle
	cylinder(Vector3(0,1.12,0),0.32,0.07,GOLD,-1,cupcake_counter)
	rod(Vector3(0,0.8,0),Vector3(0,1.12,0),0.035,GOLD,cupcake_counter)
	for i in 3: _cupcake(Vector3(-0.20+i*0.20,1.16,0),cupcake_counter)
	# Window curtains: repeat the same cream-and-rose stripes as the awning.
	var curtains := _decor_root("WindowCurtains",Vector3(-3.96,0,0.45),"Window curtains",1.5)
	for i in 10:
		var z := -0.85+i*0.29
		box(Vector3(-0.03,3.23,z-0.45),Vector3(0.17,0.26,0.29),PINK if i%2==0 else CREAM,0.045,curtains)
		ball(Vector3(0.03,3.1,z-0.45),Vector3(0.12,0.16,0.28),PINK if i%2==0 else CREAM,curtains)
	# Medallion on the left wall, with an oversized sculpted strawberry.
	var medallion := _decor_root("StrawberryMedallion",Vector3(-4.05,0,-2.83),"Strawberry wall medallion",0.6)
	var plate := cylinder(Vector3(-0.07,2.5,0),0.48,0.08,CREAM,-1,medallion)
	plate.rotation_degrees.z = 90
	var frame := ring(Vector3(-0.01,2.5,0),0.49,0.44,GOLD,medallion)
	frame.rotation_degrees.z = 90
	ball(Vector3(0.06,2.46,0),Vector3(0.12,0.49,0.39),PINK,medallion)
	for i in 3:
		var leaf := ball(Vector3(0.09,2.72,-0.09+i*0.09),Vector3(0.07,0.14,0.18),MINT,medallion)
		leaf.rotation_degrees.x = (i-1)*30
	for i in 3:
		for j in 2:
			ball(Vector3(0.132,2.35+i*0.10,-0.07+j*0.13),Vector3(0.024,0.036,0.02),GOLD,medallion)
	# Tidy folded towels and a recipe card add useful scale cues.
	var coffee: Node3D = stations[1].node
	for i in 3: box(Vector3(1.07,1.4+i*0.035,-0.08),Vector3(0.3,0.04,0.34),CREAM if i%2==0 else PINK,0.015,coffee)
	var recipe := box(Vector3(-0.04,1.42,0.49),Vector3(0.21,0.24,0.035),CREAM,0.01,bakery)
	recipe.rotation_degrees.x = -15
	label3("RECIPE",Vector3(-0.04,1.48,0.515),9,COCOA,bakery)
	# Soft oven glow stays local to the baking station.
	var oven_light := OmniLight3D.new()
	oven_light.position = Vector3(0.56,0.61,0.78)
	oven_light.light_color = Color("ffb857")
	oven_light.light_energy = 0.3
	oven_light.omni_range = 0.9
	bakery.add_child(oven_light)

func _decor_root(node_name: String, position: Vector3, display_name: String, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	root.set_meta("movable_decor",true)
	root.set_meta("display_name",display_name)
	root.set_meta("placement_radius",radius)
	add_child(root)
	return root

func _process(delta: float) -> void:
	if visiting: return
	time += delta
	if not hold_target.is_empty() and not hold_triggered and drag_distance <= 6:
		hold_elapsed += delta
		if hold_elapsed >= 0.65:
			hold_triggered = true
			object_actions_requested.emit(hold_target)
	for i in display_products.size():
		var stock := CafeProgress.product_stock(i)
		display_products[i].visible = stock > 0
		display_counts[i].text = "%d left" % stock
	for i in batch_icons.size():
		var job := CafeProgress.craft_job(i)
		var station_position: Vector3 = stations[CafeProgress.machine_for_recipe(i)].node.position
		batch_icons[i].position.x = station_position.x
		batch_icons[i].position.z = station_position.z
		batch_labels[i].position.x = station_position.x
		batch_labels[i].position.z = station_position.z
		batch_icons[i].visible = CafeProgress.batch_ready(i) and stations[CafeProgress.machine_for_recipe(i)].node.visible
		batch_icons[i].position.y = 2.8 + sin(time * 2.5) * 0.08
		batch_labels[i].visible = not job.is_empty()
		batch_labels[i].text = "Tap to display ×%d" % int(job.get("quantity", 0)) if batch_icons[i].visible else "%ds" % CafeProgress.craft_seconds_left(i)
	_animate_actors(delta)
	for i in steam.size():
		steam[i].position.y = 1.83+fmod(time*0.18+i*0.11,0.5)
		steam[i].position.x = -0.68 + sin(time*1.7+i)*0.04



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
	_make_actor("Coco",GOLD,false,[],6)
	_make_actor("Pip",Color("b9a8e6"),false,[],8)
	_make_actor("Lulu",Color("7fc6d9"),false,[],10)

func _make_actor(actor_name: String, outfit: Color, chef: bool, route: Array, phase: float) -> void:
	for i in route.size(): route[i] *= ROOM_SPREAD
	var actor := Node3D.new()
	actor.name = actor_name.replace(" ","")
	add_child(actor)
	actor.position = route[0] if chef else Vector3(-6.1,-0.63,-3.5-(phase-2)*2.5)
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
	actors.append({"node":actor,"display_name":actor_name,"route":route,"target":1,"direction":1,"wait":phase,"limbs":limbs,"treat":treat,"phase":phase,"chef":chef,"state":"enter","path_index":0,"cooldown":0.0,"base_y":actor.position.y,"sales":0,"walk_distance":0.0,"speed":0.0,"leg_segments":leg_segments,"nav_path":[],"nav_index":0,"nav_revision":-1,"seat_key":"","pending_purchase":{}})
	if not chef and CafeLife.REGULARS.has(actor_name.to_lower()):
		actors[-1].regular_id = actor_name.to_lower()
		_begin_regular_visit(actors[-1])
	_pose_legs(actors[-1])

func _begin_regular_visit(actor: Dictionary) -> void:
	if not actor.has("regular_id"): return
	actor.regular_request = CafeLife.new_regular_request(actor.regular_id)
	actor.product_choice = -1
	actor.wait = 0.0
	actor.patience = CUSTOMER_PATIENCE_SECONDS

func customer_request_details(actor: Dictionary) -> Dictionary:
	var name := str(actor.get("display_name","Customer"))
	if actor.has("regular_id") and CafeLife.REGULARS.has(actor.regular_id):
		name = str(CafeLife.REGULARS[actor.regular_id].name)
	if actor.has("regular_request") and not actor.regular_request.is_empty():
		var recipe_index := int(actor.regular_request.recipe_index)
		return {"name":name,"recipe_index":recipe_index,"item":CafeProgress.RECIPES[recipe_index].name,"waiting":actor.state == "shop"}
	return {"name":name,"recipe_index":-1,"item":"a treat from the display","waiting":actor.state == "shop"}

func _fallback_product(actor: Dictionary) -> int:
	for offset in CafeProgress.RECIPES.size():
		var candidate := (int(actor.phase)+int(actor.sales)+offset) % CafeProgress.RECIPES.size()
		var machine := CafeProgress.machine_for_recipe(candidate)
		var display := get_node_or_null("ProductDisplay%d" % machine) as Node3D
		if CafeProgress.product_stock(candidate) > 0 and is_instance_valid(display) and display.visible:
			return candidate
	return -1

func _customer_shop_position(actor: Dictionary, choice: int) -> Vector3:
	if actor.has("regular_id") and is_instance_valid(pickup_counter):
		var slot := maxi(0,int((float(actor.phase)-2.0)/2.0))
		# A short, separated queue faces the dedicated counter at the back of the café.
		var offsets := [Vector3(-1.45,0,1.28),Vector3(0,0,1.55),Vector3(1.45,0,1.28)]
		return pickup_counter.position + offsets[mini(slot,offsets.size()-1)] + Vector3(0,0.14,0)
	var machine := maxi(0,CafeProgress.machine_for_recipe(maxi(choice,0)))
	var display := get_node_or_null("ProductDisplay%d" % machine) as Node3D
	return (display.position if display else Vector3.ZERO) + Vector3(0,0.14,1.15)

func _customer_target_object(actor: Dictionary, choice: int) -> Node3D:
	if actor.has("regular_id"): return pickup_counter
	var machine := maxi(0,CafeProgress.machine_for_recipe(maxi(choice,0)))
	return get_node_or_null("ProductDisplay%d" % machine) as Node3D

func _entry_steps() -> Array:
	return [Vector3(-6.1,-0.63,2.8)*ROOM_SPREAD+CAFE_ORIGIN,Vector3(-5.2,-0.372,2.8)*ROOM_SPREAD+CAFE_ORIGIN,Vector3(-4.85,-0.152,2.8)*ROOM_SPREAD+CAFE_ORIGIN,Vector3(-4.52,0.068,2.8)*ROOM_SPREAD+CAFE_ORIGIN,Vector3(-4.05,0.14,2.8)*ROOM_SPREAD+CAFE_ORIGIN]

func _nav_cell(point: Vector3) -> Vector2i:
	var local := Vector2(point.x-CAFE_ORIGIN.x,point.z-CAFE_ORIGIN.z)
	return Vector2i(
		clampi(int(round((local.x-NAV_LOCAL_MIN.x)/NAV_CELL_SIZE)),0,int(ceil((NAV_LOCAL_MAX.x-NAV_LOCAL_MIN.x)/NAV_CELL_SIZE))),
		clampi(int(round((local.y-NAV_LOCAL_MIN.y)/NAV_CELL_SIZE)),0,int(ceil((NAV_LOCAL_MAX.y-NAV_LOCAL_MIN.y)/NAV_CELL_SIZE)))
	)

func _nav_world(cell: Vector2i, y: float) -> Vector3:
	return CAFE_ORIGIN+Vector3(NAV_LOCAL_MIN.x+cell.x*NAV_CELL_SIZE,y,NAV_LOCAL_MIN.y+cell.y*NAV_CELL_SIZE)

func _entry_blocks_characters(entry: Dictionary, point: Vector3, ignored: Node3D, extra_margin := 0.0) -> bool:
	var node: Node3D = entry.node
	if node==ignored or not is_instance_valid(node) or not node.visible: return false
	var id := str(entry.id)
	if id in ["cafe_name_sign","treat_menu_board","window_curtains","strawberry_medallion"] or id.begins_with("pendant_light"): return false
	var bounds: AABB = entry.bounds if entry.has("bounds") else _movable_visual_bounds(node)
	# High wall décor does not occupy walking space.
	if bounds.position.y>1.35: return false
	var local := node.to_local(point)
	var margin := CUSTOMER_RADIUS+extra_margin
	return local.x>=bounds.position.x-margin and local.x<=bounds.end.x+margin and local.z>=bounds.position.z-margin and local.z<=bounds.end.z+margin

func _navigation_path(start: Vector3, destination: Vector3, ignored: Node3D = null) -> Array:
	var dimensions := Vector2i(int(ceil((NAV_LOCAL_MAX.x-NAV_LOCAL_MIN.x)/NAV_CELL_SIZE))+1,int(ceil((NAV_LOCAL_MAX.y-NAV_LOCAL_MIN.y)/NAV_CELL_SIZE))+1)
	var start_cell := _nav_cell(start)
	var end_cell := _nav_cell(destination)
	var cells: Array[Vector2i] = []
	for grid_margin in [NAV_CELL_SIZE*0.75,NAV_CELL_SIZE*0.35,0.0]:
		var grid := AStarGrid2D.new()
		grid.region = Rect2i(Vector2i.ZERO,dimensions)
		grid.cell_size = Vector2.ONE*NAV_CELL_SIZE
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for y in dimensions.y:
			for x in dimensions.x:
				var cell := Vector2i(x,y)
				var point := _nav_world(cell,0.14)
				if movable_objects.any(func(entry: Dictionary) -> bool: return _entry_blocks_characters(entry,point,ignored,grid_margin)):
					grid.set_point_solid(cell,true)
		grid.set_point_solid(start_cell,false)
		grid.set_point_solid(end_cell,false)
		cells = grid.get_id_path(start_cell,end_cell)
		if not cells.is_empty(): break
	if cells.is_empty(): return []
	var result: Array = []
	for cell: Vector2i in cells:
		result.append(_nav_world(cell,destination.y))
	result[0] = Vector3(start.x,destination.y,start.z)
	result[-1] = destination
	return _simplify_navigation_path(result,ignored)

func _simplify_navigation_path(points: Array, ignored: Node3D = null) -> Array:
	if points.size()<3: return points
	var simplified: Array = [points[0]]
	var anchor := 0
	while anchor<points.size()-1:
		var next := anchor+1
		for candidate in range(points.size()-1,anchor,-1):
			if _navigation_segment_clear(points[anchor],points[candidate],ignored,NAV_CELL_SIZE*0.75):
				next = candidate
				break
		simplified.append(points[next])
		anchor = next
	return simplified

func _customer_path(actor: Dictionary) -> Array:
	var destination := _customer_shop_position(actor,int(actor.get("product_choice",0)))
	var steps := _entry_steps()
	var path: Array = []
	if actor.state == "exit":
		path = _navigation_path(actor.node.position,steps[-1])
		for index in range(steps.size()-2,-1,-1): path.append(steps[index])
		path.append(Vector3(CAFE_ORIGIN.x-6.1*ROOM_SPREAD.x,-0.63,CAFE_ORIGIN.z+12.5))
	else:
		path = steps.duplicate()
		var interior := _navigation_path(steps[-1],destination)
		for index in range(1,interior.size()): path.append(interior[index])
	return path

func _reset_actor_navigation(actor: Dictionary) -> void:
	actor.nav_path = []
	actor.nav_index = 0
	actor.nav_revision = -1
	actor.nav_attempted = false

func _walk_customer_to(actor: Dictionary, destination: Vector3, ignored: Node3D, delta: float) -> bool:
	var destination_changed := not actor.has("nav_destination") or Vector3(actor.nav_destination).distance_to(destination)>0.08
	if destination_changed or int(actor.get("nav_revision",-1))!=navigation_revision or not bool(actor.get("nav_attempted",false)):
		actor.nav_path = _navigation_path(actor.node.position,destination,ignored)
		actor.nav_index = 1 if actor.nav_path.size()>1 else 0
		actor.nav_destination = destination
		actor.nav_revision = navigation_revision
		actor.nav_attempted = true
	if actor.nav_path.is_empty():
		_rest_actor(actor,delta)
		return false
	var index := mini(int(actor.nav_index),actor.nav_path.size()-1)
	if _walk_actor(actor,actor.nav_path[index],delta):
		actor.nav_index = index+1
		if int(actor.nav_index)>=actor.nav_path.size():
			_reset_actor_navigation(actor)
			return true
	return false

func _available_customer_seat(actor: Dictionary) -> Dictionary:
	for entry: Dictionary in movable_objects:
		var table: Node3D = entry.node
		if not table.visible or not table.has_meta("seat_offsets"): continue
		var offsets: Array = table.get_meta("seat_offsets")
		for index in offsets.size():
			var key := "%s:%d" % [str(entry.id),index]
			var occupied := actors.any(func(other: Dictionary) -> bool: return other.node!=actor.node and str(other.get("seat_key",""))==key and other.state in ["to_seat","eat"])
			if occupied: continue
			var seat: Vector3 = table.to_global(offsets[index])
			return {"key":key,"position":seat,"table":table,"facing":atan2(table.global_position.x-seat.x,table.global_position.z-seat.z),"capacity":int(table.get_meta("seat_count",offsets.size()))}
	return {}

func _navigation_segment_clear(start: Vector3, destination: Vector3, ignored: Node3D = null, extra_margin := 0.0) -> bool:
	var steps := maxi(1,int(ceil(start.distance_to(destination)/0.16)))
	for index in range(1,steps+1):
		var point := start.lerp(destination,float(index)/steps)
		if movable_objects.any(func(entry: Dictionary) -> bool: return _entry_blocks_characters(entry,point,ignored,extra_margin)): return false
	return true

func _seat_departure_position(table: Node3D, seat: Vector3) -> Vector3:
	var outward := Vector2(seat.x-table.global_position.x,seat.z-table.global_position.z).normalized()
	var base_angle := atan2(outward.y,outward.x)
	for offset in [0.0,PI/4.0,-PI/4.0,PI/2.0,-PI/2.0,PI]:
		var direction := Vector3(cos(base_angle+offset),0,sin(base_angle+offset))
		var candidate := Vector3(table.global_position.x,seat.y,table.global_position.z)+direction*1.75
		if not _navigation_segment_clear(seat,candidate,table): continue
		if not _navigation_path(candidate,_entry_steps()[-1]).is_empty(): return candidate
	return seat+Vector3(outward.x,0,outward.y)*0.8

func _complete_actor_purchase(actor: Dictionary) -> void:
	var receipt: Dictionary = CafeProgress.complete_purchase(actor.get("pending_purchase",{}))
	actor.pending_purchase = {}
	if receipt.is_empty(): return
	actor.sales = int(actor.sales)+1
	if actor.has("regular_request") and CafeLife.fulfill_regular(actor.regular_request,int(receipt.index)):
		actor.regular_request.fulfilled = true
	customer_purchased.emit(receipt)

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
	# Turn deliberately at a waypoint, then keep a constant heading along the
	# straight segment. Moving while still turning caused visible zigzags.
	if turn>0.12:
		actor.speed = 0.0
		_rest_actor(actor,delta)
		return false
	var desired_speed := WALK_SPEED
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
	if _walk_customer_to(actor,actor.route[int(actor.target)],null,delta):
		if int(actor.target)==actor.route.size()-1 or int(actor.target)==0:
			actor.direction = -int(actor.direction)
			actor.wait = 2.0
		actor.target = int(actor.target)+int(actor.direction)
		_reset_actor_navigation(actor)

func _animate_customer(actor: Dictionary, delta: float) -> void:
	if actor.state == "away":
		actor.cooldown = float(actor.cooldown)-delta
		if float(actor.cooldown)<=0:
			var arrival := CAFE_ORIGIN+Vector3(-6.1*ROOM_SPREAD.x,-0.63,-17.0)
			for other: Dictionary in actors:
				if other.node != actor.node and other.node.visible and other.node.position.distance_to(arrival)<0.7: return
			actor.node.position = arrival
			actor.base_y = -0.63
			actor.node.visible = true
			actor.speed = 0.0
			actor.state = "enter"
			actor.path_index = 0
			actor.seat_key = ""
			_reset_actor_navigation(actor)
			_begin_regular_visit(actor)
		return
	if actor.state == "shop":
		var choice := int(actor.get("product_choice", -1))
		if actor.has("regular_request") and not actor.regular_request.is_empty():
			var requested := int(actor.regular_request.recipe_index)
			choice = requested if CafeProgress.product_stock(requested)>0 else -1
			actor.product_choice = requested
		elif choice < 0 or CafeProgress.product_stock(choice) == 0:
			choice = _fallback_product(actor)
			actor.product_choice = choice
		if choice >= 0:
			var destination := _customer_shop_position(actor,choice)
			if actor.node.position.distance_to(destination) > 0.04:
				actor.wait = 0.0
				_walk_customer_to(actor,destination,null,delta)
				return
		actor.wait = float(actor.wait)+delta
		actor.node.rotation.y = lerp_angle(actor.node.rotation.y,PI,minf(1,delta*5))
		_rest_actor(actor,delta)
		if choice < 0 and not actor.has("regular_id"):
			actor.patience = float(actor.get("patience",CUSTOMER_PATIENCE_SECONDS))-delta
			if float(actor.patience)<=0.0:
				actor.state = "exit"
				actor.path_index = 0
				actor.travel_path = _customer_path(actor)
				return
		if float(actor.wait)<1.6: return
		for index in ([choice] if choice >= 0 else []):
			var ticket: Dictionary = CafeProgress.take_product(index)
			if ticket.is_empty(): continue
			_set_carried_product(actor.treat,index)
			actor.treat.visible = true
			actor.pending_purchase = ticket
			var seat := _available_customer_seat(actor) if not actor.has("regular_id") and (int(actor.phase/2.0)+int(actor.sales)+1)%2==1 else {}
			if seat.is_empty():
				actor.state = "pickup"
			else:
				actor.state = "to_seat"
				actor.seat_key = seat.key
				actor.seat_position = seat.position
				actor.seat_table = seat.table
				actor.seat_facing = seat.facing
				actor.seat_exit_position = _seat_departure_position(seat.table,seat.position)
				_reset_actor_navigation(actor)
			actor.wait = 0.0
			return
		# Regulars wait for their exact favorite without losing patience. Only ordinary
		# customers leave when every display remains empty for their full visit timer.
		return
	if actor.state == "to_seat":
		var table: Node3D = actor.get("seat_table")
		if not is_instance_valid(table) or not table.visible:
			actor.seat_key = ""
			actor.state = "pickup"
			actor.wait = 0.0
			return
		var seat_position: Vector3 = actor.seat_position
		if _walk_customer_to(actor,seat_position,table,delta):
			actor.state = "eat"
			actor.wait = 0.0
			actor.node.rotation.y = float(actor.seat_facing)
		return
	if actor.state == "eat":
		actor.wait = float(actor.wait)+delta
		actor.node.rotation.y = lerp_angle(actor.node.rotation.y,float(actor.seat_facing),minf(1,delta*8))
		_rest_actor(actor,delta)
		if float(actor.wait)>=CUSTOMER_EAT_SECONDS:
			_complete_actor_purchase(actor)
			actor.seat_key = ""
			actor.state = "leave_seat"
			_reset_actor_navigation(actor)
		return
	if actor.state == "leave_seat":
		var seat_table: Node3D = actor.get("seat_table")
		if _walk_customer_to(actor,actor.seat_exit_position,seat_table,delta):
			actor.state = "exit"
			actor.path_index = 0
			actor.travel_path = _customer_path(actor)
		return
	if actor.state == "pickup":
		actor.wait = float(actor.wait)+delta
		actor.limbs[3].rotation.x = lerpf(actor.limbs[3].rotation.x,-1.1,minf(1,delta*5))
		if float(actor.wait)>1.2:
			_complete_actor_purchase(actor)
			actor.state = "exit"
			actor.path_index = 0
			actor.travel_path = _customer_path(actor)
		return
	if not actor.has("travel_path") or actor.get("travel_state","")!=actor.state or actor.travel_path.is_empty():
		actor.travel_path = _customer_path(actor)
		actor.travel_state = actor.state
		actor.path_index = 0
	var path: Array = actor.travel_path
	if path.is_empty():
		_rest_actor(actor,delta)
		return
	if _walk_actor(actor,path[int(actor.path_index)],delta):
		actor.path_index = int(actor.path_index)+1
		if int(actor.path_index)>=path.size():
			if actor.state == "enter":
				actor.state = "shop"
				actor.travel_path = []
				actor.wait = 0.0
				actor.patience = CUSTOMER_PATIENCE_SECONDS
			else:
				actor.node.visible = false
				actor.treat.visible = false
				actor.seat_key = ""
				actor.travel_path = []
				actor.state = "away"
				actor.cooldown = 5.0+float(actor.phase)

func _build_neighborhood() -> void:
	var neighborhood := Node3D.new()
	neighborhood.name = "Neighborhood"
	add_child(neighborhood)
	var ground := box(Vector3(0,-0.85,0),Vector3(100,0.25,100),Color("789a70"),0.1,neighborhood)
	ground.name = "Ground"
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("789a70")
	ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = ground_material
	# The café sits on a broad open expansion plot. Streets and scenery stay at
	# the perimeter so future reward buildings can fill the land over time.
	for x in [-20.0,20.0]:
		box(Vector3(x,-0.71,0),Vector3(5.2,0.08,100),Color("e6d2bb"),0.02,neighborhood)
		box(Vector3(x,-0.66,0),Vector3(3,0.04,100),Color("b5aeb7"),0.01,neighborhood)
	for z in [-20.0,20.0]:
		box(Vector3(0,-0.71,z),Vector3(100,0.08,5.2),Color("e6d2bb"),0.02,neighborhood)
		box(Vector3(0,-0.655,z),Vector3(100,0.04,3),Color("b5aeb7"),0.01,neighborhood)
	for i in range(-16,17):
		for x in [-20.0,20.0]:
			if absf(absf(i*3)-20)<2: continue
			box(Vector3(x,-0.62,i*3),Vector3(0.07,0.01,1.1),CREAM,0.005,neighborhood)
		for z in [-20.0,20.0]:
			if absf(absf(i*3)-20)<2: continue
			box(Vector3(i*3,-0.615,z),Vector3(1.1,0.01,0.07),CREAM,0.005,neighborhood)
	var expansion_plot := box(Vector3(0,-0.69,0),Vector3(34.0,0.1,34.0),Color("91ad78"),0.35,neighborhood)
	expansion_plot.name = "ExpansionPlot"
	var plot_material := StandardMaterial3D.new()
	plot_material.albedo_color = Color("a9c58d")
	plot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	expansion_plot.material_override = plot_material
	# A subtle inner pad keeps the original café readable inside the larger yard.
	box(Vector3(0,-0.675,0),Vector3(12.5,0.04,12.5),Color("e3cdb6"),0.18,neighborhood)
	var serial := 0
	# Keep the existing neighborhood language at the far edges of the property.
	for z in [-31.0,-25.0,25.0,31.0]:
		for x in [-31.0,-23.0,-12.0,0.0,12.0,23.0,31.0]:
			_build_house(Vector3(x,-0.68,z),serial,neighborhood)
			serial += 1
	var tree_index := 0
	for edge in range(-28,29,4):
		for p in [Vector3(edge,-0.66,-22.8),Vector3(edge,-0.66,22.8),Vector3(-22.8,-0.66,edge),Vector3(22.8,-0.66,edge)]:
			_tree(p,tree_index,neighborhood)
			tree_index += 1
	# Small garden pockets preserve the benches, flowers, and animals at the edges.
	for index in 4:
		var p: Vector3 = [Vector3(-15,-0.66,-15),Vector3(15,-0.66,-15),Vector3(-15,-0.66,15),Vector3(15,-0.66,15)][index]
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
	for road_x in [-20.0,20.0]:
		if absf(road_x-p.x)<distance:
			distance = absf(road_x-p.x)
			direction = Vector3(signf(road_x-p.x),0,0)
	for road_z in [-20.0,20.0]:
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
	# Variant silhouettes and toppings remain readable at display scale.
	match index:
		5:
			ball(Vector3.ZERO,Vector3(0.26,0.16,0.2),GOLD,treat)
			for stripe in 4:
				box(Vector3(-0.09+stripe*0.06,0.076,0),Vector3(0.026,0.018,0.13),Color("a85e2d"),0.008,treat)
			return
		6:
			cylinder(Vector3.ZERO,0.1,0.2,COCOA,0.12,treat)
			var handle := ring(Vector3(0.11,0,0),0.07,0.045,COCOA,treat)
			handle.rotation_degrees.x = 90
			for tier in 3:
				ball(Vector3(0,0.1+tier*0.035,0),Vector3(0.19-tier*0.055,0.065,0.19-tier*0.055),CREAM,treat)
			ball(Vector3(0,0.19,0),Vector3.ONE*0.035,COCOA,treat)
			return
		7:
			for candy in 3:
				var point := Vector3(-0.085+candy*0.085,0,0)
				ball(point,Vector3.ONE*0.095,COCOA,treat)
				box(point+Vector3(0,0.045,0),Vector3(0.055,0.012,0.024),GOLD,0.005,treat)
			return
		8:
			cylinder(Vector3.ZERO,0.13,0.19,COCOA,-1,treat)
			cylinder(Vector3(0,0.095,0),0.135,0.025,Color("422c37"),-1,treat)
			for star in 5:
				var angle := star*TAU/5
				ball(Vector3(cos(angle)*0.085,0.12,sin(angle)*0.085),Vector3.ONE*0.03,GOLD,treat)
			return
		9:
			cylinder(Vector3.ZERO,0.11,0.15,Color("e5bbda"),0.13,treat)
			cylinder(Vector3(0,0.08,0),0.105,0.015,Color("a56832"),-1,treat)
			var handle := ring(Vector3(0.12,0,0),0.065,0.04,Color("e5bbda"),treat)
			handle.rotation_degrees.x = 90
			for petal in 5:
				var angle := petal*TAU/5
				ball(Vector3(cos(angle)*0.022,0.093,sin(angle)*0.022),Vector3(0.036,0.012,0.036),PINK,treat)
			return
	match CafeProgress.machine_for_recipe(index):
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

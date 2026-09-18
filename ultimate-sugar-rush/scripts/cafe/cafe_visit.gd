extends Control

signal visit_closed
var snapshot: Dictionary = {}
var world: Node3D
var cleanup_tasks: Array[Dictionary] = []
var action_segments: Array[ColorRect] = []
var help_notice: Label
var actions_left := 5

static func valid_snapshot(data: Dictionary) -> bool:
	var layout: Variant = data.get("layout")
	if not layout is Dictionary or layout.get("version") != 1: return false
	if layout.get("theme","") not in ["strawberry","mint","cocoa"]: return false
	if layout.get("display_style","rose") not in ["rose","sage","walnut"]: return false
	var point: Variant = layout.get("table_position")
	if not point is Array or point.size()!=2: return false
	for coordinate: Variant in point:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)): return false
	if float(point[0])<3.5 or float(point[0])>5.5 or float(point[1])< -1.5 or float(point[1])>1.5: return false
	var upgrades: Variant = layout.get("upgrades",{})
	if not upgrades is Dictionary: return false
	for value: Variant in upgrades.values():
		if not value is bool: return false
	return data.get("display_name","") is String and str(data.get("display_name","")).length()<=32

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not valid_snapshot(snapshot):
		queue_free()
		return
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	world = load("res://scripts/cafe/cafe_scene.gd").new()
	world.visiting = true
	world.cafe_display_name = str(snapshot.display_name)
	world.visit_layout = snapshot.layout.duplicate(true)
	viewport.add_child(world)
	_build_cleanup_tasks()
	_build_action_bar()
	container.gui_input.connect(func(event: InputEvent) -> void:
		world._unhandled_input(event)
		container.accept_event())
	var banner := PanelContainer.new()
	banner.position = Vector2(30,30)
	add_child(banner)
	var text := Label.new()
	text.text = "  Visiting · %s  " % snapshot.display_name
	text.add_theme_font_size_override("font_size",34)
	text.custom_minimum_size = Vector2(1250,60)
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	banner.add_child(text)
	var back := Button.new()
	back.name = "ReturnButton"
	back.text = "Return to my café"
	back.position = Vector2(1450,30)
	back.size = Vector2(400,90)
	back.add_theme_font_size_override("font_size",30)
	add_child(back)
	var status := str(snapshot.get("status","none"))
	if status == "none" and not str(snapshot.get("code","")).is_empty():
		var add_friend := Button.new()
		add_friend.name = "AddFriendButton"
		add_friend.text = "Add friend"
		add_friend.position = Vector2(1450,135)
		add_friend.size = Vector2(400,80)
		add_friend.add_theme_font_size_override("font_size",28)
		add_child(add_friend)
		add_friend.pressed.connect(func() -> void:
			add_friend.disabled = true
			add_friend.text = "Sending…"
			var result: Dictionary = await CafeOnline.call_service("request",{"code":str(snapshot.code)})
			add_friend.text = "Friends!" if result.ok else "Try again"
			add_friend.disabled = result.ok)
	elif status == "friend" and not str(snapshot.get("code","")).is_empty():
		var remove_friend := Button.new()
		remove_friend.name = "RemoveFriendButton"
		remove_friend.text = "Remove friend"
		remove_friend.position = Vector2(1450,135)
		remove_friend.size = Vector2(400,80)
		remove_friend.add_theme_font_size_override("font_size",28)
		add_child(remove_friend)
		remove_friend.pressed.connect(func() -> void:
			remove_friend.disabled = true
			var result: Dictionary = await CafeOnline.call_service("remove",{"code":str(snapshot.code)})
			remove_friend.text = "Friend removed" if result.ok else "Try again"
			remove_friend.disabled = result.ok)
	back.pressed.connect(func() -> void:
		visit_closed.emit()
		queue_free())

func _build_action_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "CleanupBar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 24
	bar.offset_top = -92
	bar.offset_right = -24
	bar.offset_bottom = -20
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	bar.add_child(row)
	var title := Label.new()
	title.text = " Help out "
	title.add_theme_font_size_override("font_size",24)
	row.add_child(title)
	for index in 5:
		var segment := ColorRect.new()
		segment.name = "ActionSegment%d" % index
		segment.color = Color("d65b7d")
		segment.custom_minimum_size = Vector2(250,24)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(segment)
		action_segments.append(segment)
	help_notice = Label.new()
	help_notice.text = "5 chores"
	help_notice.custom_minimum_size = Vector2(150,0)
	help_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_notice.add_theme_font_size_override("font_size",23)
	row.add_child(help_notice)

func _build_cleanup_tasks() -> void:
	var points: Array[Vector3] = [Vector3(-4.4,0.13,-1.7),Vector3(-1.8,0.13,2.8),Vector3(1.1,0.13,3.1),Vector3(4.4,0.13,-2.1),Vector3(3.8,0.13,2.0)]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(snapshot.get("code",snapshot.get("display_name","starter"))))
	for i in range(points.size()-1,0,-1):
		var swap_index := rng.randi_range(0,i)
		var temp := points[i]
		points[i] = points[swap_index]
		points[swap_index] = temp
	var sweep_count := rng.randi_range(2,3)
	for index in 5:
		_add_cleanup_task("sweep" if index < sweep_count else "trash",points[index],index)

func _add_cleanup_task(kind: String, point: Vector3, index: int) -> void:
	var prop := Node3D.new()
	prop.name = "CleanupProp%d" % index
	prop.position = point
	world.add_child(prop)
	if kind == "sweep":
		for offset in [Vector3(-0.26,0,0),Vector3(0.12,0,0.13),Vector3(0.28,0,-0.12)]:
			world.ball(offset,Vector3(0.42,0.05,0.30),Color("a99084"),prop)
		var paper: MeshInstance3D = world.box(Vector3(-0.08,0.05,-0.18),Vector3(0.42,0.025,0.27),Color("fff4d8"),0.01,prop)
		paper.rotation.y = 0.35
		world.rod(Vector3(0.42,0.05,0),Vector3(0.62,0.86,0),0.035,Color("9a6246"),prop)
		world.box(Vector3(0.39,0.08,0),Vector3(0.34,0.12,0.18),Color("e8a54f"),0.04,prop)
	else:
		world.cylinder(Vector3.ZERO,0.34,0.62,Color("6ba9a0"),0.29,prop)
		world.ring(Vector3(0,0.34,0),0.34,0.27,Color("4f817b"),prop)
		for smoke_index in 3:
			var smell: MeshInstance3D = world.ring(Vector3(-0.12+smoke_index*0.12,0.65+smoke_index*0.20,0),0.13,0.08,Color("a9c36d80"),prop)
			smell.rotation.x = PI*0.5
		world.label3("☝",Vector3(0,1.18,0),64,Color("fff0d5"),prop)
	var tap := Button.new()
	tap.name = "CleanupButton%d" % index
	tap.text = "🧹  SWEEP" if kind == "sweep" else "✋  TAKE OUT"
	tap.size = Vector2(210,64)
	tap.add_theme_font_size_override("font_size",22)
	add_child(tap)
	cleanup_tasks.append({"kind":kind,"prop":prop,"button":tap,"done":false})
	tap.pressed.connect(_complete_cleanup.bind(index))

func _process(_delta: float) -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.camera): return
	for task in cleanup_tasks:
		if task.done: continue
		var target: Vector2 = world.camera.unproject_position(task.prop.global_position+Vector3(0,0.9,0))
		task.button.position = target-task.button.size*0.5

func _complete_cleanup(index: int) -> void:
	if index < 0 or index >= cleanup_tasks.size() or cleanup_tasks[index].done: return
	var task: Dictionary = cleanup_tasks[index]
	task.done = true
	cleanup_tasks[index] = task
	task.button.disabled = true
	task.button.text = "Sweeping…" if task.kind == "sweep" else "Taking it out…"
	var tween := create_tween()
	tween.tween_property(task.prop,"scale",Vector3(1.12,0.72,1.12),0.16).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.28)
	tween.tween_property(task.prop,"scale",Vector3.ZERO,0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	task.button.visible = false
	task.prop.queue_free()
	actions_left -= 1
	var completed := 5-actions_left
	if completed > 0: action_segments[completed-1].color = Color("69b99d")
	help_notice.text = "All clean!" if actions_left == 0 else "%d left" % actions_left
	help_notice.scale = Vector2(1.14,1.14)
	create_tween().tween_property(help_notice,"scale",Vector2.ONE,0.25).set_trans(Tween.TRANS_BACK)

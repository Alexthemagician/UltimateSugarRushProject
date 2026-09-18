extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func click(control: Control) -> void:
	var position := root.get_final_transform() * control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
func run() -> void:
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub._open_visit({"display_name":"Mint","layout":{"version":1,"theme":"mint","table_position":[5,1],"upgrades":{}}})
	await process_frame
	check(not hub.world.is_processing(),"Local customer simulation paused")
	check(not hub.world.is_processing_unhandled_input(),"Local cafe input disabled")
	var visitor = hub.get_node("CafeVisitor")
	await click(visitor.get_node("ReturnButton"))
	await process_frame
	check(not hub.has_node("CafeVisitor"),"Real GUI click closes visit")
	check(hub.world.is_processing() and hub.is_processing(),"Local cafe resumes")
	check(hub.world.is_processing_unhandled_input(),"Local camera input restored")
	check(not is_instance_valid(hub.modal),"Returning home leaves every menu closed")
	print("Visit return: %d failures" % failures)
	quit(failures)

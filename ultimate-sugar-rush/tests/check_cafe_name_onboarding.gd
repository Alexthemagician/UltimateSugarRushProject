extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var save := root.get_node("SaveSystem")
	check(not save.has_save(),"Disposable profile starts without a save")
	var boot = load("res://scenes/app/boot_screen.tscn").instantiate()
	root.add_child(boot)
	await process_frame
	boot._on_continue_pressed()
	await process_frame
	var prompt: Node = boot.find_child("CafeNamePrompt",true,false)
	check(is_instance_valid(prompt),"First launch asks for a café name")
	if is_instance_valid(prompt):
		var input: LineEdit = prompt.find_child("CafeNameInput",true,false)
		var start: Button = prompt.find_child("StartCafeButton",true,false)
		input.text = "Moonbeam Sweets"
		start.pressed.emit()
		check(str(save.get_value("cafe_profile","name",""))=="Moonbeam Sweets","Café name is stored in the save")
		check(save.has_save(),"Café name is written before entering the game")
		var returning_boot = load("res://scenes/app/boot_screen.tscn").instantiate()
		root.add_child(returning_boot)
		check(returning_boot._has_cafe_name(),"Returning player is recognized from the saved café name")
		returning_boot._on_continue_pressed()
		check(not is_instance_valid(returning_boot.find_child("CafeNamePrompt",true,false)),"Returning player is not asked to name the café again")
	print("Café onboarding: %d failures" % failures)
	quit(failures)

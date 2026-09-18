extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var progress:=root.get_node("CafeProgress")
	var database:=root.get_node("GameDatabase")
	for id in progress.INGREDIENTS: database.upsert_record("inventory",{"id":"ingredient_"+id,"quantity":100})
	var hub=load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub); await process_frame; hub.world.set_process(false)
	await create_timer(0.3).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/cafe_recipes_button.png")
	hub._quests(3); await create_timer(0.3).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/recipe_book_cakes.png")
	var craft:=hub.modal.find_child("CraftRecipe3",true,false) as Button
	if is_instance_valid(craft): craft.pressed.emit()
	await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/recipe_craft_picker.png")
	var picker: Control=hub.get_node_or_null("RecipeCraftPickerShade")
	if is_instance_valid(picker): picker.queue_free()
	hub._quest_journal(); await create_timer(0.3).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/mallow_quest_journal.png")
	quit()

extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var maker = load("res://scripts/cafe/cafe_scene.gd").new()
	var stage := Node3D.new()
	root.add_child(stage)
	for index in 10:
		var product := Node3D.new()
		stage.add_child(product)
		product.position = Vector3((index%5-2)*1.1,0,0 if index<5 else 1.3)
		product.scale = Vector3.ONE*2.5
		maker._set_carried_product(product,index)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.4
	camera.position = Vector3(0,5,6)
	camera.look_at(Vector3(0,0,0.5))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-25,0)
	stage.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("e9ddd5")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/recipe_models.png")
	maker.free()
	quit()

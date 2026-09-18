extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var visit = load("res://scripts/cafe/cafe_visit.gd").new()
	visit.snapshot = {"display_name":"Mint's blossom garden","layout":{"version":1,"theme":"mint","table_position":[5,1],"upgrades":{"garden":true,"oven":true,"seating":true}}}
	root.add_child(visit)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/cafe_visit.png")
	quit()

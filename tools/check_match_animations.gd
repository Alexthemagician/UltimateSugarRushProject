extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var board := MatchThreeBoard.new()
	root.add_child(board)
	await process_frame
	await create_timer(0.3).timeout
	board.busy = true
	for y in 8:
		for x in 8:
			board.cells[y][x] = {"kind": (x + y * 2) % 4, "special": 0}
	board._refresh()
	for kind in [1, 2]:
		var img := board.piece_textures[kind].get_image()
		assert(img.get_pixel(50, 90).a == 0.0, "Checkerboard must be transparent")
		assert(img.get_used_rect().size.x >= 438, "Candy must fill canvas")
		img.save_png("res://../tmp/clean_candy_%d.png" % kind)
	var clear := {Vector2i(3, 3): true, Vector2i(4, 3): true}
	await board._animate_clear(clear)
	assert(board.candy_items[27].modulate.a == 0.0, "Cleared candy reappeared")
	board._refresh()
	board._animate_directional_blast(Vector2i(3, 3), true)
	await create_timer(0.10).timeout
	assert(board.candy_items[27].modulate.a == 0.0)
	assert(board.candy_items[31].modulate.a == 1.0, "Far candy cleared ahead of blast")
	await create_timer(0.6).timeout
	assert(board.candy_items[31].modulate.a == 0.0)
	board._refresh()
	var home := board.candy_items[28].position
	await board._animate_bomb_charge(Vector2i(3, 3), clear)
	assert(board.candy_items[28].position.x > home.x + 60.0)
	board.cells[7][0] = null
	board.cells[6][0] = null
	var falls := board._collapse_and_refill()
	assert(int(falls[Vector2i(0, 0)]) > 0)
	assert(int(falls[Vector2i(0, 1)]) > 1)
	board._refresh()
	await board._animate_refill(falls)
	assert(board.candy_items[56].position == board.buttons[56].position + Vector2(6, 6))
	var sprite := board._make_moving_sprite(board.SPECIAL_TEXTURES[3], Vector2.ZERO)
	var trail := Line2D.new()
	board.add_child(trail)
	for finish: Vector2 in [Vector2(600, 100), Vector2(30, 600), Vector2(300, 30)]:
		var start := Vector2(300, 300)
		var control := start.lerp(finish, 0.5) + Vector2(0, -120)
		for frame in 61:
			var t := float(frame) / 60.0
			board._move_flying_rocket(t, sprite, trail, start, control, finish)
			var tangent := (2.0 * (1.0 - t) * (control - start) + 2.0 * t * (finish - control)).normalized()
			assert(Vector2.RIGHT.rotated(sprite.rotation - PI / 4.0).dot(tangent) > 0.999)
	sprite.queue_free()
	trail.queue_free()
	board.cells[3][3].special = board.Special.ROW
	await board._activate_special(Vector2i(3, 3), 0)
	for item: MergeItem in board.candy_items:
		assert(item.visible and item.modulate.a == 1.0)
	print("MATCH ANIMATION CHECKS PASSED")
	quit()

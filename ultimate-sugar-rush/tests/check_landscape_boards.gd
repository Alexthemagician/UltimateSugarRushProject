extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for path in ["merge/merge_game", "merge/cake_merge_game", "merge/cookie_merge_game", "merge/ice_cream_merge_game", "merge/mixed_merge_game", "match3/candy_match_game", "match3/gummy_match_game", "match3/marshmallow_match_game", "match3/challenge_match"]:
		var screen = load("res://scenes/" + path + ".tscn").instantiate()
		root.add_child(screen)
		await process_frame
		await process_frame
		var board = screen.find_child("MergeBoard",true,false)
		if board:
			check(board._cells.size() == 60, path + " has 60 slots")
			for cell in board._items:
				check(cell.x >= 0 and cell.x < 10 and cell.y >= 0 and cell.y < 6,path + " item within board")
		else:
			board = screen.find_child("MatchThreeBoard",true,false)
			check(board.objective_targets.size() > 0,path + " live collection targets")
			for target in board.objective_targets:
				check(target.get_global_rect().position.x > board.get_global_rect().end.x,path + " target right of board")
		check(Rect2(Vector2.ZERO,Vector2(1920,1080)).encloses(board.get_global_rect()),path + " board fits viewport")
		var previous_bottom := 0.0
		for card in screen.get_node("LandscapeLayout/RightObjectives").get_children():
			if not card.visible: continue
			var rect: Rect2 = card.get_global_rect()
			check(rect.position.y >= previous_bottom,path + " objectives do not overlap")
			check(rect.end.y <= 1080,path + " objective fits viewport")
			previous_bottom = rect.end.y
		screen.queue_free()
		await process_frame
	print("Landscape boards: %d failures" % failures)
	quit(failures)

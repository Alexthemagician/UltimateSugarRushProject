extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var save := root.get_node("SaveSystem")
	var records: Array = []
	for slot in 48:
		records.append({"item_id":"lemon", "column":slot%6, "row":slot/6,"frozen":slot%2==0})
	save.set_section("merge_board",{"items":records})
	for pass_index in 2:
		var board = load("res://scripts/merge/merge_board.gd").new()
		root.add_child(board)
		check(board._items.size() >= 48,"All old items retained")
		for slot in 48:
			var cell := Vector2i(slot%10,slot/10)
			check(board._items.has(cell),"Old slot maps to landscape slot")
			if board._items.has(cell):
				check(board._items[cell].item_id == "lemon","Item identity retained")
				check(board._items[cell].frozen == (slot%2==0),"Frozen state retained")
		board._save_board()
		save.save_now()
		board.queue_free()
		await process_frame
		save.load_save()
	print("Merge migration: %d failures" % failures)
	quit(failures)

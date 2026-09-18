extends SceneTree

var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var merge_screen = load("res://scenes/merge/cake_merge_game.tscn").instantiate()
	root.add_child(merge_screen)
	await process_frame
	var merge_board = merge_screen.find_child("MergeBoard", true, false)
	merge_board.persistence_enabled = false
	# A long hold is limited only by available cells, rather than an arbitrary
	# per-press item cap.
	var count_before_first_burst: int = merge_board._items.size()
	merge_screen._start_adding()
	var first_burst_size: int = merge_board._items.size() - count_before_first_burst
	check(first_burst_size >= 4 and first_burst_size <= 6, "One Add Items pulse launches a simultaneous cluster instead of one item")
	var airborne: Array = merge_board._items.values().filter(func(item: Control) -> bool: return item.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	check(airborne.size() >= first_burst_size, "Cluster items launch together along their party-cannon arcs")
	check(merge_board.get_children().any(func(node: Node) -> bool: return node is Polygon2D), "Cluster launch creates a visible cannon flash")
	merge_screen._process(10.0)
	check(merge_board._items.size() == 60, "Held Add Items fills every available board slot")
	check(not merge_screen._button_held, "Add Items burst stops itself when the board is full")
	check(merge_board.get_children().any(func(node: Node) -> bool: return node is CPUParticles2D), "Added items create a visible burst effect")

	# Commit a merge synchronously, even while its visual tweens are still active.
	for item: Node in merge_board._items.values():
		item.queue_free()
	merge_board._items.clear()
	var first = merge_board._spawn_item("chocolate_bar", Vector2i(0, 0), false)
	var second = merge_board._spawn_item("chocolate_bar", Vector2i(1, 0), false)
	var spare = merge_board._spawn_item("strawberry", Vector2i(2, 0), false)
	merge_board._merge_items(first, second)
	check(merge_board._items.has(Vector2i(1, 0)) and merge_board._items[Vector2i(1, 0)].item_id == "chocolate_batter", "Merge result is usable as soon as the item is dropped")
	merge_board._move_item(spare, Vector2i(3, 0))
	check(merge_board._items.has(Vector2i(3, 0)), "Another merge-board item can move during merge animation")
	merge_screen.queue_free()
	await process_frame

	# Exercise every other merge-board screen, including the shared regional
	# board used by Honeydew and Cocoa Moon maps.
	var progress = root.get_node("CafeProgress")
	progress.region = 1
	progress.stage = 0
	for scene_path in [
		"res://scenes/merge/merge_game.tscn",
		"res://scenes/merge/cookie_merge_game.tscn",
		"res://scenes/merge/ice_cream_merge_game.tscn",
		"res://scenes/merge/mixed_merge_game.tscn",
		"res://scenes/merge/regional_merge_game.tscn",
	]:
		var screen = load(scene_path).instantiate()
		root.add_child(screen)
		await process_frame
		var screen_board = screen.find_child("MergeBoard", true, false)
		screen_board.persistence_enabled = false
		if scene_path.ends_with("/merge_game.tscn"):
			screen._start_adding_fruit()
		else:
			screen._start_adding()
		screen._process(10.0)
		check(screen_board._items.size() == 60, "%s held Add Items reaches board capacity" % scene_path.get_file())
		screen.queue_free()
		await process_frame

	var release_screen = load("res://scenes/merge/cookie_merge_game.tscn").instantiate()
	root.add_child(release_screen)
	await process_frame
	release_screen.board.persistence_enabled = false
	release_screen.board.reset_board()
	release_screen._start_adding()
	release_screen._process(0.70)
	release_screen._stop_adding()
	var released_count: int = release_screen.board._items.size()
	release_screen._process(5.0)
	check(release_screen.board._items.size() == released_count, "Add Items burst stops immediately when the player releases the button")
	release_screen.queue_free()
	await process_frame

	var match_board = load("res://scripts/match3/match_three_board.gd").new()
	root.add_child(match_board)
	await process_frame
	match_board.cells[0][0].special = 4
	match_board._refresh()
	match_board.busy = true
	var normal_item = match_board.candy_items[1]
	normal_item.dragging = true
	match_board._on_candy_drag_started(normal_item)
	check(not normal_item.dragging, "Ordinary candy input stays locked while candy animations settle")
	var power_item = match_board.candy_items[0]
	power_item.dragging = true
	match_board._on_candy_drag_started(power_item)
	check(power_item.dragging, "Power-up input remains available during ordinary candy animations")
	power_item.dragging = false
	match_board._request_power_activation(Vector2i(0, 0))
	check(match_board.power_busy and bool(match_board.cells[0][0].get("activation_queued", false)), "Power-up use is accepted and tracked during candy animation")
	match_board._request_power_activation(Vector2i(0, 0))
	var queued_count := 0
	for row: Array in match_board.cells:
		for cell in row:
			if cell != null and bool(cell.get("activation_queued", false)): queued_count += 1
	check(queued_count == 1, "A second power-up cannot start while a power-up is already queued or animating")
	match_board.busy = false
	for frame in 600:
		await process_frame
		if not match_board.power_busy and not match_board.busy: break
	check(not match_board.power_busy and not match_board.busy, "Power-up lock clears after its full animation and cascade")
	match_board.cells[0][0] = {"kind": 0, "special": 1}
	match_board.cells[0][1] = {"kind": 1, "special": 4}
	match_board._refresh()
	match_board._play_power_effect_locked(1, Vector2i(0, 0), {Vector2i(0, 0): true})
	check(match_board.power_busy, "Power animation raises the exclusive power-up lock")
	match_board._request_power_activation(Vector2i(1, 0))
	check(not bool(match_board.cells[0][1].get("activation_queued", false)), "Another power-up is rejected while a power animation is running")
	for frame in 180:
		await process_frame
		if not match_board.power_busy: break
	check(not match_board.power_busy, "Exclusive power-up lock ends with the power animation")

	print("Board input flow: %d failures" % failures)
	quit(failures)

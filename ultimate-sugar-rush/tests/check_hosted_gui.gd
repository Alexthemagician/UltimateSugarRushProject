extends "res://tests/check_quest_gui.gd"
func find_button(node: Node, title: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text==title: return child
		var found := find_button(child,title)
		if found: return found
	return null
func settle_network() -> void:
	for frame in 1200:
		await create_timer(0.02).timeout
		if not root.get_node("CafeOnline").busy:
			await process_frame
			return
	check(false,"Network request finished within timeout")
func wait_for_button(node: Node, title: String) -> Button:
	for frame in 1200:
		await create_timer(0.02).timeout
		if is_instance_valid(node):
			var found := find_button(node,title)
			if found: return found
	check(false,"%s appeared within timeout" % title)
	return null
func wait_for_child(node: Node, path: NodePath) -> bool:
	for frame in 1200:
		await create_timer(0.02).timeout
		if is_instance_valid(node) and node.has_node(path): return true
	return false
func run() -> void:
	if not "--live-social-test" in OS.get_cmdline_user_args():
		quit(2)
		return
	var online := root.get_node("CafeOnline")
	online.session_file = "user://test_visitor_session.cfg"
	online._ready()
	var owner = load("res://scripts/core/cafe_online.gd").new()
	owner.session_file = "user://test_owner_session.cfg"
	root.add_child(owner)
	var profile: Dictionary = await owner.call_service("profile")
	if not profile.ok:
		push_error("Run hosted social test first in the same disposable profile")
		quit(1)
		return
	var published: Dictionary = await owner.call_service("publish",{"layout":owner.public_layout()})
	check(published.ok,"Test cafe published")
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	await click(hub.get_node("FriendsButton"))
	var visit_button := await wait_for_button(hub.modal,"Visit café")
	check(is_instance_valid(visit_button),"Live Friends menu loads a café card")
	check(is_instance_valid(find_button(hub.modal,"Add friend")),"Friends menu offers Add friend for a chef not yet added")
	check(is_instance_valid(await wait_for_button(hub.modal,"Remove friend")),"Friends menu offers Remove friend for starter friends")
	if is_instance_valid(visit_button):
		await settle_network()
		var visit: Dictionary = await online.call_service("visit",{"code":profile.data.code})
		check(visit.ok,"Café card target resolves to its hosted snapshot")
		if visit.ok: hub._open_visit(visit.data)
		check(hub.has_node("CafeVisitor"),"Café card snapshot opens the visitor screen")
		if hub.has_node("CafeVisitor"):
			check(is_instance_valid(find_button(hub.get_node("CafeVisitor"),"Add friend")),"Visitor view offers Add friend")
	await owner.call_service("hide")
	print("Hosted GUI: %d failures" % failures)
	quit(failures)

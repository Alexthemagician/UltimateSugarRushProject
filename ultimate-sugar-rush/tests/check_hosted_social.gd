extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	if not "--live-social-test" in OS.get_cmdline_user_args():
		print("Hosted test not run: requires --live-social-test and a disposable user data directory.")
		quit(2)
		return
	var a = load("res://scripts/core/cafe_online.gd").new()
	var b = load("res://scripts/core/cafe_online.gd").new()
	a.session_file = "user://test_owner_session.cfg"
	b.session_file = "user://test_visitor_session.cfg"
	root.add_child(a)
	root.add_child(b)
	var owner: Dictionary = await a.call_service("register",{"display_name":"Cafe QA Owner"})
	var visitor: Dictionary = await b.call_service("register",{"display_name":"Cafe QA Visitor"})
	if not owner.ok or not visitor.ok:
		push_error("Hosted identities unavailable. Check authentication setup and connectivity.")
		quit(1)
		return
	check(owner.data.code != visitor.data.code,"Independent players receive different codes")
	var owner_code := str(owner.data.code)
	var visitor_code := str(visitor.data.code)
	var layout := {"version":1,"theme":"mint","display_style":"walnut","table_position":[5,1],"upgrades":{"garden":true,"oven":false,"seating":false,"display":true}}
	var published: Dictionary = await a.call_service("publish",{"layout":layout})
	check(published.ok,"Owner publishes café")
	var discovered: Dictionary = await b.call_service("discover")
	check(discovered.ok and discovered.data.cafes.any(func(cafe: Dictionary) -> bool: return cafe.code==owner_code and cafe.status=="none"),"Visitor discovers an open café before adding its chef")
	# Free the owner's client before visiting: no live owner process supplies the scene.
	a.queue_free()
	await process_frame
	var visit: Dictionary = await b.call_service("visit",{"code":owner_code})
	check(visit.ok,"Visitor fetches café while owner client is absent")
	if visit.ok:
		var received: Dictionary = visit.data.layout
		check(int(received.version)==1 and received.theme==layout.theme and received.display_style==layout.display_style,"Hosted snapshot preserves version and finishes")
		check(Vector2(float(received.table_position[0]),float(received.table_position[1]))==Vector2(5,1),"Hosted snapshot preserves furniture coordinates across JSON number conversion")
		check(received.upgrades==layout.upgrades,"Hosted snapshot preserves upgrade flags")
		check(load("res://scripts/cafe/cafe_visit.gd").valid_snapshot(visit.data),"Hosted snapshot accepted by visitor renderer")
	var request: Dictionary = await b.call_service("request",{"code":owner_code})
	check(request.ok and bool(request.data.get("accepted",false)),"Friend request accepts immediately")
	discovered = await b.call_service("discover")
	check(discovered.ok and discovered.data.cafes.any(func(cafe: Dictionary) -> bool: return cafe.code==owner_code and cafe.status=="friend"),"Discovery card immediately reflects friendship")
	a = load("res://scripts/core/cafe_online.gd").new()
	a.session_file = "user://test_owner_session.cfg"
	root.add_child(a)
	var restored: Dictionary = await a.call_service("profile")
	check(restored.ok and restored.data.code==owner_code,"Owner identity survives client restart")
	var friends: Dictionary = await b.call_service("friends")
	check(friends.ok and friends.data.friends.any(func(friend: Dictionary) -> bool: return friend.code==owner_code and friend.status=="friend"),"Instant friend appears to visitor")
	for starter_name in ["Rosie's Berry Nook","Milo's Mint Kitchen","Coco Moon Café"]:
		check(friends.data.friends.any(func(friend: Dictionary) -> bool: return friend.display_name==starter_name and friend.status=="friend"),"Starter friend is initialized: %s" % starter_name)
	var hidden: Dictionary = await a.call_service("hide")
	check(hidden.ok,"Owner closes café to visits")
	visit = await b.call_service("visit",{"code":owner_code})
	check(not visit.ok,"Hosted service denies hidden café visit")
	var removed: Dictionary = await b.call_service("remove",{"code":owner_code})
	check(removed.ok,"Test friendship removed")
	print("Hosted social: %d failures" % failures)
	quit(failures)

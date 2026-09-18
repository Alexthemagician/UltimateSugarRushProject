extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var online := root.get_node("CafeOnline")
	check(online.STARTER_CAFES.size()==3,"Three starter cafés ship with the game")
	for cafe: Dictionary in online.STARTER_CAFES:
		check(online._starter_is_friend(str(cafe.code)),"%s starts as a friend" % cafe.display_name)
	var visit = load("res://scripts/cafe/cafe_visit.gd").new()
	visit.snapshot = online.STARTER_CAFES[0].duplicate(true)
	visit.snapshot["status"] = "friend"
	root.add_child(visit)
	await process_frame
	check(visit.cleanup_tasks.size()==5,"A visit contains exactly five cleanup actions")
	var sweep_count: int = visit.cleanup_tasks.filter(func(task: Dictionary) -> bool: return task.kind=="sweep").size()
	check(sweep_count in [2,3],"Five actions are split between sweeping and trash")
	check(visit.action_segments.size()==5,"Bottom progress bar has five segments")
	check(is_instance_valid(visit.find_child("RemoveFriendButton",true,false)),"Friend café offers Remove friend")
	visit._complete_cleanup(0)
	await create_timer(0.85).timeout
	check(visit.actions_left==4 and not visit.cleanup_tasks[0].button.visible,"Tapped chore animates away after a delay")
	check(visit.action_segments[0].color==Color("69b99d"),"Completing a chore fills one progress segment")
	var removed: Dictionary = await online.call_service("remove",{"code":str(online.STARTER_CAFES[0].code)})
	check(removed.ok and not online._starter_is_friend(str(online.STARTER_CAFES[0].code)),"Starter friend can be removed")
	var added: Dictionary = await online.call_service("request",{"code":str(online.STARTER_CAFES[0].code)})
	check(added.ok and online._starter_is_friend(str(online.STARTER_CAFES[0].code)),"Starter friend re-adds and accepts immediately")
	print("Visit chores: %d failures" % failures)
	quit(failures)

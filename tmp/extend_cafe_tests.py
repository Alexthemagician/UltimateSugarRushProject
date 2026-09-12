from pathlib import Path
p=Path('ultimate-sugar-rush/tests/check_cafe.gd');s=p.read_text(encoding='utf-8').replace('\thub.queue_free()','''	var saw_pickup := false
	var saw_release := false
	for frame in 500:
		hub.world._process(0.1)
		if hub.world.actors[1].treat.visible: saw_pickup = true
		elif saw_pickup: saw_release = true
	check(saw_pickup and saw_release,"Customer pickup and return loop")
	hub.queue_free()''')
s=s.replace('\tprint("CAFE CHECKS FINISHED:', '''	progress.region = 1
	progress.stage = 2
	progress.begin_board("res://scenes/match3/challenge_match.tscn")
	var final_board = load("res://scenes/match3/challenge_match.tscn").instantiate()
	root.add_child(final_board)
	current_scene = final_board
	await process_frame
	await final_board._complete_level()
	await create_timer(0.6).timeout
	check(current_scene.scene_file_path==progress.HUB,"Completed board returns to main cafe")
	check(bool(save.get_value("cafe_completed","region_1_stage_2",false)),"Completion path awards and unlocks")
	print("CAFE CHECKS FINISHED:''')
p.write_text(s,encoding='utf-8')

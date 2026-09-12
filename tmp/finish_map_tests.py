from pathlib import Path
p=Path('ultimate-sugar-rush/scripts/cafe/cafe_region.gd');s=p.read_text(encoding='utf-8').replace('positions = [Vector2(620','positions.assign([Vector2(620').replace('else [Vector2(600,1610),Vector2(430,1390),Vector2(660,1175),Vector2(430,930),Vector2(650,685),Vector2(560,400)]','else [Vector2(520,1610),Vector2(620,1400),Vector2(685,1150),Vector2(460,1000),Vector2(700,770),Vector2(635,490)])');p.write_text(s,encoding='utf-8')
p=Path('ultimate-sugar-rush/tests/check_cafe.gd');s=p.read_text(encoding='utf-8').replace('\tprint("CAFE CHECKS FINISHED:', '''	progress.open_region(0)
	await create_timer(0.65).timeout
	check(current_scene.scene_file_path=="res://scenes/map/world_map.tscn","Original map remains accessible")
	check(not current_scene.get_node("%CollectionsButton").visible,"Collections moved off original map")
	current_scene.get_node("%SettingsButton").pressed.emit()
	await create_timer(0.65).timeout
	check(current_scene.scene_file_path==progress.HUB,"Original map returns to cafe")
	for region in [1,2]:
		progress.open_region(region)
		await create_timer(0.65).timeout
		check(current_scene.get_child_count()>=17,"Illustrated regional map initializes fully")
		progress.open_stage(0)
		await create_timer(0.65).timeout
		check(current_scene.scene_file_path=="res://scenes/match3/challenge_match.tscn","Regional map opens playable board")
		current_scene.get_node("%BackButton").pressed.emit()
		await create_timer(0.65).timeout
		check(current_scene.scene_file_path=="res://scenes/map/cafe_region.tscn","Challenge returns to correct region")
	print("CAFE CHECKS FINISHED:''');p.write_text(s,encoding='utf-8')

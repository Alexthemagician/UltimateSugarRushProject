extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func find_named(node: Node, name_text: String) -> Node:
	if node.name==name_text: return node
	for child in node.get_children():
		var found := find_named(child,name_text)
		if found: return found
	return null
func run() -> void:
	var progress := root.get_node("CafeProgress")
	var save := root.get_node("SaveSystem")
	var hub = load("res://scenes/cafe/cafe_hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub.world.set_process(false)
	var mouth: Node3D = hub.portrait.get_node("Head/Mouth")
	var mouth_pose := mouth.transform
	var child_poses: Array = []
	for child in mouth.get_children(): child_poses.append(child.transform)
	for frame in 600: hub._process(0.02)
	check(mouth.transform==mouth_pose and mouth.get_meta("closed_smile",false),"Closed portrait smile stays fixed")
	for i in mouth.get_child_count(): check(mouth.get_child(i).transform==child_poses[i],"No mouth geometry animation")
	for actor in hub.world.actors:
		check(actor.node.get_node("Head").get_meta("hair_style")=="rounded_placeholder","Rounded hair restored")
		for pose in 120:
			actor.node.position = Vector3.ZERO
			actor.node.rotation = Vector3.ZERO
			actor.base_y = 0.0
			actor.walk_distance = pose*0.8/120
			actor.speed = 0.72
			hub.world._walk_actor(actor,Vector3(0,0,5),0.001)
			hub.world._pose_legs(actor)
			for pair in actor.leg_segments:
				var upper: Node3D = pair[0]
				var knee: Vector3 = upper.position+upper.basis.y*0.5
				check(knee.y+0.064<0.228,"Knee surface clears hem throughout full stride")
				var lower: Node3D = pair[1]
				var bottom: Vector3 = lower.position+lower.basis.y*0.5
				check(maxf(knee.y,bottom.y)+0.060<0.228,"Entire shin clears skirt")
				var hip: Vector3 = upper.position-upper.basis.y*0.5
				var at_hem := hip.lerp(knee,(hip.y-0.24)/(hip.y-knee.y))
				check(Vector2(at_hem.x,at_hem.z).length()+0.052<0.25,"Upper leg stays within garment at hem")
	hub.queue_free()
	await process_frame
	var common: Dictionary = {}
	for region in 3:
		progress.region = region
		var map = load("res://scenes/map/world_map.tscn" if region==0 else "res://scenes/map/cafe_region.tscn").instantiate()
		root.add_child(map)
		await process_frame
		check(map.positions.size()==(8 if region==0 else 6),"Original eight boards preserved")
		for key in ["MapHeader","CafeBackButton","IngredientFooter"]:
			var node: Control = map.get_node(key)
			if region==0: common[key] = node.get_rect()
			else: check(node.get_rect()==common[key],"Consistent map control placement: "+key)
		for i in map.positions.size():
			var button: Button = map.get_node("Level%d" % (i+1))
			check(button.size==Vector2(106,106),"Consistent stage button dimensions")
			if i+1<map.positions.size(): check(map.positions[i].y-map.positions[i+1].y>=163,"Stage caption cannot overlap next button")
		if region==0:
			check(not map.get_node("Level1").disabled,"First original stage open")
			for i in [2,3,4]: check(map.get_node("Level%d" % i).disabled,"Original unlock gates preserved")
			for i in [5,6,7,8]: check(not map.get_node("Level%d" % i).disabled,"Existing development access preserved")
		map.queue_free()
		await process_frame
	var host := Control.new()
	root.add_child(host)
	var rewards := root.get_node("CollectibleRewards")
	for region in 3:
		for half in 2:
			var ingredients := {}
			for offset in 3: ingredients[progress.POOLS[region][half*3+offset]] = 2+half
			var overlay: Dictionary = rewards.build_completion_overlay(host,"COMPLETE","honey_pot",{"coins":120,"xp":45,"ingredients":ingredients})
			check(find_named(overlay.layer,"RewardIcon_coins")!=null and find_named(overlay.layer,"RewardIcon_xp")!=null,"Currency icons present")
			check(find_named(overlay.layer,"RewardAmount_coins").text=="+120","Exact coin amount shown")
			for id in ingredients:
				var icon: TextureRect = find_named(overlay.layer,"RewardIcon_"+id)
				check(icon!=null and icon.texture is AtlasTexture,"Ingredient reward has associated icon")
				check(find_named(overlay.layer,"RewardAmount_"+id).text.contains(str(ingredients[id])),"Ingredient quantity shown")
			overlay.layer.queue_free()
			await process_frame
	host.queue_free()
	await process_frame
	print("VISUAL REFINEMENT CHECKS: %d failures" % failures)
	quit(1 if failures else 0)

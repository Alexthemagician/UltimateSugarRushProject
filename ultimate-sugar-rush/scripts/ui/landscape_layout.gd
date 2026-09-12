extends RefCounted

static func apply(root: Control) -> void:
	var layout := root.get_node("SafeArea/Layout")
	var canvas := Control.new()
	canvas.name = "LandscapeLayout"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	for name_text in ["Header", "StatusLabel", "ActionRow", "Rules"]:
		var control := layout.get_node_or_null(name_text) as Control
		if not control: continue
		control.reparent(canvas)
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		match name_text:
			"Header":
				control.position = Vector2(35,20)
				control.size = Vector2(1850,80)
			"StatusLabel":
				control.position = Vector2(40,105)
				control.size = Vector2(1800,55)
			"ActionRow":
				control.position = Vector2(45,165)
				control.size = Vector2(1240,90)
			"Rules":
				control.position = Vector2(1110,965)
				control.size = Vector2(750,85)
	var objectives := VBoxContainer.new()
	objectives.name = "RightObjectives"
	objectives.position = Vector2(1370,195)
	objectives.size = Vector2(500,750)
	objectives.add_theme_constant_override("separation",24)
	canvas.add_child(objectives)
	for card in layout.get_node("Objectives").get_children():
		card.reparent(objectives)
		card.custom_minimum_size = Vector2(460,150)
		for icon in card.find_children("*", "TextureRect", true, false):
			icon.custom_minimum_size = Vector2(100,100)
	var board := root.find_child("MergeBoard",true,false) as Control
	var merge := board != null
	if not board: board = root.find_child("MatchThreeBoard",true,false) as Control
	if board:
		board.reparent(canvas)
		board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		board.position = Vector2(45,270) if merge else Vector2(180,175)
		board.scale = Vector2.ONE * (0.80 if merge else 0.94)
		if not merge: objectives.position.x = 1270
	root.get_node("SafeArea").hide()

from pathlib import Path
p=Path('ultimate-sugar-rush/scripts/cafe/cafe_region.gd');s=p.read_text(encoding='utf-8')
s=s.replace('var region := CafeProgress.region','''var region := CafeProgress.region
	positions = [Vector2(620,1610),Vector2(410,1415),Vector2(680,1165),Vector2(450,1000),Vector2(660,685),Vector2(660,400)] if region==1 else [Vector2(600,1610),Vector2(430,1390),Vector2(660,1175),Vector2(430,930),Vector2(650,685),Vector2(560,400)]
	var art := TextureRect.new()
	art.texture = load("res://assets/map/honeydew_gardens.png" if region==1 else "res://assets/map/cocoa_moon.png")
	art.position = Vector2.ZERO
	art.size = Vector2(1080,1920)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var header := Panel.new()
	header.position = Vector2(35,35)
	header.size = Vector2(1010,220)
	header.add_theme_stylebox_override("panel",style(Color(1.0,0.95,0.89,0.94)))
	add_child(header)''')
s=s.replace('positions[i]-Vector2(85,45),Vector2(170,90)','positions[i]-Vector2(53,53),Vector2(106,106)')
s=s.replace('node.add_theme_font_size_override("font_size",38)','''node.add_theme_font_size_override("font_size",38)
		node.add_theme_stylebox_override("normal",style(Color("e9759e") if open else Color("bcb4bd")))
		node.add_theme_color_override("font_color",Color.WHITE)''')
s=s.replace('label(["Sweet beginnings"','var caption := label(["Sweet beginnings"')
s=s.replace('positions[i]+Vector2(-180,64),Vector2(380,85),27)','positions[i]+Vector2(-170,62),Vector2(340,48),24)\n\t\tcaption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\t\tcaption.add_theme_stylebox_override("normal",style(Color(1.0,0.96,0.90,0.94)))')
s=s.replace('label("INGREDIENTS TO DISCOVER\\n"+" • ".join(names),Vector2(75,1670),Vector2(930,170),26)','''var footer := Panel.new()
	footer.position = Vector2(35,1745)
	footer.size = Vector2(1010,150)
	footer.add_theme_stylebox_override("panel",style(Color(1.0,0.95,0.89,0.96)))
	add_child(footer)
	label("INGREDIENTS TO DISCOVER\\n"+" • ".join(names),Vector2(60,1760),Vector2(960,130),23)
	for child: Control in get_children(): design_positions[child] = child.position
	resized.connect(_center_layout)
	_center_layout()''')
a=s.index('func _draw()');s=s[:a]+'''func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("e1efe0") if CafeProgress.region==1 else Color("e7ddf0"))
'''
p.write_text(s,encoding='utf-8')

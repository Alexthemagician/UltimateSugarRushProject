from pathlib import Path
p=Path('ultimate-sugar-rush/project.godot');s=p.read_text(encoding='utf-8').replace('renderer/rendering_method="gl_compatibility"','renderer/rendering_method="forward_plus"').replace('renderer/rendering_method.mobile="gl_compatibility"','renderer/rendering_method.mobile="mobile"');s+='\nanti_aliasing/quality/msaa_3d=2\n';p.write_text(s,encoding='utf-8')
p=Path('ultimate-sugar-rush/scripts/cafe/cafe_scene.gd');s=p.read_text(encoding='utf-8').replace('get_viewport().use_taa = true','get_viewport().use_taa = RenderingServer.get_current_rendering_method() == "forward_plus"');p.write_text(s,encoding='utf-8')
p=Path('ultimate-sugar-rush/scripts/cafe/cafe_hub.gd');s=p.read_text(encoding='utf-8').replace('var world: Node3D','var world: Node3D\nvar design_positions: Dictionary = {}')
s=s.replace('\tGameDatabase.record_changed.connect','\tfor child: Node in get_children():\n\t\tif child is Control and child != backdrop: design_positions[child] = child.position\n\tresized.connect(_center_layout)\n\t_center_layout()\n\tGameDatabase.record_changed.connect')
s=s.replace('label("Last board: "+CafeProgress.reward_text(receipt),Vector2(45,230),Vector2(990,110),22)','var notice := label("Last board: "+CafeProgress.reward_text(receipt),Vector2(45,230),Vector2(990,110),22)\n\t\tdesign_positions[notice] = Vector2(45,230)\n\t\t_center_layout()')
s=s.replace('panel.position = Vector2(55,255)','panel.position = Vector2((size.x-970)*0.5,255)')
s=s.replace('\t_row("Changes are saved automatically.",column,25)','''	var notifications := CheckButton.new()
	notifications.text = "Notifications preference"
	notifications.button_pressed = GameSettings.notifications_enabled
	notifications.add_theme_font_size_override("font_size",28)
	notifications.add_theme_color_override("font_color",INK)
	notifications.custom_minimum_size = Vector2(850,80)
	notifications.toggled.connect(GameSettings.set_notifications_enabled)
	column.add_child(notifications)
	_row("Notification preference is saved; device reminders are not enabled yet.",column,23)
	_row("Changes are saved automatically.",column,25)''')
s+='''

func _center_layout() -> void:
	var offset := Vector2(maxf(0,(size.x-1080)*0.5),maxf(0,(size.y-1920)*0.5))
	for child: Control in design_positions:
		if is_instance_valid(child): child.position = design_positions[child]+offset
'''
p.write_text(s,encoding='utf-8')

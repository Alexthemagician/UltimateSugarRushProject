from pathlib import Path
root=Path('ultimate-sugar-rush')
s=Path('prototypes/fixed_cafe/cafe.gd').read_text(encoding='utf-8')
s=s.replace('extends Node3D','extends Node3D\n\nsignal station_selected(index: int)\nvar actors: Array[Dictionary] = []',1).replace('res://soft_ink.gdshader','res://scripts/cafe/soft_ink.gdshader')
s=s.replace('rough := 0.34','rough := 0.16').replace('material.metallic_specular = 0.45','material.metallic_specular = 0.85\n\tmaterial.clearcoat_enabled = true\n\tmaterial.clearcoat = 0.65\n\tmaterial.clearcoat_roughness = 0.1')
s=s.replace('\t_build_ui()','\t_build_actors()')
a=s.index('\tif "--capture"');b=s.index('\nfunc _build_room()',a);s=s[:a]+s[b:]
s=s.replace('\tselected_station = index','\tstation_selected.emit(index)\n\tif not is_instance_valid(status_label): return\n\tselected_station = index')
s=s.replace('\ttime += delta','\ttime += delta\n\t_animate_actors(delta)')
s += '''

func _build_actors() -> void:
	_make_actor("Chef Mallow",Color("f6e8ce"),true,[Vector3(-1.45,0.14,-1.7),Vector3(-1.45,0.14,-0.85),Vector3(0.0,0.14,-0.85)],0.0)
	_make_actor("Berry",PINK,false,[Vector3(-0.1,0.14,3.35),Vector3(-0.1,0.14,2.5),Vector3(0.6,0.14,2.55)],2.0)
	_make_actor("Mint",MINT,false,[Vector3(3.82,0.14,3.1),Vector3(3.82,0.14,1.0),Vector3(3.82,0.14,-0.1)],4.0)

func _make_actor(actor_name: String, outfit: Color, chef: bool, route: Array, phase: float) -> void:
	var actor := Node3D.new()
	actor.name = actor_name.replace(" ","")
	add_child(actor)
	actor.position = route[0]
	var skin := Color("ffd7b8")
	var hair := Color("593749") if chef else Color("86523b")
	ball(Vector3(0,0.61,0),Vector3(0.4,0.48,0.28),outfit,actor)
	box(Vector3(0,0.55,0.15),Vector3(0.26,0.33,0.03),CREAM,0.025,actor)
	ball(Vector3(0,1.0,0),Vector3(0.5,0.49,0.44),skin,actor)
	ball(Vector3(0,1.13,-0.025),Vector3(0.52,0.3,0.46),hair,actor)
	for side in [-1.0,1.0]:
		ball(Vector3(side*0.09,1.005,0.212),Vector3(0.068,0.10,0.025),COCOA,actor)
		ball(Vector3(side*0.09-0.012,1.025,0.23),Vector3.ONE*0.022,CREAM,actor)
		ball(Vector3(side*0.16,0.94,0.205),Vector3(0.08,0.038,0.019),PINK,actor)
		ball(Vector3(side*0.23,1.02,0),Vector3(0.1,0.14,0.09),skin,actor)
	ball(Vector3(0,0.915,0.219),Vector3(0.055,0.02,0.015),ROSE,actor)
	if chef:
		cylinder(Vector3(0,1.27,0),0.22,0.17,CREAM,-1,actor)
		for x in [-0.13,0.0,0.13]: ball(Vector3(x,1.4,0),Vector3(0.26,0.27,0.28),CREAM,actor)
	else:
		for x in [-0.2,0.2]: ball(Vector3(x,1.09,-0.04),Vector3(0.22,0.3,0.22),hair,actor)
		ball(Vector3(0.19,1.19,0.05),Vector3(0.2,0.12,0.1),outfit,actor)
	var limbs: Array[Node3D] = []
	for side in [-1.0,1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side*0.11,0.38,0)
		actor.add_child(leg)
		box(Vector3(0,-0.12,0),Vector3(0.13,0.25,0.15),COCOA,0.05,leg)
		ball(Vector3(0,-0.3,0.035),Vector3(0.17,0.13,0.26),COCOA,leg)
		limbs.append(leg)
	for side in [-1.0,1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side*0.23,0.78,0)
		actor.add_child(arm)
		ball(Vector3(0,-0.12,0),Vector3(0.15,0.3,0.15),outfit,arm)
		ball(Vector3(0,-0.27,0),Vector3.ONE*0.14,skin,arm)
		limbs.append(arm)
	var treat := Node3D.new()
	limbs[3].add_child(treat)
	treat.position = Vector3(0,-0.3,0.03)
	_cupcake(Vector3.ZERO,treat)
	treat.scale = Vector3.ONE*0.65
	treat.visible = false
	actors.append({"node":actor,"route":route,"target":1,"direction":1,"wait":phase,"limbs":limbs,"treat":treat,"phase":phase})

func _animate_actors(delta: float) -> void:
	for actor: Dictionary in actors:
		var node: Node3D = actor.node
		var limbs: Array = actor.limbs
		if float(actor.wait) > 0.0:
			actor.wait = maxf(0,float(actor.wait)-delta)
			var reach := sin(clampf((3.0-float(actor.wait))/3.0,0,1)*PI)
			limbs[3].rotation.x = -reach*1.6
			actor.treat.visible = float(actor.wait) < 1.6 and int(actor.direction)<0
			for i in 3: limbs[i].rotation.x = lerpf(limbs[i].rotation.x,0,delta*8)
			continue
		var destination: Vector3 = actor.route[int(actor.target)]
		var difference := destination-node.position
		if difference.length() < 0.04:
			if int(actor.target) == actor.route.size()-1:
				actor.direction = -1
				actor.wait = 3.0
			elif int(actor.target) == 0:
				actor.direction = 1
				actor.wait = 2.0
				actor.treat.visible = false
			actor.target = int(actor.target)+int(actor.direction)
		else:
			node.position = node.position.move_toward(destination,delta*0.6)
			node.rotation.y = lerp_angle(node.rotation.y,atan2(difference.x,difference.z),delta*8)
			for i in 4: limbs[i].rotation.x = sin(time*8+float(actor.phase)+float(i%2)*PI)*0.35
'''
(root/'scripts/cafe/cafe_scene.gd').write_text(s,encoding='utf-8')
(root/'scripts/cafe/soft_ink.gdshader').write_text(Path('prototypes/fixed_cafe/soft_ink.gdshader').read_text(),encoding='utf-8')

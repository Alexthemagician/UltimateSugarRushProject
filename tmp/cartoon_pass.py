from pathlib import Path
p=Path('prototypes/fixed_cafe/cafe.gd')
s=p.read_text(encoding='utf-8')
s=s.replace('material.metallic = 0.58 if color.is_equal_approx(GOLD) else metal\n\tmaterial.roughness = rough','''# Painted animation-cel surfaces: broad light bands, no metal reflections.
	material.metallic = 0.0
	material.roughness = 0.9
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://soft_ink.gdshader")
	ink.set_shader_parameter("ink_color", Color(color.r*0.55, color.g*0.48, color.b*0.53))
	material.next_pass = ink''')
s=s.replace('environment.ssao_intensity = 2.0','environment.ssao_intensity = 0.65').replace('environment.ssao_detail = 0.7','environment.ssao_detail = 0.2').replace('environment.reflected_light_source = 1','environment.reflected_light_source = 2')
s=s.replace('\tlabel3("FRESHLY MADE",Vector3(0,0.65,0.665),30,COCOA,station)\n','')
s=s.replace('\t_add_finishing_details()','\t_add_finishing_details()\n\t_decorate_stations()')
s=s.replace('pass_04.png','pass_05.png')
s += '''

func _decorate_stations() -> void:
	var bakery: Node3D = stations[0].node
	# Ceramic utensil crock, spatula, wooden spoon and a looped whisk.
	cylinder(Vector3(-1.01,1.53,0.34),0.12,0.31,MINT,0.15,bakery)
	ring(Vector3(-1.01,1.69,0.34),0.155,0.13,CREAM,bakery)
	rod(Vector3(-1.08,1.6,0.32),Vector3(-1.17,2.03,0.31),0.019,GOLD,bakery)
	ball(Vector3(-1.18,2.05,0.31),Vector3(0.1,0.17,0.045),GOLD,bakery)
	rod(Vector3(-0.99,1.6,0.34),Vector3(-0.95,2.04,0.34),0.018,CREAM,bakery)
	box(Vector3(-0.95,2.04,0.34),Vector3(0.10,0.17,0.04),PINK,0.025,bakery)
	rod(Vector3(-0.93,1.6,0.3),Vector3(-0.85,1.91,0.3),0.018,GOLD,bakery)
	for angle in [0.0,60.0,120.0]:
		var wire := ring(Vector3(-0.84,1.98,0.30),0.09,0.079,CREAM,bakery)
		wire.rotation_degrees = Vector3(90,angle,0)
		wire.scale = Vector3(0.75,1,1.3)
	var coffee: Node3D = stations[1].node
	# A pair of syrup bottles with pump tops and contrasting labels.
	for i in 2:
		var x := 1.03+i*0.23
		cylinder(Vector3(x,1.59,-0.4),0.08,0.39,PINK if i==0 else GOLD,-1,coffee)
		cylinder(Vector3(x,1.59,-0.4),0.083,0.13,CREAM,-1,coffee)
		cylinder(Vector3(x,1.81,-0.4),0.036,0.09,COCOA,-1,coffee)
		rod(Vector3(x,1.86,-0.4),Vector3(x,1.86,-0.28),0.016,COCOA,coffee)
	# Hand-painted milk jug with a rounded handle.
	cylinder(Vector3(0.34,1.53,0.25),0.10,0.28,PINK,0.075,coffee)
	var jug_handle := ring(Vector3(0.45,1.54,0.25),0.075,0.047,CREAM,coffee)
	jug_handle.rotation_degrees.x = 90
	var candy: Node3D = stations[2].node
	# Wrapped bonbons, each with two pinched wrapper ends.
	for i in 3:
		var p := Vector3(-0.69+i*0.67,1.44,0.48)
		var tint: Color = [MINT,PINK,Color("efbf65")][i]
		ball(p,Vector3(0.16,0.10,0.12),tint,candy)
		for direction in [-1,1]:
			var wrapper := cylinder(p+Vector3(direction*0.12,0,0),0.066,0.09,tint.lightened(0.2),0.015,candy)
			wrapper.rotation_degrees.z = direction*90
	var cakes: Node3D = stations[3].node
	# Strawberry dish and a stack of colourful macarons on the front edge.
	cylinder(Vector3(0.58,1.39,0.41),0.18,0.028,MINT,-1,cakes)
	for i in 3:
		var p := Vector3(0.49+i*0.08,1.46,0.41+(i%2)*0.04)
		ball(p,Vector3(0.10,0.13,0.09),Color("e9557d"),cakes)
		ball(p+Vector3(0,0.07,0),Vector3(0.09,0.025,0.08),MINT,cakes)
	for i in 3:
		var p := Vector3(-0.62,1.43+i*0.11,0.4)
		var tint: Color = [MINT,PINK,Color("b2a0d9")][i]
		cylinder(p,0.11,0.05,tint,-1,cakes)
		cylinder(p+Vector3(0,0.036,0),0.105,0.03,CREAM,-1,cakes)
		cylinder(p+Vector3(0,0.069,0),0.11,0.04,tint,-1,cakes)
'''
p.write_text(s,encoding='utf-8')

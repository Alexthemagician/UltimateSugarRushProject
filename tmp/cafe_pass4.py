from pathlib import Path
p=Path('prototypes/fixed_cafe/cafe.gd');s=p.read_text(encoding='utf-8')
s=s.replace('const PINK = Color("e77891")','const PINK = Color("e96c8c")').replace('const MINT = Color("76bdad")','const MINT = Color("63b9a7")')
s=s.replace('Vector3(x,3.8,-1.75),Vector3(x,3.13,-1.75)','Vector3(x,4.3,-1.75),Vector3(x,3.63,-1.75)').replace('Vector3(x,3.0,-1.75)','Vector3(x,3.5,-1.75)').replace('Vector3(x,2.87,-1.75)','Vector3(x,3.37,-1.75)')
s=s.replace('cylinder(Vector3(x,1.7,-0.15),0.22,0.58,Color("cbe4d4"),-1,station)','''var jar := cylinder(Vector3(x,1.7,-0.15),0.22,0.58,Color("cbe4d4"),-1,station)
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.8, 0.98, 0.96, 0.16)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness = 0.12
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		jar.material_override = glass
		jar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring(Vector3(x,1.44,-0.15),0.23,0.21,CREAM,station)
		for layer in 4:
			for candy_index in 5:
				var angle := candy_index * TAU/5 + layer*0.7
				ball(Vector3(x+cos(angle)*0.13,1.5+layer*0.115,-0.15+sin(angle)*0.13),Vector3(0.11,0.09,0.11),[Color("e54479"),Color("efad3c"),Color("78bd52")][i],station)''')
s=s.replace('Vector3(x-0.1+(j%2)*0.16,1.49+(j/2)*0.14,0.055)','Vector3(x-0.07+(j%2)*0.13,1.49+(j/2)*0.14,-0.08)')
s=s.replace('pass_03.png','pass_04.png')
s=s.replace('\t# Soft oven glow', '''	# Window curtains: repeat the same cream-and-rose stripes as the awning.
	for i in 10:
		var z := -0.85+i*0.29
		box(Vector3(-3.99,3.23,z),Vector3(0.17,0.26,0.29),PINK if i%2==0 else CREAM,0.045)
		ball(Vector3(-3.93,3.1,z),Vector3(0.12,0.16,0.28),PINK if i%2==0 else CREAM)
	# Medallion on the left wall, with an oversized sculpted strawberry.
	var plate := cylinder(Vector3(-4.12,2.5,2.83),0.48,0.08,CREAM)
	plate.rotation_degrees.z = 90
	var frame := ring(Vector3(-4.06,2.5,2.83),0.49,0.44,GOLD)
	frame.rotation_degrees.z = 90
	ball(Vector3(-3.99,2.46,2.83),Vector3(0.12,0.49,0.39),PINK)
	for i in 3:
		var leaf := ball(Vector3(-3.96,2.72,2.74+i*0.09),Vector3(0.07,0.14,0.18),MINT)
		leaf.rotation_degrees.x = (i-1)*30
	for i in 3:
		for j in 2:
			ball(Vector3(-3.918,2.35+i*0.10,2.76+j*0.13),Vector3(0.024,0.036,0.02),GOLD)
	# Tidy folded towels and a recipe card add useful scale cues.
	var coffee: Node3D = stations[1].node
	for i in 3: box(Vector3(1.07,1.4+i*0.035,-0.08),Vector3(0.3,0.04,0.34),CREAM if i%2==0 else PINK,0.015,coffee)
	var recipe := box(Vector3(-0.04,1.42,0.49),Vector3(0.21,0.24,0.035),CREAM,0.01,bakery)
	recipe.rotation_degrees.x = -15
	label3("RECIPE",Vector3(-0.04,1.48,0.515),9,COCOA,bakery)
	# Soft oven glow''')
p.write_text(s,encoding='utf-8')

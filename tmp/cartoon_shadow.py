from pathlib import Path
p=Path('prototypes/fixed_cafe/cafe.gd');s=p.read_text(encoding='utf-8')
a=s.index('\tvar ink := ShaderMaterial.new()');b=s.index('\tmaterials[key] = material',a)
s=s[:a]+s[b:]
s=s.replace('\tparent.add_child(node)\n\treturn node','''	parent.add_child(node)
	# Separate ink hulls must never cast shadows onto the painted surface.
	var outline := MeshInstance3D.new()
	outline.mesh = mesh
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://soft_ink.gdshader")
	ink.set_shader_parameter("ink_color", Color(color.r*0.55, color.g*0.48, color.b*0.53))
	outline.material_override = ink
	node.add_child(outline)
	return node''',1)
s=s.replace('pass_06.png','pass_07.png');p.write_text(s,encoding='utf-8')
p=Path('prototypes/fixed_cafe/README.md');s=p.read_text(encoding='utf-8').replace('pass_06','pass_07').replace('sixth pass','seventh pass');p.write_text(s,encoding='utf-8')

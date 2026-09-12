shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform vec3 ink_color : source_color = vec3(0.42, 0.23, 0.30);
void vertex() {
    VERTEX += NORMAL * 0.012;
}
void fragment() {
    ALBEDO = ink_color;
}

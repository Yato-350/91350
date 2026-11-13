shader_type spatial;
render_mode unshaded, cull_disabled;
// Cône de vision posé au sol : un damier tramé (des pixels jetés, pas de transparence).

uniform vec3 tint : source_color = vec3(0.784, 0.125, 0.173);

void fragment() {
	ivec2 cell = ivec2(FRAGCOORD.xy) % 2;
	if (cell.x != cell.y) {
		discard;
	}
	ALBEDO = tint;
}

shader_type spatial;
// Damier d'un mètre calculé dans le repère du monde.
// Sur la zone de test, il sert à juger la netteté du défilement.

uniform vec3 color_a : source_color = vec3(0.357, 0.373, 0.412);
uniform vec3 color_b : source_color = vec3(0.435, 0.451, 0.490);
uniform float cell_size = 1.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world_position.xz / cell_size + 0.001);
	ALBEDO = mix(color_a, color_b, mod(cell.x + cell.y, 2.0));
	ROUGHNESS = 1.0;
}

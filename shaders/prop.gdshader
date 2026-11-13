shader_type spatial;
// Objets et décor en voxels : couleur par sommet (sRGB, comme le matériau standard avec
// « vertex_color_is_srgb »), et vue à travers eux quand ils cachent Akan.

#include "res://shaders/cutaway.gdshaderinc"

uniform float cut_height = 2.4;
// Les sols et ce qui est au ras du sol ne sont jamais découpés.
uniform float min_height = 0.25;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Comme le matériau standard : la conversion n'a lieu que si la sortie est linéaire
	// (le renderer Compatibility travaille directement en sRGB).
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(
			pow((COLOR.rgb + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)),
			COLOR.rgb * (1.0 / 12.92),
			lessThan(COLOR.rgb, vec3(0.04045)));
	}
}

void fragment() {
	if (cutaway(VERTEX, world_position.y, FRAGCOORD.xy, VIEW_MATRIX, cut_height, min_height)) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}

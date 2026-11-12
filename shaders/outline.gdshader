shader_type spatial;
// Contours du rendu « pixel 2.5D ».
// Un quad plein écran lit la texture de profondeur et dessine un trait là où la
// profondeur « casse » : silhouettes et arêtes.
render_mode unshaded, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec3 outline_color : source_color = vec3(0.078, 0.082, 0.102);
// Cassure de profondeur (en mètres) à partir de laquelle on trace un trait.
uniform float threshold = 0.08;

void vertex() {
	// Le quad couvre tout l'écran, où qu'il soit placé dans la scène.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Distance à la caméra (en mètres) du point visible à cette position de l'écran.
float view_depth(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return -view.z / view.w;
}

void fragment() {
	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	float center = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float left = view_depth(SCREEN_UV - vec2(pixel.x, 0.0), INV_PROJECTION_MATRIX);
	float right = view_depth(SCREEN_UV + vec2(pixel.x, 0.0), INV_PROJECTION_MATRIX);
	float up = view_depth(SCREEN_UV - vec2(0.0, pixel.y), INV_PROJECTION_MATRIX);
	float down = view_depth(SCREEN_UV + vec2(0.0, pixel.y), INV_PROJECTION_MATRIX);
	// En projection orthographique, la profondeur varie linéairement sur un plan :
	// son laplacien y est nul, donc pas de faux trait sur les pentes.
	float laplacian = abs(left + right - 2.0 * center) + abs(up + down - 2.0 * center);
	float edge = step(threshold, laplacian);
	// Sur le cadre de l'image, un voisin manque : le laplacien y serait faux. Pas de trait.
	vec2 inside = step(pixel, SCREEN_UV) * step(SCREEN_UV, vec2(1.0) - pixel);
	edge *= inside.x * inside.y;
	ALBEDO = mix(texture(screen_texture, SCREEN_UV).rgb, outline_color, edge);
}

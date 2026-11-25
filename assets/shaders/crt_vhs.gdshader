shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform float scanline_strength : hint_range(0.0, 0.25, 0.005) = 0.055;
uniform float aberration_amount : hint_range(0.0, 3.0, 0.05) = 0.65;
uniform float vignette_strength : hint_range(0.0, 0.35, 0.01) = 0.10;
uniform float noise_amount : hint_range(0.0, 0.06, 0.001) = 0.007;

float grain(vec2 pixel, float frame) {
	return fract(52.9829189 * fract(dot(pixel + frame * 0.071, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float edge = smoothstep(0.38, 1.30, length(centered));
	vec2 shift = centered * edge * aberration_amount * pixel;
	vec3 color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	color.r = textureLod(screen_texture, SCREEN_UV + shift, 0.0).r;
	color.b = textureLod(screen_texture, SCREEN_UV - shift, 0.0).b;

	float row = floor(SCREEN_UV.y / pixel.y);
	float scanline = mod(row, 3.0) < 1.0 ? 1.0 : 0.0;
	color *= 1.0 - scanline * scanline_strength;
	color *= vec3(0.992, 1.0, 0.987);
	color *= 1.0 - vignette_strength * edge * edge;
	color += (grain(floor(SCREEN_UV / pixel), floor(TIME * 23.0)) - 0.5) * noise_amount;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}

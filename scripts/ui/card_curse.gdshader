shader_type canvas_item;
// Enemy cards: glowing skull eyes that pulse and dark smoke rising from the
// bottom, both stronger for stronger enemies.
uniform float smoke : hint_range(0.0, 1.0) = 0.0;
uniform float eyes : hint_range(0.0, 1.0) = 0.0;
uniform vec4 eye_color : source_color = vec4(1.0, 0.19, 0.19, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	// Glowing eyes: the eye colour pulses brighter.
	if (eyes > 0.0 && distance(c.rgb, eye_color.rgb) < 0.12) {
		float pulse = 0.6 + 0.4 * sin(TIME * 3.0);
		c.rgb = mix(c.rgb, vec3(1.0, 0.75, 0.55), pulse * eyes);
	}
	// Smoke: soft dark wisps drifting upwards, thickest near the bottom.
	if (smoke > 0.0) {
		vec2 p = vec2(UV.x * 4.0, UV.y * 6.0 + TIME * 0.6);
		float n = noise(p) * 0.6 + noise(p * 2.1 + 3.0) * 0.4;
		float height = smoothstep(0.25, 1.0, UV.y);
		float wisp = smoothstep(0.42, 0.85, n) * height * smoke;
		c.rgb = mix(c.rgb, vec3(0.42, 0.36, 0.40), wisp * 0.55);   // grey smoke
		c.rgb += vec3(0.45, 0.08, 0.06) * smoothstep(0.78, 0.95, n) * height * smoke * 0.6;  // embers glowing in it
	}
	COLOR = c;
}

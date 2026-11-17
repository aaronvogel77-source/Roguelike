shader_type canvas_item;
// Rarity effects on a card face: a gloss streak sweeping across (metal),
// sparkles (gold) and a polychrome rainbow shimmer (legendary).
uniform float gloss : hint_range(0.0, 1.0) = 0.0;
uniform float gloss_speed = 0.35;
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;
uniform float poly : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// Polychrome: the colours drift with position and time, strongest on bright pixels.
	if (poly > 0.0) {
		vec3 rainbow = hue(UV.x * 0.8 + UV.y * 0.6 - TIME * 0.18);
		c.rgb = mix(c.rgb, c.rgb * 0.45 + rainbow * (0.35 + lum * 0.6), poly * (0.35 + lum * 0.45));
	}
	// Gloss: a diagonal band of light sweeping over the card every few seconds.
	if (gloss > 0.0) {
		float pos = fract(TIME * gloss_speed) * 2.6 - 0.8;
		float band = 1.0 - smoothstep(0.0, 0.09, abs(UV.x + UV.y * 0.5 - pos));
		c.rgb += vec3(1.0, 0.97, 0.88) * band * gloss * 0.55;
	}
	// Sparkles: tiny stars blinking on bright pixels.
	if (sparkle > 0.0) {
		vec2 cell = floor(UV * vec2(18.0, 26.0));
		float seed = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		float blink = smoothstep(0.92, 1.0, sin(TIME * 2.0 + seed * 40.0));
		c.rgb += vec3(1.0, 0.95, 0.8) * blink * step(0.86, seed) * step(0.45, lum) * sparkle;
	}
	COLOR = c * tint;
}

shader_type canvas_item;

uniform float strength : hint_range(0.0, 2.0) = 0.5;
uniform bool reverse = false;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	float factor;
	if (reverse) {
		factor = 1.0 - dist * dist * dist * strength;
	} else {
		factor = 1.0 + dist * dist * dist * strength;
	}
	vec2 distorted = uv * factor + 0.5;
	distorted = clamp(distorted, 0.0, 1.0);
	COLOR = texture(TEXTURE, distorted);
}
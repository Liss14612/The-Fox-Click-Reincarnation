shader_type canvas_item;

uniform float angle : hint_range(-6.28318, 6.28318) = 0.0;
uniform vec2 pivot = vec2(0.5, 0.56);
uniform float inner_radius = 0.23;
uniform float feather = 0.04;

void fragment() {
	vec2 uv = UV;
	vec2 delta = uv - pivot;
	float dist = length(delta);

	// Маска круга внутри спирали: 1.0 в центре, 0.0 за пределами (ушки не трогаем)
	float mask = 1.0 - smoothstep(inner_radius - feather, inner_radius, dist);

	float rot = angle * mask;
	float s = sin(rot);
	float c = cos(rot);
	mat2 m = mat2(vec2(c, -s), vec2(s, c));

	vec2 rotated_uv = pivot + m * delta;
	COLOR = texture(TEXTURE, rotated_uv) * COLOR;
}
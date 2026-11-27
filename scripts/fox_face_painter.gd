class_name FoxFacePainter
extends RefCounted

const LOGO_TEXTURE_PATH: String = "res://assets/spiral_fox_logo.webp"
const C_BONE: Color = Color("e6ded4")

const UNIFIED_SPIRAL_SHADER := """
shader_type canvas_item;

uniform float angle = 0.0;
uniform vec2 center_px = vec2(640.0, 360.0);
uniform float size_px = 400.0;
uniform vec2 spiral_pivot = vec2(-0.011, 0.032);
uniform float spiral_radius = 0.112;
uniform float feather = 0.04;

void fragment() {
	float safe_size = max(size_px, 1.0);
	vec2 local_pos = (FRAGCOORD.xy - center_px) / safe_size;

	vec4 base_col = texture(TEXTURE, UV);
	vec4 out_col = base_col;

	if (abs(local_pos.x) <= 0.5 && abs(local_pos.y) <= 0.5) {
		vec2 rel = local_pos - spiral_pivot;
		float dist = length(rel);

		float weight = 1.0 - smoothstep(spiral_radius - feather, spiral_radius, dist);
		float twist = mix(0.8, 1.25, clamp(1.0 - dist / max(spiral_radius, 0.001), 0.0, 1.0));
		float subtle_rot = sin(angle) * 0.42 * weight * twist;

		float s = sin(subtle_rot);
		float c = cos(subtle_rot);
		mat2 rot_m = mat2(vec2(c, -s), vec2(s, c));

		vec2 rotated_local = spiral_pivot + rot_m * rel;
		vec2 tex_uv = clamp(rotated_local + vec2(0.5), vec2(0.0), vec2(1.0));
		vec4 spun_col = texture(TEXTURE, tex_uv);

		out_col = mix(base_col, spun_col, weight);
	}

	COLOR = out_col * COLOR;
}
"""

@export var logo_scale_ratio: float = 0.56
@export var spiral_speed: float = 1.1

var reveal: float = 1.0

var _tex: Texture2D = null
var _mat: ShaderMaterial = null
var _spiral_angle: float = 0.0
var _calm: bool = false


func _init() -> void:
	if ResourceLoader.exists(LOGO_TEXTURE_PATH):
		var res: Resource = ResourceLoader.load(LOGO_TEXTURE_PATH)
		if res is Texture2D:
			_tex = res as Texture2D

	var sh := Shader.new()
	sh.code = UNIFIED_SPIRAL_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("spiral_pivot", Vector2(-0.011, 0.032))
	_mat.set_shader_parameter("spiral_radius", 0.112)
	_mat.set_shader_parameter("feather", 0.04)

	_calm = FoxSettings.reduce_noise


func update(delta: float, _local_mouse: Vector2, _canvas_size: Vector2, _viewport_width: float) -> void:
	_calm = FoxSettings.reduce_noise
	var speed: float = 0.0 if _calm else spiral_speed
	_spiral_angle = wrapf(_spiral_angle + delta * speed, 0.0, TAU)
	if _mat != null:
		_mat.set_shader_parameter("angle", _spiral_angle)


func paint(canvas: CanvasItem, canvas_size: Vector2) -> void:
	if canvas == null or canvas_size.x <= 1.0 or canvas_size.y <= 1.0:
		return

	_calm = FoxSettings.reduce_noise
	var rv: float = clampf(reveal, 0.0, 1.0)
	var alpha: float = smoothstep(0.0, 0.45, rv)
	var center: Vector2 = canvas_size * 0.5
	var size_px: float = minf(canvas_size.x, canvas_size.y) * logo_scale_ratio * lerpf(0.94, 1.0, rv)
	var global_center: Vector2 = canvas.get_global_transform() * center

	if _mat != null:
		_mat.set_shader_parameter("center_px", global_center)
		_mat.set_shader_parameter("size_px", size_px)
		if canvas.material != _mat:
			canvas.material = _mat

	canvas.draw_set_transform(center, 0.0, Vector2.ONE)
	if _tex != null:
		var rect: Rect2 = Rect2(-size_px * 0.5, -size_px * 0.5, size_px, size_px)
		canvas.draw_texture_rect(_tex, rect, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		canvas.draw_arc(Vector2.ZERO, size_px * 0.28, 0.0, TAU, 48, Color(C_BONE, alpha), 3.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

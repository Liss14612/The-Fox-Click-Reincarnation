extends Control

const CANDIDATE_PATHS: PackedStringArray = [
	"res://assets/ui/red_fox_studio_title.png",
	"res://assets/ui/red_fox_studio_title.jpg",
	"res://assets/ui/red_fox_studio_title.webp",
	"res://assets/logo/red_fox_title.png",
	"res://assets/logo/red_fox_title.webp"
]

@export var title_texture: Texture2D
@export_range(0.5, 2.5, 0.05) var width_scale: float = 1.45
@export_range(0.15, 0.9, 0.02) var height_scale: float = 0.42
@export var use_additive_blend: bool = true
@export var glitch_interval_min: float = 0.85
@export var glitch_interval_max: float = 2.1
@export var glitch_duration: float = 0.07

var _title_rect: TextureRect
var _glitch_cd: float = 1.0
var _glitch_left: float = 0.0
var _base_pos: Vector2 = Vector2.ZERO
var _has_base_pos: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.y < 72.0:
		custom_minimum_size.y = 72.0
	_ensure_title_rect()
	_apply_texture()
	_sync_layout()

	if not resized.is_connected(_sync_layout):
		resized.connect(_sync_layout)


func _exit_tree() -> void:
	if resized.is_connected(_sync_layout):
		resized.disconnect(_sync_layout)


func _ensure_title_rect() -> void:
	for child in get_children():
		child.queue_free()

	_title_rect = TextureRect.new()
	_title_rect.name = "StudioTitleRect"
	_title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if use_additive_blend:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_title_rect.material = mat

	add_child(_title_rect)


func _resolve_texture() -> Texture2D:
	if title_texture != null:
		return title_texture
	for path: String in CANDIDATE_PATHS:
		if ResourceLoader.exists(path):
			var loaded := load(path)
			if loaded is Texture2D:
				return loaded as Texture2D
	push_warning("StudioEmblem: текстура названия RED FOX STUDIO не найдена. Назначь Title Texture в Инспекторе или положи файл в res://assets/ui/.")
	return null


func _apply_texture() -> void:
	if _title_rect == null:
		return
	var tex: Texture2D = _resolve_texture()
	_title_rect.texture = tex
	_title_rect.visible = tex != null
	_title_rect.modulate = Color.WHITE


func _is_noise_reduced() -> bool:
	var root := get_tree().root
	if root != null and root.has_node("FoxSettings"):
		var fs := root.get_node("FoxSettings")
		if "reduce_noise" in fs:
			return bool(fs.reduce_noise)
	return false


func _sync_layout() -> void:
	if not _has_base_pos:
		_base_pos = position
		_has_base_pos = true

	if _title_rect == null:
		return

	var avail_w: float = maxf(maxf(size.x, custom_minimum_size.x), 140.0)
	var avail_h: float = maxf(maxf(size.y, custom_minimum_size.y), 64.0)
	var image_width: float = avail_w * width_scale
	var image_height: float = maxf(image_width * height_scale, 56.0)

	_title_rect.size = Vector2(image_width, image_height)
	_title_rect.position = Vector2((size.x - image_width) * 0.5, (size.y - image_height) * 0.5)


func _reset_glitch() -> void:
	_glitch_left = 0.0
	position = Vector2(_base_pos.x, _base_pos.y)
	if _title_rect != null:
		_title_rect.modulate = Color.WHITE


func _process(delta: float) -> void:
	if not _has_base_pos:
		_base_pos = position
		_has_base_pos = true

	if _is_noise_reduced():
		if _glitch_left > 0.0 or absf(position.x - _base_pos.x) > 0.01:
			_reset_glitch()
		return

	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0:
			_reset_glitch()
		return

	_glitch_cd -= delta
	if _glitch_cd <= 0.0:
		_glitch_cd = randf_range(glitch_interval_min, glitch_interval_max)
		_glitch_left = glitch_duration
		position = Vector2(_base_pos.x + randf_range(-4.0, 4.0), _base_pos.y)
		if _title_rect != null:
			_title_rect.modulate = Color(1.0, 0.78, 0.82, 1.0)

extends Control

const NEXT_SCENE := "res://scenes/main_menu.tscn"
const HOLD_TIME := 0.8
const AUTO_TIME := 4.0

const RED := Color("#ff1e38")
const RED_DEEP := Color("#c0392b")
const DIM := Color("#7a5a60")
const TXT := Color("#ecd9dc")

@onready var logo_stage: Control = %LogoStage
@onready var logo_canvas: Control = %LogoCanvas
@onready var studio_lbl: Label = %StudioLabel
@onready var warn_stage: Control = %WarnStage
@onready var icon_canvas: Control = %IconCanvas
@onready var controls_txt: Label = %ControlsText
@onready var esc_txt: Label = %EscText
@onready var warn_title: Label = %WarnTitle
@onready var warn_body: Label = %WarnBody
@onready var skip_hint: Label = %SkipHint
@onready var hold_bar: ProgressBar = %HoldBar
@onready var fade: ColorRect = %Fade

var _stage: int = 0
var _holding: bool = false
var _hold: float = 0.0
var _warn_time: float = 0.0
var _glitch_off: Vector2 = Vector2.ZERO
var _glitch_left: float = 0.0
var _glitch_cd: float = 0.9
var _leaving: bool = false
var _spiral: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"JetBrains Mono", "Consolas", "Cascadia Mono", "Courier New", "DejaVu Sans Mono", "monospace"
	])
	var th := Theme.new()
	th.default_font = f
	th.default_font_size = 16
	theme = th

	_spiral.resize(97)
	for i: int in range(97):
		var t: float = float(i) / 96.0
		_spiral[i] = Vector2.from_angle(t * TAU * 2.6 - PI * 0.5) * (0.14 + 0.86 * t)

	studio_lbl.add_theme_font_size_override("font_size", 28)
	studio_lbl.add_theme_color_override("font_color", Color.WHITE)
	studio_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	controls_txt.text = "ЛКМ, ПКМ или Пробел\nдля взаимодействия"
	esc_txt.text = "Снижение шума доступно\nв настройках"

	controls_txt.add_theme_color_override("font_color", TXT)
	esc_txt.add_theme_color_override("font_color", TXT)
	warn_body.add_theme_color_override("font_color", TXT)
	for lbl: Label in [controls_txt, esc_txt, warn_body]:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	warn_title.add_theme_font_size_override("font_size", 38)
	warn_title.add_theme_color_override("font_color", RED)
	warn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	warn_body.add_theme_font_size_override("font_size", 19)
	skip_hint.add_theme_color_override("font_color", DIM)
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var fill := StyleBoxFlat.new()
	fill.bg_color = RED
	var back := StyleBoxFlat.new()
	back.bg_color = Color("#1a0205")
	back.border_width_left = 1
	back.border_width_right = 1
	back.border_width_top = 1
	back.border_width_bottom = 1
	back.border_color = RED_DEEP
	hold_bar.add_theme_stylebox_override("fill", fill)
	hold_bar.add_theme_stylebox_override("background", back)
	hold_bar.show_percentage = false
	hold_bar.max_value = 1.0
	hold_bar.value = 0.0

	if not resized.is_connected(_layout):
		resized.connect(_layout)
	if not logo_canvas.draw.is_connected(_draw_logo):
		logo_canvas.draw.connect(_draw_logo)
	if not icon_canvas.draw.is_connected(_draw_icons):
		icon_canvas.draw.connect(_draw_icons)

	_layout()

	logo_stage.modulate.a = 0.0
	warn_stage.modulate.a = 0.0
	warn_stage.visible = false
	fade.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(logo_stage, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.0)
	tw.tween_property(logo_stage, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_start_warning)

func _exit_tree() -> void:
	if resized.is_connected(_layout):
		resized.disconnect(_layout)
	if logo_canvas != null and logo_canvas.draw.is_connected(_draw_logo):
		logo_canvas.draw.disconnect(_draw_logo)
	if icon_canvas != null and icon_canvas.draw.is_connected(_draw_icons):
		icon_canvas.draw.disconnect(_draw_icons)

func _get_cols_metrics(w: float) -> Dictionary:
	var col_w: float = clampf(w * 0.28, 220.0, 320.0)
	var gap: float = clampf(w * 0.08, 48.0, 120.0)
	var total_w: float = col_w * 2.0 + gap
	var start_x: float = (w - total_w) * 0.5
	if total_w > w - 48.0:
		col_w = maxf(180.0, (w - 84.0) * 0.5)
		gap = 36.0
		start_x = (w - (col_w * 2.0 + gap)) * 0.5
	return {
		"col_w": col_w,
		"left_x": start_x,
		"right_x": start_x + col_w + gap
	}

func _get_icons_offset_y(h: float) -> float:
	# Блок инструкций смещён ближе к центру экрана
	return maxf(230.0, h * 0.36)

func _layout() -> void:
	var w: float = size.x
	var h: float = size.y
	var m: Dictionary = _get_cols_metrics(w)
	var col_w: float = float(m["col_w"])
	var left_x: float = float(m["left_x"])
	var right_x: float = float(m["right_x"])
	var icons_y: float = _get_icons_offset_y(h)

	studio_lbl.position = Vector2(0.0, h * 0.5 + 150.0)
	studio_lbl.size = Vector2(w, 40.0)

	# Предупреждение о светочувствительности вверху
	var warn_top: float = clampf(h * 0.08, 36.0, 96.0)
	warn_title.position = Vector2(w * 0.06, warn_top)
	warn_title.size = Vector2(w * 0.88, 52.0)

	warn_body.position = Vector2(w * 0.1, warn_top + 62.0)
	warn_body.size = Vector2(w * 0.8, 84.0)

	# Тексты инструкций строго под своими иконками в центральной зоне
	var text_y: float = icons_y + 194.0
	controls_txt.position = Vector2(left_x, text_y)
	controls_txt.size = Vector2(col_w, 64.0)

	esc_txt.position = Vector2(right_x, text_y)
	esc_txt.size = Vector2(col_w, 64.0)

	skip_hint.position = Vector2(0.0, h - 110.0)
	skip_hint.size = Vector2(w, 30.0)

	hold_bar.position = Vector2(w * 0.5 - 150.0, h - 70.0)
	hold_bar.size = Vector2(300.0, 10.0)

	logo_canvas.queue_redraw()
	icon_canvas.queue_redraw()

# ---------------------------------------------------------------- ЛОГО

func _draw_logo() -> void:
	var c: Vector2 = logo_canvas.size * 0.5 + Vector2(0.0, -30.0)
	if _glitch_left > 0.0:
		_logo_pass(c + _glitch_off, RED, true)
		_logo_pass(c - _glitch_off * 0.6, Color(0.2, 1.0, 0.9, 0.6), true)
	_logo_pass(c, Color.WHITE, false)

func _logo_pass(c: Vector2, tint: Color, flat: bool) -> void:
	var r: float = 110.0
	logo_canvas.draw_circle(c, r * 1.55, Color(1.0, 0.0, 0.15, 0.07))
	var pts := PackedVector2Array()
	pts.resize(_spiral.size())
	for i: int in range(_spiral.size()):
		pts[i] = c + _spiral[i] * r

	var ear_fill: Color = tint if flat else RED_DEEP
	var line_col: Color = tint if flat else Color.WHITE
	var back_col: Color = tint if flat else Color.BLACK

	for sgn: float in [-1.0, 1.0]:
		var tri := PackedVector2Array([
			c + Vector2(sgn * r * 0.95, -r * 0.30),
			c + Vector2(sgn * r * 0.72, -r * 1.30),
			c + Vector2(sgn * r * 0.12, -r * 0.85)
		])
		logo_canvas.draw_colored_polygon(tri, ear_fill)
		logo_canvas.draw_polyline(tri + PackedVector2Array([tri[0]]), line_col, 6.0, true)

	logo_canvas.draw_polyline(pts, back_col, 22.0, true)
	logo_canvas.draw_polyline(pts, line_col, 11.0, true)
	logo_canvas.draw_circle(c, 7.0, ear_fill)

func _process(delta: float) -> void:
	if _stage == 0 and not FoxSettings.reduce_noise:
		_glitch_cd -= delta
		if _glitch_cd <= 0.0:
			_glitch_cd = randf_range(0.5, 1.1)
			_glitch_left = 0.09
			_glitch_off = Vector2(randf_range(-14.0, 14.0), randf_range(-4.0, 4.0))
			logo_canvas.queue_redraw()
		elif _glitch_left > 0.0:
			_glitch_left -= delta
			if _glitch_left <= 0.0:
				logo_canvas.queue_redraw()
	elif _stage == 1 and not _leaving:
		_warn_time += delta
		if _holding:
			_hold += delta
		else:
			_hold = maxf(0.0, _hold - delta * 2.0)
		hold_bar.value = _hold / HOLD_TIME
		if _hold >= HOLD_TIME or _warn_time >= AUTO_TIME:
			_leave()

# ---------------------------------------------------------------- ПРЕДУПРЕЖДЕНИЕ

func _start_warning() -> void:
	_stage = 1
	logo_stage.visible = false
	warn_stage.visible = true
	create_tween().tween_property(warn_stage, "modulate:a", 1.0, 0.5)

func _sb(col: Color, r: Array = [8, 8, 8, 8]) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.corner_radius_top_left = r[0]
	s.corner_radius_top_right = r[1]
	s.corner_radius_bottom_right = r[2]
	s.corner_radius_bottom_left = r[3]
	return s

func _mouse_icon(pos: Vector2, left: bool) -> void:
	var sz := Vector2(60.0, 86.0)
	icon_canvas.draw_style_box(_sb(Color("#e8e0e0"), [30, 30, 30, 30]), Rect2(pos, sz))
	var hl := Rect2(pos + (Vector2.ZERO if left else Vector2(sz.x * 0.5, 0.0)), Vector2(sz.x * 0.5, 38.0))
	var rr: Array = [30, 0, 0, 0] if left else [0, 30, 0, 0]
	icon_canvas.draw_style_box(_sb(RED, rr), hl)
	icon_canvas.draw_line(pos + Vector2(0.0, 38.0), pos + Vector2(sz.x, 38.0), Color.BLACK, 2.0)
	icon_canvas.draw_line(pos + Vector2(sz.x * 0.5, 0.0), pos + Vector2(sz.x * 0.5, 38.0), Color.BLACK, 2.0)

func _key_icon(rect: Rect2, label: String, fsize: int) -> void:
	icon_canvas.draw_style_box(_sb(Color("#6a5a5e"), [6, 6, 6, 6]), Rect2(rect.position + Vector2(0.0, 6.0), rect.size))
	icon_canvas.draw_style_box(_sb(Color("#e8e0e0"), [6, 6, 6, 6]), rect)
	var font := icon_canvas.get_theme_default_font()
	var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	icon_canvas.draw_string(
		font,
		rect.position + Vector2((rect.size.x - ts.x) * 0.5, (rect.size.y + ts.y * 0.6) * 0.5),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fsize,
		Color.BLACK
	)

func _draw_icons() -> void:
	var w: float = icon_canvas.size.x
	var h: float = icon_canvas.size.y
	var m: Dictionary = _get_cols_metrics(w)
	var col_w: float = float(m["col_w"])
	var left_cx: float = float(m["left_x"]) + col_w * 0.5
	var right_cx: float = float(m["right_x"]) + col_w * 0.5
	var base_y: float = _get_icons_offset_y(h)

	_mouse_icon(Vector2(left_cx - 72.0, base_y), true)
	_mouse_icon(Vector2(left_cx + 12.0, base_y), false)
	_key_icon(Rect2(left_cx - 120.0, base_y + 106.0, 240.0, 50.0), "Пробел", 20)

	_key_icon(Rect2(right_cx - 44.0, base_y + 106.0, 88.0, 50.0), "Esc", 20)

# ---------------------------------------------------------------- ВВОД / ВЫХОД

func _input(event: InputEvent) -> void:
	if _stage != 1:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed() and not event.is_echo():
			_holding = true
		elif event.is_released():
			_holding = false

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.4)
	tw.tween_callback(_go_to_next_scene)

func _go_to_next_scene() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)

extends Control

const NEXT_SCENE := "res://scenes/main_menu.tscn"
const STUDIO_SCRIPT := preload("res://scripts/studio_emblem.gd")
const STUDIO_MAIN := "RED FOX STUDIO"

const LOGO_HOLD_TIME := 3.2
const WARN_HOLD_TIME := 4.2
const HOLD_TIME := 0.8
const AUTO_TIME := WARN_HOLD_TIME

const RED := Color("#c9182b")
const RED_BRIGHT := Color("#ff1e38")
const RED_SUB := Color("#8f1424")
const RED_DARK := Color("#4a060e")
const BONE := Color("#ede2e4")
const DIM := Color("#7a5a60")
const TXT := Color("#ecd9dc")

@onready var bg: ColorRect = get_node_or_null("%Bg")
@onready var logo_stage: Control = get_node_or_null("%LogoStage")
@onready var logo_canvas: Control = get_node_or_null("%LogoCanvas")
@onready var studio_lbl: Label = get_node_or_null("%StudioLabel")
@onready var warn_stage: Control = get_node_or_null("%WarnStage")
@onready var icon_canvas: Control = get_node_or_null("%IconCanvas")
@onready var controls_txt: Label = get_node_or_null("%ControlsText")
@onready var esc_txt: Label = get_node_or_null("%EscText")
@onready var warn_title: Label = get_node_or_null("%WarnTitle")
@onready var warn_body: Label = get_node_or_null("%WarnBody")
@onready var skip_hint: Label = get_node_or_null("%SkipHint")
@onready var hold_bar: ProgressBar = get_node_or_null("%HoldBar")
@onready var fade: ColorRect = get_node_or_null("%Fade")

var _face: FoxFacePainter = FoxFacePainter.new()
var _studio_emblem: Control
var _stage: int = 0
var _holding: bool = false
var _hold: float = 0.0
var _warn_time: float = 0.0
var _glitch_off: Vector2 = Vector2.ZERO
var _glitch_left: float = 0.0
var _glitch_cd: float = 0.9
var _logo_fading_out: bool = false
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

	if bg != null:
		bg.color = Color.BLACK
		bg.modulate = Color.WHITE
		bg.visible = true

	_spiral.resize(97)
	for i: int in range(97):
		var t: float = float(i) / 96.0
		_spiral[i] = Vector2.from_angle(t * TAU * 2.6 - PI * 0.5) * (0.14 + 0.86 * t)

	_setup_studio_emblem()

	if controls_txt != null:
		controls_txt.text = "ЛКМ, ПКМ или Пробел\nдля взаимодействия"
		controls_txt.add_theme_color_override("font_color", TXT)
		controls_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		controls_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if esc_txt != null:
		esc_txt.text = "Снижение шума доступно\nв настройках"
		esc_txt.add_theme_color_override("font_color", TXT)
		esc_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		esc_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if warn_body != null:
		warn_body.add_theme_color_override("font_color", TXT)
		warn_body.add_theme_font_size_override("font_size", 19)
		warn_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if warn_title != null:
		warn_title.add_theme_font_size_override("font_size", 38)
		warn_title.add_theme_color_override("font_color", RED_BRIGHT)
		warn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if skip_hint != null:
		skip_hint.add_theme_color_override("font_color", DIM)
		skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skip_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if hold_bar != null:
		var fill := StyleBoxFlat.new()
		fill.bg_color = RED_BRIGHT
		var back := StyleBoxFlat.new()
		back.bg_color = Color("#1a0205")
		back.border_width_left = 1
		back.border_width_right = 1
		back.border_width_top = 1
		back.border_width_bottom = 1
		back.border_color = RED_DARK
		hold_bar.add_theme_stylebox_override("fill", fill)
		hold_bar.add_theme_stylebox_override("background", back)
		hold_bar.show_percentage = false
		hold_bar.max_value = 1.0
		hold_bar.value = 0.0

	if not resized.is_connected(_layout):
		resized.connect(_layout)
	if logo_canvas != null and not logo_canvas.draw.is_connected(_draw_logo):
		logo_canvas.draw.connect(_draw_logo)
	if icon_canvas != null and not icon_canvas.draw.is_connected(_draw_icons):
		icon_canvas.draw.connect(_draw_icons)

	_layout()

	_logo_fading_out = false
	if logo_stage != null:
		logo_stage.visible = true
		logo_stage.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if warn_stage != null:
		warn_stage.modulate = Color(1.0, 1.0, 1.0, 0.0)
		warn_stage.visible = false
	if fade != null:
		fade.color = Color.BLACK
		fade.modulate = Color(1.0, 1.0, 1.0, 0.0)
		fade.visible = true
	_face.reveal = 0.0

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.set_parallel(true)
	if logo_stage != null:
		tw.tween_property(logo_stage, "modulate:a", 1.0, 0.9)
	tw.tween_property(_face, "reveal", 1.0, 1.0)
	tw.set_parallel(false)
	tw.tween_interval(LOGO_HOLD_TIME)
	tw.tween_callback(_begin_logo_fade_out)
	if logo_stage != null:
		tw.tween_property(logo_stage, "modulate:a", 0.0, 0.95)
	tw.tween_callback(_start_warning)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, true)


func _exit_tree() -> void:
	if resized.is_connected(_layout):
		resized.disconnect(_layout)
	if logo_canvas != null and logo_canvas.draw.is_connected(_draw_logo):
		logo_canvas.draw.disconnect(_draw_logo)
	if icon_canvas != null and icon_canvas.draw.is_connected(_draw_icons):
		icon_canvas.draw.disconnect(_draw_icons)


func _setup_studio_emblem() -> void:
	if studio_lbl != null:
		studio_lbl.visible = false

	var parent_stage: Control = logo_stage if logo_stage != null else self
	if _studio_emblem == null:
		_studio_emblem = STUDIO_SCRIPT.new()
		_studio_emblem.name = "StudioEmblem"
		if "studio_text" in _studio_emblem:
			_studio_emblem.studio_text = STUDIO_MAIN
		if "font_size" in _studio_emblem:
			_studio_emblem.font_size = 24
		parent_stage.add_child(_studio_emblem)


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
	return maxf(230.0, h * 0.36)


func _place_rect(ctrl: Control, pos: Vector2, sz: Vector2) -> void:
	if ctrl == null:
		return
	ctrl.anchor_left = 0.0
	ctrl.anchor_top = 0.0
	ctrl.anchor_right = 0.0
	ctrl.anchor_bottom = 0.0
	ctrl.offset_left = pos.x
	ctrl.offset_top = pos.y
	ctrl.offset_right = pos.x + sz.x
	ctrl.offset_bottom = pos.y + sz.y
	ctrl.position = pos
	ctrl.set_deferred("size", sz)


func _fill_parent(ctrl: Control) -> void:
	if ctrl == null:
		return
	ctrl.anchor_left = 0.0
	ctrl.anchor_top = 0.0
	ctrl.anchor_right = 1.0
	ctrl.anchor_bottom = 1.0
	ctrl.offset_left = 0.0
	ctrl.offset_top = 0.0
	ctrl.offset_right = 0.0
	ctrl.offset_bottom = 0.0


func _layout() -> void:
	queue_redraw()
	var w: float = size.x
	var h: float = size.y
	var m: Dictionary = _get_cols_metrics(w)
	var col_w: float = float(m["col_w"])
	var left_x: float = float(m["left_x"])
	var right_x: float = float(m["right_x"])
	var icons_y: float = _get_icons_offset_y(h)

	_fill_parent(bg)
	_fill_parent(fade)

	if _studio_emblem != null:
		var ew: float = clampf(w * 0.44, 340.0, 560.0)
		var eh: float = 44.0
		var epos := Vector2((w - ew) * 0.5, h * 0.5 + 146.0)
		_place_rect(_studio_emblem, epos, Vector2(ew, eh))
		if _studio_emblem.has_method("_sync_layout"):
			_studio_emblem._base_pos = epos
			_studio_emblem._has_base_pos = true
			_studio_emblem.call("_sync_layout")

	var warn_top: float = clampf(h * 0.08, 36.0, 96.0)
	_place_rect(warn_title, Vector2(w * 0.06, warn_top), Vector2(w * 0.88, 52.0))
	_place_rect(warn_body, Vector2(w * 0.1, warn_top + 62.0), Vector2(w * 0.8, 84.0))

	var text_y: float = icons_y + 194.0
	_place_rect(controls_txt, Vector2(left_x, text_y), Vector2(col_w, 64.0))
	_place_rect(esc_txt, Vector2(right_x, text_y), Vector2(col_w, 64.0))

	_place_rect(skip_hint, Vector2(0.0, h - 110.0), Vector2(w, 30.0))
	_place_rect(hold_bar, Vector2(w * 0.5 - 150.0, h - 70.0), Vector2(300.0, 10.0))

	if logo_canvas != null:
		logo_canvas.queue_redraw()
	if icon_canvas != null:
		icon_canvas.queue_redraw()


func _begin_logo_fade_out() -> void:
	_logo_fading_out = true
	_glitch_left = 0.0
	_glitch_off = Vector2.ZERO
	if logo_canvas != null:
		logo_canvas.queue_redraw()


func _logo_pass(delta: float) -> void:
	if logo_canvas == null:
		return
	var vp_w: float = maxf(get_viewport_rect().size.x, 1.0)
	_face.update(delta, logo_canvas.get_local_mouse_position(), logo_canvas.size, vp_w)
	logo_canvas.queue_redraw()


func _draw_logo() -> void:
	if logo_canvas == null:
		return
	if _glitch_left > 0.0 and not _logo_fading_out and not FoxSettings.reduce_noise:
		logo_canvas.draw_set_transform(_glitch_off, 0.0, Vector2.ONE)
		_face.paint(logo_canvas, logo_canvas.size)
		logo_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_face.paint(logo_canvas, logo_canvas.size)


func _process(delta: float) -> void:
	if _leaving:
		return
	if _stage == 0:
		_logo_pass(delta)
		if not FoxSettings.reduce_noise and not _logo_fading_out:
			_glitch_cd -= delta
			if _glitch_cd <= 0.0:
				_glitch_cd = randf_range(0.55, 1.15)
				_glitch_left = 0.08
				_glitch_off = Vector2(randf_range(-10.0, 10.0), randf_range(-3.0, 3.0))
				if logo_canvas != null:
					logo_canvas.queue_redraw()
			elif _glitch_left > 0.0:
				_glitch_left -= delta
				if _glitch_left <= 0.0 and logo_canvas != null:
					logo_canvas.queue_redraw()
		else:
			_glitch_left = 0.0
			_glitch_off = Vector2.ZERO
	elif _stage == 1:
		_warn_time += delta
		if _holding:
			_hold += delta
		else:
			_hold = maxf(0.0, _hold - delta * 2.0)
		if hold_bar != null:
			hold_bar.value = _hold / HOLD_TIME
		if _hold >= HOLD_TIME or _warn_time >= AUTO_TIME:
			_leave()


func _start_warning() -> void:
	if _leaving:
		return
	_stage = 1
	_warn_time = 0.0
	_hold = 0.0
	if hold_bar != null:
		hold_bar.value = 0.0
	if logo_stage != null:
		logo_stage.visible = false
	if warn_stage != null:
		warn_stage.modulate = Color(1.0, 1.0, 1.0, 0.0)
		warn_stage.visible = true
		create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(warn_stage, "modulate:a", 1.0, 0.9)


func _sb(col: Color, r: Array = [8, 8, 8, 8]) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.corner_radius_top_left = r[0]
	s.corner_radius_top_right = r[1]
	s.corner_radius_bottom_right = r[2]
	s.corner_radius_bottom_left = r[3]
	return s


func _mouse_icon(pos: Vector2, left: bool) -> void:
	if icon_canvas == null:
		return
	var sz := Vector2(60.0, 86.0)
	icon_canvas.draw_style_box(_sb(Color("#e8e0e0"), [30, 30, 30, 30]), Rect2(pos, sz))
	var hl := Rect2(pos + (Vector2.ZERO if left else Vector2(sz.x * 0.5, 0.0)), Vector2(sz.x * 0.5, 38.0))
	var rr: Array = [30, 0, 0, 0] if left else [0, 30, 0, 0]
	icon_canvas.draw_style_box(_sb(RED, rr), hl)
	icon_canvas.draw_line(pos + Vector2(0.0, 38.0), pos + Vector2(sz.x, 38.0), Color.BLACK, 2.0)
	icon_canvas.draw_line(pos + Vector2(sz.x * 0.5, 0.0), pos + Vector2(sz.x * 0.5, 38.0), Color.BLACK, 2.0)


func _key_icon(rect: Rect2, label: String, fsize: int) -> void:
	if icon_canvas == null:
		return
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
	if icon_canvas == null:
		return
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


func _input(event: InputEvent) -> void:
	if _stage != 1 or _leaving:
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
	_holding = false
	set_process(false)
	set_process_input(false)
	if fade != null:
		fade.color = Color.BLACK
		fade.visible = true

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.set_parallel(true)
	if fade != null:
		tw.tween_property(fade, "modulate:a", 1.0, 0.9)
	if warn_stage != null:
		tw.tween_property(warn_stage, "modulate:a", 0.0, 0.75)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		if warn_stage != null:
			warn_stage.visible = false
		if logo_stage != null:
			logo_stage.visible = false
		if fade != null:
			fade.color = Color.BLACK
			fade.modulate = Color.WHITE
	)
	tw.tween_interval(0.25)
	tw.tween_callback(_go_to_next_scene)


func _go_to_next_scene() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)

extends Node

const RATE := 22050.0
# Тёмная синтвейв-прогрессия (Dm -> Bb -> Gm -> A) в слышимом басовом диапазоне
const BASS_NOTES: Array[float] = [73.42, 58.27, 49.00, 55.00]
const SFX_BASE_DB := -8.5

var sound_on: bool = true
var twitch_duck: float = 0.0

var _amb: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _sub_phase: float = 0.0
var _arp_phase: float = 0.0
var _lfo: float = 0.0
var _bar_timer: float = 0.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _sfx_bank: Dictionary = {}

func _ready() -> void:
	_ensure_bus("SFX")
	_ensure_bus("Ambient")

	_amb = AudioStreamPlayer.new()
	_amb.bus = "Ambient"
	_amb.volume_db = -30.0
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	_amb.stream = gen
	add_child(_amb)
	_amb.play()
	_pb = _amb.get_stream_playback()

	for _i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.volume_db = SFX_BASE_DB
		add_child(p)
		_sfx_players.append(p)

	_sfx_bank["click"] = _bake_click()
	_sfx_bank["crit"] = _bake_crit()
	_sfx_bank["buy"] = _bake_buy()
	_sfx_bank["ui"] = _bake_ui_tick()
	_sfx_bank["error"] = _bake_error()
	_sfx_bank["win"] = _bake_win()
	_sfx_bank["twitch"] = _bake_twitch()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

func set_sound(on: bool) -> void:
	sound_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on)

func duck_for_twitch(sec: float = 0.45) -> void:
	twitch_duck = sec

func play_sfx(kind: String) -> void:
	if not sound_on or not _sfx_bank.has(kind):
		return
	var p := _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	p.stream = _sfx_bank[kind]
	p.volume_db = SFX_BASE_DB
	if kind == "click":
		p.pitch_scale = randf_range(0.95, 1.06)
	elif kind == "ui":
		p.pitch_scale = randf_range(0.97, 1.02)
	else:
		p.pitch_scale = 1.0
	p.play()

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var n := samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var s16 := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s16)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.data = data
	return wav

# 1. Тактильный механический клик + мягкий суб-удар
func _bake_click() -> AudioStreamWAV:
	var dur := 0.048
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph_sub := 0.0
	var ph_hi := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 14601
	for i in range(n):
		var t := float(i) / RATE
		var nt := float(i) / float(n)
		var f_sub := lerpf(145.0, 46.0, pow(nt, 0.48))
		ph_sub = fmod(ph_sub + f_sub / RATE, 1.0)
		var sub := sin(TAU * ph_sub) * exp(-t * 78.0) * 0.34

		ph_hi = fmod(ph_hi + lerpf(1550.0, 740.0, nt) / RATE, 1.0)
		var snap := sin(TAU * ph_hi) * exp(-t * 280.0) * 0.14
		var grit := rng.randf_range(-1.0, 1.0) * exp(-t * 480.0) * 0.08
		buf[i] = sub + snap + grit
	return _make_wav(buf)

# 2. Критический удар: мягкий FM-колокольчик без резкого звона
func _bake_crit() -> AudioStreamWAV:
	var dur := 0.26
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph_c := 0.0
	var ph_m := 0.0
	var ph_hi := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var env := exp(-t * 14.5) * minf(1.0, t * 180.0)
		ph_m = fmod(ph_m + 1318.5 / RATE, 1.0)
		var mod := sin(TAU * ph_m) * 0.9 * exp(-t * 24.0)
		ph_c = fmod(ph_c + 784.0 / RATE, 1.0)
		ph_hi = fmod(ph_hi + 1568.0 / RATE, 1.0)
		var bell := sin(TAU * ph_c + mod) * 0.24 + sin(TAU * ph_hi) * 0.10 * exp(-t * 22.0)
		buf[i] = bell * env
	return _make_wav(buf)

# 3. Покупка: мягкий двухнотный отклик (A4 -> E5)
func _bake_buy() -> AudioStreamWAV:
	var dur := 0.18
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes: Array[float] = [440.0, 659.25]
	var ph1 := 0.0
	var ph2 := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var step := 0 if t < 0.065 else 1
		var local_t := t if step == 0 else (t - 0.065)
		var f := notes[step]
		ph1 = fmod(ph1 + f / RATE, 1.0)
		ph2 = fmod(ph2 + (f * 2.0) / RATE, 1.0)
		var env := exp(-local_t * (26.0 if step == 0 else 18.0)) * minf(1.0, local_t * 220.0)
		var tri := 1.0 - absf(ph1 * 4.0 - 2.0)
		var tone := tri * 0.22 + sin(TAU * ph2) * 0.08
		buf[i] = tone * env
	return _make_wav(buf)

# 4. Щелчок интерфейса: тихий сухой импульс
func _bake_ui_tick() -> AudioStreamWAV:
	var dur := 0.028
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / RATE
		ph = fmod(ph + 1050.0 / RATE, 1.0)
		buf[i] = sin(TAU * ph) * exp(-t * 185.0) * 0.14
	return _make_wav(buf)

# 5. Ошибка / ловушка: приглушённый двойной басовый импульс
func _bake_error() -> AudioStreamWAV:
	var dur := 0.23
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph1 := 0.0
	var ph2 := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var pulse_env := 0.0
		if t < 0.085:
			pulse_env = sin((t / 0.085) * PI)
		elif t > 0.115 and t < 0.225:
			pulse_env = sin(((t - 0.115) / 0.11) * PI) * 0.8
		ph1 = fmod(ph1 + 108.0 / RATE, 1.0)
		ph2 = fmod(ph2 + 115.5 / RATE, 1.0)
		var raw := sin(TAU * ph1) + sin(TAU * ph2)
		var warm := clampf(raw * 1.1, -1.0, 1.0) * 0.20
		buf[i] = warm * pulse_env
	return _make_wav(buf)

# 6. Победа / переполнение буфера: мягкий аккорд (C5 - E5 - G5)
func _bake_win() -> AudioStreamWAV:
	var dur := 0.34
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var chord: Array[float] = [523.25, 659.25, 783.99]
	var phs: Array[float] = [0.0, 0.0, 0.0]
	for i in range(n):
		var t := float(i) / RATE
		var mix := 0.0
		for k in range(3):
			var start_t := float(k) * 0.055
			if t >= start_t:
				var lt := t - start_t
				phs[k] = fmod(phs[k] + chord[k] / RATE, 1.0)
				var env := exp(-lt * 11.0) * minf(1.0, lt * 160.0)
				var tri := 1.0 - absf(phs[k] * 4.0 - 2.0)
				mix += (tri * 0.14 + sin(TAU * phs[k]) * 0.12) * env
		buf[i] = mix
	return _make_wav(buf)

# 7. Нервный тик уха Лиса: приглушённый цифровой сигнал
func _bake_twitch() -> AudioStreamWAV:
	var dur := 0.10
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var second := t >= 0.048
		var lt := (t - 0.048) if second else t
		var f := (1950.0 - lt * 11000.0) if second else (1250.0 + lt * 12000.0)
		ph = fmod(ph + maxf(280.0, f) / RATE, 1.0)
		var env := exp(-lt * 65.0) * minf(1.0, lt * 260.0)
		buf[i] = sin(TAU * ph) * env * 0.22
	return _make_wav(buf)

func _process(delta: float) -> void:
	if not _pb:
		return
	if twitch_duck > 0.0:
		twitch_duck -= delta
	_bar_timer += delta

	var cps_log := clampf(GameState.get_effective_cps().log10_val() / 12.0, 0.0, 1.0)
	var target_db := -48.0 if twitch_duck > 0.0 else lerpf(-30.0, -15.0, cps_log)
	_amb.volume_db = lerpf(_amb.volume_db, target_db, minf(1.0, delta * 9.0))

	var note_idx := int(_bar_timer / 2.4) % BASS_NOTES.size()
	var inf_detune := float(Economy.inf_eff(GameState)) / 100.0 * 0.025
	var bass_f := BASS_NOTES[note_idx] * (1.0 + sin(_lfo * TAU) * inf_detune)
	var arp_step := int(_bar_timer * 6.0) % 4
	var arp_mults: Array[float] = [2.0, 3.0, 4.0, 3.0]
	var arp_f := bass_f * arp_mults[arp_step]

	var cutoff := lerpf(0.05, 0.22, cps_log)

	var avail := _pb.get_frames_available()
	for _i in range(avail):
		_phase = fmod(_phase + bass_f / RATE, 1.0)
		_sub_phase = fmod(_sub_phase + (bass_f * 0.5) / RATE, 1.0)
		_arp_phase = fmod(_arp_phase + arp_f / RATE, 1.0)
		_lfo = fmod(_lfo + 0.18 / RATE, 1.0)

		var saw_bass := (_phase * 2.0 - 1.0) * 0.28 + sin(TAU * _sub_phase) * 0.36
		var arp_pulse := (0.11 * cps_log) * sin(TAU * _arp_phase)
		var raw := (saw_bass + arp_pulse) * (0.72 + 0.28 * sin(TAU * _lfo))

		_pb.push_frame(Vector2(raw * cutoff * 4.5, raw * cutoff * 4.5))

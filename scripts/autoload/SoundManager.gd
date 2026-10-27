extends Node
## 《重装废土：赏金狂飙》 - 纯代码程序化音效合成器 (Godot 4 AudioStreamWAV)
## 无需外部音频素材，启动时自动生成 16-bit PCM 波形缓存，支持多声道并发播放。

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 16

var muted: bool = false
var master_volume_db: float = -6.0
var _players: Array = []
var _pool_idx: int = 0
var _streams: Dictionary = {}
var _bgm_player: AudioStreamPlayer
var _bgm_streams: Dictionary = {}
var _current_bgm: String = ""

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.volume_db = master_volume_db
		add_child(p)
		_players.append(p)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = master_volume_db - 6.5
	add_child(_bgm_player)
	_generate_all_streams()
	_load_bgm_tracks()

func _load_bgm_tracks() -> void:
	var tracks: Array = ["bgm_camp_garage", "bgm_battle_wasteland", "bgm_wanted_boss", "bgm_dr_mince"]
	for t_name in tracks:
		var wav: AudioStreamWAV = _load_wav_with_loop("res://assets/audio/%s.wav" % String(t_name))
		if wav != null:
			_bgm_streams[String(t_name)] = wav

func _load_wav_with_loop(res_path: String) -> AudioStreamWAV:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(abs_path)
		if bytes.size() > 44:
			var pcm_data: PackedByteArray = bytes.slice(44)
			var wav := AudioStreamWAV.new()
			wav.format = AudioStreamWAV.FORMAT_16_BITS
			wav.mix_rate = SAMPLE_RATE
			wav.stereo = false
			wav.data = pcm_data
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(pcm_data.size() / 2)
			return wav
	if ResourceLoader.exists(res_path):
		var s: AudioStreamWAV = load(res_path) as AudioStreamWAV
		if s != null:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.data.size() / 2)
			return s
	return null

func play_bgm(track_name: String, volume_offset_db: float = -6.5) -> void:
	if muted or not _bgm_streams.has(track_name):
		return
	if _current_bgm == track_name and _bgm_player.playing:
		return
	_current_bgm = track_name
	_bgm_player.stream = _bgm_streams[track_name]
	_bgm_player.volume_db = master_volume_db + volume_offset_db
	_bgm_player.play()

func stop_bgm() -> void:
	_current_bgm = ""
	if is_instance_valid(_bgm_player):
		_bgm_player.stop()

func toggle_mute() -> bool:
	muted = not muted
	if muted:
		if is_instance_valid(_bgm_player):
			_bgm_player.stop()
	else:
		if _current_bgm != "" and _bgm_streams.has(_current_bgm) and is_instance_valid(_bgm_player):
			_bgm_player.stream = _bgm_streams[_current_bgm]
			_bgm_player.play()
	return muted

func _generate_all_streams() -> void:
	_streams["cannon_light"] = _synth_cannon(0.28, 150.0, 28.0)
	_streams["cannon_heavy"] = _synth_cannon(0.55, 110.0, 18.0)
	_streams["subgun_mg"] = _synth_mg()
	_streams["subgun_electric"] = _synth_zap()
	_streams["subgun_flame"] = _synth_noise_burst(0.09, 0.25)
	_streams["se_missile"] = _synth_missile()
	_streams["laser"] = _synth_laser()
	_streams["explosion_small"] = _synth_explosion(0.32, 0.65)
	_streams["explosion_large"] = _synth_explosion(0.75, 0.95)
	_streams["wanted_siren"] = _synth_wanted_siren()
	_streams["mince_revive"] = _synth_mince_jingle()
	_streams["coin"] = _synth_chime(987.77, 1318.51, 0.20)
	_streams["upgrade"] = _synth_chime(587.33, 1174.66, 0.32)
	_streams["eject_alarm"] = _synth_chime(880.0, 440.0, 0.35)

func play(sound_name: String, pitch_variance: float = 0.08, volume_offset_db: float = 0.0) -> void:
	if muted or not _streams.has(sound_name):
		return
	var p: AudioStreamPlayer = _players[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	p.stream = _streams[sound_name]
	p.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	p.volume_db = master_volume_db + volume_offset_db
	p.play()

	# 手柄震动反馈联动 (根据音效类型自动触发双马达力反馈)
	match sound_name:
		"cannon_heavy":
			vibrate(0.45, 0.65, 0.14)
		"cannon_light":
			vibrate(0.20, 0.15, 0.07)
		"explosion_large":
			vibrate(0.75, 0.90, 0.30)
		"explosion_small":
			vibrate(0.30, 0.35, 0.10)
		"wanted_siren", "eject_alarm":
			vibrate(0.65, 0.80, 0.35)
		"mince_revive":
			vibrate(0.80, 0.95, 0.40)

func play_cannon_by_caliber(weight: float) -> void:
	if weight >= 7.0:
		play("cannon_heavy", 0.06, 2.0)
	else:
		play("cannon_light", 0.08, 0.0)

func vibrate(weak_magnitude: float, strong_magnitude: float, duration: float = 0.12) -> void:
	if muted:
		return
	for dev_id in Input.get_connected_joypads():
		Input.start_joy_vibration(dev_id, clampf(weak_magnitude, 0.0, 1.0), clampf(strong_magnitude, 0.0, 1.0), duration)

# --- 波形合成辅助函数 ---

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var clamped: float = clampf(samples[i], -1.0, 1.0)
		var pcm: int = int(clamped * 32767.0)
		bytes.encode_s16(i * 2, pcm)
	wav.data = bytes
	return wav

func _synth_cannon(duration: float, start_freq: float, end_freq: float) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	var noise_lp: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = pow(1.0 - t, 1.6)
		var freq: float = lerpf(start_freq, end_freq, pow(t, 0.45))
		phase += freq / float(SAMPLE_RATE)
		var saw: float = (fmod(phase, 1.0) * 2.0 - 1.0) * 0.65
		var raw_noise: float = randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.25)
		buf[i] = (saw + noise_lp * 0.75) * env
	return _make_wav(buf)

func _synth_mg() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.065)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = 1.0 - t
		var freq: float = lerpf(260.0, 65.0, t)
		phase += freq / float(SAMPLE_RATE)
		var tri: float = absf(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0
		var n: float = randf_range(-0.4, 0.4)
		buf[i] = (tri * 0.6 + n) * env * 0.65
	return _make_wav(buf)

func _synth_zap() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.09)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = 1.0 - t
		var freq: float = lerpf(780.0, 190.0, t)
		phase += freq / float(SAMPLE_RATE)
		var sq: float = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		buf[i] = sq * env * 0.45
	return _make_wav(buf)

func _synth_noise_burst(duration: float, amp: float) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var lp: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.18)
		buf[i] = lp * (1.0 - t) * amp
	return _make_wav(buf)

func _synth_missile() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.22)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	var lp: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = sin(t * PI)
		var freq: float = lerpf(320.0, 960.0, t)
		phase += freq / float(SAMPLE_RATE)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.35)
		buf[i] = (sin(phase * TAU) * 0.4 + lp * 0.5) * env * 0.65
	return _make_wav(buf)

func _synth_laser() -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * 0.20)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = 1.0 - t
		var freq: float = lerpf(1350.0, 180.0, pow(t, 0.6))
		phase += freq / float(SAMPLE_RATE)
		buf[i] = (fmod(phase, 1.0) * 2.0 - 1.0) * env * 0.55
	return _make_wav(buf)

func _synth_explosion(duration: float, amp: float) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var lp: float = 0.0
	var sub_phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = pow(1.0 - t, 1.4)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.14)
		sub_phase += lerpf(85.0, 22.0, t) / float(SAMPLE_RATE)
		buf[i] = (lp * 0.8 + sin(sub_phase * TAU) * 0.45) * env * amp
	return _make_wav(buf)

func _synth_wanted_siren() -> AudioStreamWAV:
	var duration: float = 0.9
	var count: int = int(SAMPLE_RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var cycle: float = fmod(t * 2.0, 1.0)
		var freq: float = lerpf(440.0, 880.0, 1.0 - absf(cycle * 2.0 - 1.0))
		phase += freq / float(SAMPLE_RATE)
		var saw: float = fmod(phase, 1.0) * 2.0 - 1.0
		buf[i] = saw * 0.55 * (1.0 - t * 0.25)
	return _make_wav(buf)

func _synth_mince_jingle() -> AudioStreamWAV:
	var notes: Array = [523.25, 659.25, 783.99, 1046.50]
	var note_dur: float = 0.11
	var count: int = int(SAMPLE_RATE * note_dur * notes.size())
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var sec: float = float(i) / float(SAMPLE_RATE)
		var idx: int = clampi(int(sec / note_dur), 0, notes.size() - 1)
		var local_t: float = fmod(sec, note_dur) / note_dur
		phase += notes[idx] / float(SAMPLE_RATE)
		var sq: float = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		buf[i] = sq * (1.0 - local_t) * 0.5
	return _make_wav(buf)

func _synth_chime(f1: float, f2: float, duration: float) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * duration)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var freq: float = f1 if t < 0.35 else f2
		phase += freq / float(SAMPLE_RATE)
		buf[i] = sin(phase * TAU) * (1.0 - t) * 0.55
	return _make_wav(buf)

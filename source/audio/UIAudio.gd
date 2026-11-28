extends Node

signal cue_started(kind)

const STREAMS = {
	"click": preload("res://assets/audio/ui/click.wav"),
	"select": preload("res://assets/audio/ui/select.wav"),
	"adjust": preload("res://assets/audio/ui/adjust.wav"),
	"confirm": preload("res://assets/audio/ui/confirm.wav"),
}
const POOL_SIZE = 4
const MIN_INTERVAL_MS = 75
const HOVER_INTERVAL_MS = 95
var played_count = 0
var _last_played = -1000
var _last_hover = -1000
var _player: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
var _next_player = 0
var _hover_player: AudioStreamPlayer
var _hover_stream: AudioStreamWAV
var _error_stream: AudioStreamWAV
var _order_streams := {}
var _rng := RandomNumberGenerator.new()


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 64123
	for _i in POOL_SIZE:
		var player = AudioStreamPlayer.new()
		player.bus = "Effects"
		player.volume_db = -14.0
		add_child(player)
		_players.append(player)
	_player = _players[0]
	_hover_stream = _make_hover_stream()
	_error_stream = _make_order_stream("bastion", "reject")
	_hover_player = AudioStreamPlayer.new()
	_hover_player.bus = "Effects"
	_hover_player.volume_db = -22.5
	_hover_player.stream = _hover_stream
	add_child(_hover_player)
	get_tree().node_added.connect(_watch)
	Globals.options.changed.connect(_options_changed)
	_watch_tree(get_tree().root)


func _watch_tree(node):
	_watch(node)
	for child in node.get_children():
		_watch_tree(child)


func _watch(node):
	if node is BaseButton:
		_connect_once(node.pressed, _button_pressed.bind(node))
		_connect_once(node.mouse_entered, _button_hovered.bind(node))
	if node is OptionButton:
		_connect_once(node.item_selected, _item_selected.bind(node))
	elif node is TabBar:
		_connect_once(node.tab_clicked, _item_selected.bind(node))
	elif node is ItemList:
		_connect_once(node.item_selected, _item_selected.bind(node))
	elif node is PopupMenu:
		_connect_once(node.id_pressed, _item_selected.bind(node))
	elif node is Slider:
		_connect_once(node.gui_input, _slider_input.bind(node))


func _connect_once(notification, callback):
	if not notification.is_connected(callback):
		notification.connect(callback)


func _button_pressed(button):
	if not button.disabled and _audible(button):
		play("select" if button.toggle_mode else "click")


func _button_hovered(button):
	if button.disabled or not _audible(button):
		return
	if Globals.options.effects_volume == 0 or Globals.options.master_volume == 0:
		return
	var now = Time.get_ticks_msec()
	if now - _last_hover < HOVER_INTERVAL_MS:
		return
	_last_hover = now
	_hover_player.pitch_scale = _rng.randf_range(0.97, 1.03)
	_hover_player.play()


func _item_selected(_index, control):
	if (
		(
			control is PopupMenu
			and control.can_process()
			and not control.get_meta("silent_audio", false)
		)
		or _audible(control)
	):
		play("confirm" if control is OptionButton or control is PopupMenu else "select")


func _slider_input(event, slider):
	if not slider.editable or not _audible(slider):
		return
	if (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT)
		or (
			event is InputEventKey
			and event.pressed
			and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_END]
		)
	):
		play("adjust")


func _audible(control):
	return (
		is_instance_valid(control)
		and not control.is_queued_for_deletion()
		and (control.visible if control is Window else control.is_visible_in_tree())
		and control.can_process()
		and not control.get_meta("silent_audio", false)
	)


func _take_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			_player = player
			return player
	var selected = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	_player = selected
	return selected


func play(kind):
	if Globals.options.effects_volume == 0 or Globals.options.master_volume == 0:
		return false
	var now = Time.get_ticks_msec()
	var is_error = kind == "error"
	var stream_key = "adjust" if is_error else kind
	if now - _last_played < MIN_INTERVAL_MS or not STREAMS.has(stream_key):
		return false
	_last_played = now
	var player = _take_player()
	if is_error:
		player.pitch_scale = 1.0
		player.volume_db = -14.5
		player.stream = _error_stream
	else:
		player.pitch_scale = (
			_rng.randf_range(0.985, 1.015) if kind in ["click", "adjust"] else 1.0
		)
		player.volume_db = -14.0
		player.stream = STREAMS[stream_key]
	player.play()
	played_count += 1
	cue_started.emit(kind)
	return true


func play_order(kind: String, faction: String, accepted: bool):
	if Globals.options.effects_volume == 0 or Globals.options.master_volume == 0:
		return false
	var now = Time.get_ticks_msec()
	if now - _last_played < MIN_INTERVAL_MS:
		return false
	_last_played = now
	var category := "reject"
	if accepted:
		if kind in ["attack", "attack_move", "force_attack"]:
			category = "attack"
		elif kind == "rally":
			category = "rally"
		else:
			category = "move"
	var norm_faction = faction if faction in ["bastion", "helix", "frontier"] else "bastion"
	var cache_key = "%s:%s" % [norm_faction, category]
	if not _order_streams.has(cache_key):
		_order_streams[cache_key] = _make_order_stream(norm_faction, category)
	var player = _take_player()
	player.pitch_scale = _rng.randf_range(0.99, 1.01) if accepted else 1.0
	player.volume_db = -13.5 if accepted else -14.5
	player.stream = _order_streams[cache_key]
	player.play()
	played_count += 1
	cue_started.emit("confirm" if accepted else "adjust")
	return true


static func _make_hover_stream() -> AudioStreamWAV:
	# Whisper-soft damped magnetic brush detent (22 ms) — tactile without ever piercing.
	var rate = 44100
	var duration = 0.022
	var count = int(rate * duration)
	var pcm = PackedByteArray()
	pcm.resize(count * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 4091
	var lp1 = 0.0
	var lp2 = 0.0
	for index in count:
		var t = float(index) / rate
		var w = rng.randf_range(-1.0, 1.0)
		lp1 = lerpf(lp1, w, 0.28)
		lp2 = lerpf(lp2, lp1, 0.14)
		var air = (lp1 - lp2) * exp(-t * 280.0) * 0.55
		var body = sin(TAU * 240.0 * t) * exp(-t * 210.0) * 0.42
		var sheen = sin(TAU * 1120.0 * t) * exp(-t * 340.0) * 0.12
		var env = minf(t / 0.0008, 1.0) * clampf((duration - t) / 0.005, 0.0, 1.0)
		var sample = tanh((air + body + sheen) * 1.1) * env
		pcm.encode_s16(index * 2, roundi(sample * 18000.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	return stream


static func _warm_tone(freq: float, lt: float, decay: float, attack: float = 0.0025) -> float:
	if lt < 0.0:
		return 0.0
	var ph = TAU * (freq * lt + freq * 0.012 * 0.005 * (1.0 - exp(-lt / 0.005)))
	var env = minf(lt / attack, 1.0) * exp(-lt * decay)
	return (
		(
			sin(ph) * 0.62
			+ sin(ph * 2.0 + 0.4) * 0.22 * exp(-lt * decay * 0.65)
			+ sin(ph * 3.0 + 1.1) * 0.08 * exp(-lt * decay * 1.3)
		)
		* env
	)


static func _make_order_stream(faction: String, category: String) -> AudioStreamWAV:
	# Refined faction-styled command acknowledgment cues (44.1 kHz, 16-bit PCM)
	# with damped micro-switch transients, warm harmonic intervals, and soft room tail.
	var rate = 44100
	var duration = 0.17 if category == "reject" else (0.22 if category == "rally" else 0.155)
	var count = int(rate * duration)
	var dry := PackedFloat32Array()
	dry.resize(count)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(faction + ":" + category) & 0x7fffffff
	var lp1 = 0.0
	var lp2 = 0.0
	for index in count:
		var t = float(index) / rate
		var white = rng.randf_range(-1.0, 1.0)
		lp1 = lerpf(lp1, white, 0.26)
		lp2 = lerpf(lp2, lp1, 0.18)
		var bp = lp1 - lp2
		var sample = 0.0
		if category == "reject":
			# Understated muted low double-thud rejection detent (non-harsh, unmistakable).
			for hit in [[0.0, 165.0], [0.064, 132.0]]:
				var lt = t - hit[0]
				if lt >= 0.0:
					var env = minf(lt / 0.002, 1.0) * exp(-lt * 46.0)
					sample += (
						(
							sin(TAU * hit[1] * lt) * 0.64
							+ sin(TAU * hit[1] * 2.0 * lt) * 0.16
							+ lp2 * 0.45
						)
						* env
					)
		elif faction == "helix":
			# Silky crystalline glass lock-in with refined harmonic fifth/octave bloom.
			var f0 = 587.33 if category == "attack" else (440.0 if category == "rally" else 523.25)
			var f1 = 440.0 if category == "attack" else (659.25 if category == "rally" else 783.99)
			var click = bp * exp(-t * 320.0) * 0.34
			sample = (
				click
				+ _warm_tone(f0, t, 26.0, 0.002) * 0.56
				+ _warm_tone(f1, t - 0.024, 18.0, 0.003) * 0.58
				+ _warm_tone(f1 * 1.5, t - 0.024, 24.0, 0.004) * 0.18
			)
		elif faction == "frontier":
			# Crisp field-switch mechanical detent + warm analog confirmation blip.
			var f0 = 293.66 if category == "attack" else (349.23 if category == "rally" else 329.63)
			var f1 = 220.0 if category == "attack" else (523.25 if category == "rally" else 440.0)
			var click = (bp * 0.72 + lp2 * 0.48) * minf(t / 0.001, 1.0) * exp(-t * 175.0)
			sample = (
				click * 0.68
				+ _warm_tone(f0, t, 34.0, 0.0018) * 0.52
				+ _warm_tone(f1, t - 0.028, 24.0, 0.0025) * 0.50
			)
		else:
			# Bastion: solid armored steel relay latch + warm damped brass-tinted fifth.
			var f0 = 329.63 if category == "attack" else (349.23 if category == "rally" else 392.0)
			var f1 = 246.94 if category == "attack" else (523.25 if category == "rally" else 587.33)
			var latch = (
				(lp2 * 0.62 + bp * 0.38 + sin(TAU * 155.0 * t) * 0.44)
				* minf(t / 0.001, 1.0)
				* exp(-t * 105.0)
			)
			sample = (
				latch * 0.72
				+ _warm_tone(f0, t, 30.0, 0.002) * 0.50
				+ _warm_tone(f1, t - 0.026, 20.0, 0.003) * 0.54
			)
		dry[index] = sample

	# Subtle 2-tap console room sheen so orders feel tactile and grounded
	var tap1 = int(rate * 0.011)
	var tap2 = int(rate * 0.023)
	var pcm = PackedByteArray()
	pcm.resize(count * 2)
	for index in count:
		var t = float(index) / rate
		var s = dry[index]
		if index >= tap1:
			s += dry[index - tap1] * 0.14
		if index >= tap2:
			s += dry[index - tap2] * 0.08
		var fade_out = clampf((duration - t) / 0.018, 0.0, 1.0)
		pcm.encode_s16(index * 2, roundi(tanh(s * 1.05) * fade_out * 21500.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	return stream


func _options_changed():
	if Globals.options.effects_volume == 0 or Globals.options.master_volume == 0:
		for player in _players:
			player.stop()
		_hover_player.stop()

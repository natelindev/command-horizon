extends Node

const MAX_LOCAL_PLAYERS = 4
const BED_LEVEL = -16.0
const LOCAL_LEVELS = {"car": -17.0, "tug": -16.0, "gull": -16.0}
const LOCAL_CUES = {"car": "traffic", "tug": "tug", "gull": "gull"}

var region = ""
var _bed
var _locals = []
var _streams = {}
var _game
var _camera
var _human
var _gain = 0.0
var _duck = 0.0
var _combat_left = 0.0
var _scan_left = 0.0


static func region_for(map_path):
	match load("res://source/match/ambient/AmbientCatalog.gd").authored_name(map_path):
		"BastionDesert", "DesertFrontier", "SupplyLineMap", "FirstOrdersMap":
			return "desert"
		"AlpineRelay", "SplitSignalMap":
			return "alpine"
		"IndustrialCrossroads", "BrokenFoundryMap", "CommandHorizonMap", "AirCorridorMap":
			return "industrial"
		"CoastalFoundry":
			return "coastal"
	return ""


static func loop_stream(cue):
	var stream = load("res://assets/audio/environment/%s.wav" % cue).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent()
	_camera = _game.get_node("IsometricCamera3D")
	region = region_for(_game.settings.map_path)
	if region.is_empty():
		set_process(false)
		return
	_bed = AudioStreamPlayer.new()
	_bed.bus = "Ambience"
	_bed.stream = loop_stream(region)
	_bed.volume_db = -80.0
	add_child(_bed)
	for cue in LOCAL_CUES.values():
		_streams[cue] = loop_stream(cue)
	_game.combat_audio.cue_started.connect(_combat_started)
	Globals.options.changed.connect(_options_changed)
	# Start on the first ordinary frame, after map/player setup and restoration.


func _combat_started(_kind, _point):
	_combat_left = 1.5


func _process(delta):
	var suspended = get_tree().paused or _game.restoring or ("finished" in _game and _game.finished)
	_bed.stream_paused = suspended
	for entry in _locals:
		entry.node.stream_paused = suspended
	if suspended:
		return
	if Globals.options.ambience_volume == 0 or Globals.options.master_volume == 0:
		_stop()
		return
	if not is_instance_valid(_human):
		_human = _game._get_human_player()
	var elapsed = delta / maxf(Engine.time_scale, .001)
	_gain = move_toward(_gain, 1.0, elapsed / 1.5)
	_combat_left = maxf(0.0, _combat_left - elapsed)
	var speech = _human.get_node_or_null("BattleVoice") if is_instance_valid(_human) else null
	var speaking = (
		speech != null
		and speech._audio.playing
		and not speech._audio.stream_paused
		and Globals.options.voice_volume > 0
	)
	var target_duck = (
		-8.0
		if speaking
		else -4.0 if _combat_left > 0 and Globals.options.effects_volume > 0 else 0.0
	)
	_duck = move_toward(_duck, target_duck, elapsed * (40 if target_duck < _duck else 5))
	_bed.volume_db = BED_LEVEL + linear_to_db(maxf(_gain, .0001)) + _duck
	if not _bed.playing:
		_bed.play()
	_scan_left -= elapsed
	if _scan_left <= 0:
		_scan_left = .2
		_refresh_sources()
	for entry in _locals:
		var actor = entry.actor.get_ref()
		# Recheck every frame: a remembered location never authorizes a live sound.
		if not _audible(actor):
			entry.node.stop()
			entry.gain = 0.0
			continue
		entry.gain = move_toward(entry.gain, 1.0, elapsed * 2)
		entry.node.position = _camera.unproject_position(actor.global_position)
		entry.node.max_distance = get_viewport().get_visible_rect().size.length() * .65
		var motion = -5.0 if actor.entry.kind == "car" and actor.yielding else 0.0
		entry.node.volume_db = (
			LOCAL_LEVELS[actor.entry.kind]
			+ linear_to_db(maxf(_gain * entry.gain, .0001))
			+ _duck
			+ motion
		)
		if not entry.node.playing:
			# Authored neutral phase gives independent offsets without simulation RNG.
			entry.node.play(fposmod(actor.phase, entry.node.stream.get_length()))


func _audible(actor):
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.hp <= 0:
		return false
	if _camera.is_position_behind(actor.global_position):
		return false
	var screen = _camera.unproject_position(actor.global_position)
	if not get_viewport().get_visible_rect().grow(48).has_point(screen):
		return false
	return (
		_game.settings.visibility == _game.settings.Visibility.FULL
		or (is_instance_valid(_human) and _game.battlefield.is_observed(_human, actor))
	)


func _refresh_sources():
	var life = _game.map.get_node_or_null("AmbientLife")
	if life == null:
		return
	var candidates = life.actors.filter(
		func(actor): return LOCAL_CUES.has(actor.entry.kind) and _audible(actor)
	)
	var center = get_viewport().get_visible_rect().get_center()
	candidates.sort_custom(
		func(a, b):
			return (
				_camera.unproject_position(a.global_position).distance_squared_to(center)
				< _camera.unproject_position(b.global_position).distance_squared_to(center)
			)
	)
	candidates = candidates.slice(0, MAX_LOCAL_PLAYERS)
	for entry in _locals.duplicate():
		if entry.actor.get_ref() not in candidates:
			entry.node.stop()
			entry.node.queue_free()
			_locals.erase(entry)
	for actor in candidates:
		if _locals.any(func(entry): return entry.actor.get_ref() == actor):
			continue
		var player = AudioStreamPlayer2D.new()
		player.bus = "Ambience"
		player.stream = _streams[LOCAL_CUES[actor.entry.kind]]
		player.volume_db = -80.0
		player.panning_strength = 1.0
		player.attenuation = 1.5
		add_child(player)
		_locals.append({"node": player, "actor": weakref(actor), "gain": 0.0})


func _options_changed():
	if Globals.options.ambience_volume == 0 or Globals.options.master_volume == 0:
		_stop()


func _stop():
	if is_instance_valid(_bed):
		_bed.stop()
	_gain = 0.0
	for entry in _locals:
		if is_instance_valid(entry.node):
			entry.node.stop()
		entry.gain = 0.0


func _exit_tree():
	if is_instance_valid(Globals) and is_instance_valid(Globals.options):
		if Globals.options.changed.is_connected(_options_changed):
			Globals.options.changed.disconnect(_options_changed)
	_stop()
	if is_instance_valid(_bed):
		_bed.stream = null
	for entry in _locals:
		if is_instance_valid(entry.node):
			entry.node.stream = null
	_locals.clear()
	_streams.clear()

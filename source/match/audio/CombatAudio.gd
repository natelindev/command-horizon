# gdlint: disable=max-returns
extends Node

signal cue_started(kind, point)

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")

const MAX_PLAYERS = 24
const CUES = [
	"rifle_fire",
	"autocannon_fire",
	"cannon_fire",
	"energy_fire",
	"rail_fire",
	"missile_launch",
	"impact_light",
	"impact_heavy",
	"infantry_fall",
	"vehicle_destroy",
	"structure_destroy"
]
const LEVELS = {
	"rifle_fire": -15.0,
	"autocannon_fire": -16.0,
	"cannon_fire": -10.0,
	"energy_fire": -14.0,
	"rail_fire": -12.0,
	"missile_launch": -11.0,
	"impact_light": -23.0,
	"impact_heavy": -11.0,
	"infantry_fall": -14.0,
	"vehicle_destroy": -9.0,
	"structure_destroy": -7.0,
}
var played_count = 0
var dropped_count = 0
var _players = []
var _streams = {}
var _recent = {}
var _clock = 0.0
var _random = RandomNumberGenerator.new()
var _last_variant = {}
var _game
var _camera
var _human
var _impact_focus_until = 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent()
	_camera = _game.get_node("IsometricCamera3D")
	_random.seed = 91373
	for cue in CUES:
		_streams[cue] = [load("res://assets/audio/combat/%s.wav" % cue)]
		for variant in [2, 3]:
			_streams[cue].append(load("res://assets/audio/combat/%s_%d.wav" % [cue, variant]))
	Globals.options.changed.connect(_options_changed)


static func weapon_cue(unit):
	var helix = unit.player.faction == "helix"
	match unit.type:
		"RocketInfantry", "MercenaryLancer":
			return "missile_launch"
		"SniperInfantry", "MercenaryRanger":
			return "rail_fire"
		"Hero":
			return "energy_fire" if helix else "autocannon_fire"
		"Infantry":
			return "energy_fire" if helix else "rifle_fire"
		"Tank", "AntiGroundTurret":
			return "energy_fire" if helix else "cannon_fire"
		"AdvancedTank":
			return "cannon_fire" if unit.player.faction == "frontier" else "rail_fire"
		"CombatRobot":
			if helix:
				return "rail_fire" if unit.weapon_mode == "precision" else "energy_fire"
			return "autocannon_fire"
		"Helicopter", "AntiAirTurret":
			return "missile_launch"
	return "rifle_fire"


func shot(unit, point):
	var pitch = (
		0.76
		if unit.type in ["Tank", "AntiGroundTurret"] and unit.player.faction == "helix"
		else 1.0
	)
	var cue = weapon_cue(unit)
	var light = (
		unit.type in ["Infantry", "AssaultInfantry", "MercenaryWarden"]
		or cue in ["rifle_fire", "autocannon_fire"]
	)
	return _play(cue, unit, point, 1 if light else 2, pitch)


func impact(unit, source, point):
	var heavy = (
		source.type
		in [
			"Tank",
			"AdvancedTank",
			"Helicopter",
			"AntiGroundTurret",
			"AntiAirTurret",
			"RocketInfantry",
			"MercenaryLancer"
		]
	)
	return _play("impact_heavy" if heavy else "impact_light", unit, point, 2 if heavy else 1)


func destruction(unit):
	var cue = "vehicle_destroy"
	if InfantryRoster.is_infantry(unit.type):
		cue = "infantry_fall"
	elif unit.has_method("is_constructed"):
		cue = "structure_destroy"
	return _play(cue, unit, unit.global_position, 4 if cue == "structure_destroy" else 3)


func _observed(unit):
	if _game.settings.visibility == _game.settings.Visibility.FULL:
		return true
	if not is_instance_valid(_human):
		_human = _game._get_human_player()
	return _human != null and _game.battlefield.is_observed(_human, unit)


func _play(kind, unit, point, priority, pitch = 1.0):
	if (
		_game.restoring
		or _game.is_queued_for_deletion()
		or get_tree().paused
		or ("finished" in _game and _game.finished)
		or Globals.options.effects_volume == 0
		or Globals.options.master_volume == 0
		or not is_instance_valid(unit)
		or not _observed(unit)
		or _camera.is_position_behind(point)
	):
		return false
	var screen = _camera.unproject_position(point)
	if not get_viewport().get_visible_rect().grow(96).has_point(screen):
		return false
	# Merge rapid identical events in one six-metre battle area; opposite sides
	# still retain separate stereo cues. Destruction has a shorter merge window.
	var cell = Vector2i(floori(point.x / 6), floori(point.z / 6))
	var key = "%s:%d:%d" % [kind, cell.x, cell.y]
	if _recent.get(key, -INF) > _clock:
		dropped_count += 1
		return false
	var entry = _take_player(priority)
	if entry == null:
		dropped_count += 1
		return false
	_recent[key] = _clock + (0.04 if priority >= 3 else 0.08)
	if priority >= 3 and kind != "infantry_fall":
		_impact_focus_until = _clock + .35
	entry.active = true
	entry.point = point
	entry.unit = weakref(unit)
	entry.kind = kind
	entry.priority = priority
	entry.started = _clock
	entry.node.stop()
	var variants = _streams[kind]
	var choice = (
		(_last_variant.get(kind, 0) + _random.randi_range(1, variants.size() - 1)) % variants.size()
	)
	_last_variant[kind] = choice
	entry.node.stream = variants[choice]
	# Local variation never consumes the simulation RNG, and never repeats a take.
	entry.node.pitch_scale = pitch * _random.randf_range(0.94, 1.045)
	entry.left = entry.node.stream.get_length() / entry.node.pitch_scale + 0.1
	_position(entry)
	entry.node.stream_paused = false
	entry.node.play()
	played_count += 1
	cue_started.emit(kind, point)
	return true


func _take_player(priority):
	for entry in _players:
		if not entry.active:
			return entry
	if _players.size() < MAX_PLAYERS:
		var player = AudioStreamPlayer2D.new()
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		player.bus = "Effects"
		player.panning_strength = 1.0
		player.attenuation = 1.0
		add_child(player)
		var entry = {"node": player, "active": false, "priority": 0, "started": 0.0}
		_players.append(entry)
		return entry
	var candidate = null
	for entry in _players:
		if (
			(
				entry.priority < priority
				or (entry.priority == priority and _clock - entry.started > 0.22)
			)
			and (
				candidate == null
				or entry.priority < candidate.priority
				or (entry.priority == candidate.priority and entry.started < candidate.started)
			)
		):
			candidate = entry
	return candidate


func _process(delta):
	var ended = "finished" in _game and _game.finished
	var paused = get_tree().paused and not ended
	for entry in _players:
		# A queued 2D play starts on the physics tick. Pause that tick too, so it
		# cannot restart a voice after the mixer was paused on the render frame.
		entry.node.process_mode = (
			Node.PROCESS_MODE_ALWAYS if ended else Node.PROCESS_MODE_PAUSABLE
		)
		entry.node.stream_paused = paused
	if paused:
		return
	var elapsed = delta / maxf(Engine.time_scale, 0.001)
	_clock += elapsed
	for key in _recent.keys():
		if _recent[key] <= _clock:
			_recent.erase(key)
	for entry in _players:
		if not entry.active:
			continue
		entry.left -= elapsed
		var unit = entry.unit.get_ref()
		if (
			entry.left <= 0
			or (
				is_instance_valid(unit)
				and not unit.is_queued_for_deletion()
				and not _observed(unit)
			)
		):
			entry.node.stop()
			entry.active = false
			continue
		_position(entry)


func _position(entry):
	var viewport = get_viewport().get_visible_rect()
	entry.node.position = _camera.unproject_position(entry.point)
	entry.node.max_distance = viewport.size.length() * 0.9
	if not is_instance_valid(_human):
		_human = _game._get_human_player()
	var speech = _human.get_node_or_null("BattleVoice") if is_instance_valid(_human) else null
	var duck = (
		-6.0
		if speech != null and speech._audio.playing and Globals.options.voice_volume > 0
		else 0.0
	)
	# Briefly make room for a major loss without interrupting weapons or speech.
	var impact_duck = -3.5 if _clock < _impact_focus_until and entry.priority < 3 else 0.0
	entry.node.volume_db = LEVELS[entry.kind] + duck + impact_duck


func _options_changed():
	if Globals.options.effects_volume == 0 or Globals.options.master_volume == 0:
		for entry in _players:
			entry.node.stop()
			entry.active = false


func _exit_tree():
	if is_instance_valid(Globals) and is_instance_valid(Globals.options):
		if Globals.options.changed.is_connected(_options_changed):
			Globals.options.changed.disconnect(_options_changed)
	for entry in _players:
		if is_instance_valid(entry.node):
			entry.node.stop()
			entry.node.stream = null
	_players.clear()
	_streams.clear()
	_recent.clear()

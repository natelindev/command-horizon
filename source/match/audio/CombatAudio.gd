# gdlint: disable=max-returns
extends Node

signal cue_started(kind, point)

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")

const MAX_PLAYERS = 24
const MAX_DAMAGE_LOOPS = 4
const DamageProfile = preload("res://source/match/units/traits/VehicleDamageProfile.gd")
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
	"weapon_charge": -22.0,
	"damage_diesel": -31.0,
	"damage_plasma": -34.0,
	"damage_steam": -32.0,
	"damage_backfire": -29.0,
	"commander_warning": -18.0,
	"commander_emp": -15.0,
	"complete_bastion": -24.0,
	"complete_helix": -26.0,
	"complete_frontier": -27.0,
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
var _charge_stream
var _damage_candidates := {}
var _damage_streams := {}
var _damage_refresh := 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent()
	_camera = _game.get_node("IsometricCamera3D")
	_random.seed = 91373
	for cue in CUES:
		_streams[cue] = [load("res://assets/audio/combat/%s.wav" % cue)]
		for variant in [2, 3]:
			_streams[cue].append(load("res://assets/audio/combat/%s_%d.wav" % [cue, variant]))
	_streams["damage_backfire"] = _streams["impact_light"]
	var warning = _make_warning_stream()
	_streams["commander_warning"] = [warning, warning, warning]
	_streams["commander_emp"] = _streams["energy_fire"]
	Globals.options.changed.connect(_options_changed)


static func weapon_cue(unit, weapon = {}):
	if weapon.get("kind", "") == "bomb":
		return ""  # Gravity stores have no muzzle report; their impact carries the weight.
	if weapon.get("kind", "") in ["rocket", "missile"]:
		return "missile_launch"
	if (
		weapon.get("id", "")
		in ["jet_cannon", "flak", "aa_autocannon", "twin_autocannon", "shotgun"]
	):
		return "autocannon_fire"
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


func shot(unit, point, weapon = {}):
	var pitch = (
		0.76
		if unit.type in ["Tank", "AntiGroundTurret"] and unit.player.faction == "helix"
		else 1.0
	)
	var cue = weapon_cue(unit, weapon)
	if cue.is_empty():
		return false
	var light = (
		unit.type in ["Infantry", "AssaultInfantry", "MercenaryWarden"]
		or cue in ["rifle_fire", "autocannon_fire"]
	)
	return _play(cue, unit, point, 1 if light else 2, pitch)


func update_charge(unit):
	var voice = null
	for entry in _players:
		if entry.active and entry.kind == "weapon_charge" and entry.unit.get_ref() == unit:
			voice = entry
			break
	var point = unit.get_node("ProjectileOrigin").global_position
	if unit.weapon_charge_progress < 0 or not _audible(unit, point):
		if voice != null:
			voice.node.stop()
			voice.active = false
		return
	if voice == null:
		voice = _take_player(0)
		if voice == null:
			return
		if _charge_stream == null:
			_charge_stream = _make_charge_stream()
		voice.node.stop()
		voice.active = true
		voice.unit = weakref(unit)
		voice.kind = "weapon_charge"
		voice.point_only = false
		voice.public_point = false
		voice.priority = 0
		voice.started = _clock
		voice.left = INF
		voice.node.stream = _charge_stream
		_update_charge_voice(voice, unit, point)
		voice.node.stream_paused = false
		voice.node.play()
		played_count += 1
		cue_started.emit("weapon_charge", point)
	else:
		_update_charge_voice(voice, unit, point)


func _update_charge_voice(entry, unit, point):
	entry.point = point
	entry.node.pitch_scale = lerpf(0.75, 1.6, clampf(unit.weapon_charge_progress, 0.0, 1.0))
	_position(entry)


static func _make_charge_stream():
	# A seamless 200 ms capacitor tone: all carriers and modulation complete
	# whole cycles. Pitch follows authoritative preparation, never wall time/RNG.
	var rate = 22050
	var samples = rate / 5
	var pcm = PackedByteArray()
	pcm.resize(samples * 2)
	for index in samples:
		var time = float(index) / rate
		var carrier = sin(TAU * 440.0 * time + 0.35 * sin(TAU * 30.0 * time))
		var harmonics = 0.25 * sin(TAU * 880.0 * time) + 0.1 * sin(TAU * 1320.0 * time)
		var tremolo = 0.85 + 0.15 * cos(TAU * 20.0 * time)
		pcm.encode_s16(index * 2, roundi((carrier + harmonics) * tremolo * 15000.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples
	return stream


static func heavy_impact(source, weapon = {}):
	if not weapon.is_empty():
		return (
			weapon.get("kind", "") in ["shell", "rail", "rocket", "missile", "bomb", "warhead"]
			or weapon.get("fuse", 0.0) > 0.0
		)
	return (
		source.type
		in [
			"Tank",
			"AdvancedTank",
			"Helicopter",
			"AntiGroundTurret",
			"AntiAirTurret",
			"RocketInfantry",
			"MercenaryLancer",
			"Fighter",
			"Bomber"
		]
	)


func point_observed(point: Vector3, _owner = null) -> bool:
	if _game.settings.visibility == _game.settings.Visibility.FULL:
		return true
	if not is_instance_valid(_human):
		_human = _game._get_human_player()
	if _human == null:
		return false
	for observer in _game.battlefield.nearby_units(point, 40.0):
		if (
			_human.is_allied_with(observer.player)
			and _game.battlefield.can_observe_point(observer, point)
		):
			return true
	return false


func point_impact(point: Vector3, owner = null) -> bool:
	if not point_observed(point, owner):
		return false
	# The player remains a valid lifecycle anchor when the throwing unit has died.
	return _play("impact_heavy", _game, point, 2, 1.0, true)


func commander_warning(kind: String, point: Vector3) -> bool:
	return _play(
		"commander_warning", _game, point, 3, .85 if kind == "bastion" else 1.0, true, true
	)


func commander_emp(point: Vector3) -> bool:
	return _play("commander_emp", _game, point, 3, .65, true, true)


static func _make_warning_stream() -> AudioStreamWAV:
	var rate = 22050
	var pcm = PackedByteArray()
	pcm.resize(int(rate * .6) * 2)
	for index in int(rate * .6):
		var t = float(index) / rate
		var local = fmod(t, .3)
		var envelope = sin(PI * clampf(local / .22, 0.0, 1.0))
		var frequency = 740.0 if t < .3 else 980.0
		pcm.encode_s16(index * 2, roundi(sin(TAU * frequency * t) * envelope * 13000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	return stream


func update_damage(unit, band: int):
	var id = unit.get_instance_id()
	if band <= 0 or unit.hp <= 0 or not _audible(unit, unit.global_position):
		_damage_candidates.erase(id)
		return
	_damage_candidates[id] = {"unit": weakref(unit), "band": band, "expires": _clock + 1.0}


func _refresh_damage_loops():
	var candidates := []
	for id in _damage_candidates.keys():
		var entry = _damage_candidates[id]
		var unit = entry.unit.get_ref()
		if (
			not is_instance_valid(unit)
			or unit.is_queued_for_deletion()
			or unit.hp <= 0
			or entry.expires < _clock
			or not _audible(unit, unit.global_position)
		):
			_damage_candidates.erase(id)
			continue
		candidates.append(unit)
	candidates.sort_custom(
		func(a, b):
			var selected_a = a.is_in_group("selected_units")
			var selected_b = b.is_in_group("selected_units")
			if selected_a != selected_b:
				return selected_a
			return (
				a.global_position.distance_squared_to(_camera.global_position)
				< b.global_position.distance_squared_to(_camera.global_position)
			)
	)
	candidates.resize(mini(MAX_DAMAGE_LOOPS, candidates.size()))
	for voice in _players:
		if voice.active and voice.kind.begins_with("damage_") and voice.kind != "damage_backfire":
			if voice.unit.get_ref() not in candidates:
				voice.node.stop()
				voice.active = false
	for unit in candidates:
		var voice = null
		for existing in _players:
			if (
				existing.active
				and existing.kind.begins_with("damage_")
				and existing.kind != "damage_backfire"
				and existing.unit.get_ref() == unit
			):
				voice = existing
				break
		if voice == null:
			voice = _take_player(0)
			if voice == null:
				continue
			var cue = DamageProfile.profile(unit.player.faction).cue
			if not _damage_streams.has(cue):
				_damage_streams[cue] = _make_damage_stream(unit.player.faction)
			voice.node.stop()
			voice.active = true
			voice.unit = weakref(unit)
			voice.kind = cue
			voice.priority = 0
			voice.started = _clock
			voice.left = INF
			voice.point_only = false
			voice.public_point = false
			voice.node.pitch_scale = 1.0
			voice.node.stream = _damage_streams[cue]
			voice.point = unit.global_position
			_position(voice)
			voice.node.stream_paused = false
			voice.node.play()
			played_count += 1
			cue_started.emit(cue, voice.point)
		voice.point = unit.global_position


static func _make_damage_stream(faction: String) -> AudioStreamWAV:
	var rate = 22050
	var pcm = PackedByteArray()
	pcm.resize(rate * 2)
	for index in rate:
		var t = float(index) / rate
		var value = 0.0
		match faction:
			"helix":
				value = sin(TAU * 180 * t + sin(TAU * 7 * t) * 1.2) * .3 + sin(TAU * 720 * t) * .08
			"frontier":
				value = (sin(TAU * 1673 * t) + sin(TAU * 2371 * t) + sin(TAU * 3229 * t)) * .1
				value *= .5 + .5 * sin(TAU * 3 * t)
				value += sin(TAU * 83 * t) * sin(TAU * 17 * t) * .12
			_:
				value = sin(TAU * 53 * t) * .25 + sin(TAU * 107 * t) * .15
				value *= .7 + .3 * sin(TAU * 13 * t)
		pcm.encode_s16(index * 2, roundi(value * 24000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = rate
	return stream


func impact(unit, source, point, weapon = {}):
	var heavy = heavy_impact(source, weapon)
	return _play("impact_heavy" if heavy else "impact_light", unit, point, 2 if heavy else 1)


func ability(unit, id, point):
	match id:
		"siege_anchor":
			return _play("impact_light", unit, point, 1, .65)
		"frag_grenade":
			return _play("impact_heavy", unit, point, 2)
	return false


func vehicle_backfire(unit, point):
	return _play("damage_backfire", unit, point, 0, .65)


func construction_completed(unit):
	var kind = "complete_" + unit.player.faction
	if not _streams.has(kind):
		var stream = load("res://source/match/audio/CompletionAudio.gd").make_stream(
			unit.player.faction
		)
		_streams[kind] = [stream, stream, stream]
	return _play(kind, unit, unit.global_position, 1)


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


func _audible(unit, point, point_only := false, public_point := false):
	if (
		_game.restoring
		or _game.is_queued_for_deletion()
		or get_tree().paused
		or ("finished" in _game and _game.finished)
		or Globals.options.effects_volume == 0
		or Globals.options.master_volume == 0
		or not is_instance_valid(unit)
		or (not public_point and (not point_observed(point) if point_only else not _observed(unit)))
		or (not public_point and _camera.is_position_behind(point))
	):
		return false
	return (
		public_point
		or get_viewport().get_visible_rect().grow(96).has_point(_camera.unproject_position(point))
	)


func _play(kind, unit, point, priority, pitch = 1.0, point_only := false, public_point := false):
	if not _audible(unit, point, point_only, public_point):
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
	entry.point_only = point_only
	entry.public_point = public_point
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
				or (priority > 0 and entry.priority == priority and _clock - entry.started > 0.22)
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
	_damage_refresh -= elapsed
	if _damage_refresh <= 0.0:
		_damage_refresh = .25
		_refresh_damage_loops()
	for key in _recent.keys():
		if _recent[key] <= _clock:
			_recent.erase(key)
	for entry in _players:
		if not entry.active:
			continue
		var unit = entry.unit.get_ref()
		var damage_loop = entry.kind.begins_with("damage_") and entry.kind != "damage_backfire"
		if damage_loop:
			if (
				not is_instance_valid(unit)
				or unit.is_queued_for_deletion()
				or unit.hp <= 0
				or unit.damage_visual_band == 0
				or not _audible(unit, unit.global_position)
			):
				entry.node.stop()
				entry.active = false
				continue
			entry.point = unit.global_position
		if entry.kind == "weapon_charge":
			if not is_instance_valid(unit) or unit.is_queued_for_deletion():
				entry.node.stop()
				entry.active = false
			else:
				# Also recheck fog, camera, restoration and battle end while sustaining.
				update_charge(unit)
			continue
		entry.left -= elapsed
		if (
			entry.left <= 0
			or (
				is_instance_valid(unit)
				and not unit.is_queued_for_deletion()
				and not entry.get("public_point", false)
				and (
					not point_observed(entry.point)
					if entry.get("point_only", false)
					else not _observed(unit)
				)
			)
		):
			entry.node.stop()
			entry.active = false
			continue
		_position(entry)


func _position(entry):
	var viewport = get_viewport().get_visible_rect()
	entry.node.position = _camera.unproject_position(entry.point)
	if entry.get("public_point", false):
		entry.node.position = (
			viewport.get_center()
			+ Vector2(clampf(entry.node.position.x - viewport.get_center().x, -160, 160), 0)
		)
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
	var charge_gain = 0.0
	if entry.kind == "weapon_charge":
		var unit = entry.unit.get_ref()
		charge_gain = lerpf(-5.0, 3.0, clampf(unit.weapon_charge_progress, 0.0, 1.0))
	entry.node.volume_db = LEVELS[entry.kind] + charge_gain + duck + impact_duck


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
	_charge_stream = null
	_damage_candidates.clear()
	_damage_streams.clear()
	_recent.clear()

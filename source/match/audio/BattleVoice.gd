# gdlint: disable=max-returns
extends Node

signal caption_changed(line)

const Lines = preload("res://source/match/audio/VoiceLines.gd")
const Bank = preload("res://source/match/audio/UnitVoiceBank.gd")
const MAX_PENDING = 4
const MAX_WAIT = 6.0
const CHATTER_GAP = 1.5
const DANGER_GAP = 4.0
const KILL_GAP = 4.0

var current = {}
var _pending = []
var _spoken_at = {}
var _clock = 0.0
var _remaining = 0.0
var _ended = false
var _narration_active = false
var _audio: AudioStreamPlayer
var _chirp_audio: AudioStreamPlayer
var _chirp_in: AudioStream
var _chirp_out: AudioStream
var _game
var _bank = Bank.new()
var _order_streams = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent().find_parent("Match")
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Voice"
	add_child(_audio)
	_chirp_audio = AudioStreamPlayer.new()
	_chirp_audio.bus = "Voice"
	add_child(_chirp_audio)
	if ResourceLoader.exists("res://assets/audio/voices/radio_chirp_in.wav"):
		_chirp_in = load("res://assets/audio/voices/radio_chirp_in.wav")
	if ResourceLoader.exists("res://assets/audio/voices/radio_chirp_out.wav"):
		_chirp_out = load("res://assets/audio/voices/radio_chirp_out.wav")
	# Hold this army's compressed reply streams before the first input command.
	# ResourceLoader's cache is weak; an unreferenced warm-up would load them again.
	for path in _bank.order_streams(get_parent().faction):
		_order_streams[path] = load(path)


func say(event):
	# Unit replies need a source so their identity can never fall back to Command.
	if not Lines.TEXT.has(event) or event in Lines.UNIT_EVENTS:
		return false
	var line = Lines.record(event)
	var recording = _bank.announcer(get_parent().faction, Lines.EVENTS.find_key(event))
	if recording.is_empty():
		return false
	line.merge(recording, true)
	line.speaker = (
		{"bastion": "Bastion Command", "helix": "Helix Control", "frontier": "Frontier Dispatch"}
		. get(get_parent().faction, "Command")
	)
	return _accept(line)


func say_unit(unit, kind):
	# Selection also includes neutral resources, which have no player or unit voice.
	if (
		not is_instance_valid(unit)
		or unit.is_queued_for_deletion()
		or not "player" in unit
		or unit.player != get_parent()
	):
		return false
	# Group orders reach this once per member; spend the shared chatter budget
	# before resolving a recording or advancing any voice-bank lookup work.
	if kind in Bank.ORDER_KINDS and _clock - _spoken_at.get("chatter", -INF) < CHATTER_GAP:
		return false
	var line = _bank.unit_line(unit, kind)
	if line.is_empty():
		return false
	line.event = (
		{
			"ready": Lines.EVENTS.UNIT_PRODUCTION_FINISHED,
			"select": Lines.EVENTS.UNIT_HELLO,
			"low_health": Lines.EVENTS.UNIT_LOW_HEALTH,
			"kill": Lines.EVENTS.UNIT_KILL_CONFIRMED,
		}
		. get(kind, Lines.EVENTS.UNIT_ACK_1)
	)
	line.priority = 30 if kind == "ready" else Lines.priority(line.event)
	line.source = weakref(unit)
	if line.event in Lines.COMBAT_EVENTS:
		if unit.hp <= 0 or unit.has_meta("garrison_host"):
			return false
		line.combat_key = "%s:%d" % [kind, unit.get_instance_id()]
	return _accept(line)


func _accept(line):
	var event = line.event
	if (
		_ended
		or (_narration_active and line.priority < 70 and event not in Lines.TERMINAL)
		or not is_instance_valid(_game)
		or _game.restoring
		or _game.is_queued_for_deletion()
		or ("finished" in _game and _game.finished and event not in Lines.TERMINAL)
	):
		return false
	# Reports share a budget, while worsening danger can interrupt a lesser alert.
	if (
		event
		in [Lines.EVENTS.UNIT_LOST, Lines.EVENTS.UNIT_UNDER_ATTACK, Lines.EVENTS.UNIT_LOW_HEALTH]
	):
		if (
			_clock - _spoken_at.get("danger", -INF) < DANGER_GAP
			and line.priority <= _spoken_at.get("danger_priority", 0)
		):
			return false
	if event == Lines.EVENTS.UNIT_KILL_CONFIRMED:
		if _clock - _spoken_at.get("kill", -INF) < KILL_GAP or current.get("priority", 0) >= 70:
			return false
	if event in [Lines.EVENTS.LOW_POWER, Lines.EVENTS.POWER_RESTORED]:
		# A recovered power state invalidates an unheard low-power report, and vice versa.
		_pending = _pending.filter(
			func(item):
				return item.event not in [Lines.EVENTS.LOW_POWER, Lines.EVENTS.POWER_RESTORED]
		)
	var chatter = event in Lines.ORDER_EVENTS
	var key = line.get("combat_key", "chatter" if chatter else str(event))
	var cooldown = CHATTER_GAP if chatter else Lines.cooldown(event)
	if _clock - _spoken_at.get(key, -INF) < cooldown:
		return false
	if current.get("event", -1) == event or _pending.any(func(item): return item.event == event):
		return false
	line.key = key
	if event in Lines.TERMINAL:
		_ended = true
		_pending.clear()
		_start(line)
		return true
	if current.is_empty() or (line.priority >= 70 and line.priority > current.priority):
		_start(line)
		return true
	# Input feedback expires immediately; never play an old order after a warning.
	if line.priority == 10:
		return false
	line.expires = _clock + MAX_WAIT
	if _pending.size() >= MAX_PENDING:
		var lowest = _pending.size() - 1
		if _pending[lowest].priority >= line.priority:
			return false
		_pending.remove_at(lowest)
	_pending.append(line)
	_pending.sort_custom(func(a, b): return a.priority > b.priority)
	return true


func begin_narration():
	_narration_active = true
	_pending.clear()
	_clear()


func end_narration():
	_narration_active = false


func finish(result):
	if result == "Victory":
		say(Lines.EVENTS.MATCH_FINISHED_WITH_VICTORY)
	elif result == "Defeat":
		say(Lines.EVENTS.MATCH_FINISHED_WITH_DEFEAT)
	else:
		_ended = true
		_pending.clear()
		_clear()


func _start(line):
	current = line.duplicate()
	current.erase("expires")
	_spoken_at[line.key] = _clock
	if line.event == Lines.EVENTS.UNIT_KILL_CONFIRMED:
		_spoken_at["kill"] = _clock
	if line.priority >= 70 and line.event not in Lines.TERMINAL:
		_spoken_at["danger"] = _clock
		_spoken_at["danger_priority"] = line.priority
	_bank.accepted(line)
	_audio.stop()
	var recording = _order_streams.get(line.stream)
	_audio.stream = recording if recording != null else load(line.stream)
	var mechanical = line.get("mechanical", false)
	_audio.bus = "Effects" if mechanical else "Voice"
	_audio.volume_db = -5.0 if mechanical else 0.0
	_audio.play()
	# Robots speak through their own machinery; only crew and command use the radio.
	if (
		_radioed(line)
		and is_instance_valid(_chirp_audio)
		and _chirp_in != null
		and Globals.options.voice_volume > 0
	):
		_chirp_audio.stream = _chirp_in
		_chirp_audio.volume_db = -8.0
		_chirp_audio.play()
	_remaining = maxf(_audio.stream.get_length() + 0.25, 1.2 + line.text.length() / 18.0)
	_remaining = maxf(2.2, _remaining)
	caption_changed.emit(current.duplicate())


func _process(delta):
	# Match settings freeze this subtree; tactical pause still permits feedback.
	var elapsed = delta / maxf(Engine.time_scale, 0.001)
	_clock += elapsed
	if current.is_empty():
		return
	_remaining -= elapsed
	if _remaining > 0:
		return
	_clear()
	while not _pending.is_empty():
		var line = _pending.pop_front()
		if line.has("source"):
			var unit = line.source.get_ref()
			if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.hp <= 0:
				continue
			if line.event == Lines.EVENTS.UNIT_LOW_HEALTH and unit.hp >= unit.hp_max * .4:
				continue
		if line.expires > _clock:
			_start(line)
			break


func _radioed(line):
	return (
		not line.is_empty() and not line.get("mechanical", false) and not line.get("robotic", false)
	)


func _clear():
	if (
		_radioed(current)
		and is_instance_valid(_chirp_audio)
		and _chirp_out != null
		and Globals.options.voice_volume > 0
	):
		_chirp_audio.stream = _chirp_out
		_chirp_audio.volume_db = -10.0
		_chirp_audio.play()
	_audio.stop()
	current.clear()
	_remaining = 0
	caption_changed.emit({})


func _exit_tree():
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null
	if is_instance_valid(_chirp_audio):
		_chirp_audio.stop()
		_chirp_audio.stream = null
	_pending.clear()
	current.clear()
	_order_streams.clear()

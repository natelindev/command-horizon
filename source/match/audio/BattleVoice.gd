# gdlint: disable=max-returns
extends Node

signal caption_changed(line)

const Lines = preload("res://source/match/audio/VoiceLines.gd")
const Bank = preload("res://source/match/audio/UnitVoiceBank.gd")
const MAX_PENDING = 4
const MAX_WAIT = 6.0
const CHATTER_GAP = 1.5
const DANGER_GAP = 4.0

var current = {}
var _pending = []
var _spoken_at = {}
var _clock = 0.0
var _remaining = 0.0
var _ended = false
var _audio: AudioStreamPlayer
var _game
var _bank = Bank.new()


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent().find_parent("Match")
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Voice"
	add_child(_audio)


func say(event):
	if not Lines.TEXT.has(event):
		return false
	var line = Lines.record(event)
	var recording = _bank.announcer(get_parent().faction, Lines.EVENTS.find_key(event))
	if not recording.is_empty():
		line.merge(recording, true)
		line.speaker = (
			{
				"bastion": "Bastion Command",
				"helix": "Helix Control",
				"frontier": "Frontier Dispatch"
			}
			. get(get_parent().faction, "Command")
		)
	else:
		# Legacy callers of generic unit events remain supported; gameplay uses say_unit.
		line.stream = Constants.Match.VoiceNarrator.EVENT_TO_ASSET_MAPPING[event].resource_path
	return _accept(line)


func say_unit(unit, kind):
	if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.player != get_parent():
		return false
	var line = _bank.unit_line(unit, kind)
	if line.is_empty():
		return false
	line.event = (
		Lines.EVENTS.UNIT_PRODUCTION_FINISHED
		if kind == "ready"
		else (Lines.EVENTS.UNIT_HELLO if kind == "select" else Lines.EVENTS.UNIT_ACK_1)
	)
	line.priority = 30 if kind == "ready" else 10
	line.source = weakref(unit)
	return _accept(line)


func _accept(line):
	var event = line.event
	if (
		_ended
		or not is_instance_valid(_game)
		or _game.restoring
		or _game.is_queued_for_deletion()
		or ("finished" in _game and _game.finished and event not in Lines.TERMINAL)
	):
		return false
	# Base warnings always get through; lesser danger reports share one budget.
	if event in [Lines.EVENTS.UNIT_LOST, Lines.EVENTS.UNIT_UNDER_ATTACK]:
		if _clock - _spoken_at.get("danger", -INF) < DANGER_GAP:
			return false
	if event in [Lines.EVENTS.LOW_POWER, Lines.EVENTS.POWER_RESTORED]:
		# A recovered power state invalidates an unheard low-power report, and vice versa.
		_pending = _pending.filter(
			func(item):
				return item.event not in [Lines.EVENTS.LOW_POWER, Lines.EVENTS.POWER_RESTORED]
		)
	var chatter = event in Lines.UNIT_EVENTS
	var key = "chatter" if chatter else str(event)
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
	if line.priority >= 70 and line.event not in Lines.TERMINAL:
		_spoken_at["danger"] = _clock
	_bank.accepted(line)
	_audio.stop()
	_audio.stream = load(line.stream)
	_audio.bus = "Effects" if line.get("mechanical", false) else "Voice"
	_audio.volume_db = -5.0 if line.get("mechanical", false) else 0.0
	_audio.play()
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
		if line.expires > _clock:
			_start(line)
			break


func _clear():
	_audio.stop()
	current.clear()
	_remaining = 0
	caption_changed.emit({})


func _exit_tree():
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null
	_pending.clear()
	current.clear()

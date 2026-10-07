# gdlint: disable=max-returns
extends Node

signal caption_changed(line)

const Lines = preload("res://source/match/audio/VoiceLines.gd")
const MAX_PENDING = 4
const MAX_WAIT = 6.0

var current = {}
var _pending = []
var _spoken_at = {}
var _clock = 0.0
var _remaining = 0.0
var _ended = false
var _audio: AudioStreamPlayer
var _game


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent().find_parent("Match")
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Voice"
	add_child(_audio)


func say(event):
	if (
		_ended
		or not Lines.TEXT.has(event)
		or not is_instance_valid(_game)
		or _game.restoring
		or _game.is_queued_for_deletion()
	):
		return false
	if _clock - _spoken_at.get(event, -INF) < Lines.cooldown(event):
		return false
	if current.get("event", -1) == event or _pending.any(func(line): return line.event == event):
		return false
	var line = Lines.record(event)
	if event in Lines.TERMINAL:
		_ended = true
		_pending.clear()
		_start(line)
		return true
	if current.is_empty() or (line.priority >= 70 and line.priority > current.priority):
		_start(line)
		return true
	# Acknowledgements and "Training" are only useful at the moment of the action.
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
		# There is no spoken draw line. Do not invent a victory/defeat caption.
		_ended = true
		_pending.clear()
		_clear()


func _start(line):
	current = line.duplicate()
	current.erase("expires")
	_spoken_at[line.event] = _clock
	_audio.stop()
	_audio.stream = Constants.Match.VoiceNarrator.EVENT_TO_ASSET_MAPPING[line.event]
	_audio.play()
	_remaining = maxf(_audio.stream.get_length() + 0.25, 1.2 + line.text.length() / 18.0)
	_remaining = maxf(2.2, _remaining)
	caption_changed.emit(current.duplicate())


func _process(delta):
	# Speech is presentation: tactical pause permits acknowledgements, while
	# settings/archive scene freezing suspends this node and its audio together.
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

extends Node

const TRACKS = {
	"menu": "after-the-silence",
	"bastion": "hold-the-line",
	"helix": "perfect-compliance",
	"frontier": "no-shutdown-code"
}
const TITLES = {
	"menu": "Nebulous",
	"bastion": "Rock of War",
	"helix": "Perpetual Tension",
	"frontier": "The Recon Mission"
}
const FADE_SECONDS = 2.5
const ENGAGEMENT_MEMORY = 6.0
const INTENSITY_ATTACK = 1.8
const INTENSITY_RELEASE = 7.0
const SPEECH_DUCK_DB = -3.0
const SPEECH_DUCK_ATTACK = .15
const SPEECH_DUCK_RELEASE = .6
var current_track = ""
var players = []
var intensity = 0.0
var _activity = {}
var _clock = 0.0
var _gains = [0.0, 0.0]
var _target = -1
var _scene
var _check_left = 0.0
var _pending_track = ""
var _streams = {}
var _requests = {}
var _speech_duck = 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in 2:
		var player = AudioStreamPlayer.new()
		player.name = "Music%d" % index
		player.bus = "Music"
		player.volume_db = -80
		add_child(player)
		players.append(player)
	MatchSignals.unit_weapon_hit.connect(_on_weapon_hit)


func _process(delta):
	# Neither slow-motion climaxes nor tactical pause should change musical tempo.
	var elapsed = delta / maxf(Engine.time_scale, .001)
	_poll_streams()
	_check_left -= elapsed
	if _check_left <= 0:
		_check_left = .25
		_sync_scene()
	_update_intensity(elapsed)
	_update_speech_duck(elapsed)
	for index in players.size():
		_gains[index] = move_toward(
			_gains[index], 1.0 if index == _target else 0.0, elapsed / FADE_SECONDS
		)
		var volume = linear_to_db(maxf(.0001, sin(_gains[index] * PI / 2.0))) + _speech_duck
		if not is_equal_approx(players[index].volume_db, volume):
			players[index].volume_db = volume
		if _gains[index] == 0.0 and index != _target and players[index].playing:
			players[index].stop()
		var score = players[index].stream
		if score is AudioStreamSynchronized:
			# Restore percussion and gently lift the bed as engagements grow.
			_set_stem_gain(score, 0, lerpf(.8, 1.0, intensity))
			_set_stem_gain(score, 1, intensity)


func _set_stem_gain(score, index, gain):
	var volume = linear_to_db(maxf(.0001, gain))
	if not is_equal_approx(score.get_sync_stream_volume(index), volume):
		score.set_sync_stream_volume(index, volume)


func _update_speech_duck(delta):
	var target = SPEECH_DUCK_DB if _speech_audible() else 0.0
	var seconds = SPEECH_DUCK_ATTACK if target < _speech_duck else SPEECH_DUCK_RELEASE
	_speech_duck = move_toward(_speech_duck, target, absf(SPEECH_DUCK_DB) * delta / seconds)


func _speech_audible():
	if (
		Globals.options.voice_volume == 0
		or Globals.options.master_volume == 0
		or not is_instance_valid(_scene)
		or _scene != get_tree().current_scene
		or not _scene.has_method("_get_human_player")
	):
		return false
	var human = _scene._get_human_player()
	var voice = human.get_node_or_null("BattleVoice") if is_instance_valid(human) else null
	if voice != null and _audible_voice_player(voice._audio):
		return true
	var story = _scene.get_node_or_null("CampaignStory")
	return story != null and _audible_voice_player(story._audio)


func _audible_voice_player(player):
	return (
		is_instance_valid(player)
		and player.bus == "Voice"
		and player.playing
		and not player.stream_paused
		and player.can_process()
	)


func _sync_scene():
	var scene = get_tree().current_scene
	if not is_instance_valid(scene) or not scene.is_node_ready():
		return
	var track = "menu"
	if scene.has_method("_get_human_player"):
		var human = scene._get_human_player()
		if is_instance_valid(human):
			track = human.faction
	if scene != _scene or track != current_track:
		if scene != _scene:
			_activity.clear()
			intensity = 0.0
		_scene = scene
		play_track(track)


func _on_weapon_hit(unit, source):
	var game = get_tree().current_scene
	if (
		not is_instance_valid(game)
		or game != _scene
		or not "finished" in game
		or game.finished
		or game.restoring
		or get_tree().paused
		or not is_instance_valid(unit)
		or not is_instance_valid(source)
		or unit.player == source.player
	):
		return
	var human = game._get_human_player()
	if (
		human == null
		or (
			game.settings.visibility != game.settings.Visibility.FULL
			and not game.battlefield.is_observed(human, unit)
		)
	):
		return
	# Track participants instead of hits: rapid-fire weapons cannot saturate the
	# score by themselves, and distant hidden engagements never reveal themselves.
	_activity[unit.get_instance_id()] = _clock + ENGAGEMENT_MEMORY
	_activity[source.get_instance_id()] = _clock + ENGAGEMENT_MEMORY


func _update_intensity(delta):
	_clock += delta
	for id in _activity.keys():
		if _activity[id] <= _clock:
			_activity.erase(id)
	var active = (
		is_instance_valid(_scene)
		and "finished" in _scene
		and not _scene.finished
		and not _scene.restoring
		and not get_tree().paused
		and current_track != "menu"
	)
	var target = minf(1.0, _activity.size() / 10.0) if active else 0.0
	var seconds = INTENSITY_ATTACK if target > intensity else INTENSITY_RELEASE
	intensity = move_toward(intensity, target, delta / seconds)


func play_track(track):
	if not TRACKS.has(track):
		return
	_pending_track = track
	if current_track == track:
		_pending_track = ""
		return
	# Reuse an already fading track when a quick back/load transition reverses.
	for index in players.size():
		if players[index].get_meta("track", "") == track and players[index].playing:
			_target = index
			current_track = track
			_pending_track = ""
			return
	if _streams.has(track) and (track == "menu" or _streams.has(track + ":combat")):
		_start_track(track, _streams[track])
	else:
		_request_stream(track, "" if track == "menu" else "-calm")
		if track != "menu":
			_request_stream(track + ":combat", "-combat")


func _request_stream(key, suffix):
	if _streams.has(key) or _requests.has(key):
		return
	var track = key.split(":")[0]
	var path = "res://assets/audio/music/%s%s.ogg" % [TRACKS[track], suffix]
	if ResourceLoader.load_threaded_request(path) == OK:
		_requests[key] = path
	else:
		_pending_track = ""


func _poll_streams():
	# Reading a long Ogg on a scene change must not block an input/render frame.
	# Drain superseded requests too, retaining seven reusable streams at most.
	for track in _requests.keys():
		var path = _requests[track]
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_streams[track] = ResourceLoader.load_threaded_get(path)
			_requests.erase(track)
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			_requests.erase(track)
			if _pending_track == track.split(":")[0]:
				_pending_track = ""
	if (
		not _pending_track.is_empty()
		and _streams.has(_pending_track)
		and (_pending_track == "menu" or _streams.has(_pending_track + ":combat"))
	):
		_start_track(_pending_track, _streams[_pending_track])


func _start_track(track, stream):
	_pending_track = ""
	current_track = track
	_target = 0 if _gains[0] <= _gains[1] else 1
	if stream == null:
		current_track = ""
		_target = -1
		return
	stream.loop = true
	players[_target].set_meta("track", track)
	if track == "menu":
		players[_target].stream = stream
	else:
		var percussion = _streams[track + ":combat"]
		percussion.loop = true
		# One synchronized playback keeps both layers sample-aligned through long
		# loops and audio-device changes; no polling or corrective seeks are needed.
		var score = AudioStreamSynchronized.new()
		score.stream_count = 2
		score.set_sync_stream(0, stream)
		score.set_sync_stream(1, percussion)
		_set_stem_gain(score, 0, lerpf(.8, 1.0, intensity))
		_set_stem_gain(score, 1, intensity)
		players[_target].stream = score
	players[_target].play()


func shutdown():
	set_process(false)
	_pending_track = ""
	_target = -1
	current_track = ""
	_activity.clear()
	intensity = 0.0
	_speech_duck = 0.0
	# Join outstanding loads only at shutdown, never on an interactive frame.
	for path in _requests.values():
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(path)
	_requests.clear()
	_streams.clear()
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _exit_tree():
	shutdown()

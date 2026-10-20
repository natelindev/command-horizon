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
var current_track = ""
var players = []
var _gains = [0.0, 0.0]
var _target = -1
var _scene
var _check_left = 0.0
var _pending_track = ""
var _streams = {}
var _requests = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in 2:
		var player = AudioStreamPlayer.new()
		player.name = "Music%d" % index
		player.bus = "Music"
		player.volume_db = -80
		add_child(player)
		players.append(player)


func _process(delta):
	_poll_streams()
	_check_left -= delta
	if _check_left <= 0:
		_check_left = .25
		_sync_scene()
	for index in players.size():
		var previous_gain = _gains[index]
		_gains[index] = move_toward(
			_gains[index], 1.0 if index == _target else 0.0, delta / FADE_SECONDS
		)
		# Settled tracks need no further audio-thread bus updates.
		if _gains[index] != previous_gain:
			players[index].volume_db = linear_to_db(maxf(.0001, sin(_gains[index] * PI / 2.0)))
		if _gains[index] == 0.0 and index != _target and players[index].playing:
			players[index].stop()


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
		_scene = scene
		play_track(track)


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
	if _streams.has(track):
		_start_track(track, _streams[track])
	elif not _requests.has(track):
		var path = "res://assets/audio/music/%s.ogg" % TRACKS[track]
		if ResourceLoader.load_threaded_request(path) == OK:
			_requests[track] = path
		else:
			_pending_track = ""


func _poll_streams():
	# Reading a long Ogg on a scene change must not block an input/render frame.
	# Drain superseded requests too, retaining four reusable streams at most.
	for track in _requests.keys():
		var path = _requests[track]
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_streams[track] = ResourceLoader.load_threaded_get(path)
			_requests.erase(track)
			if _pending_track == track:
				_start_track(track, _streams[track])
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			_requests.erase(track)
			if _pending_track == track:
				_pending_track = ""


func _start_track(track, stream):
	_pending_track = ""
	current_track = track
	_target = 0 if _gains[0] <= _gains[1] else 1
	if stream == null:
		current_track = ""
		_target = -1
		return
	stream.loop = true
	players[_target].stream = stream
	players[_target].set_meta("track", track)
	players[_target].play()


func _exit_tree():
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

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
	# Headless program arenas are tools, not playable battle screens.
	if "--program-arena" in OS.get_cmdline_user_args():
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
	if not TRACKS.has(track) or current_track == track:
		return
	current_track = track
	# Reuse an already fading track when a quick back/load transition reverses.
	for index in players.size():
		if players[index].get_meta("track", "") == track and players[index].playing:
			_target = index
			return
	_target = 0 if _gains[0] <= _gains[1] else 1
	var stream = load("res://assets/audio/music/%s.ogg" % TRACKS[track])
	if stream == null:
		current_track = ""
		_target = -1
		return
	stream.loop = true
	players[_target].stream = stream
	players[_target].set_meta("track", track)
	players[_target].play()

extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1})
	var director = root.get_node("MusicDirector")
	director.set_process(false)
	for track in director.TRACKS:
		director.play_track(track)
		_check(director.current_track == track, "Track selection failed: " + track)
		var player = director.players[director._target]
		_check(player.stream is AudioStreamOggVorbis, "Music is not decoded Ogg")
		_check(player.stream.get_length() >= 30, "Music is unexpectedly short")
		_check(player.stream.loop and player.playing, "Music does not play and loop")
		for index in 30:
			director._check_left = 1
			director._process(.1)
		_check(absf(player.volume_db) < .1, "Music did not fade in")
		_check(not director.players[1 - director._target].playing, "Old track still playing")
	director.play_track("menu")
	director.play_track("bastion")
	director.play_track("menu")
	_check(director.players.size() == 2, "Rapid switching allocated extra players")
	preferences.music_volume = 0
	preferences.apply()
	var bus = AudioServer.get_bus_index("Music")
	_check(bus >= 0, "Music bus missing")
	_check(AudioServer.is_bus_mute(bus), "Music mute failed")
	preferences.music_volume = .4
	preferences.apply()
	_check(not AudioServer.is_bus_mute(bus), "Music failed to unmute")
	_check(absf(db_to_linear(AudioServer.get_bus_volume_db(bus)) - .4) < .001, "Music gain failed")
	paused = true
	_check(director.can_process(), "Music stops during tactical pause")
	paused = false
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Music regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)

extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1})
	var director = root.get_node("MusicDirector")
	director.set_process(false)
	# A superseded background load must never replace the newest scene's music.
	director.play_track("bastion")
	director.play_track("helix")
	director.play_track("menu")
	var pending_deadline = Time.get_ticks_msec() + 10000
	while not director._requests.is_empty() and Time.get_ticks_msec() < pending_deadline:
		await process_frame
		director._poll_streams()
	_check(director._requests.is_empty(), "Background music loads did not finish")
	_check(director.current_track == "menu", "A stale music load replaced the latest request")
	for track in director.TRACKS:
		director.play_track(track)
		var deadline = Time.get_ticks_msec() + 10000
		while director.current_track != track and Time.get_ticks_msec() < deadline:
			await process_frame
			director._poll_streams()
		_check(director.current_track == track, "Track selection failed: " + track)
		if director.current_track != track:
			continue
		var player = director.players[director._target]
		var bed = player.stream if track == "menu" else player.stream.get_sync_stream(0)
		_check(bed is AudioStreamOggVorbis, "Music is not decoded Ogg")
		_check(player.stream.get_length() >= 150, "Music is unexpectedly short")
		_check(bed.loop and player.playing, "Music does not play and loop")
		if track == "menu":
			_check(not player.stream is AudioStreamSynchronized, "Menu retained combat percussion")
		else:
			_check(
				player.stream is AudioStreamSynchronized,
				"Faction stems are not sample-synchronized"
			)
			var percussion = player.stream.get_sync_stream(1)
			_check(percussion.loop, "Percussion stem is not looping")
			_check(
				absf(percussion.get_length() - bed.get_length()) < .01,
				"Stem durations drift across the loop: " + track
			)
		for index in 30:
			director._check_left = 1
			director._process(.1)
		_check(absf(player.volume_db) < .1, "Music did not fade in")
		if track != "menu":
			_check(
				absf(player.stream.get_sync_stream_volume(0) - linear_to_db(.8)) < .1,
				"Calm bed did not settle"
			)
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
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)

extends "res://tests/headless/SaveRestoreEdges.gd"

const REGIONS = {
	"DesertFrontier": "desert",
	"AlpineRelay": "alpine",
	"IndustrialCrossroads": "industrial",
	"CoastalFoundry": "coastal"
}
var soundscape_rules
var preferences
var original_options
var options_path
var environment_audio


func _run():
	soundscape_rules = load("res://source/match/audio/EnvironmentAudio.gd")
	preferences = root.get_node("Globals").options
	original_options = preferences.capture()
	options_path = "user://environment-options-%d.tres" % OS.get_process_id()
	save_path = "user://environment-battle-%d.json" % OS.get_process_id()
	path = "user://environment-progress-%d.json" % OS.get_process_id()
	preferences.restore({"screen": 1, "voice_volume": 0.0})
	root.get_node("SaveManager").autosaves_enabled = false
	await _preferences()
	for faction in ["bastion", "helix"]:
		for map_name in REGIONS:
			await _environment_match(faction, map_name)
			_check(environment_audio.region == REGIONS[map_name], "Wrong regional bed")
			_check(environment_audio._bed.playing, "Region did not start: " + map_name)
			_check(environment_audio._bed.bus == "Ambience", "Bed bypassed volume bus")
			if map_name == "CoastalFoundry":
				await _local_sources()
				await _lifecycle()
				await _archive_audio()
			await _remove_environment_match()
	await _campaign_regions()
	_check(
		soundscape_rules.region_for("res://unknown.tscn").is_empty(), "Unknown map guessed climate"
	)
	await _skirmish("bastion", "res://source/match/maps/BigArena.tscn")
	_check(game.environment_audio._bed == null, "Test arena received an arbitrary soundscape")
	await _remove_environment_match()
	preferences.restore(original_options)
	for file in [options_path, save_path, path]:
		DirAccess.remove_absolute(file)
	for error in errors:
		push_error(error)
	print("Environment audio regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _environment_match(faction, map_name):
	await _skirmish(faction, "res://source/match/maps/%s.tscn" % map_name)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	environment_audio = game.environment_audio
	await _frames(120)


func _remove_environment_match():
	paused = false
	var old_audio = weakref(game.environment_audio)
	game.queue_free()
	await _frames(5)
	_check(old_audio.get_ref() == null, "Scene transition retained an audio controller")


func _preferences():
	_check(soundscape_rules.BED_LEVEL <= -16.0, "Environmental bed overwhelms the mix")
	_check(preferences.ambience_volume == .55, "Legacy ambience default missing")
	preferences.ambience_volume = .25
	preferences.apply()
	var bus = AudioServer.get_bus_index("Ambience")
	_check(bus > 0 and AudioServer.get_bus_send(bus) == "Master", "Ambience bus routing missing")
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus)), .25), "Gain ignored")
	_check(preferences.persist(options_path) == OK, "Ambience preference write failed")
	var saved = ResourceLoader.load(options_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(saved.ambience_volume == .25, "Real options file lost ambience volume")
	for invalid in [NAN, INF, "bad"]:
		preferences.restore({"screen": 1, "ambience_volume": invalid})
		_check(preferences.ambience_volume == .55, "Invalid ambience volume accepted")
	preferences.restore({"screen": 1, "ambience_volume": 999.0})
	_check(preferences.ambience_volume == 1.0, "Ambience upper bound ignored")
	preferences.restore({"screen": 1, "ambience_volume": -1.0})
	_check(preferences.ambience_volume == 0 and AudioServer.is_bus_mute(bus), "Zero did not mute")
	preferences.restore({"screen": 1, "voice_volume": 0.0})
	_check(AudioServer.get_bus_effect_count(bus) == 1, "Ambience limiter duplicated")
	for cue in ["desert", "alpine", "industrial", "coastal", "traffic", "tug", "gull"]:
		var stream = soundscape_rules.loop_stream(cue)
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Loop disabled: " + cue)
		_check(stream.loop_end > stream.mix_rate * 6, "Loop endpoint truncated: " + cue)
	print("PASS regional assets, real settings file, legacy defaults, bounds, mute and bus routing")


func _local_sources():
	var life = game.map.get_node("AmbientLife")
	var actor = life.actors.filter(func(item): return item.entry.kind == "gull")[0]
	var observer = _units(game._get_human_player(), "Worker")[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(actor.position)
	camera.set_size_safely(35)
	game.settings.visibility = game.settings.Visibility.PER_PLAYER
	for unit in get_nodes_in_group("units").filter(
		func(item): return item.player == game._get_human_player()
	):
		unit.position = Vector3(6, 0, 94)
	game.battlefield.invalidate()
	await _frames(20)
	_check(environment_audio._locals.is_empty(), "Unobserved neutrals were audible")
	observer.position = actor.position + Vector3(2, 0, 0)
	game.battlefield.invalidate()
	await _frames(40)
	_check(not environment_audio._locals.is_empty(), "Observed harbor remained silent")
	_check(environment_audio._locals.size() <= 4, "Local player cap exceeded")
	_check(
		environment_audio._locals.any(func(entry): return entry.node.playing), "Local sound stopped"
	)
	observer.position = Vector3(6, 0, 94)
	game.battlefield.invalidate()
	await _frames(2)
	_check(
		environment_audio._locals.all(func(entry): return not entry.node.playing),
		"Fog loss leaked sound"
	)
	game.settings.visibility = game.settings.Visibility.FULL
	await _frames(20)
	_check(not environment_audio._locals.is_empty(), "Full visibility did not admit locals")
	life.set_physics_process(false)
	var positions = life.actors.map(func(item): return item.position)
	for index in life.actors.size():
		life.actors[index].position = Vector3(64 + index * .1, 0, 30)
	camera.set_position_safely(Vector3(64, 0, 30))
	await _frames(20)
	_check(environment_audio._locals.size() == 4, "Overlapping neutrals did not exercise voice cap")
	var local_nodes = 0
	for node in environment_audio.get_children():
		if node is AudioStreamPlayer2D and not node.is_queued_for_deletion():
			local_nodes += 1
	_check(local_nodes == 4, "Local audio nodes exceeded cap")
	for index in life.actors.size():
		life.actors[index].position = positions[index]
	life.set_physics_process(true)
	camera.set_position_safely(Vector3(115, 0, 100))
	camera.set_size_safely(18)
	await _frames(2)
	_check(
		environment_audio._locals.all(func(entry): return not entry.node.playing),
		"Offscreen source leaked"
	)
	seed(1827)
	var expected = randf()
	seed(1827)
	environment_audio._process(.25)
	_check(randf() == expected, "Environmental audio consumed simulation RNG")
	print("PASS current observation, fog loss, camera culling, bounded voices and RNG isolation")


func _lifecycle():
	paused = true
	await _frames(3)
	var gain = environment_audio._gain
	_check(environment_audio._bed.stream_paused, "Tactical pause left ambience active")
	await _frames(15)
	_check(environment_audio._gain == gain, "Pause advanced ambience fade")
	paused = false
	await _frames(5)
	_check(not environment_audio._bed.stream_paused, "Resume left ambience paused")
	preferences.ambience_volume = 0
	preferences.apply()
	_check(not environment_audio._bed.playing, "Mute retained bed playback")
	preferences.ambience_volume = .55
	preferences.apply()
	await _frames(1)
	_check(environment_audio._gain < .1, "Unmute omitted fade-in")
	await _frames(100)
	var globals = root.get_node("Globals")
	for was_paused in [false, true]:
		paused = was_paused
		var dialog = globals.open_settings()
		dialog.save_path = options_path
		await _frames(3)
		_check(environment_audio._bed.stream_paused, "Settings did not freeze ambience")
		dialog._preview("ambience_volume", .2)
		dialog._test_ambience()
		_check(dialog._ambience_sample.playing, "Settings ambience sample stayed silent")
		_check(dialog._ambience_sample.bus == "Ambience", "Sample bypassed ambience volume")
		dialog._test_ambience()
		_check(not dialog._ambience_sample.playing, "Sample toggle did not stop")
		dialog.save_path = "user://missing-environment-directory/options.tres"
		dialog._finish(true)
		_check(not dialog._closing, "Failed save closed settings")
		dialog._finish(false)
		await _frames(4)
		_check(preferences.ambience_volume == .55, "Cancel lost ambience preference")
		_check(paused == was_paused, "Settings changed tactical pause")
	paused = false
	game.restoring = true
	await _frames(3)
	_check(environment_audio._bed.stream_paused, "Restoration emitted ambience")
	game.restoring = false
	game.finished = true
	await _frames(3)
	_check(environment_audio._bed.stream_paused, "Result did not suspend ambience")
	game.finished = false
	await _frames(3)
	print(
		"PASS pause/resume, mute/fade, settings sample/cancel/write failure, restoration and result"
	)


func _archive_audio():
	paused = true
	var builder = Snapshot.new()
	var data = builder.capture(game)
	_check(data != null, "Environment battle capture failed: " + builder.error)
	if data == null:
		return
	var store = FileStore.new()
	_check(store.write_file(save_path, data), "Environment archive write failed")
	var result = await Restore.new().restore(self, store.read_file(save_path))
	_check(result.ok, "Environment restore failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	environment_audio = game.environment_audio
	await _frames(3)
	_check(environment_audio.region == "coastal", "Archive changed soundscape")
	_check(not environment_audio._bed.playing, "Paused load started bed playback")
	_check(environment_audio._locals.is_empty(), "Archive replayed neutral sources")
	paused = false
	await _frames(3)
	_check(
		environment_audio._bed.playing and environment_audio._gain < .1,
		"Loaded bed did not fade in"
	)
	print(
		"PASS actual disk restoration: no reconstruction sound, preserved region and gentle resume"
	)


func _campaign_regions():
	var catalog = load("res://source/match/campaign/CampaignCatalog.gd")
	var expected = {
		"supply_line": "desert",
		"first_orders": "desert",
		"split_signal": "alpine",
		"bastion_cinder_ford": "coastal",
		"broken_foundry": "industrial",
		"command_horizon": "industrial",
		"helix_quiet_streets": "industrial",
		"helix_the_gate": "industrial",
		"helix_cinder_ford": "coastal",
		"helix_pruning": "industrial",
		"helix_severance": "industrial",
		"frontier_drainage": "industrial",
		"frontier_cinder_ford": "coastal",
		"frontier_salvage": "desert",
		"frontier_wren": "industrial",
		"frontier_the_coalition": "industrial"
	}
	_check(expected.size() == catalog.OPERATIONS.size(), "Campaign climate coverage is stale")
	_check(
		(
			soundscape_rules
			. region_for("res://source/match/maps/HeroTheater.tscn", "unknown")
			. is_empty()
		),
		"Unknown hero operation guessed climate"
	)
	for mission in catalog.OPERATIONS:
		_check(expected.has(mission), "Missing campaign climate expectation: " + mission)
		if not expected.has(mission):
			continue
		var definition = catalog.OPERATIONS[mission]
		var settings = load("res://source/data-model/MatchSettings.gd").new()
		settings.skirmish = true
		settings.mission_id = mission
		settings.map_path = definition.map
		for index in 2:
			var side = load("res://source/data-model/PlayerSettings.gd").new()
			side.controller = index + 1
			side.faction = definition.faction if index == 0 else definition.enemy
			settings.players.append(side)
		game = load(definition.scene).instantiate()
		game.settings = settings
		game.map = load(definition.map).instantiate()
		game.progress_path = path
		root.add_child(game)
		current_scene = game
		await _frames(10)
		_check(
			game.environment_audio.region == expected[mission], "Wrong campaign climate: " + mission
		)
		_check(
			game.environment_audio._bed != null and game.environment_audio._bed.playing,
			"Campaign ambience silent: " + mission
		)
		await _remove_environment_match()
	print("PASS all %d campaign operations start their authored environment bed" % expected.size())

extends "res://tests/headless/MenuArtRegression.gd"

var hub
var _hub_path: String
var _progress_path: String


func _run():
	create_timer(180).timeout.connect(func(): quit(1))
	await _open_hub()
	await _verify_hub()
	await _cleanup_hub()
	for message in errors:
		push_error(message)
	print("Campaign command hubs: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _open_hub():
	root.get_node("SaveManager").autosaves_enabled = false
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.get_node("Globals").options.restore(
		{"screen": 1, "interface_scale": 1.5, "menu_motion": true}
	)
	await _frames(60)
	root.size = Vector2i(1280, 720)
	_hub_path = "user://hub-regression-%d.json" % OS.get_process_id()
	_progress_path = _hub_path + ".progress"
	var progress = load("res://source/match/campaign/CampaignProgress.gd").new()
	progress.record_victory(false, _progress_path)
	progress.record_operation("helix_quiet_streets", _progress_path)
	progress.record_operation("frontier_drainage", _progress_path)
	hub = load("res://source/main-menu/CampaignHub.tscn").instantiate()
	hub.hub_state_path = _hub_path
	hub.progress_path = _progress_path
	root.add_child(hub)
	current_scene = hub
	await _frames(10)
	root.size = Vector2i(1280, 720)


func _verify_hub():
	var launch = load("res://source/main-menu/CampaignLaunch.gd")
	var catalog = load("res://source/match/campaign/CampaignCatalog.gd")
	var count = 0
	for faction in catalog.ORDER:
		for id in catalog.ORDER[faction]:
			var settings = launch.settings_for(id, 2)
			_check(settings != null and settings.mission_id == id, "Lost campaign route: " + id)
			_check(
				(
					settings.players[0].faction == faction
					and settings.players[1].faction == catalog.operations()[id].enemy
				),
				"Wrong campaign faction pairing: " + id
			)
			_check(
				ResourceLoader.exists(catalog.operations()[id].scene),
				"Missing operation scene: " + id
			)
			count += 1
	_check(count == 16, "Campaign hub does not preserve all16 operations")
	for locale in ["en", "zh_CN"]:
		root.get_node("Globals").options.language = locale
		root.get_node("Globals").options.apply()
		for faction in 3:
			hub._select_faction(faction)
			await _frames(8)
			_check(hub.world.stations.size() == 3, "Hub lacks three real3D stations")
			_check(
				(
					hub.world.get_node("HubAmbience").bus == "Ambience"
					and hub.world.get_node("HubAmbience").playing
				),
				"Hub ambience bypasses its independent audio slider"
			)
			if DisplayServer.get_name() != "headless":
				hub._open_station(2)
				await _frames(6)
				var point = (
					hub._world_container.global_position
					+ hub.world.camera.unproject_position(
						hub.world.stations[0].global_position + Vector3.UP * .4
					)
				)
				var motion = InputEventMouseMotion.new()
				motion.position = point
				root.push_input(motion, true)
				for pressed in [true, false]:
					var click = InputEventMouseButton.new()
					click.button_index = MOUSE_BUTTON_LEFT
					click.position = point
					click.pressed = pressed
					root.push_input(click, true)
					await _frames(4)
				_check(hub.station == 0, "Mouse click did not activate3D command station")
			_check(
				hub.world.find_children("*", "Area3D", true, false).size() == 3,
				"Hub stations are not clickable in3D"
			)
			for index in 3:
				hub.world.station_selected.emit(index)
				await _frames(8)
				_check(hub.station == index, "World station did not open its choices")
				_check(
					root.get_visible_rect().encloses(hub._panel.get_global_rect()),
					(
						"Hub controls are clipped: %s %s %s viewport=%s"
						% [
							hub.faction,
							index,
							hub._panel.get_global_rect(),
							root.get_visible_rect()
						]
					)
				)
				for button in hub._station_buttons:
					_check(
						button.focus_mode == Control.FOCUS_ALL and button.is_visible_in_tree(),
						"Station lacks direct keyboard access"
					)
				hub._open_station(0)
				await _frames(2)
				_check(
					hub._mission_picker.item_count == catalog.ORDER[hub.faction].size(),
					"Mission picker lost routes"
				)
	hub._select_faction(0)
	hub._choose_doctrine("fortress_doctrine")
	_check(
		hub._state.doctrines.get("bastion") == "fortress_doctrine",
		"Doctrine choice did not persist"
	)
	_check(
		not hub._state.choose_doctrine("bastion", "iron_blitz", _hub_path),
		"Permanent doctrine allowed its excluded branch"
	)
	var stored = FileAccess.get_file_as_string(_progress_path)
	hub._select_faction(2)
	hub._state.recoveries = ["frontier_drainage"]
	hub._state.save_state(_hub_path)
	hub._forge("Cinder Wings")
	_check("Cinder Wings" in hub._state.insignia, "Recovered trophy did not forge an insignia")
	_check(
		FileAccess.get_file_as_string(_progress_path) == stored,
		"Hub choice rewrote existing operation progress"
	)
	var copy = load("res://source/match/campaign/CampaignHubState.gd").new()
	_check(
		(
			copy.read_state(_hub_path)
			and copy.doctrines == hub._state.doctrines
			and copy.insignia == hub._state.insignia
		),
		"Hub choices did not roundtrip"
	)
	hub._open_station(2)
	hub._play_transmission("frontier_drainage")
	_check(
		hub._audio.playing and not hub._caption.text.is_empty(),
		"Archive transmission lacks actual audio/captions"
	)
	hub._talk_mercenary("MercenaryRanger")
	_check(
		hub._audio.playing and not hub._caption.text.is_empty(),
		"Dust Ranger conversation lacks actual audio/captions"
	)
	hub._talk_mercenary("MercenaryWarden")
	_check(hub._audio.playing, "Iron Warden conversation lacks actual voice")
	var briefing = load("res://source/match/campaign/CampaignBriefing.tscn").instantiate()
	root.add_child(briefing)
	for id in catalog.operations():
		briefing.configure(id)
		briefing.seek(24)
		await _frames(1)
		_check(
			briefing.backdrop.texture != null and briefing.foreground.texture != null,
			"Briefing lacks separate painted layers: " + id
		)
		_check(
			not briefing.objectives.text.is_empty() and briefing._map_points.size() >= 2,
			"Briefing lacks theater plan/objectives: " + id
		)
	briefing.queue_free()
	await _frames(3)


func _cleanup_hub():
	hub.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(_hub_path)
	DirAccess.remove_absolute(_progress_path)

extends "res://tests/headless/SaveRestoreEdges.gd"

# Run without --headless. Captures every battlefield at the default skirmish zoom,
# a wider overview and a close detail view. `-detail-off` controls set
# terrain_detail to 0, which restores the authored procedural ground exactly.
# Optional arguments after `--` filter maps by name (for example `-- Glacier`).
const OUTPUT = "res://art/terrain-layers/"
const MAPS = [
	"battlefields/RedrockDivideMap",
	"battlefields/SaltwindBasinMap",
	"battlefields/DesertFrontierMap",
	"battlefields/PinebreakValleyMap",
	"battlefields/GlacierNarrowsMap",
	"battlefields/AlpineRelayMap",
	"battlefields/EmberworksMap",
	"battlefields/CoastalFoundryMap",
	"battlefields/CopperBadlandsMap",
	"battlefields/ShatteredOasisMap",
	"battlefields/FourRiversMap",
	"battlefields/VerdantCommonsMap",
	"battlefields/FrostboundCrownMap",
	"battlefields/RailspireJunctionMap",
	"battlefields/SunkenExchangeMap",
	"battlefields/CinderRingMap",
	"BastionDesert",
	"DesertFrontier",
	"SupplyLineMap",
	"AlpineRelay",
	"SplitSignalMap",
	"CoastalFoundry",
	"IndustrialCrossroads",
	"BrokenFoundryMap",
	"CommandHorizonMap",
	"PlainAndSimple",
	"BigArena",
]

# Campaign-only maps need their mission controller to start.
const CAMPAIGN = {
	"CommandHorizonMap": ["command_horizon", "res://source/match/campaign/CommandHorizon.tscn"],
	"BrokenFoundryMap": ["broken_foundry", "res://source/match/campaign/BrokenFoundry.tscn"],
}

var _ground = []


class RenderErrorLog:
	extends Logger

	var messages = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, _type, _backtraces):
		mutex.lock()
		messages.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Terrain layer preview needs a renderer; omit --headless")
		quit(1)
		return
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	(
		preferences
		. restore(
			{
				"screen": 1,
				"edge_scrolling": false,
				"day_cycle": false,
				"weather": 1,
				"living_world": true,
				"time_of_day": 0,
				"interface_scale": 1.0,
				"graphics_dof": false,
			}
		)
	)
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await create_timer(1).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1920, 1200)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	var filters = OS.get_cmdline_user_args()
	for map_name in MAPS:
		if not filters.is_empty() and not Array(filters).any(func(f): return f in map_name):
			continue
		paused = false
		await _launch(map_name)
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		await _frames(20)
		paused = true
		_collect_ground()
		_check(not _ground.is_empty(), map_name + " has no layered ground material")
		var hq = _units(game._get_human_player(), "CommandCenter")[0]
		var size = game.map.size
		var center = Vector3(size.x / 2.0, 0, size.y / 2.0)
		var label = map_name.get_file().to_snake_case().replace("_", "-")
		await _pair(label + "-battle", hq.global_position + Vector3(8, 0, 6), 28)
		# Campaign briefings pan the camera between captures, so pixels cannot match.
		if not CAMPAIGN.has(map_name):
			await _check_setting(label + "-battle", hq.global_position + Vector3(8, 0, 6), 28)
		await _pair(label + "-field", center, 28)
		await _capture(label + "-overview", center, 45)
		await _pair(label + "-detail", center + Vector3(6, 0, 4), 12)
		_ground.clear()
		if "progress_path" in game:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress_path))
		game.queue_free()
		await _frames(5)
		paused = false
	preferences.restore(original)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	for message in errors:
		push_error(message)
	print("Terrain layer rendered preview: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _launch(map_name):
	if not CAMPAIGN.has(map_name):
		await _skirmish("bastion", "res://source/match/maps/%s.tscn" % map_name)
		return
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = CAMPAIGN[map_name][0]
	settings.map_path = "res://source/match/maps/%s.tscn" % map_name
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		settings.players.append(side)
	game = load(CAMPAIGN[map_name][1]).instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	game.progress_path = "user://terrain-preview-progress-%d.json" % OS.get_process_id()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(60)


# The "Ground detail" setting off must render exactly the authored control.
func _check_setting(label, point, zoom):
	var options = root.get_node("Globals").options
	options.graphics_ground_detail = false
	options.apply()
	var off = await _capture(label + "-setting-off", point, zoom)
	options.graphics_ground_detail = true
	options.apply()
	var on = await _capture(label, point, zoom)
	var control = Image.load_from_file(
		ProjectSettings.globalize_path(OUTPUT + label + "-detail-off.png")
	)
	var matching = 0
	var changed = 0
	var samples = 0
	for x in range(40, off.get_width() - 40, 37):
		for y in range(140, off.get_height() - 140, 37):
			samples += 1
			var a = off.get_pixel(x, y)
			matching += int(
				abs(a.r - control.get_pixel(x, y).r) + abs(a.g - control.get_pixel(x, y).g) < .02
			)
			changed += int(not a.is_equal_approx(on.get_pixel(x, y)))
	_check(matching > samples * .97, label + ": setting off does not match the authored ground")
	_check(changed > samples * .3, label + ": setting on did not restore scanned ground")


func _collect_ground():
	var seen = {}
	for mesh in game.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			if not material is ShaderMaterial or seen.has(material):
				continue
			seen[material] = true
			if material.get_shader_parameter("base_color") is Texture2D:
				_ground.append(material)


func _set_detail(amount):
	for material in _ground:
		material.set_shader_parameter("terrain_detail", amount)
	var decals = game.map.get_node_or_null("GroundDecals")
	if decals != null:
		decals.visible = amount > 0.0


func _pair(label, point, zoom):
	await _capture(label, point, zoom)
	_set_detail(0.0)
	await _capture(label + "-detail-off", point, zoom)
	_set_detail(1.0)


func _capture(label, point, zoom):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.size_max = 150
	camera.set_size_safely(zoom)
	camera.set_position_safely(point)
	await _frames(12)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels != null and not pixels.is_empty(), "Empty rendered capture: " + label)
	if pixels != null:
		_check(pixels.save_png(OUTPUT + label + ".png") == OK, "Failed to save " + label)
	print("Captured ", label)
	return pixels

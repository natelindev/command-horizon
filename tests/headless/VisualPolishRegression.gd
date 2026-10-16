extends "res://tests/headless/RosterLayoutRegression.gd"

var rendered = false
var captures = "res://tmp/visual-polish"


func _run():
	rendered = "--render" in OS.get_cmdline_user_args()
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.0, "menu_motion": false, "language": "en"})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(captures)
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _capture("home")
	TranslationServer.set_locale("zh_CN")
	await _capture("home-zh")
	TranslationServer.set_locale("en")
	menu.free()
	var setup = load("res://source/main-menu/Play.tscn").instantiate()
	setup.preferences_path = "user://visual-polish-no-preferences.cfg"
	root.add_child(setup)
	current_scene = setup
	for index in setup.MAPS.size():
		setup._map_list.select(index)
		setup._on_map_list_item_selected(index)
		await _frames(4)
		_check(setup._preview._terrain != null, "Map preview has no terrain")
		_check(
			root.get_visible_rect().encloses(setup._start_button.get_global_rect()),
			"Start button outside viewport"
		)
		await _capture("map-%d" % index)
	options.interface_scale = 1.5
	options.apply()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(6)
	_check(
		root.get_visible_rect().encloses(setup._start_button.get_global_rect()),
		"Setup clipped at 150%"
	)
	await _capture("setup-150")
	TranslationServer.set_locale("zh_CN")
	await _capture("setup-zh-150")
	_check(
		root.get_visible_rect().encloses(setup._start_button.get_global_rect()),
		"Chinese setup clipped at 150%"
	)
	TranslationServer.set_locale("en")
	setup.free()
	options.interface_scale = 1.0
	options.apply()
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	for faction in factions.IDS:
		for role in catalog.INFANTRY_ROLES:
			var icon = load(factions.icon(faction, role))
			_check(
				icon is Texture2D and icon.get_width() > 0, "Missing portrait: " + faction + role
			)
			if icon is Texture2D:
				var pixels = icon.get_image()
				_check(
					pixels.get_used_rect().get_area() > 1024, "Empty portrait: " + faction + role
				)
	await _layout_fixture("bastion")
	var human = game._get_human_player()
	var barracks = _units(human, "Barracks")[0]
	var menus = _select(barracks)
	await _frames(6)
	_check_layout(menus, "barracks")
	for entry in menus._buttons:
		_check(entry.button.portrait() != null, "Barracks missing " + entry.type)
	await _capture("barracks")
	var lab = _units(human, "CommandLab")[0]
	menus = _select(lab)
	await _frames(6)
	var research = menus._research_panel
	_check(research != null, "No research panel")
	_check(
		research.find_children("*Artwork", "TextureRect", true, false).size() == 5,
		"Research artwork missing"
	)
	await _capture("research")
	_check(
		research.get_global_rect().end.x <= menus._scroll.get_global_rect().end.x,
		"Research cards clipped horizontally"
	)
	research._research_branch("weapons")
	game.hud._toggle_pause()
	await _frames(120)
	game.hud.pause_after_load()
	research.refresh()
	await _capture("research-active")
	research._cancel_active()
	menus._scroll.scroll_vertical = 1000
	await _capture("research-doctrine")
	var structure = _units(human, "PowerPlant")[0]
	var mesh = structure.get_node("Geometry").find_children("*", "MeshInstance3D", true, false)[0]
	var before_material = mesh.get_active_material(0)
	structure.mark_as_under_construction()
	var visual = structure.get_node_or_null("ConstructionVisual")
	_check(visual != null, "Construction has no animated visual")
	_check(mesh.get_active_material(0) is ShaderMaterial, "Construction still uses static ghost")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(16)
	camera.set_position_safely(structure.position + Vector3(3, 0, 0))
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _capture("construction-00")
	structure.construct(.45)
	_check(
		is_equal_approx(mesh.get_active_material(0).get_shader_parameter("progress"), .45),
		"Assembly does not follow paid progress"
	)
	var phase = visual._phase
	visual._process(.5)
	_check(visual._phase > phase, "Assembly does not animate")
	await _capture("construction-45")
	structure.construct(.55)
	await _frames(2)
	_check(
		structure.get_node_or_null("ConstructionVisual") == null, "Finished building retains visual"
	)
	_check(mesh.get_active_material(0) == before_material, "Completion lost original materials")
	await _capture("construction-100")
	camera.set_size_safely(20)
	camera.set_position_safely(Vector3(46, 0, 30))
	await _capture("trees")
	paused = false
	game.queue_free()
	await _frames(4)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Visual polish: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _capture(label):
	await _frames(8)
	if rendered:
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(captures + "/" + label + ".png")

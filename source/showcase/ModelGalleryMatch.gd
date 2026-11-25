extends "res://source/match/Skirmish.gd"

const Document = preload("res://source/scenario/ScenarioDocument.gd")

const FACTIONS = ["bastion", "helix", "frontier"]
const FACTION_LABELS = {
	"bastion": "Bastion Directorate",
	"helix": "Helix Systems",
	"frontier": "Free Frontier Coalition",
}
const FACTION_ORIGINS = {
	"bastion": 22.0,
	"helix": 74.0,
	"frontier": 126.0,
}
const STRUCTURES_ROW_1 = [
	"CommandCenter",
	"Barracks",
	"VehicleFactory",
	"AircraftFactory",
	"PowerPlant",
]
const STRUCTURES_ROW_2 = [
	"CommandLab",
	"RepairDepot",
	"AntiGroundTurret",
	"AntiAirTurret",
]
const INFANTRY_ROW = [
	"Infantry",
	"AssaultInfantry",
	"RocketInfantry",
	"SniperInfantry",
	"Hero",
]
const VEHICLE_ROW = [
	"Worker",
	"RepairRobot",
	"Tank",
	"CombatRobot",
	"AdvancedTank",
	"AntiAirVehicle",
]
const AIR_ROW = [
	"Drone",
	"Helicopter",
	"Fighter",
	"Bomber",
]

var _gallery_entries: Array = []
var _gallery_index := 0
var _air_frozen := true
var _focus_label: Label = null


static func build_scenario_document() -> Dictionary:
	var doc = Document.canonical(
		{
			"version": Document.VERSION,
			"title": "All-Faction Model Gallery",
			"size": [160, 104],
			"biome": "temperate",
			"spawns": [
				{"x": 24, "z": 16, "yaw": 180},
				{"x": 74, "z": 16, "yaw": 180},
				{"x": 126, "z": 16, "yaw": 180},
				{"x": 74, "z": 92, "yaw": 0},
			],
			"items": [
				{"kind": "materials", "x": 18, "z": 76, "yaw": 0, "amount": 2000},
				{"kind": "electronics", "x": 30, "z": 76, "yaw": 0, "amount": 2000},
				{"kind": "materials", "x": 68, "z": 76, "yaw": 0, "amount": 2000},
				{"kind": "electronics", "x": 80, "z": 76, "yaw": 0, "amount": 2000},
				{"kind": "materials", "x": 120, "z": 76, "yaw": 0, "amount": 2000},
				{"kind": "electronics", "x": 132, "z": 76, "yaw": 0, "amount": 2000},
			],
		}
	)
	var codec = Document.new()
	assert(codec.validate(doc), codec.error)
	return doc


static func create_match_settings() -> Resource:
	var doc = build_scenario_document()
	Document.new().write_document("model-gallery", doc)
	var match_settings = load("res://source/data-model/MatchSettings.gd").new()
	match_settings.skirmish = true
	match_settings.advanced_start = false
	match_settings.battlefield_events = false
	match_settings.visibility = match_settings.Visibility.FULL
	match_settings.map_path = Document.MAP
	match_settings.scenario = doc
	for index in range(FACTIONS.size()):
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = (
			Constants.PlayerType.HUMAN if index == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		side.faction = FACTIONS[index]
		side.team = 1
		side.color = Constants.Player.COLORS[index]
		side.spawn_index = index
		match_settings.players.append(side)
	return match_settings


func _enter_tree():
	if settings == null:
		settings = create_match_settings()
	if map == null:
		var scenario_map = load(Document.MAP).instantiate()
		scenario_map.scenario = settings.scenario.duplicate(true)
		map = scenario_map
	super()


func _ready():
	super()
	get_node("/root/SaveManager").autosaves_enabled = false
	for player in get_cached_group("players"):
		if player != _get_human_player():
			player.set_process(false)
			player.set_physics_process(false)
	fog_of_war.reveal()
	_camera.size_min = 3.5
	_camera.size_max = 72.0
	_build_gallery_hud()
	if not _gallery_entries.is_empty():
		_focus_entry(0)
	else:
		_jump_faction("bastion")


func _spawn_player_units(player, _spawn_transform):
	player.resource_a = 999
	player.resource_b = 999
	var origin_x: float = FACTION_ORIGINS.get(player.faction, 24.0)
	_spawn_row(player, STRUCTURES_ROW_1, origin_x, 22.0, 7.6, true)
	_spawn_row(player, STRUCTURES_ROW_2, origin_x + 3.8, 33.0, 7.6, true)
	_spawn_row(player, INFANTRY_ROW, origin_x + 7.0, 44.0, 3.6, false)
	_spawn_row(player, VEHICLE_ROW, origin_x + 1.5, 53.0, 5.6, false)
	_spawn_row(player, AIR_ROW, origin_x + 4.5, 64.0, 6.8, false, true)


func _spawn_row(
	player, roles: Array, start_x: float, z_pos: float, spacing: float, is_structure: bool, is_air: bool = false
):
	for index in range(roles.size()):
		var role: String = roles[index]
		var point = Vector3(start_x + index * spacing, 1.5 if is_air else 0.0, z_pos)
		var unit = load(Catalog.scene_path(role)).instantiate()
		_setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
		unit.global_rotation.y = PI
		if is_air:
			var movement = unit.get_node_or_null("Movement")
			if movement != null:
				movement.set_physics_process(not _air_frozen)
		_gallery_entries.append(
			{
				"faction": player.faction,
				"role": role,
				"title": Catalog.NAMES.get(role, role),
				"unit": unit,
				"is_structure": is_structure,
				"zoom": 10.5 if is_structure else 6.0,
			}
		)


func _check_outcome(_delta):
	pass


func objective_text():
	return "Model Gallery · WASD/Drag pan · Wheel zoom · Q/E rotate · [ / ] cycle models"


func _build_gallery_hud():
	var layer = CanvasLayer.new()
	layer.name = "ModelGalleryNavigator"
	layer.layer = 12
	add_child(layer)

	var panel = PanelContainer.new()
	panel.position = Vector2(16, 48)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("0f1821e6")
	style.border_color = Color("4a6578cc")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)
	for faction in FACTIONS:
		var btn = Button.new()
		btn.text = faction.capitalize()
		btn.pressed.connect(_jump_faction.bind(faction))
		row1.add_child(btn)
	var overview = Button.new()
	overview.text = "All 3 Factions"
	overview.pressed.connect(_jump_overview)
	row1.add_child(overview)

	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vbox.add_child(row2)
	var prev_btn = Button.new()
	prev_btn.text = "< Prev ["
	prev_btn.pressed.connect(_step_entry.bind(-1))
	row2.add_child(prev_btn)

	_focus_label = Label.new()
	_focus_label.custom_minimum_size.x = 260
	_focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row2.add_child(_focus_label)

	var next_btn = Button.new()
	next_btn.text = "] Next >"
	next_btn.pressed.connect(_step_entry.bind(1))
	row2.add_child(next_btn)

	var row3 = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	vbox.add_child(row3)
	for spec in [["Close (4.5m)", 4.5], ["Detail (8m)", 8.0], ["Wing (28m)", 28.0]]:
		var zbtn = Button.new()
		zbtn.text = spec[0]
		zbtn.pressed.connect(func(): _camera.set_size_safely(spec[1]))
		row3.add_child(zbtn)

	var air_btn = Button.new()
	air_btn.text = "Hover Air: Frozen"
	air_btn.pressed.connect(func():
		_air_frozen = not _air_frozen
		air_btn.text = "Hover Air: Frozen" if _air_frozen else "Hover Air: Live"
		for entry in _gallery_entries:
			if entry.role in AIR_ROW and is_instance_valid(entry.unit):
				var movement = entry.unit.get_node_or_null("Movement")
				if movement != null:
					movement.set_physics_process(not _air_frozen)
	)
	row3.add_child(air_btn)

	var viewer_btn = Button.new()
	viewer_btn.text = "3D Turntable"
	viewer_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://source/showcase/HelixShowcase.tscn")
	)
	row3.add_child(viewer_btn)

	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
	)
	row3.add_child(menu_btn)


func _jump_faction(faction: String):
	for index in range(_gallery_entries.size()):
		if _gallery_entries[index].faction == faction and _gallery_entries[index].role == "Tank":
			_focus_entry(index, 22.0)
			return
	_camera.set_position_safely(Vector3(FACTION_ORIGINS.get(faction, 74.0) + 14.0, 0.0, 44.0))
	_camera.set_size_safely(28.0)


func _jump_overview():
	_camera.set_position_safely(Vector3(82.0, 0.0, 44.0))
	_camera.set_size_safely(56.0)
	if _focus_label != null:
		_focus_label.text = "All 3 Factions Overview (72 models)"


func _step_entry(delta: int):
	if _gallery_entries.is_empty():
		return
	var next_index = posmod(_gallery_index + delta, _gallery_entries.size())
	_focus_entry(next_index)


func _focus_entry(index: int, zoom_override: float = -1.0):
	_gallery_index = index
	var entry = _gallery_entries[index]
	var unit = entry.unit
	if is_instance_valid(unit):
		_camera.set_position_safely(Vector3(unit.global_position.x, 0.0, unit.global_position.z))
		_camera.set_size_safely(zoom_override if zoom_override > 0.0 else entry.zoom)
	if _focus_label != null:
		var factions = load("res://source/match/FactionCatalog.gd")
		var display_name = factions.title(entry.faction, entry.role)
		_focus_label.text = "%s · %s (%d/%d)" % [
			entry.faction.capitalize(), display_name, index + 1, _gallery_entries.size()
		]


func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BRACKETLEFT:
			_step_entry(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_BRACKETRIGHT:
			_step_entry(1)
			get_viewport().set_input_as_handled()

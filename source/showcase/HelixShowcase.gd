extends Node3D

# Canonical role IDs resolve through the same model/equipment path as battle.
const INFANTRY = ["Infantry", "AssaultInfantry", "RocketInfantry", "SniperInfantry", "Hero"]
const UNITS = [
	"Worker",
	"Tank",
	"CombatRobot",
	"AdvancedTank",
	"AntiAirVehicle",
	"RepairRobot",
	"Drone",
	"Helicopter",
	"Fighter",
	"Bomber"
]
const STRUCTURES = [
	"CommandCenter",
	"Barracks",
	"VehicleFactory",
	"AircraftFactory",
	"PowerPlant",
	"CommandLab",
	"RepairDepot",
	"AntiGroundTurret",
	"AntiAirTurret"
]
var _factions

var _faction := "helix"
var _current_asset := "Tank"
var _heading: Label = null
var _model = null
var _camera = null
var _roster = null
var _title = null
var _description = null
var _rotation_enabled = true
var _team_index = 0
var _elapsed = 0.0
var _team_material = StandardMaterial3D.new()


func _ready():
	_factions = load("res://source/match/FactionCatalog.gd")
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("25343f")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c7dde5")
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -30, 0)
	light.light_energy = 1.6
	light.shadow_enabled = true
	add_child(light)
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var surface = StandardMaterial3D.new()
	surface.albedo_color = Color("344653")
	surface.roughness = 0.9
	ground.material_override = surface
	ground.position.y = -0.03
	add_child(ground)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 10.5
	_camera.position = Vector3(9, 7, -12)
	add_child(_camera)
	_camera.look_at(Vector3(0, 2.6, 0))
	_camera.h_offset = -1.4
	_team_material.albedo_color = Color("146f78")
	_team_material.metallic = 0.25
	_team_material.roughness = 0.42
	_build_ui()
	_show_roster(UNITS)
	_select("Tank")


func _build_ui():
	var layer = CanvasLayer.new()
	add_child(layer)
	var panel = PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size.x = 365
	var style = StyleBoxFlat.new()
	style.bg_color = Color("121d27ed")
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)
	_heading = Label.new()
	_heading.text = "HELIX SYSTEMS"
	_heading.add_theme_font_size_override("font_size", 25)
	content.add_child(_heading)
	var subtitle = Label.new()
	subtitle.text = "Faction model review"
	content.add_child(subtitle)
	var faction_tabs = HBoxContainer.new()
	content.add_child(faction_tabs)
	for f_id in ["bastion", "helix", "frontier"]:
		var fbtn = Button.new()
		fbtn.text = f_id.capitalize()
		fbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fbtn.pressed.connect(_set_faction.bind(f_id))
		faction_tabs.add_child(fbtn)
	var tabs = HBoxContainer.new()
	content.add_child(tabs)
	for entry in [["Infantry", INFANTRY], ["Vehicles", UNITS], ["Structures", STRUCTURES]]:
		var button = Button.new()
		button.text = entry[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_show_roster.bind(entry[1]))
		tabs.add_child(button)
	_roster = VBoxContainer.new()
	_roster.add_theme_constant_override("separation", 4)
	content.add_child(_roster)
	var rotate = Button.new()
	rotate.text = "Pause / rotate model  [Space]"
	rotate.pressed.connect(func(): _rotation_enabled = not _rotation_enabled)
	content.add_child(rotate)
	var color = Button.new()
	color.text = "Change team markings"
	color.pressed.connect(_change_team)
	content.add_child(color)
	var gallery = Button.new()
	gallery.text = "Battlefield Gallery (all units)"
	gallery.pressed.connect(func(): get_tree().change_scene_to_file("res://source/showcase/ModelGalleryMatch.tscn"))
	content.add_child(gallery)
	var back = Button.new()
	back.text = "Back to menu  [Esc]"
	back.pressed.connect(_back)
	content.add_child(back)
	var details = VBoxContainer.new()
	details.position = Vector2(440, 34)
	layer.add_child(details)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	details.add_child(_title)
	_description = Label.new()
	_description.add_theme_font_size_override("font_size", 17)
	_description.custom_minimum_size.x = 650
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_description)
	var hint = Label.new()
	hint.text = "Wheel: zoom    Q / E: turn    Space: pause rotation"
	hint.add_theme_font_size_override("font_size", 14)
	details.add_child(hint)


var _current_entries := UNITS


func _set_faction(faction_id: String):
	_faction = faction_id
	if _heading != null:
		_heading.text = {
			"bastion": "BASTION DIRECTORATE",
			"helix": "HELIX SYSTEMS",
			"frontier": "FREE FRONTIER",
		}.get(faction_id, faction_id.to_upper())
	_show_roster(_current_entries, _current_asset)


func _show_roster(entries, preferred_asset := ""):
	_current_entries = entries
	for child in _roster.get_children():
		_roster.remove_child(child)
		child.queue_free()
	for asset in entries:
		var button = Button.new()
		button.name = asset
		button.text = _factions.title(_faction, asset)
		button.icon = load(_factions.icon(_faction, asset))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 28)
		button.custom_minimum_size = Vector2(320, 36)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select.bind(asset))
		_roster.add_child(button)
	_select(preferred_asset if preferred_asset in entries else entries[0])


func _select(asset):
	_current_asset = asset
	if _model != null:
		remove_child(_model)
		_model.queue_free()
	var unit = load(_factions.scene_path(_faction, asset)).instantiate()
	_factions.prepare_model(unit, _faction)
	if asset in INFANTRY:
		load("res://source/match/units/traits/InfantryMotion.gd").new().setup(unit, 0, asset)
	_model = unit.get_node("Geometry")
	unit.remove_child(_model)
	unit.free()
	add_child(_model)
	var bounds = AABB()
	var first = true
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree():
			continue
		var box = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for index in range(mesh.mesh.get_surface_count()):
			var material = mesh.get_active_material(index)
			if material != null and material.resource_name.begins_with("TeamColor"):
				mesh.set_surface_override_material(index, _team_material)
	var factor = 5.8 / max(bounds.size.x, bounds.size.y, bounds.size.z)
	_model.scale = Vector3.ONE * factor
	_model.position = (
		-Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	)
	_model.rotation.y = 0.0
	_camera.size = 10.5
	_title.text = _factions.title(_faction, asset)
	_description.text = _factions.description(_faction, asset)


func _process(delta):
	if _model == null:
		return
	_elapsed += delta
	if _rotation_enabled:
		_model.rotation.y += delta * 0.25
	for rotor in _model.find_children("*Rotor?", "Node3D", true, false):
		rotor.rotation.y += delta * 14.0 if _rotation_enabled else 0.0


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:
				_rotation_enabled = not _rotation_enabled
			KEY_Q:
				_model.rotation.y += 0.15
			KEY_E:
				_model.rotation.y -= 0.15
			KEY_ESCAPE:
				_back()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.size = max(5.5, _camera.size - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.size = min(17.0, _camera.size + 0.5)


func _change_team():
	_team_index = (_team_index + 1) % 3
	_team_material.albedo_color = [Color("146f78"), Color("c95b53"), Color("dfa944")][_team_index]


func _back():
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")

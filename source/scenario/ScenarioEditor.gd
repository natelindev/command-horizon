# gdlint: disable=max-file-lines,max-public-methods
extends Control

const Document = preload("res://source/scenario/ScenarioDocument.gd")
const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const TOOL_NAMES = {
	"select": "Select / move",
	"spawn": "Starting position",
	"materials": "Materials deposit",
	"electronics": "Electronics deposit",
	"refinery": "Tech Refinery",
	"data_relay": "Data Relay"
}
var document: Dictionary = {}
var _codec = Document.new()
var _undo: Array = []
var _redo: Array = []
var _tool := "select"
var _selection := -1
var _spawns_selected := false
var _tool_buttons := {}
var _viewport: SubViewport
var _surface: SubViewportContainer
var _world: Node3D
var _pieces: Node3D
var _camera: Camera3D
var _center := Vector3(48, 0, 48)
var _zoom := 115.0
var _status: Label
var _filename: LineEdit
var _title: LineEdit
var _library: OptionButton
var _biome: OptionButton
var _players: OptionButton
var _faction: OptionButton
var _opponent: OptionButton
var _spawn_slot: SpinBox
var _width: SpinBox
var _depth: SpinBox
var _x: SpinBox
var _z: SpinBox
var _yaw: SpinBox
var _amount: SpinBox
var _selected_name: Label
var _undo_button: Button
var _redo_button: Button
var _pan := false


func _ready():
	theme = ArtTheme.create()
	document = get_tree().get_meta("scenario_editor_draft", Document.blank()).duplicate(true)
	if not _codec.validate(document):
		document = Document.blank()
	_build_ui()
	_build_world()
	_sync_document_controls()
	_rebuild()
	_refresh_library()
	_select_tool("select")


func _build_ui():
	var background := ColorRect.new()
	background.color = Color("111a20")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var top := HBoxContainer.new()
	page.add_child(top)
	_label(top, "SCENARIO EDITOR", true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top, "Main menu", _main_menu)
	_undo_button = _button(top, "Undo", _undo_edit)
	_redo_button = _button(top, "Redo", _redo_edit)
	_button(top, "New battlefield", _new_document)
	var files := HBoxContainer.new()
	page.add_child(files)
	_filename = LineEdit.new()
	_filename.placeholder_text = tr("Filename")
	_filename.text = "my-battlefield"
	_filename.custom_minimum_size.x = 230
	files.add_child(_filename)
	_button(files, "Save battlefield", _save)
	_library = OptionButton.new()
	_library.custom_minimum_size.x = 240
	files.add_child(_library)
	_button(files, "Load battlefield", _load_file)
	_title = LineEdit.new()
	_title.placeholder_text = tr("Battlefield title")
	_title.max_length = 80
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	files.add_child(_title)
	_title.text_submitted.connect(func(_text): _apply_settings())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	page.add_child(body)
	var palette := VBoxContainer.new()
	palette.custom_minimum_size.x = 230
	body.add_child(palette)
	_label(palette, "Terrain & pieces", true)
	var tiles := GridContainer.new()
	tiles.columns = 2
	palette.add_child(tiles)
	for kind in Document.TOOLS + Document.KITS.keys():
		var caption: String = TOOL_NAMES.get(kind, Document.KITS.get(kind, {}).get("name", kind))
		var button = _button(tiles, caption, _select_tool.bind(kind))
		button.custom_minimum_size = Vector2(150, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = button.text
		var space = button.text.find(" ")
		if space >= 0:
			button.text = button.text.substr(0, space) + "\n" + button.text.substr(space + 1)
		button.toggle_mode = true
		_tool_buttons[kind] = button
	_label(palette, "Left click to place or select")
	_label(palette, "Right click to remove")
	_label(palette, "Middle drag to pan · Wheel to zoom")
	_surface = SubViewportContainer.new()
	_surface.name = "MapCanvas"
	_surface.stretch = true
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_surface.custom_minimum_size = Vector2(400, 350)
	body.add_child(_surface)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_surface.add_child(_viewport)
	_surface.gui_input.connect(_canvas_input)
	var inspector := VBoxContainer.new()
	inspector.custom_minimum_size.x = 235
	body.add_child(inspector)
	_label(inspector, "Battlefield", true)
	_width = _number(inspector, "Width (m)", 48, 192, 8)
	_depth = _number(inspector, "Depth (m)", 48, 192, 8)
	_biome = _options(inspector, "Terrain", ["Desert", "Temperate", "Volcanic"])
	_players = _options(inspector, "Starting positions", ["2 players", "4 players"])
	_button(inspector, "Apply battlefield", _apply_settings)
	inspector.add_child(HSeparator.new())
	_selected_name = _label(inspector, "Piece properties", true)
	_spawn_slot = _number(inspector, "Starting slot", 1, 4, 1)
	_spawn_slot.get_parent().hide()
	_x = _number(inspector, "X (m)", 0, 192, .5)
	_z = _number(inspector, "Z (m)", 0, 192, .5)
	_yaw = _number(inspector, "Rotation (degrees)", -360, 360, 15)
	_amount = _number(inspector, "Deposit amount", 0, 10000, 50)
	_amount.value = 800
	_button(inspector, "Apply to selection", _apply_selection)
	_button(inspector, "Remove selection", _remove_selection)
	var launch := HBoxContainer.new()
	page.add_child(launch)
	_faction = _options(launch, "Your faction", ["Bastion", "Helix", "Frontier"])
	_opponent = _options(launch, "Opponent faction", ["Bastion", "Helix", "Frontier"])
	_opponent.select(1)
	var play = _button(launch, "Play battlefield", _play)
	play.theme_type_variation = "BattlePrimaryButton"
	_status = _label(launch, "")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_world():
	_world = Node3D.new()
	_viewport.add_child(_world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("1a262e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c0d3dd")
	environment.environment.ambient_light_energy = .7
	_world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	_world.add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.far = 600
	_world.add_child(_camera)
	_camera.make_current()
	_update_camera()


func _rebuild():
	if is_instance_valid(_pieces):
		_world.remove_child(_pieces)
		_pieces.queue_free()
	_pieces = Node3D.new()
	_world.add_child(_pieces)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(document.size[0], document.size[1])
	ground.position = Vector3(document.size[0], 0, document.size[1]) * .5
	var material := StandardMaterial3D.new()
	material.albedo_color = {
		"desert": Color("8a7656"), "temperate": Color("57694b"), "volcanic": Color("555153")
	}[document.biome]
	material.roughness = 1.0
	ground.material_override = material
	_pieces.add_child(ground)
	_grid()
	for index in document.spawns.size():
		var entry = document.spawns[index]
		var marker = _primitive(Vector3(entry.x, .06, entry.z), Color("d8d8c3"), 5.0, .1)
		var label := Label3D.new()
		label.text = str(index + 1)
		label.font_size = 72
		label.pixel_size = .04
		label.outline_size = 8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = 2.0
		marker.add_child(label)
	for entry in document.items:
		var point := Vector3(entry.x, 0, entry.z)
		if entry.kind in Document.KITS:
			var kit = Document.KITS[entry.kind]
			var model = load("res://assets/models/environment/%s.glb" % kit.model).instantiate()
			model.scale = Vector3.ONE * kit.scale
			model.position = point
			model.rotation.y = deg_to_rad(entry.yaw)
			_pieces.add_child(model)
		else:
			var colors = {
				"materials": Color("dba76b"),
				"electronics": Color("75ced7"),
				"refinery": Color("b9b8a2"),
				"data_relay": Color("a0bbd2")
			}
			_primitive(point + Vector3.UP * .8, colors[entry.kind], 2.0, 1.6)
			var label := Label3D.new()
			label.text = tr(TOOL_NAMES[entry.kind])
			label.font_size = 28
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = point + Vector3.UP * 2.6
			_pieces.add_child(label)
	if _selection >= 0:
		var entries: Array = document.spawns if _spawns_selected else document.items
		if _selection < entries.size():
			var entry = entries[_selection]
			_selection_ring(Vector3(entry.x, .12, entry.z))
	_undo_button.disabled = _undo.is_empty()
	_redo_button.disabled = _redo.is_empty()
	get_tree().set_meta("scenario_editor_draft", document.duplicate(true))


func _grid():
	var lines := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 1, 1, .13)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for x in range(0, int(document.size[0]) + 1, 4):
		lines.surface_add_vertex(Vector3(x, .025, 0))
		lines.surface_add_vertex(Vector3(x, .025, document.size[1]))
	for z in range(0, int(document.size[1]) + 1, 4):
		lines.surface_add_vertex(Vector3(0, .025, z))
		lines.surface_add_vertex(Vector3(document.size[0], .025, z))
	lines.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = lines
	_pieces.add_child(node)


func _selection_ring(point: Vector3):
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.WHITE
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for index in 48:
		for next in [index, index + 1]:
			var angle: float = next * TAU / 48.0
			mesh.surface_add_vertex(point + Vector3(cos(angle), 0, sin(angle)) * 3)
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	_pieces.add_child(node)


func _primitive(point: Vector3, color: Color, diameter: float, height: float) -> Node3D:
	var node := MeshInstance3D.new()
	node.mesh = CylinderMesh.new()
	node.mesh.top_radius = diameter * .5
	node.mesh.bottom_radius = diameter * .5
	node.mesh.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .8
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	node.position = point
	_pieces.add_child(node)
	return node


func _canvas_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan = event.pressed
		elif (
			event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
		):
			_zoom = clampf(
				_zoom * (.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 24, 260
			)
			_update_camera()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var ray = _camera.project_ray_origin(event.position)
			var direction = _camera.project_ray_normal(event.position)
			if absf(direction.y) > .001:
				var point: Vector3 = ray - direction * ray.y / direction.y
				point = Vector3(snappedf(point.x, .5), 0, snappedf(point.z, .5))
				if event.button_index == MOUSE_BUTTON_RIGHT:
					_pick(point)
					_remove_selection()
				else:
					place_at(point)
		_surface.accept_event()
	elif event is InputEventMouseMotion and _pan:
		var distance := _zoom / maxf(1.0, _surface.size.y)
		_center -= _camera.global_basis.x * event.relative.x * distance
		_center -= (_camera.global_basis.y * Vector3(1, 0, 1)) * event.relative.y * distance * 1.6
		_center.x = clampf(_center.x, 0, document.size[0])
		_center.z = clampf(_center.z, 0, document.size[1])
		_update_camera()


func place_at(point: Vector3) -> bool:
	if _tool == "select":
		_pick(point)
		return true
	var next := document.duplicate(true)
	if _tool == "spawn":
		var index := clampi(int(_spawn_slot.value) - 1, 0, next.spawns.size() - 1)
		next.spawns[index] = {"x": point.x, "z": point.z, "yaw": _yaw.value}
	else:
		next.items.append(
			{
				"kind": _tool,
				"x": point.x,
				"z": point.z,
				"yaw": _yaw.value,
				"amount": int(_amount.value) if _tool in ["materials", "electronics"] else 0
			}
		)
	return _commit(next)


func _pick(point: Vector3):
	var best := 5.0
	_selection = -1
	for spawns in [false, true]:
		var entries: Array = document.spawns if spawns else document.items
		for index in entries.size():
			var entry = entries[index]
			var distance := point.distance_to(Vector3(entry.x, 0, entry.z))
			if distance < best:
				best = distance
				_selection = index
				_spawns_selected = spawns
	if _selection >= 0:
		var entry = (document.spawns if _spawns_selected else document.items)[_selection]
		_x.value = entry.x
		_z.value = entry.z
		_yaw.value = entry.yaw
		_amount.value = entry.get("amount", 0)
		_selected_name.text = (
			tr("Starting position")
			if _spawns_selected
			else tr(
				TOOL_NAMES.get(
					entry.kind, Document.KITS.get(entry.kind, {}).get("name", entry.kind)
				)
			)
		)
		_spawn_slot.get_parent().visible = _spawns_selected
		_amount.get_parent().visible = (
			not _spawns_selected and entry.kind in ["materials", "electronics"]
		)
	_rebuild()


func _apply_selection():
	if _selection < 0:
		return
	var next := document.duplicate(true)
	var entry = (next.spawns if _spawns_selected else next.items)[_selection]
	entry.x = _x.value
	entry.z = _z.value
	entry.yaw = _yaw.value
	if not _spawns_selected:
		entry.amount = int(_amount.value) if entry.kind in ["materials", "electronics"] else 0
	_commit(next)


func _remove_selection():
	if _selection < 0:
		return
	if _spawns_selected:
		_status.text = tr("Move starting positions or change the player count.")
		return
	var next := document.duplicate(true)
	next.items.remove_at(_selection)
	_selection = -1
	_commit(next)


func _commit(next: Dictionary) -> bool:
	if not _codec.validate(next):
		_status.text = tr(_codec.error)
		return false
	if next == document:
		return true
	_undo.append(document.duplicate(true))
	if _undo.size() > 64:
		_undo.pop_front()
	_redo.clear()
	document = next
	if _selection >= (document.spawns.size() if _spawns_selected else document.items.size()):
		_selection = -1
	_status.text = tr("Unsaved changes")
	_rebuild()
	return true


func _undo_edit():
	if _undo.is_empty():
		return
	_redo.append(document)
	document = _undo.pop_back()
	_selection = -1
	_sync_document_controls()
	_rebuild()
	_status.text = tr("Unsaved changes")


func _redo_edit():
	if _redo.is_empty():
		return
	_undo.append(document)
	document = _redo.pop_back()
	_selection = -1
	_sync_document_controls()
	_rebuild()
	_status.text = tr("Unsaved changes")


func _apply_settings() -> bool:
	var next := document.duplicate(true)
	next.title = _title.text.strip_edges()
	next.size = [int(_width.value), int(_depth.value)]
	next.biome = ["desert", "temperate", "volcanic"][_biome.selected]
	var count := 2 if _players.selected == 0 else 4
	if count != next.spawns.size():
		next.spawns = next.spawns.slice(0, count)
		if count == 4:
			next.spawns.append({"x": 14, "z": next.size[1] - 14, "yaw": 90})
			next.spawns.append({"x": next.size[0] - 14, "z": 14, "yaw": -90})
	if _commit(next):
		_spawn_slot.max_value = count
		return true
	return false


func _sync_document_controls():
	_title.text = document.title
	_width.value = document.size[0]
	_depth.value = document.size[1]
	_biome.select(["desert", "temperate", "volcanic"].find(document.biome))
	_players.select(0 if document.spawns.size() == 2 else 1)
	_spawn_slot.max_value = document.spawns.size()


func _select_tool(kind: String):
	_tool = kind
	for key in _tool_buttons:
		_tool_buttons[key].set_pressed_no_signal(key == kind)
	_status.text = tr(TOOL_NAMES.get(kind, Document.KITS.get(kind, {}).get("name", kind)))
	_spawn_slot.get_parent().visible = kind == "spawn"
	_amount.get_parent().visible = kind in ["materials", "electronics"]


func _update_camera():
	_camera.size = _zoom
	_camera.position = _center + Vector3(70, 95, 70)
	_camera.look_at(_center)


func _save():
	if _title.text.strip_edges() != document.title:
		if not _apply_settings():
			return
	if _codec.write_document(_filename.text, document):
		_status.text = tr("Battlefield saved")
		_refresh_library()
	else:
		_status.text = tr(_codec.error)


func _load_file():
	if _library.item_count == 0:
		return
	var name_to_load := _library.get_item_text(_library.selected)
	var loaded := _codec.read_document(name_to_load)
	if loaded.is_empty():
		_status.text = tr(_codec.error)
		return
	_commit(loaded)
	_filename.text = name_to_load
	_selection = -1
	_sync_document_controls()
	_status.text = tr("Battlefield loaded")


func _refresh_library():
	_library.clear()
	for filename in Document.files():
		_library.add_item(filename)


func _new_document():
	_selection = -1
	_commit(Document.blank())
	_sync_document_controls()
	_center = Vector3(48, 0, 48)
	_update_camera()


func _play():
	if not _codec.validate(document):
		_status.text = tr(_codec.error)
		return
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = Document.MAP
	settings.scenario = document.duplicate(true)
	settings.battlefield_events = false
	settings.match_seed = 1
	for index in document.spawns.size():
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = (
			Constants.PlayerType.HUMAN if index == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		side.faction = ["bastion", "helix", "frontier"][
			_faction.selected if index == 0 else _opponent.selected
		]
		side.color = Constants.Player.COLORS[index]
		side.spawn_index = index
		settings.players.append(side)
	get_tree().set_meta("scenario_editor_draft", document.duplicate(true))
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = Document.MAP
	get_tree().root.add_child(loading)
	get_tree().current_scene = loading
	queue_free()


func _main_menu():
	get_tree().set_meta("scenario_editor_draft", document.duplicate(true))
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")


func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var focus = get_viewport().gui_get_focus_owner()
	if focus is LineEdit and not event.ctrl_pressed and not event.meta_pressed:
		return
	if event.ctrl_pressed or event.meta_pressed:
		if event.keycode == KEY_Z:
			if event.shift_pressed:
				_redo_edit()
			else:
				_undo_edit()
		elif event.keycode == KEY_Y:
			_redo_edit()
		elif event.keycode == KEY_S:
			_save()
	elif event.keycode == KEY_DELETE:
		_remove_selection()
	elif event.keycode == KEY_R:
		_yaw.value = wrapf(_yaw.value + 90, -180, 180)
	get_viewport().set_input_as_handled()


func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = tr(caption)
	button.custom_minimum_size.y = 36
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(parent: Node, caption: String, heading := false) -> Label:
	var label := Label.new()
	label.text = tr(caption)
	if heading:
		label.theme_type_variation = "HudHeading"
	parent.add_child(label)
	return label


func _number(parent: Node, caption: String, minimum: float, maximum: float, step: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, caption).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var number := SpinBox.new()
	number.min_value = minimum
	number.max_value = maximum
	number.step = step
	number.custom_minimum_size.x = 108
	row.add_child(number)
	return number


func _options(parent: Node, caption: String, values: Array) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, caption)
	var options := OptionButton.new()
	for value in values:
		options.add_item(tr(value))
	row.add_child(options)
	return options

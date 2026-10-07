extends CanvasLayer

const Bindings = preload("res://source/input/KeyBindings.gd")

var _pause_button = null
var _pause_owned = false
var _selection_start = Vector2.ZERO
var _help_label


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	var panel = PanelContainer.new()
	panel.position = Vector2(14, 64)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("19212bd9")
	style.set_corner_radius_all(7)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var content = VBoxContainer.new()
	panel.add_child(content)
	var title = Label.new()
	title.text = "BASTION  /  DESERT FRONTIER"
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)
	var objective = Label.new()
	_help_label = objective
	objective.text = (
		"Destroy the opposing force. Expand and reinforce your base.\n"
		+ "Drag to select · Right-click to command · Wheel to zoom\n"
		+ "Camera and control groups: Settings → Controls"
	)
	objective.add_theme_font_size_override("font_size", 13)
	content.add_child(objective)
	_pause_button = Button.new()
	_pause_button.text = Bindings.hint("Tactical pause", "pause_battle")
	_pause_button.pressed.connect(_toggle_pause)
	content.add_child(_pause_button)
	Globals.options.changed.connect(_refresh_shortcuts)
	_refresh_shortcuts()


func _input(event):
	if not event is InputEventKey:
		return
	if is_instance_valid(Globals.settings_dialog):
		return
	var manager = get_node_or_null("/root/SaveManager")
	if manager != null and is_instance_valid(manager.dialog):
		return
	# Battle shortcuts take priority over a focused HUD button's Space/arrow keys.
	# Tab/Enter remain available for activating controls; dialogs own their input.
	_unhandled_input(event)


func _unhandled_input(event):
	var focus = get_viewport().gui_get_focus_owner()
	if event is InputEventKey and (focus is LineEdit or focus is TextEdit):
		return
	if event.is_action_pressed("pause_battle", false, true):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if not _pause_owned:
		return
	if event.is_action_pressed("toggle_match_menu", false, true):
		_toggle_pause()
		return
	var placement = get_parent()._get_human_player().get_node("StructurePlacementHandler")
	if placement._structure_placement_started():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_selection_start = event.position
			else:
				_select_while_paused(event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var target = _pick_unit(event.position)
			if target != null:
				MatchSignals.unit_targeted.emit(target)
			else:
				var point = get_viewport().get_camera_3d().get_ray_intersection(event.position)
				if point != null:
					MatchSignals.terrain_targeted.emit(point)
			get_viewport().set_input_as_handled()


func _pick_unit(screen_position):
	var camera = get_viewport().get_camera_3d()
	var origin = camera.project_ray_origin(screen_position)
	var query = PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(screen_position) * 1000.0, 7
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.visible:
		return hit.collider
	return null


func _select_while_paused(screen_position):
	if not Globals.options.selection_modifier_pressed():
		MatchSignals.deselect_all_units.emit()
	if _selection_start.distance_to(screen_position) < 8.0:
		var unit = _pick_unit(screen_position)
		if unit != null:
			unit.get_node("Selection").select()
		return
	var rectangle = Rect2(_selection_start, screen_position - _selection_start).abs()
	var camera = get_viewport().get_camera_3d()
	for unit in get_tree().get_nodes_in_group("controlled_units"):
		if rectangle.has_point(camera.unproject_position(unit.global_position)):
			unit.get_node("Selection").select()


func _toggle_pause():
	# Never release a pause owned by the match menu or victory/defeat screen.
	if get_tree().paused and not _pause_owned:
		return
	_pause_owned = not _pause_owned
	get_tree().paused = _pause_owned
	_refresh_shortcuts()


func _refresh_shortcuts():
	if is_instance_valid(_pause_button):
		_pause_button.text = Bindings.hint(
			"Resume battle" if _pause_owned else "Tactical pause", "pause_battle"
		)

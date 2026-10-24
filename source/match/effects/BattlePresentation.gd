extends Node

const COLLAPSE_SECONDS = 2.5
const COLLAPSE_SCALE = .3
var cinematic = false
var inspecting = false
var _game
var _camera
var _elapsed = 0.0
var _old_scale = 1.0
var _camera_state = {}
var _origin = Vector3.ZERO
var _focus = Vector3.ZERO
var _inspection_layer: CanvasLayer
var _result_overlay
var _hud_visibility = []


func _ready():
	name = "BattlePresentation"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent()
	_camera = _game.get_node("IsometricCamera3D")
	MatchSignals.unit_destroying.connect(_on_destroying)


func _on_destroying(unit):
	# Automated battle replays must retain their simulation clock. Rendered previews
	# and the headless regression exercise the presentation explicitly.
	if DisplayServer.get_name() != "headless" and can_present_collapse(unit):
		begin_collapse(unit.global_position)


func can_present_collapse(unit):
	if (
		_game.restoring
		or _game.finished
		or cinematic
		or get_tree().paused
		or unit.type != "CommandCenter"
		or unit.player == _game._get_human_player()
		or unit.find_parent("Match") != _game
		or not unit.is_visible_in_tree()
		or unit.is_under_construction()
		or (
			_game.settings.visibility != _game.settings.Visibility.FULL
			and not _game.battlefield.is_observed(_game._get_human_player(), unit)
		)
	):
		return false
	return true


func begin_collapse(point):
	if (
		cinematic
		or _game.restoring
		or _game.finished
		or get_tree().paused
		or Globals.options.reduced_flashes
		or not Globals.options.hud_motion
		or (_game.campaign_story != null and _game.campaign_story.cinematic)
	):
		return false
	cinematic = true
	_elapsed = 0.0
	_old_scale = Engine.time_scale
	_camera_state = {
		"processing": _camera.is_processing(),
		"input": _camera.is_processing_unhandled_input(),
		"transform": _camera.global_transform,
	}
	_origin = _camera._calculate_pivot_point()
	_focus = point
	_camera.set_process(false)
	_camera.set_process_unhandled_input(false)
	Engine.time_scale = _old_scale * COLLAPSE_SCALE
	return true


func _process(delta):
	if not cinematic:
		return
	# The battle keeps its normal victory/rebuild rules. Only presentation owns
	# this temporary scale, and a pause, result, load or scene exit releases it.
	if (
		get_tree().paused
		or _game.finished
		or _game.restoring
		or Globals.options.reduced_flashes
		or not Globals.options.hud_motion
	):
		end_collapse()
		return
	_elapsed += delta / maxf(Engine.time_scale, .001)
	var arrival = smoothstep(0.0, .7, _elapsed)
	var departure = smoothstep(1.9, COLLAPSE_SECONDS, _elapsed)
	var drift = Vector3(1.5, 0, -1.0) * clampf((_elapsed - .7) / 1.2, 0, 1)
	_camera.set_position_safely(_origin.lerp(_focus + drift, arrival * (1.0 - departure)))
	if _elapsed >= COLLAPSE_SECONDS:
		end_collapse()


func end_collapse():
	if not cinematic:
		return
	cinematic = false
	Engine.time_scale = _old_scale
	if is_instance_valid(_camera):
		_camera.global_transform = _camera_state.transform
		_camera.reset_physics_interpolation()
		_camera.set_process(_camera_state.processing)
		_camera.set_process_unhandled_input(_camera_state.input)
	_camera_state.clear()


func _input(event):
	# Deliberate input immediately returns control without swallowing that input.
	if (
		cinematic
		and (
			(event is InputEventKey and event.pressed and not event.echo)
			or (event is InputEventMouseButton and event.pressed)
		)
	):
		end_collapse()
	if inspecting and event.is_action_pressed("toggle_match_menu", false, true):
		show_results()
		get_viewport().set_input_as_handled()


func inspect_battlefield():
	if not _game.finished or inspecting:
		return false
	end_collapse()
	inspecting = true
	# Keep simulation frozen; the existing always-processing camera remains free.
	get_tree().paused = true
	_game.hud.cancel_map_assignment()
	_game._get_human_player().get_node("StructurePlacementHandler")._cancel_structure_placement()
	MatchSignals.deselect_all_units.emit()
	_result_overlay = _game.hud._overlay
	_hud_visibility.clear()
	# CanvasLayers form visibility boundaries, so hide the results layer explicitly.
	var panels = [_game.hud, _game.get_node("HUD")]
	panels.append_array(_result_overlay.find_children("*", "CanvasLayer", true, false))
	for panel in panels:
		_hud_visibility.append([panel, panel.visible])
		panel.hide()
	_reveal_battlefield()
	_inspection_layer = CanvasLayer.new()
	_inspection_layer.layer = 10
	add_child(_inspection_layer)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.position = Vector2(-294, 18)
	margin.custom_minimum_size = Vector2(276, 48)
	_inspection_layer.add_child(margin)
	var button = Button.new()
	button.name = "ReturnToResultsButton"
	button.text = tr("Return to results")
	button.tooltip_text = (
		tr("Return to results")
		+ " · "
		+ load("res://source/input/KeyBindings.gd").label("toggle_match_menu")
	)
	button.theme = load("res://source/match/hud/BattleTheme.gd").create()
	button.theme_type_variation = "BattlePrimaryButton"
	button.pressed.connect(show_results)
	margin.add_child(button)
	button.grab_focus()
	return true


func _reveal_battlefield():
	# Disclosure is only available after the immutable result has been recorded.
	_game.fog_of_war.hide()
	var visibility = _game.get_node("Handlers/UnitVisibilityHandler")
	visibility.hide()
	for unit in get_tree().get_nodes_in_group("units"):
		unit.show()
	# Refresh neutral scenery with full knowledge once, then retain the original
	# match settings so Play again always starts with the chosen fog rules.
	var visibility_before = _game.settings.visibility
	_game.settings.visibility = _game.settings.Visibility.FULL
	for target in get_tree().get_nodes_in_group("neutral_targets"):
		target.refresh_visibility(_game)
		if target.is_in_group("neutral_buildings") and is_instance_valid(target._model):
			target._model.visible = target.visible
	_game.settings.visibility = visibility_before
	# Remembered structures would otherwise overlap their final real positions.
	for dummy in visibility._structure_to_dummy_mapping.values() + visibility._orphaned_dummies:
		if is_instance_valid(dummy):
			dummy.hide()


func show_results():
	if not inspecting:
		return
	inspecting = false
	for entry in _hud_visibility:
		if is_instance_valid(entry[0]):
			entry[0].visible = entry[1]
	_hud_visibility.clear()
	if is_instance_valid(_inspection_layer):
		_inspection_layer.queue_free()
	if is_instance_valid(_result_overlay):
		_result_overlay.show()
		var button = _result_overlay.find_child("InspectBattlefieldButton", true, false)
		if button != null:
			button.grab_focus()
	get_tree().paused = true


func _exit_tree():
	end_collapse()

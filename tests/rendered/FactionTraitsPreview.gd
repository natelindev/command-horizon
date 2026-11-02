extends "res://tests/headless/AutonomousAssemblyRegression.gd"

# Run with a renderer: Godot --path . --script tests/rendered/FactionTraitsPreview.gd
# Focused visual evidence for active nanite construction, researched shields and
# occupied mobile garrisons at 720p / 150% UI in both supported languages.
const OUTPUT = "res://art/faction-traits/"


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
		push_error("Faction traits preview needs a renderer; omit --headless")
		quit(1)
		return
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	construct = load("res://source/match/units/actions/Constructing.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	for language in ["en", "zh_CN"]:
		(
			preferences
			. restore(
				{
					"screen": 1,
					"interface_scale": 1.5,
					"edge_scrolling": false,
					"day_cycle": false,
					"weather": 1,
					"health_bars": 1,
					"language": language,
				}
			)
		)
		await create_timer(2.0).timeout
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		await _helix_preview(language)
		await _frontier_preview(language)
	paused = false
	game.queue_free()
	await _frames(5)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Faction traits preview: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _reveal_and_frame(point, size_value = 22.0):
	game.settings.visibility = game.settings.Visibility.FULL
	var handler = game.get_node("Handlers/UnitVisibilityHandler")
	for unit in get_nodes_in_group("units"):
		handler._recalculate_unit_visibility(unit)
	game.fog_of_war._physics_process(0.0)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(size_value)
	camera.set_position_safely(point)
	await _frames(12)


func _select(unit):
	root.get_node("MatchSignals").deselect_all_units.emit()
	unit.get_node("Selection").select()
	await _frames(5)


func _helix_preview(language):
	await _fixture("helix")
	var engineer_description = factions.description("helix", "Worker")
	_check(
		"nanite beacon" in engineer_description, "Helix engineer description omits nanite building"
	)
	if language == "zh_CN":
		_check(
			"纳米信标" in str(TranslationServer.translate(engineer_description)),
			"Chinese engineer description omits nanite building"
		)
	human.technology.completed.append("plasma_shields")
	var site = _spawn("PowerPlant", Vector3(45, 0, 30), true)
	var worker = _worker_at(site)
	var skimmer = _spawn("Tank", site.position + Vector3(7, 0, 3))
	skimmer.stance = skimmer.Stance.HOLD_FIRE
	skimmer.shields = skimmer.shields_max * .55
	skimmer.shields_changed.emit()
	skimmer.process_mode = Node.PROCESS_MODE_DISABLED
	await _reveal_and_frame(site.position + Vector3(3, 0, 1), 22.0)
	worker.issue_manual_order(construct.new(site))
	await _frames(12)
	_check(is_instance_of(worker.action, harvest), "Helix preview engineer remains tethered")
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	site.get_node("AutonomousAssembly")._process(3.0)
	await _select(site)
	await _frames(45)
	var visual = site.get_node("ConstructionVisual")
	_check(visual.is_worked() and visual.rig.activity > .5, "Autonomous site looks abandoned")
	_check(visual.bursts > 0, "Active nanite site emitted no rendered construction particles")
	_check(
		game.combat_effects._emitters.get("mote") is GPUParticles3D,
		"Nanite construction does not have its pooled GPU particle setup"
	)
	var bar = skimmer.get_node("HealthBar")
	_check(skimmer.shields_max > 0.0, "Helix preview skimmer lacks researched shields")
	_check(
		bar.is_visible_in_tree() and bar._drawn_shield_enabled, "World shield bar is not visible"
	)
	var menus = game.find_child("UnitMenus", true, false)
	menus._refresh_buttons()
	_check(menus._stop_button.is_visible_in_tree(), "Autonomous site cannot be cancelled in HUD")
	_check(
		(
			(
				str(TranslationServer.translate("%d M / %d E"))
				% [site.construction_refund().resource_a, site.construction_refund().resource_b]
			)
			in menus._stop_button.tooltip_text
		),
		"Autonomous site cancellation omits its refund tooltip"
	)
	await _shot("helix-720p-%s-autonomous-shields" % language)


func _frontier_preview(language):
	await _fixture("frontier")
	var rig = _spawn("AdvancedTank", Vector3(45, 0, 30))
	rig.stance = rig.Stance.HOLD_FIRE
	var passengers = []
	for index in 4:
		var passenger = _spawn(
			"RocketInfantry" if index == 0 else "Infantry",
			rig.position + Vector3(2.0 + index * .25, 0, 0)
		)
		passenger.stance = passenger.Stance.HOLD_FIRE
		passenger.manual_orders.submit(passenger.manual_orders.target_order("garrison", rig))
		passengers.append(passenger)
	await _reveal_and_frame(rig.position, 16.0)
	await _frames(90)
	_check(rig.occupants.size() == 4, "Frontier preview did not fill all four firing mounts")
	_check(
		passengers.all(func(unit): return unit.has_meta("garrison_host") and not unit.visible),
		"Embarked infantry remain visible on the vehicle"
	)
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	await _reveal_and_frame(rig.position, 16.0)
	await _select(rig)
	var menus = game.find_child("UnitMenus", true, false)
	var panel = menus._orders_panel
	panel.refresh()
	var unload = panel._eject
	_check(
		(
			str(TranslationServer.translate(factions.description("frontier", "AdvancedTank")))
			in menus._status.tooltip_text
		),
		"Ironback tooltip omits its updated infantry transport description"
	)
	_check(unload.is_visible_in_tree(), "Occupied rig has no visible bottom HUD unload button")
	_check(
		unload.text == str(TranslationServer.translate("Unload infantry")),
		"Unload label untranslated"
	)
	if language == "zh_CN":
		_check(unload.text == "步兵下车", "Chinese unload label is missing from imported catalog")
	_check(
		str(TranslationServer.translate("Garrison %d / %d")) % [4, 4] in unload.tooltip_text,
		"Occupied idle rig unload tooltip omits the firing mount count"
	)
	_check(
		unload.accessibility_description == unload.tooltip_text,
		"Unload accessibility description does not describe its action and occupants"
	)
	_check(
		menus.get_global_rect().encloses(unload.get_global_rect()),
		"Unload infantry button lies outside bottom HUD"
	)
	await _shot("frontier-720p-%s-occupied-rig" % language)
	await _shot("frontier-720p-%s-unload-tooltip" % language, unload)
	panel._leave_building()
	await _frames(5)
	_check(rig.occupants.is_empty(), "Bottom HUD unload action did not release passengers")
	_check(passengers.all(func(unit): return unit.visible), "Disembarked infantry remain hidden")


func _shot(label, hover_control = null):
	# macOS may ignore the first size request during its fullscreen transition.
	# Reapply after the match is ready, and validate the real rendered dimensions.
	root.mode = Window.MODE_WINDOWED
	await _frames(3)
	root.size = Vector2i(1280, 720)
	await _frames(12)
	var menus = game.find_child("UnitMenus", true, false)
	var mini = game.find_child("Minimap", true, false)
	var rect = menus.get_global_rect()
	_check(
		rect.position.y >= mini.get_global_rect().position.y - .5,
		"Console exceeds height budget: " + label
	)
	_check(root.get_visible_rect().encloses(rect), "Bottom HUD exceeds viewport: " + label)
	_check(
		absf(rect.end.y - root.get_visible_rect().end.y) < .5,
		"Operation menu does not sit at bottom: " + label
	)
	Input.warp_mouse(root.get_visible_rect().size - Vector2(16, 280))
	await _frames(3)
	_check(
		root.find_children("*", "Window", true, false).all(func(window): return not window.visible),
		"Operation menu introduced a floating window: " + label
	)
	if hover_control != null:
		var point = root.get_final_transform() * hover_control.get_global_rect().get_center()
		var motion = InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion, false)
		await _frames(60)
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
	var picture = root.get_texture().get_image()
	_check(picture.get_size() == Vector2i(1280, 720), "Capture is not 720p: " + label)
	_check(picture.save_png(OUTPUT + label + ".png") == OK, "Could not save capture: " + label)
	print("Captured ", label)

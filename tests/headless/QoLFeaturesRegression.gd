extends "res://tests/headless/SaveRestoreEdges.gd"

## Regression test suite for QoL updates:
## 1. Keybindings & micro hotkeys (Stop, Hold, Select All Combat, Cycle/All Idle Worker, Alert jump)
## 2. Options & Health Bar display modes (Selected, Always, Damaged)
## 3. Smart army box-selection (excludes harvesting workers when army is selected)
## 4. Roster right-click unit dequeue and refund
## 5. Minimap direct order dispatch

const MAP = "res://source/match/maps/DesertFrontier.tscn"
var _sections = 0


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original_options = options.capture()

	_test_keybindings()

	await _skirmish("bastion", MAP)
	_hold_players()

	await _test_health_bar_modes()
	await _test_smart_selection()
	await _test_roster_dequeue()
	await _test_minimap_orders()

	game.queue_free()
	await _frames(5)

	options.restore(original_options)

	_check(_sections == 5, "Expected 5 sections, finished %d" % _sections)
	for message in errors:
		push_error(message)
	print("QoL Features regression: %d failures over %d sections" % [errors.size(), _sections])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _hold_players():
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.set_process(false)


func _select(units):
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()


func _test_keybindings():
	var Bindings = load("res://source/input/KeyBindings.gd")
	var default_keys = Bindings.defaults().keys
	_check(default_keys.get("stop_order") == KEY_S, "stop_order default must be KEY_S")
	_check(default_keys.get("hold_order") == KEY_H, "hold_order default must be KEY_H")
	_check(default_keys.get("select_all_combat_units") == KEY_F3, "select_all_combat_units must be KEY_F3")
	_check(default_keys.get("cycle_idle_worker") == KEY_PERIOD, "cycle_idle_worker must be KEY_PERIOD")
	_check(default_keys.get("jump_to_alert") == KEY_QUOTELEFT, "jump_to_alert must be KEY_QUOTELEFT")
	_check(default_keys.has("select_all_idle_workers"), "Bindings must have select_all_idle_workers")
	_check(default_keys.has("center_on_headquarters"), "Bindings must have center_on_headquarters")

	# Verify normalization migrates older settings
	var legacy_v5 = {"version": 5, "keys": {"pause": KEY_P}}
	var normalized = Bindings.normalize(legacy_v5)
	_check(normalized.keys.get("stop_order") == KEY_S, "Legacy v5 must migrate stop_order")
	_check(normalized.keys.get("select_all_combat_units") == KEY_F3, "Legacy v5 must migrate select_all_combat_units")
	_sections += 1


func _test_health_bar_modes():
	var options = root.get_node("Globals").options
	_check(options.get("health_bars") != null, "options must have health_bars property")

	var human = game._get_human_player()
	var unit = _units(human, "Tank")[0]
	var health_bar = unit.get_node_or_null("HealthBar")
	_check(health_bar != null, "Tank should have HealthBar child")

	if health_bar != null:
		# Mode 0: Selected only
		options.health_bars = 0
		options.emit_changed()
		_select([unit])
		await _frames(2)
		_check(health_bar.visible, "Mode 0: selected unit bar should be visible")
		_select([])
		await _frames(2)
		_check(not health_bar.visible, "Mode 0: deselected unit bar should hide")

		# Mode 1: Always show
		options.health_bars = 1
		options.emit_changed()
		await _frames(2)
		_check(health_bar.visible, "Mode 1: bar should be visible when always show is set")
		_select([unit])
		await _frames(2)
		_select([])
		await _frames(2)
		_check(health_bar.visible, "Mode 1: bar should remain visible on deselection")

		# Mode 2: Damaged only
		options.health_bars = 2
		options.emit_changed()
		await _frames(2)
		_check(not health_bar.visible, "Mode 2: full HP unselected unit bar should be hidden")
		unit.hp = unit.hp - 10
		unit.hp_changed.emit()
		await _frames(2)
		_check(health_bar.visible, "Mode 2: damaged unit bar should be visible")

	_sections += 1


func _test_smart_selection():
	var Utils = load("res://source/Utils.gd")
	var selector = game.find_child("ArealUnitSelectionHandler", true, false)
	_check(selector != null, "ArealUnitSelectionHandler exists")
	if selector == null:
		_sections += 1
		return

	var human = game._get_human_player()
	var worker = _units(human, "Worker")[0]
	var tank = _units(human, "Tank")[0]

	# 1. Idle worker + Tank -> both are selected because worker is not harvesting
	var set1 = Utils.Set.new()
	set1.add(worker)
	set1.add(tank)
	var res1 = selector._filter_combat_over_workers(set1)
	_check(res1.has(worker) and res1.has(tank), "Idle worker with army should not be excluded")

	# 2. Harvesting worker (carrying cargo) + Tank -> harvesting worker is excluded
	worker.resource_a = 5
	var set2 = Utils.Set.new()
	set2.add(worker)
	set2.add(tank)
	var res2 = selector._filter_combat_over_workers(set2)
	_check(not res2.has(worker) and res2.has(tank), "Harvesting worker must be excluded when army is boxed")

	# 3. Only harvesting worker boxed -> kept
	var set3 = Utils.Set.new()
	set3.add(worker)
	var res3 = selector._filter_combat_over_workers(set3)
	_check(res3.has(worker), "Harvesting worker boxed alone must be selected")

	worker.resource_a = 0
	_sections += 1


func _test_roster_dequeue():
	var human = game._get_human_player()
	var factory = _units(human, "VehicleFactory")[0]
	var menus = game.find_child("UnitMenus")
	_check(menus != null, "HUD/UnitMenus exists")

	# Select the factory
	_select([factory])
	await _frames(3)

	var queue = factory.production_queue
	var catalog = load("res://source/match/BastionCatalog.gd")
	var tank_scene = load(catalog.scene_path("Tank"))
	var initial_resources = human.resource_a

	# Produce a tank
	var job = queue.produce(tank_scene)
	_check(job != null, "VehicleFactory produced tank into queue")
	_check(queue.size() == 1, "Queue has 1 element")
	_check(human.resource_a < initial_resources, "Resources deducted for tank")

	# Find the tank roster button in menus
	var tank_btn = null
	for entry in menus._buttons:
		if entry.type == "Tank":
			tank_btn = entry.button
			break
	_check(tank_btn != null, "Tank button found in roster")

	if tank_btn != null:
		# Dequeue by right-clicking roster button
		menus._dequeue_roster(tank_btn, 1)
		_check(queue.size() == 0, "Queue emptied after right-click dequeue")
		_check(human.resource_a == initial_resources, "Resources fully refunded on dequeue")

	_select([])
	await _frames(2)
	_sections += 1


func _test_minimap_orders():
	var minimap = game.find_child("Minimap")
	var direct_orders = game.hud.direct_orders if "hud" in game and is_instance_valid(game.hud) else null
	_check(minimap != null and direct_orders != null, "Minimap and DirectOrders exist")
	if minimap != null and direct_orders != null:
		direct_orders.kind = "attack"
		var mock_event = InputEventMouseButton.new()
		mock_event.button_index = MOUSE_BUTTON_LEFT
		mock_event.pressed = true
		mock_event.position = Vector2(50, 50)
		minimap._on_gui_input(mock_event)
		_check(direct_orders.kind == "", "Direct orders committed on minimap click")
	_sections += 1

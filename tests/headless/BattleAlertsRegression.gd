extends "res://tests/headless/SettingsRegression.gd"

var harvest
var alerts
var panel


func _run():
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	save_path = "user://alerts-battle-%d.json" % OS.get_process_id()
	for faction in ["bastion", "helix"]:
		await _setup(faction)
		alerts = game.alerts
		panel = game.hud.alert_panel
		_check(await _idle_and_navigation() == true, "idle_and_navigation suite aborted")
		_check(await _combat_events() == true, "combat_events suite aborted")
		_check(await _economy_conditions() == true, "economy_conditions suite aborted")
		_check(await _history_and_restore() == true, "history_and_restore suite aborted")
		await _clean_match()
	preferences.restore(original)
	DirAccess.remove_absolute(save_path)
	print("Battle alerts: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _kind(kind, active_only = false):
	return alerts.entries.filter(
		func(entry): return entry.kind == kind and (entry.active or not active_only)
	)


func _idle_and_navigation():
	_check(_kind("idle").is_empty(), "Idle alert appeared without debounce")
	await _frames(430)
	var idle = _kind("idle", true)
	_check(idle.size() == 1 and idle[0].count == 4, "Idle engineers did not group")
	if idle.is_empty():
		return
	var identity = idle[0].id
	alerts.mark_read()
	await _frames(120)
	_check(
		_kind("idle")[0].id == identity and alerts.unread_count() == 0,
		"Ongoing idle state spammed history"
	)
	var workers = _units(game._get_human_player(), "Worker")
	var action = workers[0].action
	var program = workers[0].program
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(42, 0, 42))
	paused = true
	var clock = game.simulation_time
	game.hud._arm_attack()
	panel.navigate(identity)
	await _frames(3)
	_check(
		get_nodes_in_group("selected_units").size() == 4,
		"Paused alert navigation did not select engineers"
	)
	_check(
		workers[0].action == action and workers[0].program == program,
		"Inspection changed engineer authority"
	)
	_check(
		(
			camera.unproject_position(workers[0].global_position_yless).distance_to(
				root.get_visible_rect().size / 2
			)
			< 1
		),
		"Inspection did not move the camera"
	)
	_check(
		not game.hud._attack_armed and game.hud._assignment_kind == "",
		"Inspection retained a pending battlefield targeting mode"
	)
	await _frames(90)
	_check(paused and game.simulation_time == clock, "Alert navigation advanced paused battle")
	var settings = root.get_node("Globals").open_settings()
	camera.set_position_safely(Vector3(40, 0, 40))
	var frozen_position = camera.position
	panel.navigate(identity)
	_check(camera.position == frozen_position, "Alert navigation bypassed Settings")
	settings._finish(false)
	await _frames(3)
	for worker in workers:
		worker.issue_manual_order(
			load("res://source/match/units/actions/Moving.gd").new(Vector3(30, 0, 30))
		)
	await _frames(40)
	_check(
		not alerts.entry_by_id(identity).active, "Assigned engineers left an active idle warning"
	)
	_check(paused and game.simulation_time == clock, "Paused reassignment advanced alert time")
	paused = false
	print(
		"PASS idle grouping/debounce, stable read state, paused inspection and modal/order authority"
	)

	return true


func _combat_events():
	var sides = _sides()
	var human = sides[0]
	human.coordination_unlocked = true
	var victims = []
	for index in range(6):
		victims.append(_spawn_weapon("Infantry", human, Vector3(35 + index * 0.5, 0, 25)))
	var squad = human.squad_roster.create("Eastern screen", victims)
	_check(squad != null, "Casualty squad could not be created")
	var attacker = _spawn_weapon("Tank", sides[1], Vector3(40, 0, 25))
	await _frames(5)
	victims[0].receive_weapon_hit(attacker)
	_check(_kind("attack", true).size() == 1, "Actual damage did not create a location alert")
	var incoming = _kind("attack", true)[0]
	_check(incoming.title.begins_with("Eastern screen"), "Incoming fire lost squad name")
	for victim in victims:
		victim.hp = 1
		victim.receive_weapon_hit(attacker)
	await _frames(3)
	var losses = _kind("loss")
	_check(losses.size() == 1 and losses[0].count == 6, "Six real casualties did not coalesce")
	if losses.is_empty():
		return
	var loss = losses[0]
	_check(alerts.live_units(loss).is_empty(), "Destroyed squad retained selectable units")
	_check(
		loss.title == "Eastern screen · 6 units lost", "Destroyed squad history lost its identity"
	)
	panel.navigate(loss.id)
	_check(
		(
			game.get_node("IsometricCamera3D").unproject_position(loss.point).distance_to(
				root.get_visible_rect().size / 2
			)
			< 1
		),
		"Destroyed squad location is not navigable"
	)
	var count = alerts.entries.size()
	attacker.hp = 1
	attacker.receive_weapon_hit(_units(human, "Tank")[0])
	await _frames(2)
	_check(alerts.entries.size() == count, "Enemy casualty leaked into human alerts")
	var foundation = _spawn_weapon("PowerPlant", human, Vector3(30, 0, 25))
	foundation.construct(1.0)
	foundation.hp -= 1
	_check(_kind("base_attack").is_empty(), "Generic HP decrease created an attack alert")
	foundation.receive_weapon_hit(_units(sides[1], "Tank")[0])
	_check(_kind("base_attack", true).size() == 1, "Actual building hit lacks base alert")
	paused = true
	var latest = incoming.last
	await _frames(600)
	_check(incoming.active and incoming.last == latest, "Tactical pause expired attack history")
	paused = false
	await _frames(520)
	_check(not incoming.active, "Attack did not resolve after fire stopped")
	print(
		"PASS human damage, grouped losses, dead-location navigation, ownership and pausable expiry"
	)

	return true


func _deposit(point):
	var deposit = load("res://source/match/units/non-player/ResourceB.tscn").instantiate()
	deposit.resource_b = 2
	game.map.add_child(deposit)
	deposit.global_position = point
	return deposit


func _economy_conditions():
	var human = game._get_human_player()
	var workers = _units(human, "Worker")
	# Idle engineers still participate in normal avoidance. The combat fixture
	# freezes their entire subtree; leaving them frozen creates an artificial
	# solid wall at HQ's unloading face for the two live couriers below.
	for worker in workers:
		worker.process_mode = Node.PROCESS_MODE_PAUSABLE
	for deposit in get_nodes_in_group("resource_units"):
		deposit.queue_free()
	await _frames(3)
	var field = _deposit(Vector3(30, 0, 20))
	var stock_before = human.resource_b
	var started = game.simulation_time
	for index in range(2):
		var worker = workers[index]
		worker.process_mode = Node.PROCESS_MODE_PAUSABLE
		worker.issue_manual_order(null)
		worker.resource_a = 0
		worker.resource_b = 0
		worker.global_position = Vector3(30 + (-1.4 if index == 0 else 1.4), 0, 20)
		worker.issue_manual_order(harvest.new(field))
	await _frames(180)
	for _index in range(20):
		var entries = _kind("field_electronics", true)
		if entries.size() == 1 and entries[0].count == 2:
			break
		await _frames(60)
	_check(
		not is_instance_valid(field) or field.is_queued_for_deletion(),
		"Real gathering did not exhaust field"
	)
	var depleted = _kind("field_electronics", true)
	_check(depleted.size() == 1 and depleted[0].count == 2, "Depleted field workers did not group")
	_check(
		(
			workers[0].resource_b == 0
			and workers[1].resource_b == 0
			and human.resource_b == stock_before + 2
		),
		"Final field cargo was not delivered exactly once"
	)
	print("FINAL FIELD RETURN ", human.faction, " elapsed=", game.simulation_time - started)
	if depleted.is_empty():
		return
	var entry = depleted[0]
	for idle in _kind("idle", true):
		var idle_units = alerts.live_units(idle)
		_check(
			workers[0] not in idle_units and workers[1] not in idle_units,
			"Depleted workers also emitted generic idle alerts"
		)

	var new_field = _deposit(Vector3(50, 0, 20))
	new_field.resource_b = 100
	for worker in workers.slice(0, 2):
		worker.issue_manual_order(harvest.new(new_field))
	await _frames(40)
	_check(not entry.active, "Reassigned field did not resolve")
	# A destroyed real drop-off leaves cargo and an actionable worker group intact.
	for worker in workers.slice(0, 2):
		worker.process_mode = Node.PROCESS_MODE_DISABLED
	var courier = workers[2]
	var hq = _units(human, "CommandCenter")[0]
	var hq_point = hq.global_position
	courier.process_mode = Node.PROCESS_MODE_PAUSABLE
	courier.resource_b = 3
	courier.issue_manual_order(harvest.new(hq))
	hq.hp = 0
	await _frames(130)
	var stranded = _kind("drop_off", true)
	_check(
		not stranded.is_empty() and courier.resource_b == 3,
		"HQ loss did not preserve/alert stranded cargo"
	)
	if stranded.is_empty():
		return
	var cargo_alert = stranded[0]
	var rebuilt_hq = _spawn_weapon("CommandCenter", human, hq_point)
	rebuilt_hq.construct(1.0)
	courier.issue_manual_order(harvest.new(rebuilt_hq))
	var electronics = human.resource_b
	await _frames(300)
	_check(
		not cargo_alert.active and courier.resource_b == 0 and human.resource_b >= electronics + 3,
		"Explicit HQ reassignment did not resolve/deliver cargo"
	)
	courier.process_mode = Node.PROCESS_MODE_DISABLED
	# A real paid chip job stalls when its lab is destroyed, then resumes unchanged.
	var factory = _units(human, "VehicleFactory")[0]
	var queue = factory.get_node("ProductionQueue")
	human.resource_a = 500
	human.resource_b = 500
	queue.fit_chips = true
	var tank_scene = load("res://source/match/units/Tank.tscn")
	var job = queue.produce(tank_scene)
	_check(job != null, "Paid chip job could not start")
	var extra = queue.produce(tank_scene)
	_check(extra != null, "Second paid chip job could not start")
	var lab = _units(human, "CommandLab")[0]
	lab.hp = 0
	await _frames(4)
	factory.process_mode = Node.PROCESS_MODE_PAUSABLE
	var remaining = job.time_left
	await _frames(160)
	var blocked = _kind("production", true)
	_check(
		blocked.size() == 1 and job.time_left == remaining,
		"Paid prerequisite loss did not stall/alert"
	)
	_check(blocked[0].detail.contains("Rebuild"), "Blocked queue has no actionable reason")
	paused = true
	var paused_clock = game.simulation_time
	queue.cancel(extra)
	await _frames(45)
	_check(
		blocked[0].count == 1 and game.simulation_time == paused_clock,
		"Paused refund left stale alert count or advanced time"
	)
	paused = false
	var restored_lab = _spawn_weapon("CommandLab", human, Vector3(21, 0, 25))
	restored_lab.construct(1.0)
	await _frames(40)
	_check(
		restored_lab.is_constructed() and job.time_left < remaining,
		"Rebuilt prerequisite did not resume paid queue"
	)
	_check(not blocked[0].active, "Resumed production left an active warning")
	var air_factory = _spawn_weapon("AircraftFactory", human, Vector3(44, 0, 32))
	air_factory.construct(1.0)
	for plant in _units(human, "PowerPlant"):
		plant.hp = 0
	paused = true
	var power_clock = game.simulation_time
	await _frames(45)
	var totals = human.power_totals()
	var bar = game.find_child("ResourcesBar", true, false)
	_check(
		bar._power_title.text.contains("%d used / %d supply" % [totals.y, totals.x]),
		"Power bar stayed stale after immediate tactical pause"
	)
	_check(game.simulation_time == power_clock, "Power display refresh advanced the battle")
	paused = false
	await _frames(160)
	_check(_kind("power", true).size() == 1, "Low power lacks grouped alert")
	var power = _kind("power", true)[0]
	_check(power.detail.contains("35%"), "Low power alert claims a full production block")
	var plant = _spawn_weapon("PowerPlant", human, Vector3(25, 0, 32))
	plant.construct(1.0)
	await _frames(40)
	_check(plant.is_constructed() and not power.active, "Restored power did not resolve alert")
	print("PASS real depletion/reassignment, stranded cargo, paid queue/lab and power recovery")

	return true


func _history_and_restore():
	alerts.clear_history()
	_check(
		alerts.entries.all(func(entry): return entry.active),
		"Clear history removed/retained wrong states"
	)
	var own = game._get_human_player()
	# Distinct losses over time remain bounded with unique stable row IDs.
	for index in range(40):
		var unit = _spawn_weapon(
			"Infantry", own, Vector3(10 + index % 7 * 7, 0, 10 + index / 7 * 7)
		)
		game.simulation_time += 7
		unit.hp = 0
	await _frames(3)
	_check(alerts.entries.size() <= alerts.LIMIT, "Alert history exceeded its cap")
	var ids = {}
	for entry in alerts.entries:
		_check(not ids.has(entry.id), "Alert row IDs collided")
		ids[entry.id] = true
	# Distinct active squads saturate the history without lower-priority condition churn.
	var weak_attacker = _units(_sides()[1], "Infantry")[0]
	for index in range(26):
		var member = _spawn_weapon("Infantry", own, Vector3(36, 0, 30))
		own.squad_roster.create("Screen %d" % index, [member])
		member.receive_weapon_hit(weak_attacker)
	_check(
		(
			alerts.entries.size() == alerts.LIMIT
			and alerts.entries.all(func(entry): return entry.active and entry.priority == 100)
		),
		"Active squad burst did not honor alert cap/priority"
	)
	var retained = alerts.entries.map(func(entry): return entry.id)
	for _index in range(4):
		alerts.scan()
	_check(
		alerts.entries.map(func(entry): return entry.id) == retained,
		"Lower-priority conditions churned full active history"
	)
	for plant in _units(own, "PowerPlant"):
		plant.hp = 0
	await _frames(600)
	_check(_kind("power", true).size() == 1, "Pre-save power condition missing")
	paused = true
	var snapshot = Snapshot.new()
	var data = snapshot.capture(game)
	_check(data != null, "Alert archive capture failed: " + snapshot.error)
	if data == null:
		return
	var store = FileStore.new()
	_check(store.write_file(save_path, data), "Alert archive write failed: " + store.error)
	var result = await Restore.new().restore(self, store.read_file(save_path))
	_check(result.ok, "Alert archive restore failed: " + result.get("error", ""))
	game = current_scene
	alerts = game.alerts
	panel = game.hud.alert_panel
	await _frames(3)
	_check(alerts.entries.is_empty(), "Restoration replayed historical alerts")
	for side in get_nodes_in_group("players"):
		if side != game._get_human_player():
			side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	await _frames(480)
	_check(
		_kind("loss").is_empty() and _kind("attack").is_empty(),
		"Deferred reconstruction emitted combat history"
	)
	_check(
		_kind("power", true).size() == 1, "Loaded battle did not derive current low-power condition"
	)
	game.finished = true
	var before = alerts.entries.size()
	_units(game._get_human_player(), "Tank")[0].hp = 0
	await _frames(5)
	_check(alerts.entries.size() == before, "Ended battle generated an alert")
	print(
		"PASS bounded history/unique IDs, safe Clear, disk restore isolation and result suppression"
	)

	return true

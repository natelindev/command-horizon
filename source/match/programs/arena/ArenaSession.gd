extends Node

signal updated
signal completed(result)

const Research = preload("res://source/match/programs/arena/ArenaResearch.gd")
const Scenarios = preload("res://source/match/programs/arena/ArenaScenarios.gd")
const Record = preload("res://source/match/programs/ProgramRecord.gd")
const Application = preload("res://source/match/programs/ProgramApplication.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")
const Moving = preload("res://source/match/units/actions/Moving.gd")
const ORIGIN = Vector3(24, 0, 24)
const SAFE = Vector3(18, 0, 24)
const DESTINATION = Vector3(28, 0, 24)
const MANUAL = Vector3(22, 0, 30)
var game
var subject
var partner
var record = {}
var faction = "bastion"
var research = Research.baseline()
var role = "Tank"
var case_index = 0
var elapsed = 0.0
var running = false
var starting = false
var evaluations = 0
var trace = []
var outcome = {}
var facts = {}
var _running_research = Research.baseline()
var _events = {}
var _sample_elapsed = 0.0
var _last_intent = "none"
var _manual_evaluations = 0


func start():
	if starting:
		return
	starting = true
	running = false
	if is_instance_valid(game):
		game.queue_free()
		await game.tree_exited
	game = null
	subject = null
	partner = null
	elapsed = 0.0
	evaluations = 0
	trace.clear()
	outcome.clear()
	facts.clear()
	_events.clear()
	_sample_elapsed = 0.0
	_last_intent = "none"
	if not Record.validate(record) or not Record.is_script(record) or role not in record.roles:
		_finish_error("Invalid program or role.")
		return
	if not Scenarios.available(case_index, role):
		_finish_error("Choose a compatible role for this scenario.")
		return
	if not Research.valid(research):
		_finish_error("Invalid research setup.")
		return
	_running_research = research.duplicate(true)
	_create_match()
	var domain = Constants.Match.Navigation.Domain.TERRAIN
	var navigation_map = game.navigation.get_navigation_map_rid_by_domain(domain)
	var synchronized = false
	for frame in range(300):
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(navigation_map) > 0:
			synchronized = true
			break
	if not synchronized:
		_finish_error("Navigation did not become ready. Restart the test.")
		return
	_setup_fixture()
	# Units await navigation synchronization in their own movement setup.
	for frame in range(3):
		await get_tree().physics_frame
	subject.program.evaluated.connect(_evaluated)
	var applied = Application.apply(record, [subject], subject.player)
	if not applied.ok:
		_finish_error(applied.error)
		return
	starting = false
	running = true
	_event("Test started with a fresh unit and program memory.")
	updated.emit()


func _create_match():
	FeatureFlags.god_mode = false
	game = load("res://source/match/Match.tscn").instantiate()
	game.set_script(load("res://source/match/programs/arena/ArenaMatch.gd"))
	for child_name in ["UI", "HUD", "Menu", "Debug", "Handlers", "RectangularSelection3D", "Fog"]:
		game.get_node(child_name).free()
	game.settings = load("res://source/data-model/MatchSettings.gd").new()
	game.settings.visibility = game.settings.Visibility.FULL
	for index in range(2):
		var player_settings = load("res://source/data-model/PlayerSettings.gd").new()
		player_settings.color = Constants.Player.COLORS[3 if index == 0 else 1]
		player_settings.faction = (
			faction if index == 0 else ("helix" if faction == "bastion" else "bastion")
		)
		game.settings.players.append(player_settings)
	var map = load("res://source/match/Map.tscn").instantiate()
	map.size = Vector2(80, 80)
	var ground = ShaderMaterial.new()
	ground.shader = load("res://source/match/programs/arena/arena_ground.gdshader")
	map.find_child("Terrain").material_override = ground
	if Scenarios.CASES[case_index].id == "blocked":
		for wall in [
			[Vector3(28, 1, 21), Vector3(6, 2, 0.8)],
			[Vector3(28, 1, 27), Vector3(6, 2, 0.8)],
			[Vector3(25, 1, 24), Vector3(0.8, 2, 6)],
			[Vector3(31, 1, 24), Vector3(0.8, 2, 6)]
		]:
			_add_wall(map, wall[0], wall[1])
	game.map = map
	add_child(game)


func _add_wall(map, position, size):
	var wall = StaticBody3D.new()
	wall.position = position
	wall.collision_layer = 2
	wall.add_to_group("terrain_navigation_input")
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	collision.shape = box
	wall.add_child(collision)
	var visual = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("899595")
	material.roughness = 0.8
	visual.material_override = material
	wall.add_child(visual)
	map.get_node("Decorations").add_child(wall)


func _marker(point, title):
	var label = Label3D.new()
	label.text = title
	label.position = point + Vector3(0, 0.2, -1)
	label.font_size = 36
	label.pixel_size = 0.014
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("dce5df")
	game.add_child(label)


func _spawn(type, owner, point):
	var unit = load(Catalog.scene_path(type)).instantiate()
	unit.set_meta("chip_installed", true)
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), owner, false)
	unit.issue_manual_order(null)
	return unit


func _setup_fixture():
	var player = game.get_node("Players").get_child(0)
	var opponent = game.get_node("Players").get_child(1)
	Research.apply(player, _running_research)
	subject = _spawn(role, player, ORIGIN)
	subject.program.anchor = ORIGIN
	subject.program.safe_point = SAFE
	subject.program.route = [SAFE, DESTINATION]
	match Scenarios.CASES[case_index].id:
		"retreat":
			subject.hp = subject.hp_max * 0.2
		"escort":
			partner = _spawn("Tank", player, DESTINATION)
			subject.program.escort = partner
		"hidden":
			partner = _spawn("Tank", opponent, ORIGIN + Vector3(3, 0, 0))
			partner.hp_max = 10000
			partner.hp = 10000
		"assignments":
			subject.program.anchor = null
			subject.program.safe_point = null
			subject.program.route = []
		"blocked":
			subject.program.anchor = DESTINATION
		"repair":
			partner = _spawn("Tank", player, ORIGIN + Vector3(2, 0, 0))
			partner.hp = partner.hp_max * 0.4
			facts.initial_hp = partner.hp
	if is_instance_valid(partner):
		# Passive targets still use real movement/HP; no automatic retaliation.
		partner.action = null
	if subject.program.anchor != null:
		_marker(subject.program.anchor, "AREA")
	if Scenarios.CASES[case_index].id == "retreat":
		_marker(SAFE, "SAFE")
	if Scenarios.CASES[case_index].id in ["manual", "blocked"]:
		_marker(MANUAL, "MANUAL")


func _physics_process(delta):
	if not running:
		return
	elapsed += delta
	if not is_instance_valid(subject) or subject.is_queued_for_deletion():
		_finish_error("Test unit was destroyed.")
		return
	_drive_events()
	_observe()
	_sample_elapsed += delta
	if _sample_elapsed >= 0.2:
		_sample_elapsed = 0.0
		_append(
			"state",
			(
				"HP %d%% · %s · %s"
				% [100 * subject.hp / subject.hp_max, subject.program.mode, subject.program.reason]
			)
		)
		updated.emit()
	if elapsed >= Scenarios.CASES[case_index].duration:
		_finish()


func _once(key, at):
	if elapsed < at or _events.has(key):
		return false
	_events[key] = true
	return true


func _drive_events():
	match Scenarios.CASES[case_index].id:
		"retreat":
			if _once("partial", 4):
				facts.retreated = _distance(SAFE) < 1.5
				subject.hp = subject.hp_max * 0.5
				_event("Health restored to 50%; recovery should remain active.")
			if _once("recovered", 6):
				facts.stayed = _distance(SAFE) < 1.5
				subject.hp = subject.hp_max
				_event("Full health restored; return to the area.")
		"escort":
			if _once("ally_move", 3):
				facts.approached = (
					subject.global_position_yless.distance_to(partner.global_position_yless) < 3.8
				)
				partner.issue_manual_order(Moving.new(Vector3(33, 0, 24)))
				_event("Assigned ally ordered to move 5 m.")
		"hidden":
			if _once("hidden", 3):
				facts.fired = partner.hp < 10000
				partner.global_position = Vector3(70, 0, 70)
				game.battlefield.invalidate()
				_event("Enemy moved out of all allied sight.")
		"assignments":
			if _once("assigned", 3):
				facts.waited = subject.program.mode == "Waiting" and _distance(ORIGIN) < 0.5
				subject.program.anchor = DESTINATION
				_marker(DESTINATION, "AREA")
				_event("Area assigned 4 m east of the starting point.")
		"manual":
			if _once("manual", 2):
				_manual_order()
		"blocked":
			if _once("manual", 10):
				facts.blocked = subject.program.mode == "Blocked"
				_manual_order()
		"repair":
			if _once("destroyed", 3):
				facts.healed = partner.hp > facts.initial_hp
				partner.hp = 0
				_event("Repair target destroyed.")


func _manual_order():
	_manual_evaluations = evaluations
	subject.issue_manual_order(Moving.new(MANUAL))
	_event("Direct move order issued. The program must stay suspended.")


func _observe():
	if subject.program.mode == "Error":
		facts.runtime_error = subject.program.reason
	if _events.has("manual") and evaluations > _manual_evaluations:
		facts.manual_violation = true
	if Scenarios.CASES[case_index].id == "retreat" and elapsed > 4 and elapsed < 6:
		if _distance(SAFE) > 1.5:
			facts.left_early = true


func _evaluated(snapshot, result):
	evaluations += 1
	if not result.ok:
		facts.runtime_error = result.error
		_append("fault", result.error)
		return
	_last_intent = result.intent.kind
	var id = Scenarios.CASES[case_index].id
	if id == "hidden":
		if (
			elapsed < 3
			and (
				_last_intent == "attack"
				or (_last_intent == "guard" and subject.aim_target == partner)
			)
		):
			facts.engaged = true
		if elapsed > 3.5:
			facts.observed_loss = snapshot.enemies.is_empty()
			if (
				_last_intent == "attack"
				or (_last_intent == "guard" and subject.aim_target == partner)
			):
				facts.stale_attack = true
	if id == "repair" and elapsed > 3.5 and _last_intent == "repair":
		facts.stale_repair = true
	_append("intent", JSON.stringify(result.intent))


func _distance(point):
	return subject.global_position_yless.distance_to(point)


func _append(kind, text):
	var position = subject.global_position_yless if is_instance_valid(subject) else Vector3.ZERO
	trace.append(
		{
			"time": snappedf(elapsed, 0.01),
			"kind": kind,
			"text": text.left(240),
			"x": snappedf(position.x, 0.01),
			"z": snappedf(position.z, 0.01)
		}
	)
	if trace.size() > 180:
		trace.pop_front()


func _event(text):
	_append("event", text)


func _expect(checks, condition, text):
	checks.append({"passed": bool(condition), "text": text})


func _finish():
	var checks = []
	_expect(checks, evaluations > 0, "Program evaluated on the real test unit")
	_expect(checks, not facts.has("runtime_error"), "No runtime fault")
	match Scenarios.CASES[case_index].id:
		"retreat":
			_expect(checks, facts.get("retreated", false), "Reached safe point at low health")
			_expect(
				checks,
				facts.get("stayed", false) and not facts.get("left_early", false),
				"Stayed safe at 50% HP"
			)
			_expect(checks, _distance(ORIGIN) < 2.5, "Returned to assigned area after recovery")
		"escort":
			_expect(checks, facts.get("approached", false), "Approached assigned ally")
			_expect(
				checks,
				subject.global_position_yless.distance_to(partner.global_position_yless) < 3.8,
				"Followed moving ally within 3.8 m"
			)
		"hidden":
			_expect(
				checks,
				facts.get("engaged", false) and facts.get("fired", false),
				"Requested an attack and damaged visible target"
			)
			_expect(
				checks,
				facts.get("observed_loss", false) and not facts.get("stale_attack", false),
				"Stopped requesting attacks after loss of contact"
			)
		"assignments":
			_expect(checks, facts.get("waited", false), "Waited without guessing a destination")
			_expect(checks, _distance(DESTINATION) < 1.5, "Reached area after assignment")
		"manual", "blocked":
			if Scenarios.CASES[case_index].id == "blocked":
				_expect(checks, facts.get("blocked", false), "Reported Blocked at the sealed pen")
			_expect(
				checks,
				not facts.get("manual_violation", false) and subject.program.mode == "Manual",
				"Direct order stopped script evaluation"
			)
			_expect(checks, _distance(MANUAL) < 1.5, "Reached the manual destination")
		"repair":
			_expect(checks, facts.get("healed", false), "Healed the real damaged ally")
			_expect(
				checks,
				not facts.get("stale_repair", false),
				"Stopped requesting repair of destroyed target"
			)
	var passed = checks.all(func(check): return check.passed)
	outcome = {
		"passed": passed,
		"checks": checks,
		"error": facts.get("runtime_error", ""),
		"scenario": Scenarios.CASES[case_index].id,
		"role": role,
		"faction": faction,
		"research": _running_research.duplicate(true),
		"source_hash": record.source_hash,
		"evaluations": evaluations,
		"trace": trace.duplicate(true)
	}
	_stop()


func _finish_error(message):
	outcome = {
		"passed": false,
		"checks": [],
		"error": message,
		"trace": trace.duplicate(true),
		"research": _running_research.duplicate(true),
		"faction": faction,
		"role": role,
		"scenario":
		(
			Scenarios.CASES[case_index].id
			if case_index >= 0 and case_index < Scenarios.CASES.size()
			else "Test"
		)
	}
	_stop()


func _stop():
	running = false
	starting = false
	if is_instance_valid(game):
		game.process_mode = Node.PROCESS_MODE_DISABLED
	completed.emit(outcome)
	updated.emit()

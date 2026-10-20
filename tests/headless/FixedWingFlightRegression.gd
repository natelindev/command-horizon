extends SceneTree

# Fixed-wing flight: stands, taxi, take-off roll on the runway, physically bounded
# turns, station orbit, glide-slope approach, rollout, taxi back, rearm, ground
# vulnerability while parked, missile strikes and level bombing.

const Catalog = preload("res://source/match/BastionCatalog.gd")
const ACTIONS = "res://source/match/units/actions/"
const FIELD_CENTER = Vector3(44, 0, 40)
var _errors = []
var _game
var _human
var _enemy
var _field
var _units = []
# Loaded at runtime: these scripts depend on autoloads that a SceneTree script
# compiles before.
var Rules
var Phase


func _initialize():
	call_deferred("_run")


func _run():
	Rules = load("res://source/match/combat/CombatRules.gd")
	Phase = load("res://source/match/units/traits/FixedWingFlight.gd").Phase
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if index == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(p): return p != _human)[0]
	_enemy.set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	await _ticks(30)
	for unit in get_nodes_in_group("units"):
		if unit.type != "CommandCenter":
			unit.queue_free()
		else:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _ticks(5)
	_field = _spawn("AircraftFactory", _human, FIELD_CENTER)
	await _ticks(10)
	var fighter = _spawn("Fighter", _human, FIELD_CENTER + Vector3(2, 0, -4))
	await _ticks(10)
	await _test_parking(fighter)
	await _test_sortie(fighter)
	await _test_return(fighter)
	await _test_rearm(fighter)
	await _test_strike(fighter)
	await _test_bombing()
	_game.queue_free()
	await _ticks(5)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: stands, taxi, runway take-off, bounded turns, station orbit, glide approach, "
				+ "rollout and taxi back, rearm, parked ground target, missile strike, level bombing"
			)
		)
	quit(0 if _errors.is_empty() else 1)


func _test_parking(fighter):
	var flight = fighter.get_node("Movement")
	_check(flight.phase == Phase.PARKED, "New fighter did not park at the airfield")
	_check(flight.airfield == _field and flight.stand == 0, "Fighter did not claim the first stand")
	_check(
		_flat(fighter.global_position).distance_to(_flat(_field.stand_point(0))) < 0.05,
		"Parked fighter is not on its stand"
	)
	var rifle = _spawn("Infantry", _enemy, FIELD_CENTER + Vector3(8, 0, 0))
	await _ticks(2)
	_check(Rules.can_target(rifle, fighter), "Parked aircraft is not a ground target")
	rifle.queue_free()


func _test_sortie(fighter):
	var flight = fighter.get_node("Movement")
	var station = Vector3(20, 0, 22)
	fighter.action = load(ACTIONS + "Moving.gd").new(station)
	_check(str(fighter.action).begins_with("AirStation"), "Move order was not flown as a station")
	var phases = [flight.phase]
	var lift_off_along = INF
	var worst_lateral = 0.0
	var tightest_ratio = INF
	var max_bank = 0.0
	var previous_heading = flight.heading
	var arrived_at = -1
	var threshold = _field.runway_threshold()
	var direction = _field.runway_direction()
	for tick in range(1800):
		await _ticks(1)
		if phases.is_empty() or phases[-1] != flight.phase:
			phases.append(flight.phase)
		var relative = _flat(fighter.global_position - threshold)
		if flight.phase == Phase.TAKEOFF:
			worst_lateral = maxf(
				worst_lateral, absf(relative.dot(direction.rotated(Vector3.UP, PI / 2.0)))
			)
			if lift_off_along == INF and flight.height_above_ground() > 0.05:
				lift_off_along = relative.dot(direction)
		if flight.phase == Phase.AIRBORNE:
			max_bank = maxf(max_bank, absf(flight.bank))
			var rate = absf(angle_difference(previous_heading, flight.heading)) * 30.0
			if rate > 0.05:
				var minimum = flight.airspeed ** 2 / (9.8 * tan(flight.max_bank))
				tightest_ratio = minf(tightest_ratio, (flight.airspeed / rate) / minimum)
		previous_heading = flight.heading
		if flight.arrived():
			arrived_at = tick
			break
	_check(
		phases.slice(0, 4) == [Phase.PARKED, Phase.TAXI, Phase.TAKEOFF, Phase.AIRBORNE],
		"Departure did not taxi, roll and climb: %s" % [phases]
	)
	_check(worst_lateral < 0.35, "Take-off roll left the runway centerline: %s" % worst_lateral)
	_check(
		lift_off_along > 0.0 and lift_off_along < _field.runway_length(),
		"Fighter did not lift off on the runway: %s" % lift_off_along
	)
	_check(max_bank <= flight.max_bank + 0.001, "Bank exceeded its limit")
	_check(tightest_ratio >= 0.97, "Turned tighter than its bank allows: %s" % tightest_ratio)
	_check(arrived_at > 0, "Fighter never reached its station")
	await _ticks(2)
	_check(str(fighter.action).begins_with("AirIdle"), "Arrived station order did not complete")
	_check(fighter.combat_domain() == 0, "Airborne fighter is not an air target")
	var distances = []
	var heights = []
	for _tick in range(240):
		await _ticks(1)
		distances.append(_flat(fighter.global_position).distance_to(_flat(station)))
		heights.append(flight.height_above_ground())
	_check(
		distances.min() > flight.orbit_radius - 2.5 and distances.max() < flight.orbit_radius + 3.5,
		"Station orbit drifted: %s..%s" % [distances.min(), distances.max()]
	)
	_check(heights.min() > 3.0 and heights.max() < 8.0, "Patrol altitude out of band")
	_check(flight.airspeed >= flight.stall_speed, "Fighter flew below stall speed")


func _test_return(fighter):
	var flight = fighter.get_node("Movement")
	fighter.action = load(ACTIONS + "RecoveringAtService.gd").new(_field)
	_check(str(fighter.action).begins_with("AirReturn"), "Return order was not translated")
	var threshold = _field.runway_threshold()
	var direction = _field.runway_direction()
	var end = -1
	var touchdown = null
	var above_slope = 0.0
	var rollout_lateral = 0.0
	var parked = false
	for _tick in range(3600):
		await _ticks(1)
		# Measure against whichever runway end the approach chose.
		if flight._landing_end >= 0 and flight._landing_end != end:
			end = flight._landing_end
			threshold = _field.landing_threshold(end)
			direction = _field.landing_direction(end)
		var relative = _flat(fighter.global_position - threshold)
		var lateral = absf(relative.dot(direction.rotated(Vector3.UP, PI / 2.0)))
		if flight.phase == Phase.APPROACH:
			var to_touchdown = -relative.dot(direction)
			if to_touchdown > 2.0:
				above_slope = maxf(
					above_slope, flight.height_above_ground() - to_touchdown * flight.glide_slope
				)
		if flight.phase == Phase.ROLLOUT:
			if touchdown == null:
				touchdown = [relative.dot(direction), lateral]
			rollout_lateral = maxf(rollout_lateral, lateral)
		if flight.is_parked():
			parked = true
			break
	_check(parked, "Fighter never landed and parked")
	_check(touchdown != null, "Fighter never touched down on the runway")
	if touchdown != null:
		_check(
			touchdown[0] > -0.6 and touchdown[0] < _field.runway_length() * 0.6,
			"Touchdown off the runway: %s" % touchdown[0]
		)
		_check(touchdown[1] < 0.9, "Touchdown off the centerline: %s" % touchdown[1])
	_check(rollout_lateral < 1.0, "Rollout left the runway: %s" % rollout_lateral)
	_check(above_slope < 1.4, "Approach flew far above the glide slope: %s" % above_slope)
	_check(flight.go_arounds <= 1, "Approach needed repeated go-arounds: %s" % flight.go_arounds)
	_check(flight.stand == 0, "Fighter parked on another stand")
	_check(
		_flat(fighter.global_position).distance_to(_flat(_field.stand_point(0))) < 0.3,
		"Taxi did not end on the stand"
	)
	_check(fighter.combat_domain() == 1, "Landed fighter is not a ground target")
	await _ticks(5)


func _test_rearm(fighter):
	fighter.stores.missile = 0
	fighter.stores.cannon = 0
	_check(not fighter.sortie_ready(false), "Empty fighter reported a full load")
	await _ticks(30 * 12)
	_check(fighter.stores_full(), "Fighter did not rearm on its stand: %s" % [fighter.stores])


func _test_strike(fighter):
	var target = _spawn("Helicopter", _enemy, Vector3(22, 0, 30))
	await _ticks(10)
	target.process_mode = Node.PROCESS_MODE_DISABLED
	target.global_position.y = 2.5
	var before = target.hp
	fighter.action = load(ACTIONS + "AutoAttacking.gd").new(target)
	_check(str(fighter.action).begins_with("AirStrike"), "Attack order was not flown as a strike")
	var used = false
	for _tick in range(2400):
		await _ticks(1)
		if not is_instance_valid(target) or target.hp < before:
			used = true
			break
	_check(used, "Fighter missiles never damaged an aircraft")
	_check(fighter.stores.missile < 4, "Fighter struck without expending stores")
	if is_instance_valid(target):
		target.queue_free()
	fighter.action = load(ACTIONS + "RecoveringAtService.gd").new(_field)
	await _until(func(): return fighter.get_node("Movement").is_parked(), 3600)


func _test_bombing():
	var bomber = _spawn("Bomber", _human, FIELD_CENTER + Vector3(2, 0, 0))
	await _ticks(10)
	var flight = bomber.get_node("Movement")
	_check(flight.is_parked() and flight.stand == 1, "Bomber did not take the next free stand")
	var tank = _spawn("Tank", _enemy, Vector3(22, 0, 46))
	await _ticks(10)
	tank.process_mode = Node.PROCESS_MODE_DISABLED
	var before = tank.hp
	bomber.action = load(ACTIONS + "AutoAttacking.gd").new(tank)
	var hit = await _until(func(): return not is_instance_valid(tank) or tank.hp < before, 4200)
	_check(hit, "Bomber stick never damaged its target")
	# The stick walks on for its remaining releases after the first impact.
	await _ticks(40)
	_check(bomber.stores.bomb == 0, "Bomber did not release its whole stick")
	var home = await _until(func(): return flight.is_parked(), 7200)
	_check(home, "Bomber did not return to rearm after its sortie")


func _until(condition, limit):
	for _tick in range(limit):
		await _ticks(1)
		if condition.call():
			return true
	return false


func _spawn(role, player, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	_units.append(unit)
	return unit


static func _flat(vector):
	return vector * Vector3(1, 0, 1)


func _ticks(count):
	for _index in range(count):
		await physics_frame


func _check(condition, message):
	if not condition:
		_errors.append(message)

extends "res://tests/headless/UnitAnimationRegression.gd"

var _rules
var _probe_script
var _comparisons := 0
var _actors := []


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_rules = load("res://source/match/combat/CombatRules.gd")
	_probe_script = load("res://tests/fixtures/NativeUnitStateProbe.gd")
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		if _game.unit_state_store == null:
			_check(false, "Run with --native-unit-state; resident state is required")
			await _close()
			break
		_actors = []
		for side in 2:
			for role in MOBILE_ROLES + ["Fighter", "Bomber", "AntiAirTurret", "CommandLab"]:
				var actor = _spawn(role, side, Vector3(20 + _actors.size(), 0, 25))
				_check(actor._native_state != null, "Unit did not bind: " + role)
				_actors.append(actor)
				var metadata: Array = actor._native_state.metadata()
				_check(
					bool(metadata[0] & 1) == (role not in ["Fighter", "Bomber"]),
					"Domain override detection differs: " + role
				)
		await _frames(3)
		_movement_technologies()
		var custom = _probe_script.new()
		_players[1].add_child(custom)
		_actors.append(custom)
		_check(
			not bool(custom._native_state.metadata()[0] & 1), "Custom domain override was cached"
		)
		var shot = load("res://source/match/combat/Shot.gd").from(_actors[0], Vector3.ZERO)
		for step in 480:
			var source = _actors[step % (_actors.size() - 1)]
			var target = _actors[(step * 7 + 3) % _actors.size()]
			if source == target:
				target = custom
			_mutate(source, step)
			custom.interactive = step % 11 != 0
			custom.invulnerable = step % 13 == 0
			custom.allow_damage = step % 17 != 0
			custom.forced_only = step % 19 == 0
			custom.domain_override = 1 if step % 3 == 0 else 2
			_players[0].team = 0 if step % 4 == 0 else -1
			_players[1].team = 0 if step % 5 == 0 else 1
			for forced in [false, true]:
				_compare(source, target, forced)
				_compare(source, custom, forced)
				shot.force_attack = forced
				var native: bool = _rules.can_receive(shot, target)
				var reference: bool = _oracle(
					[target], func(): return _rules.can_receive(shot, target)
				)
				_check(
					native == reference, "Frozen projectile eligibility differs at step %d" % step
				)
				_comparisons += 1
			_compare_values(source, step)
			# Replacements and shared-array edits both remain visible immediately.
			if step % 7 == 0:
				source.attack_domains.clear()
				_compare(source, target, false)
				source.attack_domains.append(target.combat_domain())
				_compare(source, target, false)
		_custom_player(custom)
		var signalled := []
		var witness = _actors[0]
		witness.hp_changed.connect(
			func(): signalled.append(witness._native_state.hp == witness.hp), CONNECT_ONE_SHOT
		)
		witness.hp -= .125
		_check(signalled == [true], "Health signal observed stale resident state")
		var queued = _actors[1]
		queued.queue_free()
		_compare(witness, queued, true)
		_compare(queued, custom, false)
		var statistics: Array = _game.unit_state_store.statistics()
		_check(
			(
				statistics.size() == 9
				and statistics[2] > 0
				and statistics[3] > 0
				and statistics[4] > 0
			),
			"Resident mutation, eligibility and speed paths did not execute"
		)
		_actors.clear()
		await _close()
	_lifetime()
	for message in _errors:
		push_error(message)
	print("Native unit state: %d failures across %d comparisons" % [_errors.size(), _comparisons])
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _movement_technologies():
	var owner = _players[0]
	var original_faction = owner.faction
	var original_completed = owner.technology.completed
	for faction in ["bastion", "helix", "frontier"]:
		owner.faction = faction
		for technology in ["", "high_octane", "phase_thrusters", "iron_blitz"]:
			owner.technology.completed = []
			if technology != "":
				owner.technology.completed.append(technology)
			for actor in _actors:
				if actor.player != owner:
					continue
				_check(
					bool(actor._native_state.metadata()[0] & 8192),
					"Standard movement technology was not bound: " + actor.type
				)
				_compare_values(actor, 1000)
				# Capture, array mutation and owner faction changes have no tick delay.
				actor.reparent(_players[1])
				_compare_values(actor, 1001)
				actor.reparent(owner)
			owner.technology.completed.clear()
			for actor in _actors:
				if actor.player == owner:
					_compare_values(actor, 1002)
	# Alternate public property types retain the script path's semantics.
	owner.faction = &"frontier"
	owner.technology.completed = PackedStringArray(["high_octane"])
	for actor in _actors:
		if actor.player == owner:
			_compare_values(actor, 1003)
	owner.faction = original_faction
	owner.technology.completed = original_completed
	var custom = load("res://tests/fixtures/NativeMovementFactorProbe.gd").new()
	owner.add_child(custom)
	_check(
		not bool(custom._native_state.metadata()[0] & 8192),
		"Custom movement technology override was cached"
	)
	for factor in [1.25, 0.0, 2.0]:
		custom.movement_factor = factor
		custom.movement_factor_reads = 0
		_check(
			is_equal_approx(custom._native_state.speed(), 4.0 * factor),
			"Custom movement technology lost its live modifier"
		)
		_check(custom.movement_factor_reads == 1, "Custom speed query bypassed its script")
	custom.free()


func _mutate(unit, step: int):
	unit.hp = 20.0 + step * .125
	unit.hp_max = 500.0 + step
	unit.sight_range = 5.0 + step % 9
	unit.attack_damage = null if step % 13 == 0 else 2.5 + step % 8
	unit.attack_interval = null if step % 17 == 0 else .2 + (step % 7) * .1
	unit.attack_range = null if step % 11 == 0 else 4.0 + step % 12
	unit.attack_domains = [1, 2] if step % 2 == 0 else [1]
	unit.experience = (step % 4) * 200.0
	unit.scrap_hardened_tiers = step % 3
	if unit.has_method("is_constructed"):
		unit._construction_progress = .5 if step % 4 == 0 else 1.0
	var movement = unit.get_node_or_null("Movement")
	if movement != null:
		movement.speed = 2.0 + (step % 7) * .25
		movement.domain = 1 if step % 3 == 0 else 2
	if unit.suppression != null:
		unit.suppression.band = step % 3
	if unit.signature != null:
		unit.signature.kind = "maneuver" if step % 2 == 0 else "precision"
		unit.signature.window_left = 2.0 if step % 5 == 0 else 0.0
		var completed: Array = unit.player.technology.completed
		if step % 3 == 0 and not "doctrine" in completed:
			completed.append("doctrine")
		elif step % 3 != 0:
			completed.erase("doctrine")
	if unit.abilities != null:
		for id in ["siege_anchor", "combat_sprint"]:
			var ability = unit.abilities.get_ability(id)
			if ability != null:
				ability.is_active = step % 2 == 0
				ability.active_left = 1.0
	if step % 7 == 0:
		_game.commander_support.emp[unit] = 1.0
	else:
		_game.commander_support.emp.erase(unit)
	if step % 9 == 0:
		unit.set_meta("garrison_host", _actors[0])
	else:
		unit.remove_meta("garrison_host")
	if step % 10 == 0:
		unit.set_meta("breach_pending", true)
	else:
		unit.remove_meta("breach_pending")
	if step % 21 == 0:
		unit.reparent(_players[0] if unit.player == _players[1] else _players[1])


func _compare(source, target, forced: bool):
	_check(
		source._native_state.can_target(target, forced) >= 0, "Ordinary Unit pair used the fallback"
	)
	var native: bool = _rules.can_target(source, target, forced)
	var reference: bool = _oracle(
		[source, target], func(): return _rules.can_target(source, target, forced)
	)
	_check(native == reference, "Target legality differs: %s -> %s" % [source.type, target.type])
	var received: bool = _rules.can_receive(source, target, forced)
	var expected: bool = _oracle(
		[source, target], func(): return _rules.can_receive(source, target, forced)
	)
	_check(received == expected, "Receive legality differs: %s -> %s" % [source.type, target.type])
	_comparisons += 2


func _compare_values(unit, step: int):
	var native := [
		unit.movement_speed,
		unit.attack_damage,
		unit.attack_interval,
		unit.attack_range,
		unit._native_state.hp,
		unit._native_state.hp_max,
		unit._native_state.sight_range,
		unit._native_state.domain,
	]
	var expected: Array = _oracle(
		[unit],
		func():
			return [
				unit.movement_speed,
				unit.attack_damage,
				unit.attack_interval,
				unit.attack_range,
				unit.hp,
				unit.hp_max,
				unit.sight_range,
				unit.movement_domain,
			]
	)
	for index in native.size():
		_check(
			(
				(native[index] == null and expected[index] == null)
				or (
					native[index] != null
					and expected[index] != null
					and is_equal_approx(native[index], expected[index])
				)
			),
			(
				"Modifier differs: %s field=%d step=%d (%s / %s)"
				% [unit.type, index, step, native[index], expected[index]]
			)
		)
	_comparisons += native.size()


func _oracle(units: Array, callback: Callable):
	var held := {}
	for unit in units:
		if not held.has(unit):
			held[unit] = unit._native_state
			unit._native_state = null
	var result = callback.call()
	for unit in held:
		unit._native_state = held[unit]
	return result


func _custom_player(target):
	var player = load("res://tests/fixtures/NativeUnitStatePlayer.gd").new()
	_game.get_node("Players").add_child(player)
	var source = _probe_script.new()
	player.add_child(source)
	for allowed in [true, false]:
		player.allow_alliance = allowed
		_compare(source, target, false)
	player.queue_free()


func _lifetime():
	var store = ClassDB.instantiate("CopperfinUnitStore")
	var node := Node3D.new()
	root.add_child(node)
	var values := [100, 100, 5, 1, 8, 16, null, 1, 0, 1, 1, 0]
	var state = store.bind_unit(node, null, values, [1, 2], 1)
	_check(state != null, "Standalone state did not bind")
	var first: int = state.handle
	state = null
	_check(store.statistics()[0] == 0, "Released state retained its slot")
	state = store.bind_unit(node, null, values, [1], 1)
	_check(state.handle != first, "Reused slot retained a stale generation")
	var weak = weakref(store)
	store = null
	_check(weak.get_ref() != null, "State lost its owning store")
	node.free()
	_check(state.can_target(null, false) == -1, "Freed unit remained queryable")
	state = null
	_check(weak.get_ref() == null, "Native unit state retained an ownership cycle")

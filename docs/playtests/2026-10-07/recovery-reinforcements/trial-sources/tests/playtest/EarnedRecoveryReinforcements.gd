extends "res://tests/playtest/RecoveryReinforcementMatches.gd"

const EARNED = "res://docs/playtests/2026-10-07/material-handoff/control-unresolved"
var restored_policy = {}
var restored_at = 0.0
var initial_funds = Vector2.ZERO
var initial_army = {}
var apply_restored_policy = false


func _start(_settings):
	var files = load("res://source/match/saves/SaveFile.gd").new()
	var data = files.read_file(EARNED + ".json")
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await restore.restore(self, data)
	_check(result.ok, "Earned recovery archive did not restore")
	if not result.ok:
		quit(2)
		return null
	var restored = result.game
	var owner = restored._get_human_player()
	restored_at = data.simulation_time
	initial_funds = Vector2(owner.resource_a, owner.resource_b)
	restored_policy = JSON.parse_string(FileAccess.get_file_as_string(EARNED + "-policy.json"))
	_check(restored_policy.retreating.is_empty(), "Replay needs archived retreat membership")
	initial_army.clear()
	for row in restored_policy.army:
		var unit = restore.entities[row.id]
		initial_army[unit.get_instance_id()] = true
		_check(unit.type == row.role, "Earned recovery army reference mismatch")
		if unit.program != null and unit.program.mode == "Running":
			# Restore test-only authoring ownership without reapplying a live program.
			_check(
				unit.program.program_title.begins_with("Authored field guard"),
				"Unexpected saved guard"
			)
			unit.set_meta("policy_programmed", true)
			unit.set_meta("authored_policy_attempted", true)
			unit.set_meta("authored_policy", true)
	for record in data.units:
		var unit = restore.entities[record.id]
		_check(
			unit.position == record.position and unit.hp == record.hp, "Paused restore changed unit"
		)
	await _frames(30)
	_check(
		paused and restored.simulation_time == restored_at, "Earned restore advanced while paused"
	)
	_check(
		Vector2(owner.resource_a, owner.resource_b) == initial_funds, "Earned restore changed funds"
	)
	_check(
		get_nodes_in_group("players").any(
			func(side): return side != owner and side.is_processing()
		),
		"Earned replay disabled opponent"
	)
	apply_restored_policy = true
	return restored


func _economy():
	if apply_restored_policy:
		apply_restored_policy = false
		phase = restored_policy.phase
		phase_started = restored_policy.phase_started
		last_home_pressure = restored_policy.last_home_pressure
		saw_home_attack = restored_policy.saw_home_attack
		vehicle_sequence = int(restored_policy.vehicle_sequence)
		last_infantry_order = game.simulation_time
		_programmed = true
		metrics.continuation = {
			"archive": EARNED + ".json",
			"restored_at": restored_at,
			"initial_funds": [initial_funds.x, initial_funds.y],
			"first_new_ground": null,
			"first_nine_ground": null,
			"initial_readiness":
			load("res://tests/playtest/reference/PolicyReadiness.gd").sample(self)
		}
		_check(
			_policy_army().size() == initial_army.size(),
			"Restored recovery army membership changed"
		)
		game.hud._toggle_pause()
	super()


func _measure():
	super()
	var army = _policy_army()
	if (
		metrics.continuation.first_new_ground == null
		and army.any(func(unit): return not initial_army.has(unit.get_instance_id()))
	):
		metrics.continuation.first_new_ground = game.simulation_time - restored_at
	if metrics.continuation.first_nine_ground == null and army.size() >= 9:
		metrics.continuation.first_nine_ground = game.simulation_time - restored_at


func _sample():
	var row = super()
	row.continuation_elapsed = game.simulation_time - restored_at
	# The matrix's ordinary 60/12 starting-bank subtraction is invalid here.
	var income = Vector2(human.resource_a, human.resource_b) - initial_funds + _spent
	metrics.harvested = [income.x, income.y]
	return row

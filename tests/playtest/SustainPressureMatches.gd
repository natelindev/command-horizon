extends "res://tests/playtest/ScreenedOpeningMatches.gd"

var next_sustain_sample = 0.0


func _play_case(index):
	next_sustain_sample = 0.0
	await super(index)


func _measure():
	super()
	if game.simulation_time < next_sustain_sample:
		return
	next_sustain_sample = game.simulation_time + 10.0
	var units = plan_rules.owned_units(human)
	var repairs = load("res://source/match/combat/RepairService.gd")
	var wounded = units.filter(
		func(unit):
			return unit.movement_speed > 0 and unit.type != "Worker" and unit.hp < unit.hp_max * .8
	)
	var patients = []
	for unit in wounded:
		patients.append(
			{
				"id": unit.get_instance_id(),
				"role": unit.type,
				"hp": unit.hp,
				"max_hp": unit.hp_max,
				"position": [unit.position.x, unit.position.z],
				"support_near": _support_near(unit, repairs),
				"has_facility":
				units.any(func(source): return repairs.facility_eligible(source, unit)),
				"action": unit.action.get_script().resource_path if unit.action != null else ""
			}
		)
	var buildings = []
	for unit in units:
		if unit.has_method("is_constructed"):
			buildings.append(
				{
					"role": unit.type,
					"built": unit.is_constructed(),
					"hp": unit.hp,
					"position": [unit.position.x, unit.position.z]
				}
			)
	var row = {
		"seconds": game.simulation_time,
		"funds": [human.resource_a, human.resource_b],
		"power": [human.power_totals().x, human.power_totals().y],
		"workers": _economy_workers(units).size(),
		"patients": patients,
		"buildings": buildings
	}
	if not metrics.has("sustain_samples"):
		metrics.sustain_samples = []
	metrics.sustain_samples.append(row)
	print("SUSTAIN ", JSON.stringify(row))


func _support_near(unit, repairs):
	for source in unit.player.get_children():
		if not source.is_in_group("units") or source.is_queued_for_deletion() or source.hp <= 0:
			continue
		var distance = unit.global_position_yless.distance_to(source.global_position_yless)
		if repairs.facility_eligible(source, unit) and distance <= repairs.FACILITY_RANGE:
			return true
		if (
			source.type == "RepairRobot"
			and repairs.mobile_eligible(source, unit)
			and repairs.mobile_distance(source, unit) <= 3.0
			and repairs.stationary(source)
		):
			return true
	return false


# Subclasses reserve units for their own recovery policies.
func _protected_from_command(_unit):
	return false

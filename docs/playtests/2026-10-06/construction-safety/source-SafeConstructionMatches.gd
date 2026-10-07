extends "res://tests/playtest/CautiousRelayMatches.gd"

var safe_construction = true
var construction_observed = []
var construction_rejected = 0


func _place(role, builder):
	construction_observed = economy_policy.contacts(game, human)
	construction_rejected = 0
	var before = plan_rules.owned_units(human)
	super(role, builder)
	var added = plan_rules.owned_units(human).filter(func(unit): return unit not in before)
	if not metrics.has("construction_decisions"):
		metrics.construction_decisions = []
	metrics.construction_policy = "observed_site_and_approach" if safe_construction else "original"
	# Record purchases and changes in deferral reason, not every identical half-second retry.
	var row = {
		"seconds": game.simulation_time,
		"requested": role,
		"rejected": construction_rejected,
		"observed": construction_observed.size(),
		"purchased":
		added.map(func(unit): return {"role": unit.type, "position": _site_array(unit.position)})
	}
	var records = metrics.construction_decisions
	if (
		not added.is_empty()
		or records.is_empty()
		or records[-1].requested != row.requested
		or records[-1].rejected != row.rejected
		or not records[-1].purchased.is_empty()
	):
		records.append(row)


func _placement_candidate_allowed(point, builder):
	if not safe_construction:
		return true
	# Match the existing engineer danger margins; no hidden positions or
	# prediction of future attacks. The segment is a conservative approach heuristic.
	var allowed = (
		not economy_policy.danger(point, builder, construction_observed)
		and economy_policy._clear_approach(
			builder.global_position_yless, point, builder, construction_observed
		)
	)
	if not allowed:
		construction_rejected += 1
	return allowed


func _site_array(point):
	return [point.x, point.y, point.z]

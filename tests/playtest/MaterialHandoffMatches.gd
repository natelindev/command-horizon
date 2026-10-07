extends "res://tests/playtest/SustainedDefenseMatches.gd"

var material_handoff
var materials_enabled = false


func _run():
	materials_enabled = "--material-handoff" in OS.get_cmdline_user_args()
	await super()


func _play_case(index):
	material_handoff = load("res://tests/playtest/reference/MaterialHandoffPolicy.gd").new()
	await super(index)


func _economy():
	super()
	if not materials_enabled:
		return
	var demand = Vector2i.ZERO
	for job in _reference_requests():
		demand += Vector2i(job.cost.resource_a, job.cost.resource_b)
	var research = _reference_research()
	if not research.is_empty():
		demand += Vector2i(research.cost.resource_a, research.cost.resource_b)
	var units = plan_rules.owned_units(human)
	var protected = units.filter(
		func(unit): return unit.type == "Worker" and engineer_safety.protected(unit)
	)
	var issued = material_handoff.restore_materials(game, human, units, protected, demand)
	metrics.material_handoffs = material_handoff.material_handoffs
	if issued > 0:
		print("MATERIAL HANDOFF ", JSON.stringify(material_handoff.material_handoffs[-1]))
		if archive_prefix != "":
			_archive_progress("material_handoff")


func _sample():
	var row = super()
	row.material_handoff_enabled = materials_enabled
	return row

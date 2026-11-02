extends "res://source/match/units/Unit.gd"

signal constructed

const ConstructionVisual = preload("res://source/match/effects/ConstructionVisual.gd")
const FOUNDATION_HEALTH_FRACTION = 0.25

var _construction_progress = 1.0:
	set(value):
		_construction_progress = value
		if _native_state != null:
			_native_state.construction = value

@onready var production_queue = find_child("ProductionQueue"):
	set(_value):
		pass


func _ready():
	await super()
	_setup_autonomous_assembly()
	var activity = load("res://source/match/effects/StructureActivity.gd").new()
	activity.name = "StructureActivity"
	add_child(activity)
	add_child(load("res://source/match/effects/BaseApron.gd").new())


func is_revealing():
	return super() and is_constructed()


func _handle_unit_death():
	if (
		not is_queued_for_deletion()
		and _match != null
		and not _match.restoring
		and is_constructed()
	):
		var ruin = load("res://source/match/world/StructureRuin.gd").from_structure(self)
		_match.map.add_child(ruin)
	super()


func mark_as_under_construction():
	assert(not is_under_construction(), "structure already under construction")
	_construction_progress = 0.0
	if hp == null:
		await ready
	hp = _foundation_hp()
	_setup_autonomous_assembly()
	var visual = ConstructionVisual.new()
	visual.name = "ConstructionVisual"
	add_child(visual)


func _setup_autonomous_assembly():
	if (
		is_under_construction()
		and player != null
		and player.faction == "helix"
		and not has_node("AutonomousAssembly")
	):
		var assembly = load("res://source/match/units/traits/AutonomousAssembly.gd").new()
		assembly.name = "AutonomousAssembly"
		add_child(assembly)


func needs_constructor() -> bool:
	var assembly = get_node_or_null("AutonomousAssembly")
	return is_under_construction() and (assembly == null or not assembly.active())


func _foundation_hp():
	return maxf(1.0, floorf(hp_max * FOUNDATION_HEALTH_FRACTION))


func construct(progress):
	assert(is_under_construction(), "structure must be under construction")

	# Add only the health earned by this step, retaining damage already suffered.
	var remaining_hp = hp_max - _foundation_hp()
	var expected_hp_before_progressing = floorf(_construction_progress * remaining_hp)
	_construction_progress = min(1.0, _construction_progress + progress)
	var expected_hp_after_progressing = floorf(_construction_progress * remaining_hp)
	if expected_hp_after_progressing > expected_hp_before_progressing:
		hp = minf(hp_max, hp + expected_hp_after_progressing - expected_hp_before_progressing)
	var visual = get_node_or_null("ConstructionVisual")
	if visual != null:
		visual.refresh()
	if _construction_progress >= 1.0:
		_finish_construction()


func construction_refund():
	if not is_under_construction() or is_queued_for_deletion() or hp <= 0:
		return {"resource_a": 0, "resource_b": 0}
	var scene_path = get_script().resource_path.replace(".gd", ".tscn")
	var cost = load("res://source/match/FactionCatalog.gd").cost(
		player, scene_path.get_file().get_basename(), true
	)
	var unused = 1.0 - _construction_progress if player.get_meta("skirmish", false) else 1.0
	return {
		"resource_a": floori(cost.resource_a * unused),
		"resource_b": floori(cost.resource_b * unused)
	}


func cancel_construction():
	var gate = load("res://source/match/network/NetworkGate.gd")
	if gate.intercept(self, {"kind": "cancel_build", "unit": gate.id_for(self)}):
		return false
	if not is_under_construction() or is_queued_for_deletion() or hp <= 0:
		return false
	player.add_resources(construction_refund())
	queue_free()
	return true


func is_constructed():
	return _construction_progress >= 1.0


func is_under_construction():
	return not is_constructed()


func construction_progress():
	return _construction_progress


func _finish_construction():
	var visual = get_node_or_null("ConstructionVisual")
	if visual != null:
		visual.finish()
	if is_inside_tree():
		constructed.emit()
		MatchSignals.unit_construction_finished.emit(self)

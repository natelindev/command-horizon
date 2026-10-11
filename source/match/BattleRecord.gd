extends Node

const STAT_COUNTERS = [
	"materials", "electronics", "structures_built", "units_destroyed", "structures_destroyed"
]
const COUNTERS = [
	"forces_trained",
	"engineers_trained",
	"forces_lost",
	"engineers_lost",
	"structures_lost",
	"foundations_lost"
]
var data = {
	"complete_history": true,
	"started_at": 0.0,
	"basic_at": -1.0,
	"program_at": -1.0,
	"forces_trained": 0,
	"engineers_trained": 0,
	"forces_lost": 0,
	"engineers_lost": 0,
	"structures_lost": 0,
	"foundations_lost": 0,
	"statistics":
	{
		"materials": 0,
		"electronics": 0,
		"structures_built": 0,
		"units_destroyed": 0,
		"structures_destroyed": 0,
		"recorded_from": 0.0
	}
}
@onready var game = get_parent()


func _ready():
	MatchSignals.unit_production_finished.connect(_produced)
	MatchSignals.unit_destroying.connect(_lost)
	MatchSignals.resources_mined.connect(_mined)
	MatchSignals.unit_construction_finished.connect(_built)
	MatchSignals.unit_weapon_hit.connect(_weapon_hit)
	observe()


func _owned(unit):
	return not game.restoring and not game.finished and unit.player == game._get_human_player()


func _produced(unit, _producer):
	if _owned(unit) and unit.movement_speed > 0:
		data["engineers_trained" if unit.type == "Worker" else "forces_trained"] += 1


func _lost(unit):
	if not _owned(unit):
		return
	if unit.has_method("is_constructed"):
		data["structures_lost" if unit.is_constructed() else "foundations_lost"] += 1
	elif unit.movement_speed > 0:
		data["engineers_lost" if unit.type == "Worker" else "forces_lost"] += 1


func _mined(worker, kind, amount):
	if _owned(worker) and kind in ["materials", "electronics"]:
		data.statistics[kind] += amount


func _built(unit):
	if _owned(unit):
		data.statistics.structures_built += 1


func _weapon_hit(victim, attacker):
	if not _owned(attacker) or victim.player == attacker.player or victim.hp > 0:
		return
	# Weapon-hit is emitted once per accepted hit, after lethal damage is applied.
	var key = "structures_destroyed" if victim.has_method("is_constructed") else "units_destroyed"
	data.statistics[key] += 1


func observe():
	if game.restoring or game.finished:
		return
	var owner = game._get_human_player()
	if data.basic_at == -1 and owner.basic_programs_unlocked():
		data.basic_at = game.simulation_time
	if data.program_at != -1:
		return
	for unit in owner.get_children():
		if not unit.is_in_group("units") or unit.is_queued_for_deletion() or unit.hp <= 0:
			continue
		if unit.program != null and is_instance_valid(unit.program._owned_action):
			if (
				unit.action == unit.program._owned_action
				and unit.program.mode in ["Running", "Waiting", "Blocked"]
			):
				data.program_at = game.simulation_time
				break


func capture():
	return data.duplicate(true)


func restore(saved):
	if not saved.is_empty():
		data = saved.duplicate(true)
		if not data.has("statistics"):
			_start_statistics()
		return
	# Older archives cannot reconstruct production/losses or an earlier program run.
	for key in COUNTERS:
		data[key] = 0
	_start_statistics()
	data.complete_history = false
	data.started_at = game.simulation_time
	data.basic_at = -2.0 if game._get_human_player().basic_programs_unlocked() else -1.0
	data.program_at = -2.0


func _start_statistics():
	data.statistics = {"recorded_from": game.simulation_time}
	for key in STAT_COUNTERS:
		data.statistics[key] = 0


static func valid(saved, now):
	if (
		not saved is Dictionary
		or saved.size() != (11 if saved.has("statistics") else 10)
		or not saved.get("complete_history") is bool
	):
		return false
	if saved.has("statistics"):
		var stats = saved.statistics
		if not stats is Dictionary or stats.size() != STAT_COUNTERS.size() + 1:
			return false
		for key in STAT_COUNTERS:
			if not stats.get(key) is int or stats[key] < 0 or stats[key] > 1000000000:
				return false
		var start = stats.get("recorded_from")
		if not (start is int or start is float) or not is_finite(start) or start < 0 or start > now:
			return false
	for key in COUNTERS:
		if not saved.get(key) is int or saved[key] < 0 or saved[key] > 1000000:
			return false
	for key in ["started_at", "basic_at", "program_at"]:
		var value = saved.get(key)
		if not (value is int or value is float) or not is_finite(value):
			return false
		if value < 0:
			if key == "started_at" or value not in [-1.0, -2.0]:
				return false
		elif value > now or (key != "started_at" and value < saved.started_at):
			return false
	return true


func summary():
	var lines = []
	if not data.complete_history:
		lines.append("Battle record begins at " + _clock(data.started_at))
	lines.append("Forces · %d trained / %d lost" % [data.forces_trained, data.forces_lost])
	lines.append("Engineers · %d trained / %d lost" % [data.engineers_trained, data.engineers_lost])
	lines.append(
		"Structures lost · %d built / %d unfinished" % [data.structures_lost, data.foundations_lost]
	)
	lines.append("Basic programs unlocked · " + _milestone(data.basic_at))
	lines.append("First program active · " + _milestone(data.program_at))
	return "\n".join(lines)


static func _milestone(value):
	if value == -2:
		return "Not recorded"
	return "Not reached" if value < 0 else _clock(value)


static func _clock(value):
	var seconds = int(value)
	return "%02d:%02d" % [seconds / 60, seconds % 60]


func statistics_rows():
	return [
		["Units produced", data.forces_trained + data.engineers_trained],
		["Materials mined", data.statistics.materials],
		["Electronics mined", data.statistics.electronics],
		["Buildings completed", data.statistics.structures_built],
		["Enemy units destroyed", data.statistics.units_destroyed],
		["Enemy buildings destroyed", data.statistics.structures_destroyed],
		["Units lost", data.forces_lost + data.engineers_lost],
		["Buildings lost", data.structures_lost + data.foundations_lost]
	]

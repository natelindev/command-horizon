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
	}
}
@onready var game = get_parent()


func _ready():
	MatchSignals.unit_production_finished.connect(_produced)
	MatchSignals.unit_destroying.connect(_lost)
	MatchSignals.resources_mined.connect(_mined)
	MatchSignals.unit_construction_finished.connect(_built)
	MatchSignals.unit_weapon_hit.connect(_weapon_hit)


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


func capture():
	return data.duplicate(true)


func restore(saved):
	data = saved.duplicate(true)


static func valid(saved):
	if not saved is Dictionary or saved.size() != COUNTERS.size() + 1:
		return false
	var stats = saved.get("statistics")
	if not stats is Dictionary or stats.size() != STAT_COUNTERS.size():
		return false
	for key in STAT_COUNTERS:
		if not stats.get(key) is int or stats[key] < 0 or stats[key] > 1000000000:
			return false
	for key in COUNTERS:
		if not saved.get(key) is int or saved[key] < 0 or saved[key] > 1000000:
			return false
	return true


func summary():
	var lines = [
		"Forces · %d trained / %d lost" % [data.forces_trained, data.forces_lost],
		"Engineers · %d trained / %d lost" % [data.engineers_trained, data.engineers_lost],
		"Structures lost · %d built / %d unfinished" % [data.structures_lost, data.foundations_lost]
	]
	return "\n".join(lines)


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

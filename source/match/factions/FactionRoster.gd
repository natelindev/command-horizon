extends Resource

## Authored roster data. Role IDs remain stable in orders and saves, while scenes,
## absolute unit statistics, production batches and exclusions belong to a faction.
@export var faction_id: String = ""
@export var scenes: Dictionary = {}
@export var statistics: Dictionary = {}
@export var batches: Dictionary = {}
@export var production: Dictionary = {}
# Generic [] defaults lose the authored packed values during binary export.
@export var excluded_structures: PackedStringArray = PackedStringArray()
@export var excluded_units: PackedStringArray = PackedStringArray()


func scene_for(role: String) -> String:
	return scenes.get(role, "res://source/match/units/%s.tscn" % role)


func batch_size(role: String) -> int:
	return maxi(1, batches.get(role, 1))


func allows(role: String, building: bool = false) -> bool:
	return role not in (excluded_structures if building else excluded_units)

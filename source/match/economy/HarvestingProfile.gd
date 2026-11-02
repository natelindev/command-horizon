extends RefCounted

## The economic identity is shared by manual orders, AI harvesting and saves.
## Values are derived from the faction, never copied into a second mutable state.
const CAPACITY = {"bastion": 8, "helix": 4, "frontier": 4}
const PHASE_CHANNEL = 1.2
const SELF_REPAIR_RATE = 1.5
const SELF_REPAIR_DELAY = 5.0
const SMELTING_BONUS = 0.15

var faction: String
var cargo_capacity: int
var travel_multiplier: float = 1.0


func _init(identity = "bastion"):
	faction = identity
	cargo_capacity = CAPACITY.get(faction, 4)
	# The heavy tracked hull trades travel speed for its doubled cargo bay.
	travel_multiplier = {"bastion": .9, "helix": 1.15, "frontier": 1.0}.get(faction, 1.0)


func collection_interval(kind: int, base_interval: float) -> float:
	return base_interval / (1.25 if faction == "helix" and kind == 2 else 1.0)


func phase_delivery() -> bool:
	return faction == "helix"


static func valid_dropoff(worker, structure, hq_only = false) -> bool:
	return (
		is_instance_valid(worker)
		and is_instance_valid(structure)
		and not structure.is_queued_for_deletion()
		and "type" in structure
		and (
			structure.type
			in (["CommandCenter"] if hq_only else ["CommandCenter", "ForwardRefinery"])
		)
		and structure.player == worker.player
		and structure.hp != null
		and structure.hp > 0
		and structure.has_method("is_constructed")
		and structure.is_constructed()
		and (structure.type != "ForwardRefinery" or worker.player.faction == "bastion")
	)


static func deliver(worker, structure):
	assert(valid_dropoff(worker, structure), "Cargo requires a completed friendly drop-off")
	var materials: int = worker.resource_a
	if materials > 0 and structure.type == "ForwardRefinery":
		materials = structure.refine_materials(materials)
	worker.player.resource_a += materials
	worker.player.resource_b += worker.resource_b
	worker.resource_a = 0
	worker.resource_b = 0

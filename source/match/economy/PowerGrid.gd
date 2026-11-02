extends RefCounted

## Derived grid state is never saved separately from its generators and abilities.
const BROWNOUT_RATE = 0.25
const SURGE_OUTPUT = 1.5


static func totals(player) -> Vector2i:
	var factions = load("res://source/match/FactionCatalog.gd")
	var supply = 0
	var demand = 0
	for structure in player.structure_candidates():
		if (
			structure.is_queued_for_deletion()
			or structure.get_parent() != player
			or not structure.is_constructed()
			or ("hp" in structure and structure.hp <= 0)
		):
			continue
		var output = factions.power_supply(player.faction, structure.type)
		if (
			"abilities" in structure
			and structure.abilities != null
			and structure.abilities.is_active("grid_surge")
		):
			output = floori(output * SURGE_OUTPUT)
		supply += output
		demand += factions.power_usage(player.faction, structure.type)
		if (
			player.faction == "helix"
			and structure.type == "PowerPlant"
			and "abilities" in structure
			and structure.abilities != null
			and structure.abilities.is_active("power_overdrive")
		):
			demand += 3
	return Vector2i(supply, demand)


static func state(player) -> String:
	var power = totals(player)
	return "brownout" if power.y > power.x else ("balanced" if power.y == power.x else "surplus")


static func turret_disabled(unit) -> bool:
	return (
		is_instance_valid(unit)
		and "type" in unit
		and unit.type in ["AntiGroundTurret", "AntiAirTurret"]
		and unit.player != null
		and unit.player.has_method("is_brownout")
		and unit.player.is_brownout()
	)

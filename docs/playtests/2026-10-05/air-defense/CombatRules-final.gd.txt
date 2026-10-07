extends RefCounted

# One multiplier only; damage remains floating point all the way to HP.
const MULTIPLIERS = {
	"Rifle": [1.0, 0.6, 0.15, 0.15],
	"Autocannon": [1.25, 1.0, 0.45, 0.35],
	"Tank cannon": [0.5, 1.0, 1.0, 0.7],
	"Heavy cannon": [0.35, 0.9, 1.3, 0.8],
	"Precision rail": [0.4, 1.0, 1.4, 0.8],
	"Anti-armor lance": [0.3, 0.8, 2.0, 0.5],
	"Strike missile": [0.75, 1.0, 1.0, 0.6],
	"Anti-air": [0.0, 1.0, 0.0, 0.0],
}
const ARMOR_NAMES = ["Infantry", "Light machine", "Heavy armor", "Structure"]
const PROFILES = {
	"Infantry": "Rifle",
	"CombatRobot": "Autocannon",
	"Tank": "Tank cannon",
	"AdvancedTank": "Precision rail",
	"Helicopter": "Strike missile",
	"AntiGroundTurret": "Tank cannon",
	"AntiAirTurret": "Anti-air",
}


static func armor_for(role):
	if role == "Infantry":
		return 0
	if role in ["Tank", "AdvancedTank"]:
		return 2
	if (
		role
		in [
			"EvacTransport",
			"SupplyTruck",
			"Worker",
			"RepairRobot",
			"CombatRobot",
			"Drone",
			"Helicopter"
		]
	):
		return 1
	return 3


static func can_target(source, target):
	return (
		is_instance_valid(source)
		and is_instance_valid(target)
		and not source.is_queued_for_deletion()
		and not target.is_queued_for_deletion()
		and source.hp != null
		and source.hp > 0
		and "hp" in target
		and target.hp != null
		and target.hp > 0
		and "player" in target
		and source.player != target.player
		and source.attack_range != null
		and target.movement_domain in source.attack_domains
		and (not source.has_method("is_constructed") or source.is_constructed())
	)


static func damage(source, target):
	if not can_target(source, target):
		return 0.0
	var profile = profile_for(source)
	if (
		source.type == "CombatRobot"
		and target.movement_domain == Constants.Match.Navigation.Domain.AIR
	):
		profile = "Anti-air"
	elif source.type == "CombatRobot" and source.player.faction == "helix":
		profile = "Anti-armor lance"
	if not MULTIPLIERS.has(profile):
		return 0.0
	var factor = target.signature.damage_factor() if target.signature != null else 1.0
	if source.player.technology != null:
		factor *= source.player.technology.damage_factor(source.type)
	return float(source.attack_damage) * MULTIPLIERS[profile][armor_for(target.type)] * factor


static func range_for(source, target):
	if (
		source.type == "CombatRobot"
		and source.player.faction != "helix"
		and target.movement_domain == Constants.Match.Navigation.Domain.AIR
	):
		return minf(4.5, source.attack_range)
	return source.attack_range


static func preparation_for(unit):
	if unit.type == "AdvancedTank":
		return 0.0 if unit.player.faction == "frontier" else 0.75
	if (
		unit.type == "CombatRobot"
		and unit.player.faction == "helix"
		and unit.weapon_mode == "precision"
	):
		return 0.75
	return 0.0


static func describe(unit):
	var text = ARMOR_NAMES[armor_for(unit.type)]
	if unit.type == "AdvancedTank" and unit.player.faction == "helix":
		return text + " · Precision rail · " + unit.deployment_status()
	if PROFILES.has(unit.type):
		text += " · " + profile_for(unit)
		if unit.type == "CombatRobot":
			if unit.player.faction == "helix":
				return ARMOR_NAMES[armor_for(unit.type)] + " · " + unit.weapon_status()
			text += " 5.5 m / AA 4.5 m · shared reload"
	return text


static func profile_for(unit):
	if unit.type == "AdvancedTank" and unit.player.faction == "frontier":
		return "Heavy cannon"
	return PROFILES.get(unit.type, "")

extends RefCounted

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")
const Technologies = preload("res://source/match/research/TechnologyCatalog.gd")
const Players = preload("res://source/match/Players.gd")

# Armor profiles; damage remains floating point all the way to HP.
const MULTIPLIERS = {
	"Infantry rocket": [.3, 1.1, 1.7, 1.1],
	"Sniper rifle": [1.5, .4, .1, .1],
	"Assault rifle": [1.2, .5, .12, .15],
	"Rifle": [1.0, 0.6, 0.15, 0.15],
	"Autocannon": [1.25, 1.0, 0.45, 0.35],
	"Tank cannon": [0.5, 1.0, 1.0, 0.7],
	"Heavy cannon": [0.35, 0.9, 1.3, 0.8],
	"Precision rail": [0.4, 1.0, 1.4, 0.8],
	"Anti-armor lance": [0.3, 0.8, 2.0, 0.5],
	"Strike missile": [0.75, 1.0, 1.0, 0.6],
	"Anti-air": [1.0, 1.0, 1.0, 1.0],
	"Infantry SAM": [0.0, 0.85, 0.0, 0.0],
	"Fighter missile": [1.0, 1.0, 1.0, 1.0],
	"Heavy bomb": [1.1, 1.0, 0.9, 2.0],
	"Loitering munition": [0.6, 1.3, 1.5, 1.2],
	"Flak": [1.0, 1.0, 1.0, 1.0],
}
# Shoulder-launched missiles need a short lock before launching at aircraft.
const INFANTRY_SAM_RANGE = 9.0
const INFANTRY_SAM_LOCK = 0.8
const ARMOR_NAMES = ["Infantry", "Light machine", "Heavy armor", "Structure"]
const PROFILES = {
	"MercenaryLancer": "Infantry rocket",
	"MercenaryRanger": "Sniper rifle",
	"MercenaryWarden": "Assault rifle",
	"RocketInfantry": "Infantry rocket",
	"SniperInfantry": "Sniper rifle",
	"AssaultInfantry": "Assault rifle",
	"Hero": "Autocannon",
	"Infantry": "Rifle",
	"CombatRobot": "Autocannon",
	"Tank": "Tank cannon",
	"AdvancedTank": "Precision rail",
	"Helicopter": "Strike missile",
	"Fighter": "Fighter missile",
	"Bomber": "Heavy bomb",
	"Drone": "Loitering munition",
	"AntiAirVehicle": "Flak",
	"AntiGroundTurret": "Tank cannon",
	"AntiAirTurret": "Anti-air",
}


static func armor_for(role):
	if InfantryRoster.is_infantry(role):
		return 0
	if role in ["Tank", "AdvancedTank", "AntiAirVehicle"]:
		return 2
	if (
		InfantryRoster.is_aircraft(role)
		or role in ["SupplyTruck", "Worker", "RepairRobot", "CombatRobot"]
	):
		return 1
	return 3


static func can_target(source, target, forced = false):
	return (
		is_instance_valid(source)
		and not source.is_queued_for_deletion()
		and source.hp != null
		and source.hp > 0
		and source.attack_range != null
		and (not source.has_method("is_constructed") or source.is_constructed())
		and (not source.has_method("armed") or source.armed())
		and can_receive(source, target, forced)
	)


static func can_force_target(source, target):
	return can_target(source, target, true)


static func explicit_attack(source, target):
	if not is_instance_valid(target):
		return false
	if "force_attack" in source:
		return source.force_attack
	var action = source.get("action")
	return (
		is_instance_valid(action)
		and "force_attack" in action
		and action.force_attack
		and "_target_unit" in action
		and action._target_unit == target
	)


# Target-side legality shared by live shooters and in-flight rounds (Shot).
static func can_receive(source, target, forced = false):
	return (
		is_instance_valid(target)
		and not target.is_queued_for_deletion()
		and not target.has_meta("garrison_host")
		and target.has_method("combat_domain")
		and target.has_method("receive_shot")
		and (not "interactive" in target or target.interactive)
		and "hp" in target
		and target.hp != null
		and target.hp > 0
		and (not "invulnerable" in target or not target.invulnerable)
		and (not target.has_method("can_take_damage") or target.can_take_damage())
		and "player" in target
		and (
			forced
			or explicit_attack(source, target)
			or (
				not Players.allied(source.player, target.player)
				and (not target.has_method("force_attack_only") or not target.force_attack_only())
			)
		)
		and target.combat_domain() in source.attack_domains
	)


static func damage(source, target):
	if not can_target(source, target):
		return 0.0
	return _damage(source, target)


# A round keeps its frozen weapon facts after its shooter is destroyed.
static func damage_from(shot, target):
	if not can_receive(shot, target):
		return 0.0
	return _damage(shot, target)


static func _damage(source, target):
	var profile = profile_for(source)
	if (
		source.type == "CombatRobot"
		and (
			_airborne(target)
			or (source.player.faction == "helix" and source.weapon_mode == "interception")
		)
	):
		profile = "Anti-air"
	elif source.type == "CombatRobot" and source.player.faction == "helix":
		profile = "Anti-armor lance"
	elif (
		source.type == "RocketInfantry"
		and target.combat_domain() == Constants.Match.Navigation.Domain.AIR
	):
		profile = "Infantry SAM"
	if not MULTIPLIERS.has(profile):
		return 0.0
	var factor = target.signature.damage_factor() if target.signature != null else 1.0
	# AA weapons retain full air damage; research upgrades ground damage,
	# including parked aircraft whose armor class is still Light machine.
	if profile in ["Anti-air", "Flak"] and not _airborne(target):
		factor *= aa_ground_damage_factor(source.player)
	if source.player.technology != null:
		factor *= source.player.technology.damage_factor(source.type)
	var armor = armor_for(target.type)
	if (
		target.is_in_group("neutral_targets")
		and target.combat_domain() == Constants.Match.Navigation.Domain.AIR
	):
		armor = 1
	return float(source.attack_damage) * MULTIPLIERS[profile][armor] * factor


static func aa_ground_damage_factor(player):
	return (
		player.technology.aa_ground_damage_factor()
		if player.technology != null
		else Technologies.AA_GROUND_DAMAGE_FACTOR
	)


static func range_for(source, target):
	if (
		source.type == "CombatRobot"
		and source.player.faction != "helix"
		and target.combat_domain() == Constants.Match.Navigation.Domain.AIR
	):
		return minf(6.5, source.attack_range)
	if source.type == "RocketInfantry" and _airborne(target):
		return minf(INFANTRY_SAM_RANGE, source.attack_range)
	return (
		source.attack_range
		+ high_ground_range_bonus(source, target)
		+ (target.radius if target.is_in_group("neutral_buildings") else 0.0)
		+ (
			source.get_meta("garrison_host").radius + 2.0
			if source.has_meta("garrison_host")
			else 0.0
		)
	)


static func high_ground_range_bonus(source, target = null) -> float:
	if not source.has_method("terrain_advantage") or not source.terrain_advantage():
		return 0.0
	if target != null:
		if (
			target.combat_domain() == Constants.Match.Navigation.Domain.AIR
			or source.global_position.y - target.global_position.y < 1.5
		):
			return 0.0
	return minf(1.5, float(source.attack_range) * 0.1) if source.attack_range != null else 0.0


static func preparation_for(unit, target = null):
	if unit.type == "RocketInfantry":
		return INFANTRY_SAM_LOCK if target != null and _airborne(target) else 0.0
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
			text += " 8 m / AA 6.5 m · shared reload"
		elif unit.type == "RocketInfantry":
			text += " 10 m / AA missile 9 m · shared reload"
	return text


static func _airborne(target):
	return (
		is_instance_valid(target)
		and target.combat_domain() == Constants.Match.Navigation.Domain.AIR
	)


static func profile_for(unit):
	if unit.type == "Hero" and unit.player.faction == "helix":
		return "Anti-armor lance"
	if unit.type == "AdvancedTank" and unit.player.faction == "frontier":
		return "Heavy cannon"
	return PROFILES.get(unit.type, "")

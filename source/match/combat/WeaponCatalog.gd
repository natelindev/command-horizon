extends RefCounted

# Physical weapon profiles. Speeds are metres per second on the battlefield scale
# (a tank is about two metres long); spreads are one-sigma angles in radians.
# Damage and armour multipliers stay in CombatRules; these only shape flight.
#
# kind:
#   bullet  fast, gravity, contact only
#   shell   ballistic arc, contact only
#   rocket  unguided motor burn, then ballistic
#   missile guided by lead pursuit with a turn-rate limit and proximity fuse
#   bomb    released with the carrier's velocity, gravity and drag
#   rail    hypervelocity slug resolved along its firing line in one tick

# Preloaded directly: scripts that compile before autoloads also preload this.
const MatchRules = preload("res://source/match/MatchConstants.gd")
const GRAVITY = 9.8

const RIFLE = {"id": "rifle", "kind": "bullet", "speed": 62.0, "spread": 0.018, "visual": "tracer"}
const SNIPER = {
	"id": "sniper", "kind": "bullet", "speed": 95.0, "spread": 0.004, "visual": "tracer"
}
const ASSAULT = {
	"id": "assault", "kind": "bullet", "speed": 56.0, "spread": 0.032, "visual": "tracer"
}
const AUTOCANNON = {
	"id": "autocannon",
	"kind": "bullet",
	"speed": 48.0,
	"spread": 0.02,
	"visual": "heavy_tracer",
	"splash": 0.6
}
const TANK_SHELL = {
	"id": "tank_shell",
	"kind": "shell",
	"speed": 38.0,
	"spread": 0.008,
	"visual": "slug",
	"splash": 0.9
}
const HEAVY_SHELL = {
	"id": "heavy_shell",
	"kind": "shell",
	"speed": 32.0,
	"spread": 0.009,
	"visual": "slug",
	"splash": 1.3
}
const SIEGE_SHELL = {
	"id": "siege_shell", "kind": "shell", "speed": 19.0,
	"spread": 0.004, "visual": "slug", "splash": 3.8, "high_arc": true, "life": 4.0,
}
const PRISM_BEAM = {
	"id": "prism_beam", "kind": "rail", "speed": 400.0,
	"spread": 0.0, "visual": "rail", "prism": true,
}
const THERMAL_BEAM = {
	"id": "thermal_beam", "kind": "rail", "speed": 400.0,
	"spread": 0.0, "visual": "rail",
}
const ION_DISRUPTOR = {
	"id": "ion_disruptor", "kind": "missile", "speed": 22.0,
	"turn": 7.0, "spread": 0.0, "visual": "rocket", "gravity": 0.0,
	"shield_pierce": true, "ion_stall": 1.0, "life": 2.0,
}
const DEMOLITION_CHARGE = {
	"id": "demolition_charge", "kind": "warhead", "speed": 0.0,
	"visual": "bomb", "splash": 4.0,
}
const RAIL = {"id": "rail", "kind": "rail", "speed": 400.0, "spread": 0.001, "visual": "rail"}
const INFANTRY_ROCKET = {
	"id": "infantry_rocket",
	"kind": "rocket",
	"speed": 9.0,
	"thrust": 30.0,
	"burn": 0.45,
	"max_speed": 24.0,
	"gravity": 0.35,
	"spread": 0.03,
	"visual": "rocket",
	"splash": 1.0,
}
const GUIDED_SALVO = {
	"id": "guided_salvo",
	"kind": "missile",
	"speed": 24.0,
	"turn": 8.0,
	"gravity": 0.0,
	"spread": 0.0,
	"visual": "rocket",
	"ability_damage": 34.0,
}
const STRIKE_ROCKET = {
	"id": "strike_rocket",
	"kind": "rocket",
	"speed": 16.0,
	"thrust": 26.0,
	"burn": 0.5,
	"max_speed": 30.0,
	"gravity": 0.5,
	"spread": 0.035,
	"visual": "rocket",
	"splash": 1.1,
}
const SAM = {
	"id": "sam",
	"kind": "missile",
	"speed": 10.0,
	"thrust": 34.0,
	"burn": 1.2,
	"max_speed": 30.0,
	"turn": 3.2,
	"fuse": 0.7,
	"drag": 0.35,
	"spread": 0.05,
	"visual": "missile",
	"splash": 1.2,
	"life": 3.2,
}

const INFANTRY_SAM = {
	"id": "infantry_sam",
	"kind": "missile",
	"speed": 12.0,
	"thrust": 30.0,
	"burn": 1.0,
	"max_speed": 28.0,
	"turn": 4.0,
	"fuse": 0.5,
	"drag": 0.3,
	"spread": 0.04,
	"visual": "missile",
	"splash": 0.8,
	"life": 2.6,
}
# Aircraft stores. Rounds launched from an aircraft add the carrier's velocity.
const AIR_TO_AIR = {
	"id": "air_to_air",
	"kind": "missile",
	"speed": 6.0,
	"thrust": 42.0,
	"burn": 0.9,
	"max_speed": 36.0,
	"turn": 4.8,
	"fuse": 0.7,
	"drag": 0.25,
	"spread": 0.03,
	"visual": "missile",
	"splash": 1.0,
	"life": 3.0,
}
const JET_CANNON = {
	"id": "jet_cannon",
	"kind": "bullet",
	"speed": 58.0,
	"spread": 0.014,
	"visual": "heavy_tracer",
	"damage_scale": 0.22,
}
const GRAVITY_BOMB = {
	"id": "gravity_bomb",
	"kind": "bomb",
	"speed": 0.0,
	"drag": 0.08,
	"spread": 0.0,
	"visual": "bomb",
	"splash": 2.4,
	"life": 4.0,
}
# Mobile anti-air: proximity-fused flak bursts near aircraft or at the end of
# their short flight; Helix fires fast guided interceptors; Frontier a rapid gun.
const FLAK = {
	"id": "flak",
	"kind": "bullet",
	"speed": 46.0,
	"spread": 0.022,
	"fuse": 0.9,
	"splash": 1.3,
	"visual": "heavy_tracer",
	"life": 0.4,
	"cloud_seconds": 2.0,
}
const FLAK_CLOUD = {
	"id": "flak_cloud", "kind": "cloud", "speed": 0.0,
	"visual": "flak_cloud", "splash": 2.1, "life": 2.0,
}
const INTERCEPTOR = {
	"id": "interceptor",
	"kind": "missile",
	"speed": 14.0,
	"thrust": 46.0,
	"burn": 0.8,
	"max_speed": 40.0,
	"turn": 5.5,
	"fuse": 0.8,
	"drag": 0.25,
	"spread": 0.03,
	"visual": "missile",
	"splash": 1.2,
	"life": 2.4,
	"ion_stall": 2.5,
}
const AA_AUTOCANNON = {
	"id": "aa_autocannon",
	"kind": "bullet",
	"speed": 55.0,
	"spread": 0.025,
	"visual": "heavy_tracer"
}
const SAM_SWARM = {
	"id": "sam_swarm", "kind": "rocket", "speed": 40.0,
	"thrust": 35.0, "burn": 0.35, "max_speed": 52.0, "gravity": 0.0,
	"spread": 0.012, "visual": "rocket", "splash": 0.8, "life": 1.0,
}
const PULSE_LASER = {
	"id": "pulse_laser",
	"kind": "bullet",
	"speed": 65.0,
	"spread": 0.008,
	"visual": "tracer",
	"splash": 0.4
}
const TWIN_AUTOCANNON = {
	"id": "twin_autocannon",
	"kind": "bullet",
	"speed": 52.0,
	"spread": 0.015,
	"visual": "heavy_tracer",
	"splash": 0.6,
	"barrels": 2
}
const SHOTGUN = {
	"id": "shotgun", "kind": "bullet", "speed": 46.0, "spread": 0.045, "visual": "heavy_tracer"
}
const EMP_ROCKET = {
	"id": "emp_rocket",
	"kind": "missile",
	"speed": 22.0,
	"turn": 7.0,
	"gravity": 0.0,
	"spread": 0.0,
	"visual": "rocket",
	"ability_damage": 35.0
}
# A kamikaze drone's own warhead, detonated where the airframe strikes.
const DRONE_WARHEAD = {
	"id": "drone_warhead",
	"kind": "warhead",
	"speed": 0.0,
	"visual": "missile",
	"splash": 1.8,
}
const ALL = [
	RIFLE,
	SNIPER,
	ASSAULT,
	AUTOCANNON,
	TANK_SHELL,
	HEAVY_SHELL,
	SIEGE_SHELL,
	PRISM_BEAM,
	THERMAL_BEAM,
	ION_DISRUPTOR,
	DEMOLITION_CHARGE,
	SAM_SWARM,
	RAIL,
	INFANTRY_ROCKET,
	GUIDED_SALVO,
	STRIKE_ROCKET,
	SAM,
	INFANTRY_SAM,
	AIR_TO_AIR,
	JET_CANNON,
	GRAVITY_BOMB,
	DRONE_WARHEAD,
	FLAK,
	FLAK_CLOUD,
	INTERCEPTOR,
	AA_AUTOCANNON,
	PULSE_LASER,
	TWIN_AUTOCANNON,
	SHOTGUN,
	EMP_ROCKET,
]

const BY_ROLE = {
	"Infantry": RIFLE,
	"SniperInfantry": SNIPER,
	"AssaultInfantry": ASSAULT,
	"RocketInfantry": INFANTRY_ROCKET,
	"Hero": AUTOCANNON,
	"MercenaryRanger": SNIPER,
	"MercenaryWarden": SHOTGUN,
	"MercenaryLancer": INFANTRY_ROCKET,
	"CombatRobot": AUTOCANNON,
	"Tank": TANK_SHELL,
	"AdvancedTank": RAIL,
	"AntiGroundTurret": TANK_SHELL,
	"Helicopter": STRIKE_ROCKET,
	"AntiAirTurret": SAM,
	"AntiAirVehicle": FLAK,
}
const FACTION_ROLE = {
	"bastion:AdvancedTank": SIEGE_SHELL,
	"helix:AdvancedTank": PRISM_BEAM,
	"helix:AntiGroundTurret": PRISM_BEAM,
	"helix:Infantry": PULSE_LASER,
	"helix:AssaultInfantry": PULSE_LASER,
	"helix:SniperInfantry": THERMAL_BEAM,
	"helix:RocketInfantry": ION_DISRUPTOR,
	"helix:Tank": PULSE_LASER,
	"frontier:Tank": TWIN_AUTOCANNON,
	"frontier:AdvancedTank": TWIN_AUTOCANNON,
	"frontier:CombatRobot": DEMOLITION_CHARGE,
	"frontier:Worker": AUTOCANNON,
	"helix:AntiAirVehicle": INTERCEPTOR,
	"frontier:AntiAirVehicle": SAM_SWARM,
}


static func profile(unit, target = null):
	if (
		unit.type == "RocketInfantry"
		and is_instance_valid(target)
		and target.combat_domain() == MatchRules.Navigation.Domain.AIR
	):
		return INFANTRY_SAM
	var faction = unit.player.faction if unit.player != null and "faction" in unit.player else ""
	var key = faction + ":" + unit.type
	if FACTION_ROLE.has(key):
		return FACTION_ROLE[key]
	return BY_ROLE.get(unit.type, TANK_SHELL)


static func by_id(id):
	for weapon in ALL:
		if weapon.id == id:
			return weapon
	return {}


static func ids():
	return ALL.map(func(weapon): return weapon.id)


# Guidance and motors make a round's own flight time hard to state exactly; this
# conservative upper bound sizes lifetimes and save validation.
static func lifetime(weapon, reach):
	if weapon.has("life"):
		return weapon.life
	var speed = maxf(weapon.speed, weapon.get("max_speed", weapon.speed) * 0.5)
	return clampf(reach / speed * 2.5 + 0.25, 0.3, 3.0)


static func suppression_hit(weapon: Dictionary, player) -> float:
	match weapon.get("id", ""):
		"rifle", "pulse_laser":
			return 6.0
		"assault", "shotgun":
			return 8.0
		"autocannon", "twin_autocannon":
			return 16.0
		"flak", "aa_autocannon":
			return (
				8.0
				* load("res://source/match/combat/CombatRules.gd").aa_ground_damage_factor(player)
			)
	return 0.0


static func suppresses_nearby(weapon: Dictionary) -> bool:
	return weapon.get("id", "") in ["autocannon", "twin_autocannon", "flak", "aa_autocannon"]

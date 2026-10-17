extends RefCounted

const STRUCTURE_LIMIT = 40
const INFANTRY_ROLES = ["Infantry", "RocketInfantry", "SniperInfantry", "AssaultInfantry", "Hero"]
const GARRISON_CAPACITY = 8

const MISSION_NAMES = {"SupplyTruck": "Supply truck", "EvacTransport": "Rescue VTOL"}

const NAMES = {
	"RocketInfantry": "Anti-armor infantry",
	"SniperInfantry": "Sniper",
	"AssaultInfantry": "Assault infantry",
	"Hero": "Marshal Aegis",
	"Worker": "Engineer rover",
	"Infantry": "Rifle infantry",
	"Tank": "Bastion tank",
	"AdvancedTank": "Railgun tank",
	"RepairRobot": "Repair robot",
	"CombatRobot": "Combat walker",
	"Drone": "Recon drone",
	"Helicopter": "VTOL strike aircraft",
	"CommandCenter": "Headquarters",
	"Barracks": "Barracks",
	"VehicleFactory": "Vehicle factory",
	"AircraftFactory": "Airfield",
	"PowerPlant": "Power generator",
	"CommandLab": "Command lab",
	"RepairDepot": "Repair depot",
	"AntiGroundTurret": "Ground battery",
	"AntiAirTurret": "Missile battery",
}
const DESCRIPTIONS = {
	"RocketInfantry":
	"Shoulder-launched rockets break heavy armor and structures; slow reload, weak against infantry.",
	"SniperInfantry":
	"Long-range precision rifle against infantry. Fragile and ineffective against heavy armor.",
	"AssaultInfantry":
	(
		"Armored close-range assault troops. Rapid fire against infantry; "
		+ "vulnerable to long-range weapons."
	),
	"Hero":
	(
		"Unique faction hero. One alive or in training per player; can retrain "
		+ "after death. Requires a command lab."
	),
	"Worker": "Harvest materials and electronics. Construct your base.",
	"Infantry":
	(
		"Inexpensive troops against infantry and light machines; weak against heavy armor. "
		+ "Capture relays and recover at barracks."
	),
	"Tank":
	(
		"Frontline armor with a ground-only cannon. Use infantry screens and repair support; "
		+ "aircraft require another weapon."
	),
	"AdvancedTank":
	(
		"12 m anti-armor railgun with a 0.75 s charge per shot. Ground targets only; protect "
		+ "it with a frontline screen."
	),
	"RepairRobot": "Repairs nearby allies while idle. Right-click an ally to follow and repair.",
	"CombatRobot":
	(
		"Autocannon against infantry and light machines; weaker against heavy armor. 8 m "
		+ "ground / 6.5 m anti-air, shared reload."
	),
	"Drone": "Unarmed reconnaissance with extended vision.",
	"Helicopter":
	(
		"Strike aircraft for ground raids and air combat. Avoid dedicated anti-air and "
		+ "return to an airfield for service."
	),
	"CommandCenter": "Produces engineer rovers. Receives harvested resources. Supplies 8 power.",
	"Barracks":
	(
		"Trains four infantry classes and a unique hero. Two infantry recovery "
		+ "slots within 5 m. Uses 3 power."
	),
	"VehicleFactory": "Produces armor and support robots. Uses 6 power.",
	"AircraftFactory":
	"Produces scouts and strike aircraft. Two aircraft service slots within 5 m. Uses 8 power.",
	"PowerPlant": "Supplies 12 power. Low power slows production and service buildings.",
	"CommandLab":
	(
		"With a vehicle factory, unlocks combat walkers and strike aircraft. "
		+ "Research Coordination for railgun tanks. Uses 5 power."
	),
	"RepairDepot":
	"Two ground repair slots within 5 m. Does not stack with other repairs. Uses 3 power.",
	"AntiGroundTurret":
	"Defensive cannon against ground targets; cannot engage aircraft. Uses 2 power.",
	"AntiAirTurret": "Missile defense against aircraft. Uses 2 power.",
}
const PRODUCES = {
	"CommandCenter": ["Worker"],
	"Barracks": INFANTRY_ROLES,
	"VehicleFactory": ["Tank", "RepairRobot", "CombatRobot", "AdvancedTank"],
	"AircraftFactory": ["Drone", "Helicopter"],
}
const STRUCTURES = [
	"CommandCenter",
	"Barracks",
	"VehicleFactory",
	"AircraftFactory",
	"PowerPlant",
	"CommandLab",
	"RepairDepot",
	"AntiGroundTurret",
	"AntiAirTurret"
]
const REQUIRES = {"Hero": "CommandLab", "AdvancedTank": "CommandLab", "CombatRobot": "CommandLab"}
const POWER_SUPPLY = {"CommandCenter": 8, "PowerPlant": 12}
const POWER_USAGE = {
	"Barracks": 3,
	"VehicleFactory": 6,
	"AircraftFactory": 8,
	"CommandLab": 5,
	"RepairDepot": 3,
	"AntiGroundTurret": 2,
	"AntiAirTurret": 2
}
const POPULATION_LIMIT = 100


static func scene_path(unit_type):
	return "res://source/match/units/%s.tscn" % unit_type


static func is_infantry(role):
	return role in INFANTRY_ROLES


static func icon_path(unit_type):
	if unit_type in INFANTRY_ROLES:
		return "res://assets/ui/infantry/bastion/%s.png" % unit_type
	if unit_type in STRUCTURES:
		return "res://assets/ui/bastion/structures-v2/%s.png" % unit_type
	return "res://assets/ui/bastion/%s.png" % unit_type


static func type_from_path(path):
	return path.get_file().get_basename()


static func requirement_met(player, unit_type):
	return not REQUIRES.has(unit_type) or player.has_completed_structure(REQUIRES[unit_type])

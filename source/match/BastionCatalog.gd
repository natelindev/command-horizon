extends RefCounted

const Mercenaries = preload("res://source/match/world/MercenaryCatalog.gd")

const STRUCTURE_LIMIT = 40
const INFANTRY_ROLES = ["Infantry", "RocketInfantry", "SniperInfantry", "AssaultInfantry", "Hero"]
const GARRISON_CAPACITY = 8
const ROTORCRAFT_ROLES = ["Drone", "Helicopter"]
const FIXED_WING_ROLES = ["Fighter", "Bomber"]
const AIRCRAFT_ROLES = ROTORCRAFT_ROLES + FIXED_WING_ROLES

const MISSION_NAMES = {"SupplyTruck": "Supply truck"}

const NAMES = {
	"MercenaryWarden": "Iron Warden",
	"MercenaryRanger": "Dust Ranger",
	"MercenaryLancer": "Breach Lancer",
	"RocketInfantry": "Anti-armor infantry",
	"SniperInfantry": "Sniper",
	"AssaultInfantry": "Assault infantry",
	"Hero": "Marshal Aegis",
	"Worker": "Mule Hauler",
	"Infantry": "Rifle infantry",
	"Tank": "Bastion tank",
	"AdvancedTank": "Siege Colossus",
	"RepairRobot": "Repair robot",
	"CombatRobot": "Bulwark Walker",
	"Drone": "Strike drone",
	"Helicopter": "Attack helicopter",
	"Fighter": "Interceptor jet",
	"Bomber": "Heavy bomber",
	"AntiAirVehicle": "Flak Halftrack",
	"ForwardRefinery": "Forward refinery",
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
	"AntiAirVehicle":
	(
		"Proximity flak halftrack. Bursts leave aerial denial clouds that damage clustered "
		+ "aircraft for 2 seconds. Escort it with tanks and infantry."
	),
	"Fighter":
	(
		"Multirole jet. Guided missiles deal full damage to air and ground targets; "
		+ "close-range cannon support. Lands at its airfield to rearm."
	),
	"Bomber":
	(
		"Heavy level bomber. High bomb damage, doubled against buildings. "
		+ "One stick per sortie; needs fighter escort."
	),
	"RocketInfantry":
	(
		"Shoulder-launched rockets break heavy armor and structures; guided missiles lock onto "
		+ "aircraft. Slow reload, weak against infantry."
	),
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
	"Worker": "Armored bulk hauler. Collect eight materials per load, construct and repair structures; self-repairs when idle.",
	"Infantry":
	(
		"Inexpensive troops against infantry and light machines; weak against heavy armor. "
		+ "Capture relays and recover at barracks."
	),
	"Tank":
	(
		"Heavy frontline armor with thick composite plating and a 105 mm cannon. "
		+ "Serves as the durable anchor of your ground forces."
	),
	"AdvancedTank":
	(
		"Deploy hydraulic anchors for 2 seconds to fire a 155 mm siege cannon. "
		+ "16 m range with wide explosive splash. Moving retracts the anchors and disables fire."
	),
	"RepairRobot": "Repairs nearby allies while idle. Right-click an ally to follow and repair.",
	"CombatRobot":
	(
		"Armored walker carrying a frontal kinetic shield. Intercepts direct-fire rounds "
		+ "in a 60-degree forward arc, sheltering infantry advancing behind it."
	),
	"Drone":
	(
		"Expendable loitering munition. Scouts while hovering; an attack order sends it "
		+ "diving into a vehicle or structure as its own warhead. Holds fire by default."
	),
	"Helicopter":
	(
		"Attack helicopter. Rockets against ground forces while hovering in place; reloads on "
		+ "cooldown in the field. Vulnerable to rocket infantry and anti-air."
	),
	"ForwardRefinery": "Forward materials drop-off. Build near ore to shorten Mule Hauler delivery routes.",
	"CommandCenter": "Produces Mule Haulers. Receives harvested resources. Supplies 8 power.",
	"Barracks":
	(
		"Trains four infantry classes and a unique hero. Two infantry recovery "
		+ "slots within 5 m. Uses 3 power."
	),
	"VehicleFactory": "Produces armor and support robots. Uses 6 power.",
	"AircraftFactory":
	(
		"Runway airfield. Builds drones, helicopters, fighters and bombers; jets park, rearm "
		+ "and repair on 4 stands, rotorcraft on 2 helipads. Uses 8 power."
	),
	"PowerPlant": "Supplies 12 power. Low power slows production and service buildings.",
	"CommandLab":
	(
		"With a vehicle factory, unlocks combat walkers and strike aircraft. "
		+ "Research Coordination for Siege Colossi. Uses 5 power."
	),
	"RepairDepot":
	"Two ground repair slots within 5 m. Does not stack with other repairs. Uses 3 power.",
	"AntiGroundTurret":
	"Defensive cannon against ground targets; cannot engage aircraft. Uses 2 power.",
	"AntiAirTurret":
	(
		"Missile air defense that prioritizes aircraft. Ground damage: 33% "
		+ "Uses 2 power."
	),
}
const PRODUCES = {
	"CommandCenter": ["Worker"],
	"Barracks": INFANTRY_ROLES,
	"VehicleFactory": ["Tank", "AntiAirVehicle", "RepairRobot", "CombatRobot", "AdvancedTank"],
	"AircraftFactory": ["Drone", "Helicopter", "Fighter", "Bomber"],
}
const STRUCTURES = [
	"ForwardRefinery",
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
const REQUIRES = {
	"Hero": "CommandLab",
	"AdvancedTank": "CommandLab",
	"CombatRobot": "CommandLab",
	"Fighter": "CommandLab",
	"Bomber": "CommandLab",
}
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
	return role in INFANTRY_ROLES or role in Mercenaries.ROLES


static func is_aircraft(role):
	return role in AIRCRAFT_ROLES


static func is_fixed_wing(role):
	return role in FIXED_WING_ROLES


static func icon_path(unit_type):
	if unit_type in ["AdvancedTank", "CombatRobot", "AntiAirVehicle"]:
		return "res://assets/ui/bastion/%s.png" % {"AdvancedTank":"SiegeColossus", "CombatRobot":"BulwarkWalker", "AntiAirVehicle":"FlakHalftrack"}[unit_type]
	if unit_type in INFANTRY_ROLES:
		return "res://assets/ui/infantry/bastion/%s.png" % unit_type
	if unit_type in STRUCTURES:
		return "res://assets/ui/bastion/structures-v2/%s.png" % unit_type
	return "res://assets/ui/bastion/%s.png" % unit_type


static func type_from_path(path):
	var filename = path.get_file().get_basename()
	return {
		"SiegeColossus": "AdvancedTank", "PrismSkimmer": "AdvancedTank", "BattleRig": "AdvancedTank",
		"BulwarkWalker": "CombatRobot", "PhaseLancer": "CombatRobot", "DemolitionBuggy": "CombatRobot",
		"FlakHalftrack": "AntiAirVehicle", "SkywardInterceptor": "AntiAirVehicle", "SAMTechnical": "AntiAirVehicle",
	}.get(filename, filename)


static func requirement_met(player, unit_type):
	return not REQUIRES.has(unit_type) or player.has_completed_structure(REQUIRES[unit_type])

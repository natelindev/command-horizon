extends RefCounted

const MODELS = {
	"Worker": "ScrapperRig",
	"Infantry": "RidgeRanger",
	"Tank": "Outrider",
	"RepairRobot": "PatchCrawler",
	"CombatRobot": "JackalRig",
	"AdvancedTank": "Ironback",
	"Drone": "LookoutDrone",
	"Helicopter": "KestrelGunship",
	"Fighter": "HornetFighter",
	"Bomber": "BuzzardBomber",
	"AntiAirVehicle": "RipsawTruck",
	"CommandCenter": "ConvoyHQ",
	"Barracks": "RangerCamp",
	"VehicleFactory": "MotorPool",
	"AircraftFactory": "RotorPad",
	"PowerPlant": "DieselArray",
	"CommandLab": "RelayWorkshop",
	"RepairDepot": "FieldWorkshop",
	"AntiGroundTurret": "RoadblockGun",
	"AntiAirTurret": "WatchtowerAA",
}
const NAMES = {
	"Worker": "Scrapper rig",
	"Infantry": "Ridge ranger",
	"Tank": "Outrider",
	"RepairRobot": "Patch crawler",
	"CombatRobot": "Jackal rig",
	"AdvancedTank": "Ironback",
	"Drone": "Lookout drone",
	"Helicopter": "Kestrel gunship",
	"Fighter": "Hornet fighter",
	"Bomber": "Buzzard bomber",
	"AntiAirVehicle": "Ripsaw AA truck",
	"CommandCenter": "Convoy HQ",
	"Barracks": "Ranger camp",
	"VehicleFactory": "Motor pool",
	"AircraftFactory": "Bush airstrip",
	"PowerPlant": "Diesel array",
	"CommandLab": "Relay workshop",
	"RepairDepot": "Field workshop",
	"AntiGroundTurret": "Roadblock gun",
	"AntiAirTurret": "Watchtower AA",
}
const COSTS = {
	"Hero": [48, 24],
	"AssaultInfantry": [10, 2],
	"SniperInfantry": [12, 6],
	"RocketInfantry": [12, 4],
	"Worker": [6, 0],
	"Infantry": [5, 0],
	"Tank": [20, 4],
	"RepairRobot": [14, 4],
	"CombatRobot": [22, 8],
	"AdvancedTank": [34, 14],
	"Drone": [7, 4],
	"Helicopter": [28, 12],
	"Fighter": [26, 14],
	"Bomber": [38, 16],
	"AntiAirVehicle": [18, 6],
}
const DESCRIPTIONS = {
	"RepairRobot": "Field repair support. Services damaged ground machines.",
	"Worker":
	(
		"Unarmed engineer. Harvest fields, construct buildings and recover "
		+ "20% of a ground machine’s material cost from its wreck within 3 "
		+ "minutes. Deliver cargo to HQ."
	),
	"Infantry":
	(
		"Fast field infantry against infantry and light machines. Capture "
		+ "relays; recover at a ranger camp. Weak against armor."
	),
	"Tank": "Mobile, lightly protected ground cannon. Use flanks and withdraw for repairs.",
	"CombatRobot":
	(
		"Shielded autocannon against infantry and light machines. "
		+ "Short-range anti-air shares its reload. Avoid heavy armor."
	),
	"AdvancedTank":
	(
		"12 m heavy cannon against armor. Fires without a preparation "
		+ "charge; lighter protection demands scouting and repair support."
	),
	"Drone":
	(
		"Expendable loitering munition. Scouts while hovering; an attack order sends it "
		+ "diving into a vehicle or structure as its own warhead. Holds fire by default."
	),
	"Helicopter":
	(
		"Attack helicopter. Rockets against ground forces while hovering in place; lands on "
		+ "an airfield helipad to rearm. Vulnerable to rocket infantry and anti-air."
	),
	"CommandCenter":
	"Produces scrapper rigs, accepts harvested and salvaged materials, and supplies 8 power.",
	"Barracks":
	(
		"Trains four infantry classes and a unique hero. Two infantry recovery "
		+ "slots within 5 m. Uses 3 power."
	),
	"VehicleFactory": "Produces refurbished armor and service rigs. Uses 6 power.",
	"AircraftFactory":
	(
		"Runway airfield. Builds drones, helicopters, fighters and bombers; jets park, rearm "
		+ "and repair on 4 stands, rotorcraft on 2 helipads. Uses 8 power."
	),
	"CommandLab":
	(
		"Unlocks heroes and Kestrels. Research Coordination for Maneuver Burst. "
		+ "Jackals need a motor pool; Ironbacks need a field workshop. Uses 5 power."
	),
	"PowerPlant": "Supplies 12 power to keep production and research running.",
	"RepairDepot": "Unlocks Ironbacks without Coordination. Repairs ground machines. Uses 3 power.",
	"AntiGroundTurret": "Fixed ground cannon; protect against infantry and aircraft. Uses 2 power.",
	"AntiAirTurret":
	(
		"Dedicated air defense that prioritizes aircraft. Ground damage: 33% "
		+ "(100% with Dual-purpose AA). Uses 2 power."
	),
}

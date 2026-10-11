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
	"CommandCenter": "Convoy HQ",
	"Barracks": "Ranger camp",
	"VehicleFactory": "Motor pool",
	"AircraftFactory": "Rotor pad",
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
	"RepairRobot": [14, 6],
	"CombatRobot": [22, 12],
	"AdvancedTank": [34, 18],
	"Drone": [7, 4],
	"Helicopter": [28, 16],
}
const DESCRIPTIONS = {
	"RepairRobot": "Field repair support. Built-in program chip; service damaged ground machines.",
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
	"Tank":
	(
		"Mobile, lightly protected ground cannon. Retrofit at HQ or "
		+ "workshop for 2 E / 3 s. Use flanks and withdraw for repairs."
	),
	"CombatRobot":
	(
		"Shielded autocannon against infantry and light machines. "
		+ "Short-range anti-air shares its reload. Avoid heavy armor."
	),
	"AdvancedTank":
	(
		"8 m heavy cannon against armor. Fires without a preparation "
		+ "charge; lighter protection demands scouting and repair support."
	),
	"Drone":
	(
		"Unarmed quadrotor with extended vision. Scout flanks and wreck "
		+ "sites before committing engineers."
	),
	"Helicopter":
	(
		"Mobile strike rotorcraft against ground and air targets. Avoid "
		+ "anti-air; return to a rotor pad for service."
	),
	"CommandCenter":
	"Produces scrapper rigs, accepts harvested and salvaged materials, and supplies 20 power.",
	"Barracks":
	"Trains four infantry classes and a unique hero. Two infantry recovery slots within 5 m. Uses 3 power.",
	"VehicleFactory":
	(
		"Produces refurbished armor and service rigs. Fit chips to new "
		+ "Outriders for +2 E / +3 s. Uses 6 power."
	),
	"AircraftFactory":
	"Produces scouts and strike rotorcraft. Two aircraft service slots within 5 m. Uses 8 power.",
	"CommandLab":
	(
		"With a motor pool, unlocks programs, Jackals and Kestrels. "
		+ "Research Coordination for Ironbacks and Maneuver Burst. Uses 5 "
		+ "power."
	),
	"PowerPlant": "Supplies 25 power to keep production and research running.",
	"RepairDepot":
	"Repairs mechanical ground units and fits vehicle chips for 2 E / 3 s. Uses 3 power.",
	"AntiGroundTurret": "Fixed ground cannon; protect against infantry and aircraft. Uses 2 power.",
	"AntiAirTurret": "Dedicated air defense. Cannot fire at ground targets. Uses 2 power.",
}

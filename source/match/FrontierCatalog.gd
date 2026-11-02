extends RefCounted

const MODELS = {
	"Worker": "ScrapperRig",
	"Infantry": "RidgeRanger",
	"Tank": "Outrider",
	"RepairRobot": "PatchCrawler",
	"CombatRobot": "DemolitionBuggy",
	"AdvancedTank": "BattleRig",
	"Drone": "LookoutDrone",
	"Helicopter": "KestrelGunship",
	"Fighter": "HornetFighter",
	"Bomber": "BuzzardBomber",
	"AntiAirVehicle": "SAMTechnical",
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
	"AssaultInfantry": "Scrap vanguard",
	"RocketInfantry": "Tank hunter",
	"SniperInfantry": "Frontier marksman",
	"Tank": "Outrider",
	"RepairRobot": "Patch crawler",
	"CombatRobot": "Demolition Buggy",
	"AdvancedTank": "Battle Rig",
	"Drone": "Lookout drone",
	"Helicopter": "Kestrel gunship",
	"Fighter": "Hornet fighter",
	"Bomber": "Buzzard bomber",
	"AntiAirVehicle": "SAM Technical",
	"CommandCenter": "Convoy HQ",
	"Barracks": "Ranger camp",
	"VehicleFactory": "Motor pool",
	"AircraftFactory": "Bush airstrip",
	"PowerPlant": "Diesel array",
	"CommandLab": "Scrap Yard",
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
	"AntiAirVehicle": "Fast SAM technical firing high-velocity unguided rocket swarms. Deadly against low aircraft from ambush.",
	"RepairRobot": "Field repair support. Services damaged ground machines.",
	"Worker":
	(
		"Armed scrapper with a 20 mm defensive cannon. Harvest fields, construct buildings and recover "
		+ "35% of a ground machine’s material cost from its wreck within 3 "
		+ "minutes. Dismantle wrecks into materials on-site."
	),
	"Infantry":
	(
		"Fast guerrilla infantry against infantry and light machines. Capture "
		+ "relays; recover at a ranger camp. Weak against armor."
	),
	"AssaultInfantry":
	(
		"Aggressive wasteland raider armed with a trench shotgun. Rapid close-range "
		+ "shrapnel bursts; uses Adrenaline sprint."
	),
	"RocketInfantry":
	(
		"Mobile anti-tank hunter armed with scavenged heavy RPGs to break enemy armor. "
		+ "Fires Guided Salvo rockets."
	),
	"SniperInfantry":
	(
		"Frontier tracker with a heavy scoped hunting rifle. Long-range precision "
		+ "fire against infantry."
	),
	"Tank": "Fast wheeled technical with twin autocannons. Flank enemy armor and screen lines.",
	"CombatRobot":
	(
		"Fast demolition buggy packed with volatile munitions. Charges a ground target "
		+ "and detonates on contact, devastating structures and tightly packed columns."
	),
	"AdvancedTank":
	(
		"Armored flatbed with twin forward autocannons and four infantry firing ports. "
		+ "Passengers remain protected inside and fire while moving. Select infantry and "
		+ "right-click the Battle Rig to board; use Unload infantry to disembark."
	),
	"Drone":
	(
		"Expendable loitering munition. Scouts while hovering; an attack order sends it "
		+ "diving into a vehicle or structure as its own warhead. Holds fire by default."
	),
	"Helicopter":
	(
		"Mercenary rocket helicopter hired through the Scrap Yard's Black Market. "
		+ "One loaded sortie; departs when its rockets or 90-second fuel supply runs out."
	),
	"Fighter": "Light mercenary fighter hired through the Black Market. Nose-mounted cannon and missiles; one finite-ammunition, 90-second sortie without an airfield.",
	"Bomber": "Improvised mercenary bomber hired through the Black Market. One fuel-air bombing sortie, then departs; no on-map rearming.",
	"CommandCenter":
	"Produces scrapper rigs, accepts harvested and salvaged materials, and supplies 8 power.",
	"Barracks":
	(
		"Trains militia in triplets and specialists in pairs, plus a unique hero. Two infantry recovery "
		+ "slots within 5 m. Uses 2 power."
	),
	"VehicleFactory": "Builds Outrider pairs, demolition buggies, mobile Battle Rigs and Lookout drones. Uses little power.",
	"AircraftFactory":
	(
		"Runway airfield. Builds drones, helicopters, fighters and bombers; jets park, rearm "
		+ "and repair on 4 stands, rotorcraft on 2 helipads. Uses 8 power."
	),
	"CommandLab":
	(
		"Hosts faction research, heroes and the Black Market. Exchange resources or hire "
		+ "Kestrel, Hornet and Buzzard sorties without an airfield. Uses 3 power."
	),
	"PowerPlant": "Supplies 12 power to keep production and research running.",
	"RepairDepot": "Unlocks Battle Rigs without Coordination. Repairs ground machines. Uses 2 power.",
	"AntiGroundTurret": "Fixed ground cannon; protect against infantry and aircraft. Uses 1 power.",
	"AntiAirTurret":
	(
		"Dedicated air defense that prioritizes aircraft. Ground damage: 33% "
		+ "Uses 1 power."
	),
}

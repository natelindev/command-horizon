extends RefCounted

# Pure values shared with inert archive validation. No autoload or scene dependencies.
const Frontier = preload("res://source/match/FrontierCatalog.gd")
const Bastion = preload("res://source/match/BastionCatalog.gd")
const UNIT_COSTS = {
	"Hero": [48, 24],
	"AssaultInfantry": [10, 2],
	"SniperInfantry": [12, 6],
	"RocketInfantry": [12, 4],
	"Worker": [6, 0],
	"CrackRig": [28, 0],
	"Infantry": [6, 0],
	"Tank": [24, 6],
	"RepairRobot": [16, 6],
	"CombatRobot": [24, 12],
	"AdvancedTank": [40, 18],
	"Drone": [8, 4],
	"Helicopter": [32, 14],
	"Fighter": [30, 16],
	"Bomber": [42, 18],
	"AntiAirVehicle": [22, 8],
}
const HELIX_COSTS = {
	"Hero": [48, 24],
	"AssaultInfantry": [10, 2],
	"SniperInfantry": [12, 6],
	"RocketInfantry": [12, 4],
	"Worker": [6, 0],
	"CrackRig": [28, 0],
	"Infantry": [6, 0],
	"Tank": [22, 10],
	"RepairRobot": [14, 8],
	"CombatRobot": [26, 14],
	"AdvancedTank": [36, 22],
	"Drone": [8, 6],
	"Helicopter": [28, 18],
	"Fighter": [28, 20],
	"Bomber": [40, 22],
	"AntiAirVehicle": [20, 12],
}
const IDS = ["bastion", "helix", "frontier"]
const NAMES = {
	"bastion": "Bastion Directorate",
	"helix": "Helix Systems",
	"frontier": "Free Frontier Coalition"
}


# Frontier trades rough, salvaged aircraft for hardened Barracks infantry.
static func health_factor(faction, role = ""):
	if faction == "frontier":
		if role in Bastion.INFANTRY_ROLES:
			return 1.1
		if Bastion.is_aircraft(role):
			return 0.7
	return {"helix": 0.45, "frontier": 0.85}.get(faction, 1.0)


static func damage_factor(faction, role):
	if faction == "frontier":
		if role in Bastion.INFANTRY_ROLES:
			return 1.15
		if Bastion.is_aircraft(role):
			return 0.8
	return 1.0


static func signature_title(faction):
	return (
		{"bastion": "Anchor sector", "helix": "Precision window", "frontier": "Maneuver burst"}
		. get(faction, "")
	)


static func signature_cooldown(faction):
	return {"bastion": 10.0, "helix": 8.0, "frontier": 25.0}.get(faction, 0.0)


static func unit_costs(faction):
	return (
		Frontier.COSTS
		if faction == "frontier"
		else (HELIX_COSTS if faction == "helix" else UNIT_COSTS)
	)

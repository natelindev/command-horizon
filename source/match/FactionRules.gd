extends RefCounted

# Pure values shared with inert archive validation. No autoload or scene dependencies.
const Frontier = preload("res://source/match/FrontierCatalog.gd")
const UNIT_COSTS = {
	"Worker": [6, 0],
	"Infantry": [6, 0],
	"Tank": [24, 6],
	"RepairRobot": [16, 8],
	"CombatRobot": [24, 16],
	"AdvancedTank": [40, 24],
	"Drone": [8, 4],
	"Helicopter": [32, 20],
}
const HELIX_COSTS = {
	"Worker": [6, 0],
	"Infantry": [6, 0],
	"Tank": [22, 10],
	"RepairRobot": [14, 12],
	"CombatRobot": [26, 20],
	"AdvancedTank": [36, 30],
	"Drone": [8, 6],
	"Helicopter": [28, 24],
}
const IDS = ["bastion", "helix", "frontier"]
const NAMES = {
	"bastion": "Bastion Directorate",
	"helix": "Helix Systems",
	"frontier": "Free Frontier Coalition"
}


static func chip_cost(faction):
	return 2 if faction == "frontier" else 4


static func chip_seconds(faction):
	return 3.0 if faction == "frontier" else 5.0


static func health_factor(faction):
	return {"helix": 0.8, "frontier": 0.85}.get(faction, 1.0)


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

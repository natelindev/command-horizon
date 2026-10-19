extends RefCounted

# Pure values shared with inert archive validation. No autoload or scene dependencies.
const Frontier = preload("res://source/match/FrontierCatalog.gd")
const UNIT_COSTS = {
	"Hero": [48, 24],
	"AssaultInfantry": [10, 2],
	"SniperInfantry": [12, 6],
	"RocketInfantry": [12, 4],
	"Worker": [6, 0],
	"Infantry": [6, 0],
	"Tank": [24, 6],
	"RepairRobot": [16, 6],
	"CombatRobot": [24, 12],
	"AdvancedTank": [40, 18],
	"Drone": [8, 4],
	"Helicopter": [32, 14],
}
const HELIX_COSTS = {
	"Hero": [48, 24],
	"AssaultInfantry": [10, 2],
	"SniperInfantry": [12, 6],
	"RocketInfantry": [12, 4],
	"Worker": [6, 0],
	"Infantry": [6, 0],
	"Tank": [22, 10],
	"RepairRobot": [14, 8],
	"CombatRobot": [26, 14],
	"AdvancedTank": [36, 22],
	"Drone": [8, 6],
	"Helicopter": [28, 18],
}
# Archives may contain contracts bought before the pacing rebalance. Their paid
# remaining time stays valid; newly purchased contracts use current durations.
const ARCHIVE_PRODUCTION_LIMITS = {
	"MercenaryWarden": 14.0,
	"MercenaryRanger": 15.0,
	"MercenaryLancer": 18.0,
	"Hero": 40.0,
	"AssaultInfantry": 12.0,
	"SniperInfantry": 16.0,
	"RocketInfantry": 14.0,
	"Worker": 8.0,
	"Infantry": 8.0,
	"Tank": 20.0,
	"RepairRobot": 18.0,
	"CombatRobot": 24.0,
	"AdvancedTank": 32.0,
	"Drone": 12.0,
	"Helicopter": 28.0,
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

extends RefCounted

# Pure save-validation data; loading this must never instantiate a scene or autoload.
const Factions = preload("res://source/match/FactionRules.gd")
const ROLES = [
	"Worker",
	"CrackRig",
	"Tank",
	"AntiAirVehicle",
	"RepairRobot",
	"CombatRobot",
	"AdvancedTank",
	"Drone",
	"Helicopter",
	"Fighter",
	"Bomber"
]
const LIFETIME = 180.0
const LIMIT = 128
const REFINED_SHARE = 0.40


static func amount(faction, role):
	return floori(Factions.unit_costs(faction)[role][0] * .35) if role in ROLES else 0


static func refined_amount(faction, role) -> int:
	if role not in ROLES:
		return 0
	var cost = Factions.unit_costs(faction).get(role, [0, 0])
	return floori(cost[1] * REFINED_SHARE) if cost[1] > 0 else 0

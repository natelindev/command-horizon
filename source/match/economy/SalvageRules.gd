extends RefCounted

# Pure save-validation data; loading this must never instantiate a scene or autoload.
const Factions = preload("res://source/match/FactionRules.gd")
const ROLES = ["Worker", "Tank", "RepairRobot", "CombatRobot", "AdvancedTank"]
const LIFETIME = 180.0
const LIMIT = 128


static func amount(faction, role):
	return floori(Factions.unit_costs(faction)[role][0] * .2) if role in ROLES else 0

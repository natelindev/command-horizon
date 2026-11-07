extends RefCounted

## Model names are faction aliases; gameplay roles alone cannot identify a hovercraft.
const VEHICLES = [
	"Tank",
	"AdvancedTank",
	"AntiAirVehicle",
	"CombatRobot",
	"Worker",
	"SupplyTruck",
	"DemolitionBuggy",
	"FlakHalftrack",
	"SAMTechnical",
	"BattleRig",
	"RepairRobot"
]
const WHEELED = [
	"Worker", "SupplyTruck", "DemolitionBuggy", "FlakHalftrack", "SAMTechnical", "BattleRig"
]


static func is_hover(unit) -> bool:
	if unit.has_method("is_flux_skimmer") and unit.is_flux_skimmer():
		return true
	return (
		unit.player != null
		and unit.player.faction == "helix"
		and unit.type in ["Worker", "Tank", "AdvancedTank", "AntiAirVehicle"]
	)


static func wheeled(unit) -> bool:
	if is_hover(unit):
		return false
	return (
		unit.type in WHEELED
		or (
			unit.player != null
			and unit.player.faction == "frontier"
			and unit.type in ["Tank", "AdvancedTank", "AntiAirVehicle"]
		)
	)


static func leaves_marks(unit) -> bool:
	return unit.type in VEHICLES and not is_hover(unit)

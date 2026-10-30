extends RefCounted

const Factions = preload("res://source/match/FactionCatalog.gd")

const COUNTERS = {
	"Infantry":
	{
		"role_label": "Light Line Infantry",
		"strong_against": ["Worker", "SupplyTruck", "SniperInfantry"],
		"countered_by": ["Tank", "CombatRobot", "AssaultInfantry", "MercenaryWarden"],
		"notes": "Point capture and screen; vulnerable to armor and high-rate-of-fire weapons."
	},
	"AssaultInfantry":
	{
		"role_label": "Close-Quarters Shock Troops",
		"strong_against": ["Infantry", "SniperInfantry", "Worker"],
		"countered_by": ["Tank", "CombatRobot", "Helicopter", "MercenaryWarden"],
		"notes": "Close-range burst and sprint; vulnerable to armor, kiting, and air."
	},
	"RocketInfantry":
	{
		"role_label": "Anti-Armor & Air Defense",
		"strong_against": ["Tank", "AdvancedTank", "Helicopter", "AntiAirVehicle"],
		"countered_by": ["SniperInfantry", "Infantry", "CombatRobot", "MercenaryRanger"],
		"notes": "Piercing rockets and SAM tracking; vulnerable to snipers and swarms."
	},
	"SniperInfantry":
	{
		"role_label": "Long-Range Precision Marksman",
		"strong_against": ["RocketInfantry", "Infantry", "Worker"],
		"countered_by": ["Tank", "AssaultInfantry", "Helicopter", "MercenaryWarden"],
		"notes": "Extreme range and vision against unarmored targets; vulnerable to armor."
	},
	"Tank":
	{
		"role_label": "Main Battle Armor",
		"strong_against": ["Infantry", "AssaultInfantry", "SniperInfantry", "CombatRobot"],
		"countered_by": ["RocketInfantry", "AdvancedTank", "Helicopter", "MercenaryLancer"],
		"notes": "Durable frontline anchor; cannot engage air and weak to piercing rockets."
	},
	"AdvancedTank":
	{
		"role_label": "Long-Range Siege & Tank Destroyer",
		"strong_against": ["Tank", "AntiAirVehicle", "AntiGroundTurret"],
		"countered_by": ["Helicopter", "Bomber", "AssaultInfantry", "MercenaryLancer"],
		"notes": "Outranges turrets and punches heavy armor; vulnerable to air and flankers."
	},
	"CombatRobot":
	{
		"role_label": "Mobile Fire Support Walker",
		"strong_against": ["Infantry", "AssaultInfantry", "Drone", "SupplyTruck"],
		"countered_by": ["Tank", "RocketInfantry", "AdvancedTank", "Bomber"],
		"notes": "Autocannon shreds light machines and infantry; vulnerable to tanks."
	},
	"AntiAirVehicle":
	{
		"role_label": "Mobile Anti-Air Flak",
		"strong_against": ["Drone", "Helicopter", "Bomber", "Fighter"],
		"countered_by": ["Tank", "AdvancedTank", "RocketInfantry"],
		"notes": "Rapid flak shreds aircraft; weak against ground armor and heavy weapons."
	},
	"Drone":
	{
		"role_label": "Light Reconnaissance Drone",
		"strong_against": ["Worker", "SupplyTruck"],
		"countered_by": ["AntiAirVehicle", "CombatRobot", "Fighter", "RocketInfantry"],
		"notes": "Inexpensive aerial scout; fragile and easily shot down by anti-air."
	},
	"Helicopter":
	{
		"role_label": "Ground-Attack Gunship",
		"strong_against": ["Tank", "AdvancedTank", "SniperInfantry", "Worker"],
		"countered_by": ["AntiAirVehicle", "Fighter", "AntiAirTurret", "RocketInfantry"],
		"notes": "Mobile aerial missile strikes against ground targets; vulnerable to AA."
	},
	"Fighter":
	{
		"role_label": "Air Superiority Interceptor",
		"strong_against": ["Helicopter", "Bomber", "Drone"],
		"countered_by": ["AntiAirVehicle", "AntiAirTurret", "RocketInfantry"],
		"notes": "Fast dogfighter intercepting hostile aircraft; cannot attack ground."
	},
	"Bomber":
	{
		"role_label": "Heavy Demolition Bomber",
		"strong_against": ["AntiGroundTurret", "CommandCenter", "Barracks", "VehicleFactory"],
		"countered_by": ["Fighter", "AntiAirVehicle", "AntiAirTurret"],
		"notes": "Demolishes enemy structures; vulnerable to air superiority fighters."
	},
	"RepairRobot":
	{
		"role_label": "Field Maintenance & Repair",
		"strong_against": [],
		"countered_by": ["Tank", "CombatRobot", "SniperInfantry"],
		"notes": "Repairs friendly vehicles and buildings; unarmed."
	},
	"Worker":
	{
		"role_label": "Engineering & Resource Extraction",
		"strong_against": [],
		"countered_by": ["Infantry", "Tank", "Drone"],
		"notes": "Constructs bases and harvests materials; unarmed."
	},
	"Hero":
	{
		"role_label": "Tactical Field Commander",
		"strong_against": ["Infantry", "CombatRobot", "Tank"],
		"countered_by": ["AdvancedTank", "SniperInfantry", "RocketInfantry"],
		"notes": "Powerful frontline leader with abilities; focus with anti-armor fire."
	},
	"MercenaryWarden":
	{
		"role_label": "Heavy Ballistic Breacher",
		"strong_against": ["Infantry", "AssaultInfantry", "CombatRobot"],
		"countered_by": ["Tank", "SniperInfantry", "Helicopter", "AdvancedTank"],
		"notes": "Shield and shotgun hold chokepoints; vulnerable to armor and range."
	},
	"MercenaryRanger":
	{
		"role_label": "Spotter & Anti-Infantry Scout",
		"strong_against": ["SniperInfantry", "RocketInfantry", "Worker"],
		"countered_by": ["Tank", "AssaultInfantry", "Helicopter", "MercenaryWarden"],
		"notes": "Illumination flare and 18 m sight; fragile and weak to heavy armor."
	},
	"MercenaryLancer":
	{
		"role_label": "EMP Demolition Specialist",
		"strong_against": ["Tank", "AdvancedTank", "AntiGroundTurret"],
		"countered_by": ["SniperInfantry", "Infantry", "CombatRobot", "AssaultInfantry"],
		"notes": "EMP disruptor disables heavy vehicles; slow fire against swarms."
	},
	"AntiGroundTurret":
	{
		"role_label": "Defensive Ground Battery",
		"strong_against": ["Tank", "Infantry", "CombatRobot"],
		"countered_by": ["AdvancedTank", "Bomber", "Helicopter"],
		"notes": "Fortified cannon defends chokepoints; outranged by siege artillery."
	},
	"AntiAirTurret":
	{
		"role_label": "Defensive Missile Battery",
		"strong_against": ["Helicopter", "Bomber", "Drone", "Fighter"],
		"countered_by": ["Tank", "AdvancedTank", "RocketInfantry"],
		"notes": "Heavy surface-to-air missiles protect base airspace; ground blind."
	},
}


static func role_label(role: String) -> String:
	return COUNTERS.get(role, {}).get("role_label", "")


static func strong_against(role: String) -> Array:
	return COUNTERS.get(role, {}).get("strong_against", [])


static func countered_by(role: String) -> Array:
	return COUNTERS.get(role, {}).get("countered_by", [])


static func counters_for(role: String) -> Array:
	return countered_by(role)


static func _title(target_role: String, faction: String) -> String:
	if target_role.is_empty():
		return ""
	if faction.is_empty():
		return Factions.title("bastion", target_role)
	return Factions.title(faction, target_role)


static func format_tooltip(role: String, faction: String = "") -> String:
	if not COUNTERS.has(role):
		return ""
	var entry = COUNTERS[role]
	var strong: Array = entry.get("strong_against", [])
	var weak: Array = entry.get("countered_by", [])
	var lines = PackedStringArray()
	if not strong.is_empty():
		var names = strong.map(func(r): return TranslationServer.translate(_title(r, faction)))
		lines.append(TranslationServer.translate("Strong vs: %s") % ", ".join(names))
	if not weak.is_empty():
		var names = weak.map(func(r): return TranslationServer.translate(_title(r, faction)))
		lines.append(TranslationServer.translate("Countered by: %s") % ", ".join(names))
	return "\n".join(lines)


static func format_facts(role: String, faction: String = "") -> Array:
	if not COUNTERS.has(role):
		return []
	var entry = COUNTERS[role]
	var facts = []
	var label: String = entry.get("role_label", "")
	if not label.is_empty():
		facts.append(TranslationServer.translate("Role: %s") % TranslationServer.translate(label))
	var strong: Array = entry.get("strong_against", [])
	if not strong.is_empty():
		var names = strong.map(func(r): return TranslationServer.translate(_title(r, faction)))
		facts.append(TranslationServer.translate("Strong vs: %s") % ", ".join(names))
	var weak: Array = entry.get("countered_by", [])
	if not weak.is_empty():
		var names = weak.map(func(r): return TranslationServer.translate(_title(r, faction)))
		facts.append(TranslationServer.translate("Countered by: %s") % ", ".join(names))
	return facts

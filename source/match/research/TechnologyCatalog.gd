extends RefCounted

const COMBAT_ROLES = [
	"MercenaryWarden",
	"MercenaryRanger",
	"MercenaryLancer",
	"Infantry",
	"RocketInfantry",
	"SniperInfantry",
	"AssaultInfantry",
	"Hero",
	"Tank",
	"CombatRobot",
	"AdvancedTank",
	"Helicopter"
]

const AA_GROUND_DAMAGE_FACTOR = 0.33
const COORDINATION_COST = {"resource_a": 20, "resource_b": 20}
const COORDINATION_DURATION = 30.0
# Historical mirrored research remains readable only for archived snapshots.
# New matches expose these faction-specific branches and exclusive doctrines.
const BRANCHES = [
	"reactive_armor",
	"tandem_rockets",
	"siege_logistics",
	"bunker_reinforcements",
	"fortress_doctrine",
	"iron_blitz",
	"plasma_shields",
	"beam_amplification",
	"flux_capacitors",
	"phase_thrusters",
	"phase_overload",
	"continuous_coherence",
	"scrap_cannibalization",
	"high_octane",
	"concealed_claymores",
	"guerrilla_insurgency",
	"salvage_war_machine",
]
const FACTION_TECHNOLOGIES = {
	"bastion":
	[
		"reactive_armor",
		"tandem_rockets",
		"siege_logistics",
		"bunker_reinforcements",
		"fortress_doctrine",
		"iron_blitz"
	],
	"helix":
	[
		"plasma_shields",
		"beam_amplification",
		"flux_capacitors",
		"phase_thrusters",
		"phase_overload",
		"continuous_coherence"
	],
	"frontier":
	[
		"scrap_cannibalization",
		"high_octane",
		"concealed_claymores",
		"guerrilla_insurgency",
		"salvage_war_machine"
	],
}
const EXCLUSIVE_PAIRS = [
	["fortress_doctrine", "iron_blitz"],
	["phase_overload", "continuous_coherence"],
	["guerrilla_insurgency", "salvage_war_machine"],
]
# Innate 55% shield envelope; hull is the complementary 45% of each role.
const PLASMA_SHIELDS = {
	"Worker": 66.0,
	"Infantry": 12.1,
	"RocketInfantry": 17.6,
	"SniperInfantry": 11.0,
	"AssaultInfantry": 20.9,
	"Hero": 60.5,
	"Tank": 63.25,
	"CombatRobot": 71.5,
	"AdvancedTank": 79.75,
	"RepairRobot": 24.75,
	"Helicopter": 27.5,
	"Fighter": 24.75,
	"Bomber": 49.5,
	"AntiAirVehicle": 38.5,
	"Drone": 13.75,
}
const ITEMS = {
	"plasma_shields":
	{
		"title": "Harmonic Shield Resonators",
		"cost": Vector2i(40, 25),
		"seconds": 40.0,
		"requires": ["coordination"]
	},
	"weapons_1":
	{"title": "Weapon systems I", "cost": Vector2i(30, 20), "seconds": 35.0, "requires": []},
	"weapons_2":
	{
		"title": "Weapon systems II",
		"cost": Vector2i(60, 40),
		"seconds": 50.0,
		"requires": ["weapons_1", "coordination"]
	},
	"weapons_3":
	{
		"title": "Weapon systems III",
		"cost": Vector2i(90, 60),
		"seconds": 65.0,
		"requires": ["weapons_2", "coordination"]
	},
	"armor_1":
	{"title": "Combat armor I", "cost": Vector2i(30, 15), "seconds": 35.0, "requires": []},
	"armor_2":
	{
		"title": "Combat armor II",
		"cost": Vector2i(60, 30),
		"seconds": 50.0,
		"requires": ["armor_1", "coordination"]
	},
	"armor_3":
	{
		"title": "Combat armor III",
		"cost": Vector2i(90, 45),
		"seconds": 65.0,
		"requires": ["armor_2", "coordination"]
	},
	"service":
	{"title": "Field service", "cost": Vector2i(35, 25), "seconds": 40.0, "requires": []},
	"doctrine":
	{
		"title": "Faction doctrine",
		"cost": Vector2i(45, 35),
		"seconds": 50.0,
		"requires": ["coordination"]
	},
	"dual_purpose_aa":
	{
		"title": "Dual-purpose AA",
		"cost": Vector2i(40, 30),
		"seconds": 45.0,
		"requires": ["coordination"]
	},
	"tank_stabilizers":
	{
		"title": "Gyrostabilizers",
		"cost": Vector2i(45, 25),
		"seconds": 40.0,
		"requires": ["coordination"]
	},
	"tandem_rockets":
	{
		"title": "Tandem Warheads",
		"cost": Vector2i(40, 25),
		"seconds": 35.0,
		"requires": ["coordination"]
	},
	"reactive_armor":
	{
		"title": "Reactive Composite Armor",
		"cost": Vector2i(50, 30),
		"seconds": 45.0,
		"requires": ["coordination"]
	},
	"siege_logistics":
	{
		"title": "Automated Repair Cranes",
		"cost": Vector2i(45, 25),
		"seconds": 40.0,
		"requires": ["coordination"]
	},
	"flux_capacitors":
	{
		"title": "Flux Capacitors",
		"cost": Vector2i(45, 35),
		"seconds": 40.0,
		"requires": ["coordination"]
	},
	"scrap_cannibalization":
	{
		"title": "Scrap Cannibalization",
		"cost": Vector2i(40, 20),
		"seconds": 35.0,
		"requires": ["coordination"]
	},
	"high_octane":
	{
		"title": "High-Octane Superchargers",
		"cost": Vector2i(40, 25),
		"seconds": 40.0,
		"requires": ["coordination"]
	},
	"beam_amplification":
	{
		"title": "Coherent Beam Amplification",
		"cost": Vector2i(50, 35),
		"seconds": 45.0,
		"requires": ["coordination"]
	},
	"phase_thrusters":
	{
		"title": "Instant Hover Thrusters",
		"cost": Vector2i(40, 30),
		"seconds": 40.0,
		"requires": ["coordination"]
	},
	"bunker_reinforcements":
	{
		"title": "Bunker Reinforcements",
		"cost": Vector2i(40, 15),
		"seconds": 35.0,
		"requires": ["coordination"]
	},
	"concealed_claymores":
	{
		"title": "Concealed Claymores",
		"cost": Vector2i(35, 20),
		"seconds": 35.0,
		"requires": ["coordination"]
	},
	"fortress_doctrine":
	{
		"title": "Fortress Doctrine",
		"cost": Vector2i(55, 35),
		"seconds": 50.0,
		"requires": ["coordination"]
	},
	"iron_blitz":
	{
		"title": "Iron Blitz",
		"cost": Vector2i(55, 35),
		"seconds": 50.0,
		"requires": ["coordination"]
	},
	"phase_overload":
	{
		"title": "Phase Overload",
		"cost": Vector2i(55, 40),
		"seconds": 50.0,
		"requires": ["coordination"]
	},
	"continuous_coherence":
	{
		"title": "Continuous Coherence",
		"cost": Vector2i(55, 40),
		"seconds": 50.0,
		"requires": ["coordination"]
	},
	"guerrilla_insurgency":
	{
		"title": "Guerrilla Insurgency",
		"cost": Vector2i(45, 25),
		"seconds": 45.0,
		"requires": ["coordination"]
	},
	"salvage_war_machine":
	{
		"title": "Salvage War Machine",
		"cost": Vector2i(45, 25),
		"seconds": 45.0,
		"requires": ["coordination"]
	},
}


static func title(id, faction):
	if id == "doctrine":
		if faction == "frontier":
			return "Rapid redeployment"
		return "Fortified Anchor" if faction == "bastion" else "Accelerated Precision"
	return ITEMS[id].title if ITEMS.has(id) else "Coordination"


static func cost(id):
	if id == "coordination":
		return Vector2i(COORDINATION_COST.resource_a, COORDINATION_COST.resource_b)
	return ITEMS[id].cost


static func requirements(id):
	return [] if id == "coordination" else ITEMS[id].requires


static func description(id, faction):
	if id == "doctrine" and faction == "frontier":
		return (
			"Maneuver Burst grants +50% movement speed instead of +35%. Its 6 "
			+ "s duration and 25 s cooldown stay the same; all orders continue."
		)
	match id:
		"beam_amplification":
			return "Focused Prism beams ramp up by 15% damage each second on the same target, up to +60%."
		"phase_thrusters":
			return "Helix hover vehicles gain +15% movement speed and faster repulsor response."
		"bunker_reinforcements":
			return "Concrete bunkers gain reinforced firing positions and 50% more durability."
		"concealed_claymores":
			return "Hidden proximity mines deal double damage over double the explosion radius."
		"fortress_doctrine":
			return (
				"Permanent doctrine: structures gain 30% maximum HP, bunkers auto-repair "
				+ "and sandbag durability doubles. Excludes Iron Blitz."
			)
		"iron_blitz":
			return (
				"Permanent doctrine: tanks gain 20% movement speed and stabilized fire on "
				+ "the move. Excludes Fortress Doctrine."
			)
		"phase_overload":
			return (
				"Permanent doctrine: shield breaks emit an EMP flash and Phase Shift "
				+ "cooldown is halved. Excludes Continuous Coherence."
			)
		"continuous_coherence":
			return (
				"Permanent doctrine: Prism beams chain to two more targets and link range "
				+ "increases 50%. Excludes Phase Overload."
			)
		"guerrilla_insurgency":
			return (
				"Permanent doctrine: destroyed structures release militia and the mine "
				+ "limit doubles. Excludes Salvage War Machine."
			)
		"salvage_war_machine":
			return (
				"Permanent doctrine: destroyed enemy tanks can be salvaged directly into "
				+ "Outrider buggies. Excludes Guerrilla Insurgency."
			)
		"plasma_shields":
			return (
				"Increase innate plasma shield capacity by 30% and reduce the out-of-combat "
				+ "recharge delay from 5 to 3 seconds. Shields regenerate at 8 HP per second."
			)
		"dual_purpose_aa":
			return (
				"AA vehicles, AA turrets and Helix Interception deal 100% ground damage "
				+ "instead of 33%. Applies to existing and new units. Air damage is unchanged; "
				+ "AA turrets always prioritize aircraft."
			)
		"weapons_1", "weapons_2", "weapons_3":
			return (
				(
					"Combat units deal +%d%% weapon damage. Applies to existing and new "
					+ "infantry, armor, walkers and strike aircraft."
				)
				% (10 if id == "weapons_1" else (20 if id == "weapons_2" else 30))
			)
		"armor_1", "armor_2", "armor_3":
			return (
				(
					"Combat units gain +%d%% maximum HP. Existing units keep their health "
					+ "percentage; engineers, support and buildings are unchanged."
				)
				% (10 if id == "armor_1" else (20 if id == "armor_2" else 30))
			)
		"tank_stabilizers":
			return (
				"Main battle tanks gain gyro-stabilized fire control: +1.5 m attack "
				+ "range and +25% damage against structures and infantry."
			)
		"tandem_rockets":
			return (
				"Rocket infantry fire tandem-charge warheads dealing +35% damage to "
				+ "heavy armor, and shoulder SAM missile lock-on time is halved to 0.4 s."
			)
		"reactive_armor":
			return (
				"Bastion combat vehicles and walkers deflect small-arms fire: infantry "
				+ "rifles and light autocannons deal 25% less damage to them."
			)
		"siege_logistics":
			return (
				"Repair depots gain an additional service slot (repair 2 units at once) "
				+ "and vehicle factories assemble heavy tanks and walkers 15% faster."
			)
		"flux_capacitors":
			return (
				"Helix energy weapons charge and spin up 40% faster. Lancer walker "
				+ "weapon mode switching delay is reduced from 2.0 s to 0.5 s."
			)
		"scrap_cannibalization":
			return (
				"Scrapper rigs harvest 50% more materials from wrecks "
				+ "and salvaging a wreck instantly repairs 25 HP to nearby friendly vehicles."
			)
		"high_octane":
			return "All Frontier wheeled vehicles gain +18% movement speed."
		"service":
			return (
				"Repair robots, depots, barracks and airfields restore health 25% faster. "
				+ "Service range and capacity stay the same."
			)
		"doctrine":
			return (
				(
					"Anchor reduces incoming damage by 25% instead of 15%. Hold still for "
					+ "2 seconds inside its sector; movement still breaks Anchor."
				)
				if faction == "bastion"
				else (
					"Precision Window cuts the first shot's preparation time by 50% instead "
					+ "of 20%. Its duration, cooldown, damage and reload stay the same."
				)
			)
	return ""


static func next_in_branch(branch, completed):
	var choices = (
		[branch + "_1", branch + "_2", branch + "_3"]
		if branch in ["weapons", "armor"]
		else [branch]
	)
	for id in choices:
		if id not in completed:
			return id
	return ""


static func rank(branch, completed):
	return (
		int(branch + "_1" in completed)
		+ int(branch + "_2" in completed)
		+ int(branch + "_3" in completed)
	)


static func damage_factor(role, completed):
	return 1.0 + .1 * rank("weapons", completed) if role in COMBAT_ROLES else 1.0


static func health_factor(role, completed):
	if (
		"fortress_doctrine" in completed
		and role in preload("res://source/match/BastionCatalog.gd").STRUCTURES
	):
		return 1.3
	return 1.0 + .1 * rank("armor", completed) if role in COMBAT_ROLES else 1.0


static func available(id, faction):
	return id in ["", "coordination"] or id in FACTION_TECHNOLOGIES.get(faction, [])


static func exclusion(id: String, planned: Array) -> String:
	for pair in EXCLUSIVE_PAIRS:
		if id in pair:
			for other in pair:
				if other != id and other in planned:
					return other
	return ""


static func shield_capacity(role, faction, completed) -> float:
	if faction != "helix":
		return 0.0
	return PLASMA_SHIELDS.get(role, 0.0) * (1.3 if "plasma_shields" in completed else 1.0)


static func empty_state():
	return {"completed": [], "active": "", "left": -1.0, "paid": {}, "queued": []}


static func valid_state(state, coordination, coordination_active = false):
	if not state is Dictionary or state.size() != 5:
		return false
	if not state.get("completed") is Array or not state.get("active") is String:
		return false
	if not state.get("left") is float and not state.get("left") is int:
		return false
	if not state.get("paid") is Dictionary or not is_finite(float(state.left)):
		return false
	if not state.get("queued") is Array or state.queued.size() > ITEMS.size() + 1:
		return false
	if state.completed.size() > ITEMS.size():
		return false
	var seen = []
	for id in state.completed:
		if not id is String or not ITEMS.has(id) or id in seen:
			return false
		if exclusion(id, seen) != "":
			return false
		seen.append(id)
	for id in seen:
		if not _prerequisites(id, seen, coordination):
			return false
	if state.active == "":
		if state.left != -1.0 or not state.paid.is_empty():
			return false
	else:
		if not ITEMS.has(state.active) or state.active in seen or coordination_active:
			return false
		if exclusion(state.active, seen) != "":
			return false
		var item = ITEMS[state.active]
		if not (
			_prerequisites(state.active, seen, coordination)
			and state.left > 0
			and state.left <= item.seconds
			and _valid_payment(state.active, state.paid)
		):
			return false
		seen.append(state.active)
	if coordination or coordination_active:
		seen.append("coordination")
	for entry in state.queued:
		if not entry is Dictionary or entry.size() != 2:
			return false
		var id = entry.get("id")
		if not id is String or (id != "coordination" and not ITEMS.has(id)) or id in seen:
			return false
		if exclusion(id, seen) != "":
			return false
		if not _valid_payment(id, entry.get("paid")):
			return false
		if not requirements(id).all(func(required): return required in seen):
			return false
		seen.append(id)
	return true


static func _valid_payment(id, payment):
	var price = cost(id)
	return (
		payment is Dictionary
		and payment.size() == 2
		and payment.get("resource_a") is int
		and payment.get("resource_b") is int
		and payment.resource_a == price.x
		and payment.resource_b == price.y
	)


static func _prerequisites(id, completed, coordination):
	return ITEMS[id].requires.all(
		func(required): return coordination if required == "coordination" else required in completed
	)

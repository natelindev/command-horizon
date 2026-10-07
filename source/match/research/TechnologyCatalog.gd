extends RefCounted

const COMBAT_ROLES = ["Infantry", "Tank", "CombatRobot", "AdvancedTank", "Helicopter"]
const BRANCHES = ["weapons", "armor", "service", "doctrine"]
const ITEMS = {
	"weapons_1":
	{"title": "Weapon systems I", "cost": Vector2i(30, 20), "seconds": 35.0, "requires": []},
	"weapons_2":
	{
		"title": "Weapon systems II",
		"cost": Vector2i(60, 40),
		"seconds": 50.0,
		"requires": ["weapons_1", "coordination"]
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
	"service":
	{"title": "Field service", "cost": Vector2i(35, 25), "seconds": 40.0, "requires": []},
	"doctrine":
	{
		"title": "Faction doctrine",
		"cost": Vector2i(45, 35),
		"seconds": 50.0,
		"requires": ["coordination"]
	},
}


static func title(id, faction):
	if id == "doctrine":
		if faction == "frontier":
			return "Rapid redeployment"
		return "Fortified Anchor" if faction == "bastion" else "Accelerated Precision"
	return ITEMS[id].title if ITEMS.has(id) else "Coordination"


static func description(id, faction):
	if id == "doctrine" and faction == "frontier":
		return (
			"Maneuver Burst grants +50% movement speed instead of +35%. Its 6 "
			+ "s duration and 25 s cooldown stay the same; all orders continue."
		)
	match id:
		"weapons_1", "weapons_2":
			return (
				(
					"Combat units deal +%d%% weapon damage. Applies to existing and new "
					+ "infantry, armor, walkers and strike aircraft."
				)
				% (10 if id == "weapons_1" else 20)
			)
		"armor_1", "armor_2":
			return (
				(
					"Combat units gain +%d%% maximum HP. Existing units keep their health "
					+ "percentage; engineers, support and buildings are unchanged."
				)
				% (10 if id == "armor_1" else 20)
			)
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
	var choices = [branch + "_1", branch + "_2"] if branch in ["weapons", "armor"] else [branch]
	for id in choices:
		if id not in completed:
			return id
	return ""


static func rank(branch, completed):
	return int(branch + "_1" in completed) + int(branch + "_2" in completed)


static func damage_factor(role, completed):
	return 1.0 + .1 * rank("weapons", completed) if role in COMBAT_ROLES else 1.0


static func health_factor(role, completed):
	return 1.0 + .1 * rank("armor", completed) if role in COMBAT_ROLES else 1.0


static func empty_state():
	return {"completed": [], "active": "", "left": -1.0, "paid": {}}


static func valid_state(state, coordination):
	if not state is Dictionary or state.size() != 4:
		return false
	if not state.get("completed") is Array or not state.get("active") is String:
		return false
	if not state.get("left") is float and not state.get("left") is int:
		return false
	if not state.get("paid") is Dictionary or not is_finite(float(state.left)):
		return false
	if state.completed.size() > ITEMS.size():
		return false
	var seen = []
	for id in state.completed:
		if not id is String or not ITEMS.has(id) or id in seen:
			return false
		seen.append(id)
	for id in seen:
		if not _prerequisites(id, seen, coordination):
			return false
	if state.active == "":
		return state.left == -1.0 and state.paid.is_empty()
	if not ITEMS.has(state.active) or state.active in seen:
		return false
	var item = ITEMS[state.active]
	return (
		_prerequisites(state.active, seen, coordination)
		and state.left > 0
		and state.left <= item.seconds
		and state.paid.size() == 2
		and state.paid.get("resource_a") is int
		and state.paid.get("resource_b") is int
		and state.paid.resource_a == item.cost.x
		and state.paid.resource_b == item.cost.y
	)


static func _prerequisites(id, completed, coordination):
	return ITEMS[id].requires.all(
		func(required): return coordination if required == "coordination" else required in completed
	)

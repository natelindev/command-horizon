# gdlint: disable=max-returns
extends Node

const Catalog = preload("res://source/match/research/TechnologyCatalog.gd")
var completed = []
var active = ""
var left = -1.0
var paid = {}
@onready var player = get_parent()


func reason(id, lab):
	if not Catalog.ITEMS.has(id):
		return "Unknown technology."
	if id in completed:
		return "Research complete."
	if active != "" or player.coordination_left > 0:
		return "Finish or cancel the current research first."
	if (
		not is_instance_valid(lab)
		or lab.is_queued_for_deletion()
		or lab.hp <= 0
		or lab.player != player
		or lab.type != "CommandLab"
		or not lab.is_constructed()
	):
		return "Requires a completed friendly lab."
	if not player.basic_programs_unlocked():
		return "Requires a completed vehicle factory and lab."
	for required in Catalog.ITEMS[id].requires:
		if not (
			player.coordination_unlocked if required == "coordination" else required in completed
		):
			return "Requires %s." % Catalog.title(required, player.faction)
	var price = Catalog.ITEMS[id].cost
	if not player.has_resources({"resource_a": price.x, "resource_b": price.y}):
		return (
			"Need %d M / %d E more."
			% [maxi(0, price.x - player.resource_a), maxi(0, price.y - player.resource_b)]
		)
	return ""


func start(id, lab):
	if reason(id, lab) != "":
		return false
	var item = Catalog.ITEMS[id]
	active = id
	left = item.seconds
	paid = {"resource_a": item.cost.x, "resource_b": item.cost.y}
	player.subtract_resources(paid)
	player.emit_changed()
	return true


func cancel():
	if active == "":
		return false
	var refund = paid.duplicate()
	active = ""
	left = -1.0
	paid.clear()
	player.add_resources(refund)
	player.emit_changed()
	return true


func _physics_process(delta):
	if active == "" or not player.has_completed_structure("CommandLab"):
		return
	left = maxf(0.0, left - delta * player.production_factor())
	if left > 0:
		return
	var finished = active
	completed.append(active)
	active = ""
	left = -1.0
	paid.clear()
	for unit in player.get_children():
		if unit.is_in_group("units"):
			apply_unit(unit)
	player.emit_changed()
	var game = player.find_parent("Match")
	if game != null and game._get_human_player() == player:
		game.hud.show_notice("Research complete · " + Catalog.title(finished, player.faction))


func apply_unit(unit):
	if unit.is_queued_for_deletion() or unit.hp == null or unit.hp <= 0:
		return
	var maximum = unit.base_hp_max * Catalog.health_factor(unit.type, completed)
	if is_equal_approx(maximum, unit.hp_max):
		return
	var ratio = unit.hp / unit.hp_max
	unit.hp_max = maximum
	unit.hp = maximum * ratio


func damage_factor(role):
	return Catalog.damage_factor(role, completed)


func service_factor():
	return 1.25 if "service" in completed else 1.0


func has_doctrine():
	return "doctrine" in completed


func status():
	if active == "":
		return "Choose a technology"
	var suffix = ""
	if not player.has_completed_structure("CommandLab"):
		suffix = " · paused, rebuild a lab"
	elif player.production_factor() < 1:
		suffix = " · low power, 35% speed"
	return "%s · %.1f s remaining%s" % [Catalog.title(active, player.faction), left, suffix]


func capture():
	return {
		"completed": completed.duplicate(), "active": active, "left": left, "paid": paid.duplicate()
	}


func restore(state):
	completed = state.completed.duplicate()
	active = state.active
	left = state.left
	paid = state.paid.duplicate()


func summary(role):
	var lines = PackedStringArray()
	if role in Catalog.COMBAT_ROLES:
		var weapons = Catalog.rank("weapons", completed)
		var armor = Catalog.rank("armor", completed)
		if weapons > 0:
			lines.append(
				"Weapon systems %s · +%d%% damage" % ["II" if weapons == 2 else "I", weapons * 10]
			)
		if armor > 0:
			lines.append(
				"Combat armor %s · +%d%% maximum HP" % ["II" if armor == 2 else "I", armor * 10]
			)
	if (
		"service" in completed
		and role in ["RepairRobot", "RepairDepot", "Barracks", "AircraftFactory"]
	):
		lines.append("Field service · +25% recovery speed")
	if has_doctrine() and role in ["Tank", "CombatRobot", "AdvancedTank"]:
		lines.append(Catalog.title("doctrine", player.faction) + " researched")
	return "\n".join(lines)

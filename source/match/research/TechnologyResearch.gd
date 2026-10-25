# gdlint: disable=max-returns
extends Node

const Catalog = preload("res://source/match/research/TechnologyCatalog.gd")
var completed = []
var active = ""
var left = -1.0
var paid = {}
var queued = []
var _advanced_frame = -1
@onready var player = get_parent()


func reason(id, lab):
	if not Catalog.ITEMS.has(id):
		return "Unknown technology."
	if active != "" or player.coordination_left > 0 or not queued.is_empty():
		return "Finish or cancel the current research first."
	return queue_reason(id, lab)


func queue_reason(id, lab):
	if id != "coordination" and not Catalog.ITEMS.has(id):
		return "Unknown technology."
	if not Catalog.available(id, player.faction):
		return "Requires the Helix faction."
	if id in completed or (id == "coordination" and player.coordination_unlocked):
		return "Research complete."
	if id == active or (id == "coordination" and player.coordination_left > 0):
		return "Research is already in progress."
	if queued.any(func(entry): return entry.id == id):
		return "Research is already queued."
	if (
		not is_instance_valid(lab)
		or lab.is_queued_for_deletion()
		or lab.hp <= 0
		or lab.player != player
		or lab.type != "CommandLab"
		or not lab.is_constructed()
	):
		return "Requires a completed friendly lab."
	if not player.lab_research_unlocked():
		return "Requires a completed vehicle factory and lab."
	var planned = planned_technologies()
	for required in Catalog.requirements(id):
		if required not in planned:
			return "Requires %s." % Catalog.title(required, player.faction)
	var price = Catalog.cost(id)
	if not player.has_resources({"resource_a": price.x, "resource_b": price.y}):
		return (
			"Need %d M / %d E more."
			% [maxi(0, price.x - player.resource_a), maxi(0, price.y - player.resource_b)]
		)
	return ""


func start(id, lab):
	if reason(id, lab) != "":
		return false
	return enqueue(id, lab)


func enqueue(id, lab):
	if queue_reason(id, lab) != "":
		return false
	var price = Catalog.cost(id)
	var payment = {"resource_a": price.x, "resource_b": price.y}
	# Reserve every project at purchase, matching unit production. The active
	# project and each queued entry own their payment until completion or refund.
	if active == "" and player.coordination_left <= 0 and queued.is_empty():
		_begin_paid(id, payment)
	else:
		queued.append({"id": id, "paid": payment})
	player.subtract_resources(payment)
	player.emit_changed()
	return true


func planned_technologies():
	var result = completed.duplicate()
	if active != "":
		result.append(active)
	if player.coordination_unlocked or player.coordination_left > 0:
		result.append("coordination")
	for entry in queued:
		result.append(entry.id)
	return result


func _begin_paid(id, payment):
	if id == "coordination":
		player.coordination_left = player.COORDINATION_DURATION
	else:
		active = id
		left = Catalog.ITEMS[id].seconds
		paid = payment.duplicate()


func advance_queue():
	if active != "" or player.coordination_left > 0 or queued.is_empty():
		return
	var next = queued.pop_front()
	_begin_paid(next.id, next.paid)
	# Coordination advances in the parent player's callback. Its successor
	# must not consume the same physics tick again in this child callback.
	_advanced_frame = Engine.get_physics_frames()


func cancel():
	if active == "":
		return false
	var refund = paid.duplicate()
	active = ""
	left = -1.0
	paid.clear()
	_prune_dependents()
	advance_queue()
	player.add_resources(refund)
	player.emit_changed()
	return true


func cancel_queued(index):
	if index < 0 or index >= queued.size():
		return false
	var entry = queued[index]
	queued.remove_at(index)
	_prune_dependents()
	player.add_resources(entry.paid)
	player.emit_changed()
	return true


func coordination_cancelled():
	_prune_dependents()
	advance_queue()
	player.emit_changed()


func _prune_dependents():
	var available = completed.duplicate()
	if active != "":
		available.append(active)
	if player.coordination_unlocked or player.coordination_left > 0:
		available.append("coordination")
	var kept = []
	var refund = {"resource_a": 0, "resource_b": 0}
	for entry in queued:
		if Catalog.requirements(entry.id).all(func(required): return required in available):
			kept.append(entry)
			available.append(entry.id)
		else:
			refund.resource_a += entry.paid.resource_a
			refund.resource_b += entry.paid.resource_b
	queued = kept
	if refund.resource_a > 0 or refund.resource_b > 0:
		player.add_resources(refund)


func _physics_process(delta):
	if active == "" and player.coordination_left <= 0 and not queued.is_empty():
		advance_queue()
		player.emit_changed()
		return
	if (
		active == ""
		or _advanced_frame == Engine.get_physics_frames()
		or not player.has_completed_structure("CommandLab")
	):
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
	advance_queue()
	player.emit_changed()
	MatchSignals.research_completed.emit(player, finished)
	var game = player.find_parent("Match")
	if game != null and game._get_human_player() == player:
		game.hud.show_notice("Research complete · " + Catalog.title(finished, player.faction))


func apply_unit(unit):
	if unit.is_queued_for_deletion() or unit.hp == null or unit.hp <= 0:
		return
	unit.update_shields()
	var maximum = unit.base_hp_max * Catalog.health_factor(unit.type, completed)
	if is_equal_approx(maximum, unit.hp_max):
		return
	var ratio = unit.hp / unit.hp_max
	unit.hp_max = maximum
	unit.hp = maximum * ratio


func damage_factor(role):
	return Catalog.damage_factor(role, completed)


func aa_ground_damage_factor():
	return 1.0 if "dual_purpose_aa" in completed else Catalog.AA_GROUND_DAMAGE_FACTOR


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
		"completed": completed.duplicate(),
		"active": active,
		"left": left,
		"paid": paid.duplicate(),
		"queued": queued.duplicate(true)
	}


func restore(state):
	completed = state.completed.duplicate()
	active = state.active
	left = state.left
	paid = state.paid.duplicate()
	queued = state.queued.duplicate(true)
	_advanced_frame = -1


func summary(role):
	var lines = PackedStringArray()
	var capacity = Catalog.shield_capacity(role, player.faction, completed)
	if capacity > 0:
		lines.append("Plasma Shields · %d shield HP" % int(capacity))
	if (
		"dual_purpose_aa" in completed
		and (
			role in ["AntiAirVehicle", "AntiAirTurret"]
			or (role == "CombatRobot" and player.faction == "helix")
		)
	):
		lines.append("Dual-purpose AA · 100% ground damage")
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

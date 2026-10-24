# gdlint: disable=max-returns
extends Node

const Bindings = preload("res://source/input/KeyBindings.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Orders = preload("res://source/match/orders/ManualOrders.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
const Repairs = preload("res://source/match/combat/RepairService.gd")
const Recover = preload("res://source/match/units/actions/RecoveringAtService.gd")
const Behavior = preload("res://source/match/orders/UnitBehavior.gd")
const COMMANDS = {
	"patrol":
	{
		"title": "Patrol",
		"action": "patrol_order",
		"description":
		(
			"Patrol between the starting point and a destination, engaging enemies en route. "
			+ "Fixed-wing aircraft patrol the destination. Continues until stopped or replaced; "
			+ "Skip advances queued orders."
		)
	},
	"follow": {"title": "Follow", "action": "", "description": "Follow a friendly unit."},
	"guard": {"title": "Guard", "action": "", "description": "Move to a position and defend it."},
	"move":
	{
		"title": "Move",
		"action": "move_order",
		"description": "Move to a point without acquiring enemies along the way."
	},
	"attack":
	{
		"title": "Attack target",
		"action": "attack_target",
		"description":
		"Attack a visible enemy or neutral target. On lost sight, visit its last known position and hold."
	},
	"attack_move":
	{
		"title": "Attack move",
		"action": "attack_move",
		"description": "Advance toward a point, stopping to fire at legal enemies in weapon range."
	}
}

var kind = ""
var _release_button = 0
@onready var hud = get_parent()


func _ready():
	MatchSignals.place_structure.connect(func(_scene): hud.cancel_map_assignment())


func eligible(command):
	var mobile = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				is_instance_valid(unit)
				and not unit.is_queued_for_deletion()
				and unit.is_in_group("controlled_units")
				and unit.hp > 0
				and unit.manual_orders != null
				and unit.movement_speed > 0
			)
	)
	if command in ["move", "guard", "follow", "patrol"]:
		return mobile
	var armed = mobile.filter(func(unit): return unit.attack_range != null)
	# A mixed army advances its selected scouts, engineers and repair support
	# along with the combatants. Unarmed-only selections retain ordinary Move.
	return mobile if command == "attack_move" and not armed.is_empty() else armed


func arm(command):
	if not COMMANDS.has(command) or _blocked():
		return
	if kind == command:
		cancel()
		return
	if eligible(command).is_empty():
		hud.show_notice(
			(
				"Select mobile units."
				if command in ["move", "guard", "follow", "patrol"]
				else "Select armed mobile units."
			)
		)
		return
	hud.cancel_map_assignment()
	(
		hud
		. get_parent()
		. _get_human_player()
		. get_node("StructurePlacementHandler")
		. _cancel_structure_placement()
	)
	kind = command
	prompt()
	hud._refresh_shortcuts()


func cargo_return_state():
	var workers = eligible("move").filter(func(unit): return unit.type == "Worker")
	var loaded = workers.filter(func(unit): return unit.resource_a + unit.resource_b > 0)
	var orders = []
	for worker in loaded:
		var hq = Harvest._find_cc_closest_to_unit(worker)
		if hq != null:
			orders.append([worker, Orders.target_order("gather", hq)])
	var description = (
		"Deliver cargo to each engineer's nearest completed friendly HQ.\n"
		+ "Then wait for a new resource assignment.\n"
		+ ("Replaces current orders. Hold %s to queue." % Bindings.label("shift_selecting"))
	)
	if loaded.is_empty():
		description = "Selected engineers have no cargo to deliver.\n" + description
	elif orders.is_empty():
		description = "A completed friendly HQ is required.\n" + description
	return {"orders": orders, "description": description}


func return_cargo(append = false):
	if _blocked():
		return false
	# Recompute targets on activation; a selected engineer or HQ may have died
	# since the panel refreshed. Empty carriers and other roles keep their orders.
	var state = cargo_return_state()
	if state.orders.is_empty():
		hud.show_notice(state.description)
		return false
	var accepted = 0
	for pair in state.orders:
		if pair[0].manual_orders.submit(pair[1], append):
			accepted += 1
	if accepted > 0:
		hud.cancel_map_assignment()
		(
			hud
			. get_parent()
			. _get_human_player()
			. get_node("StructurePlacementHandler")
			. _cancel_structure_placement()
		)
	hud.show_notice(
		(
			"Return cargo · %d engineers%s" % [accepted, " · queued" if append else ""]
			if accepted == state.orders.size()
			else (
				"Return cargo · %d ordered / %d queues full"
				% [accepted, state.orders.size() - accepted]
			)
		)
	)
	return accepted > 0


func recovery_state():
	var wounded = eligible("move").filter(func(unit): return unit.hp < unit.hp_max)
	var orders = []
	var missing = {}
	var facilities = get_tree().get_nodes_in_group("units").filter(
		func(unit): return unit.type in ["Barracks", "RepairDepot", "AircraftFactory"]
	)
	facilities.append_array(
		load("res://source/match/world/PointOfInterestCatalog.gd").sites(hud.get_parent()).filter(
			func(site): return site.kind == "repair"
		)
	)
	for unit in wounded:
		var nearest = null
		var distance = INF
		for facility in facilities:
			if not Repairs.facility_eligible(facility, unit):
				continue
			var candidate = Utils.Match.Unit.Movement.path_distance_to(
				unit, facility.global_position_yless, Recover.ARRIVAL_RANGE
			)
			if candidate < distance:
				nearest = facility
				distance = candidate
		if nearest != null:
			orders.append([unit, Orders.target_order("recover", nearest)])
		else:
			var title = Factions.title(unit.player.faction, Repairs.facility_for_role(unit.type))
			missing[title] = missing.get(title, 0) + 1
	var description = (
		"Recover to full health at the nearest completed friendly service facility.\n"
		+ "Infantry: barracks · Aircraft: flight facility · Vehicles and engineers: repair depot.\n"
		+ "Then continue queued orders or hold position.\n"
		+ "Replaces current orders. Hold %s to queue." % Bindings.label("shift_selecting")
	)
	var label = "Recover health"
	if wounded.is_empty():
		description = "Selected mobile units are at full health.\n" + description
	elif not missing.is_empty():
		label += " · %d/%d supported" % [orders.size(), wounded.size()]
		var needs = []
		for title in missing:
			needs.append(
				"%s: %d %s" % [title, missing[title], "unit" if missing[title] == 1 else "units"]
			)
		description = (
			"%d of %d wounded units have facility support.\n" % [orders.size(), wounded.size()]
			+ "Missing service:\n"
			+ "\n".join(needs)
			+ ".\n"
			+ "Units without support keep their orders.\n"
			+ description
		)
	return {
		"orders": orders,
		"label": label,
		"description": description,
		"unavailable": wounded.size() - orders.size()
	}


func recover_health(append = false):
	if _blocked():
		return false
	var state = recovery_state()
	if state.orders.is_empty():
		hud.show_notice(state.description)
		return false
	var accepted = 0
	for pair in state.orders:
		if pair[0].manual_orders.submit(pair[1], append):
			accepted += 1
	if accepted > 0:
		hud.cancel_map_assignment()
		(
			hud
			. get_parent()
			. _get_human_player()
			. get_node("StructurePlacementHandler")
			. _cancel_structure_placement()
		)
	var message = "Recover · %d units%s" % [accepted, " · queued" if append else ""]
	if accepted < state.orders.size():
		message += " · %d queues full" % (state.orders.size() - accepted)
	if state.unavailable > 0:
		message += " · %d without service" % state.unavailable
	hud.show_notice(message)
	return accepted > 0


func cancel():
	if kind.is_empty():
		return
	kind = ""
	hud._assignment_hint.hide()
	hud._refresh_shortcuts()


func prompt(message = ""):
	if kind.is_empty():
		return
	if not message.is_empty() and is_instance_valid(hud.command_feedback):
		hud.command_feedback.reject(message)
	hud._hint_left = 0.0
	hud._notice_slot.scroll_vertical = 0
	hud._assignment_hint.show()
	hud._assignment_hint.text = (
		(
			(
				"Follow: choose a friendly unit."
				if kind == "follow"
				else (
					"Attack target: choose a visible enemy or neutral target."
					if kind in ["attack", "follow"]
					else COMMANDS[kind].title + ": choose a destination."
				)
			)
			if message.is_empty()
			else message
		)
		+ " %s / right-click cancels." % Bindings.label("toggle_match_menu")
	)


func handle_input(event):
	if _blocked():
		return false
	for command in COMMANDS:
		if COMMANDS[command].action != "" and Bindings.pressed(event, COMMANDS[command].action):
			arm(command)
			get_viewport().set_input_as_handled()
			return true
	if not event is InputEventMouseButton:
		return false
	if event.button_index == _release_button and not event.pressed:
		_release_button = 0
		get_viewport().set_input_as_handled()
		return true
	if (
		kind.is_empty()
		or not event.pressed
		or event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
	):
		return false
	_release_button = event.button_index
	get_viewport().set_input_as_handled()
	if event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
	else:
		var point = get_viewport().get_camera_3d().get_ray_intersection(event.position)
		var target = hud._pick_unit(event.position) if kind in ["attack", "follow"] else null
		commit(point, target, Bindings.held("shift_selecting"))
	return true


func commit(point, target, append):
	if kind.is_empty() or _blocked():
		return false
	var units = eligible(kind)
	if units.is_empty():
		cancel()
		hud.show_notice("No selected units can carry out that command.")
		return false
	var orders = []
	if kind == "follow":
		if (
			not is_instance_valid(target)
			or target.is_queued_for_deletion()
			or not target.is_in_group("units")
			or target.player != units[0].player
			or target.hp <= 0
		):
			prompt("Choose a friendly unit to follow.")
			return false
		for unit in units:
			if unit != target:
				orders.append([unit, Orders.target_order("follow", target)])
		if orders.is_empty():
			prompt("Choose another friendly unit to follow.")
			return false
	elif kind == "attack":
		if (
			not is_instance_valid(target)
			or target.is_queued_for_deletion()
			or not (target.is_in_group("adversary_units") or target.is_in_group("neutral_targets"))
			or not hud.get_parent().battlefield.is_observed(units[0].player, target)
		):
			prompt("Choose a visible enemy or neutral target.")
			return false
		for unit in units:
			if Rules.can_target(unit, target):
				orders.append([unit, Orders.target_order("attack", target)])
		if orders.is_empty():
			prompt("Selected weapons cannot attack that target.")
			return false
	else:
		var extent = hud.get_parent().map.size
		if (
			not point is Vector3
			or not point.is_finite()
			or point.x < 0
			or point.z < 0
			or point.x > extent.x
			or point.z > extent.y
		):
			prompt("Choose a point inside the battlefield.")
			return false
		# Preserve the same separate ground/air spacing used by contextual movement.
		for domain in [
			Constants.Match.Navigation.Domain.TERRAIN, Constants.Match.Navigation.Domain.AIR
		]:
			var members = units.filter(func(unit): return unit.movement_domain == domain)
			for pair in Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(members, point):
				var order_kind = kind
				if kind == "guard" or (kind == "attack_move" and pair[0].attack_range == null):
					order_kind = "move"
				orders.append([pair[0], Orders.point_order(order_kind, pair[1])])
	var accepted = 0
	for pair in orders:
		var accepted_order = (
			Behavior.guard(pair[0], pair[1].point, append)
			if kind == "guard"
			else (
				Behavior.follow(pair[0], target, append)
				if kind == "follow"
				else pair[0].manual_orders.submit(pair[1], append)
			)
		)
		if accepted_order:
			accepted += 1
	var title = COMMANDS[kind].title
	cancel()
	hud.show_notice(
		(
			"%s · %d units%s" % [title, accepted, " · queued" if append else ""]
			if accepted == orders.size()
			else "%s · %d ordered / %d queues full" % [title, accepted, orders.size() - accepted]
		)
	)
	return accepted > 0


func _blocked():
	var manager = get_node_or_null("/root/SaveManager")
	return (
		hud.get_parent().finished
		or hud._overlay != null
		or is_instance_valid(Globals.settings_dialog)
		or (manager != null and is_instance_valid(manager.dialog))
	)

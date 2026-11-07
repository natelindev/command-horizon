# gdlint: disable=max-returns
extends Node

const Bindings = preload("res://source/input/KeyBindings.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Planner = preload("res://source/match/orders/FormationPlanner.gd")
const Cohesion = preload("res://source/match/orders/CohesionGroup.gd")
const Orders = preload("res://source/match/orders/ManualOrders.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
const Repairs = preload("res://source/match/combat/RepairService.gd")
const Recover = preload("res://source/match/units/actions/RecoveringAtService.gd")
const Behavior = preload("res://source/match/orders/UnitBehavior.gd")
const RangeRing = preload("res://source/match/effects/TacticalRangeRing.gd")
const COMMANDS = {
	"force_attack":
	{
		"title": "Force attack",
		"action": "force_attack",
		"description": "Attack a damageable unit or building, including allied and neutral targets."
	},
	"patrol":
	{
		"title": "Patrol",
		"action": "patrol_order",
		"description":
		(
			"Patrol between the starting point and a destination, engaging enemies en route. "
			+ "Fixed-wing aircraft patrol the destination. Continues until stopped or replaced."
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

const ENGINEERING_OPERATIONS = {
	"field_barricade": "barricade",
	"scrap_barricade": "barricade",
	"field_bunker": "bunker",
	"field_tank_trap": "tank_trap",
	"scrap_mine": "mine",
	"sweep_mines": "sweep",
}
const ENGINEERING_ROTATION = [
	"field_barricade", "scrap_barricade", "field_bunker", "field_tank_trap"
]

var kind = ""
var ability_id = ""
var last_cast = {}
var engineering_angle = 0.0
var _ability_range = null
var _ability_selection = []
var _release_button = 0
@onready var hud = get_parent()


func _ready():
	MatchSignals.place_structure.connect(func(_scene): hud.cancel_map_assignment())
	set_process(false)


func ability_units(id = "") -> Array:
	return get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				is_instance_valid(unit)
				and not unit.is_queued_for_deletion()
				and unit.is_in_group("controlled_units")
				and "abilities" in unit
				and unit.abilities != null
				and unit.abilities.unit_available()
				and (id.is_empty() or unit.abilities.get_ability(id) != null)
			)
	)


## The first selected ability on a key also owns its command-card column.
func ability_for_key(key: String) -> String:
	for unit in ability_units():
		for ability in unit.abilities.abilities:
			if ability.key == key:
				return ability.id
	return ""


func activate_ability(id: String) -> bool:
	if _blocked():
		return false
	var units = ability_units(id)
	if units.is_empty():
		return false
	var ability = units[0].abilities.get_ability(id)
	if ability.target_type in ["target_point", "target_unit"]:
		return arm_ability(id)
	if get_tree().paused:
		hud.show_notice("Resume the battle to use abilities.")
		return false
	var accepted = 0
	# One activation consumes one ready caster, including instant abilities.
	for unit in units:
		if unit.abilities.trigger(id):
			accepted = 1
			last_cast = {"ability": id, "unit": weakref(unit)}
			break
	if accepted > 0:
		hud.cancel_map_assignment()
		(
			hud
			. get_parent()
			. _get_human_player()
			. get_node("StructurePlacementHandler")
			. _cancel_structure_placement()
		)
		hud.show_notice("%s · %d units" % [tr(ability.name), accepted])
	else:
		hud.show_notice(units[0].abilities.availability_issue(id))
	return accepted > 0


func arm_ability(id: String) -> bool:
	if _blocked():
		return false
	if kind == "ability" and ability_id == id:
		cancel()
		return true
	var candidates = ability_units(id)
	var units = candidates.filter(
		func(unit): return unit.abilities.availability_issue(id).is_empty()
	)
	if units.is_empty():
		hud.show_notice(
			(
				candidates[0].abilities.availability_issue(id)
				if not candidates.is_empty()
				else "No selected unit has that ability ready."
			)
		)
		return false
	var ability = units[0].abilities.get_ability(id)
	if ability.target_type not in ["target_point", "target_unit"]:
		return false
	hud.cancel_map_assignment()
	(
		hud
		. get_parent()
		. _get_human_player()
		. get_node("StructurePlacementHandler")
		. _cancel_structure_placement()
	)
	kind = "ability"
	ability_id = id
	engineering_angle = 0.0
	_ability_selection = get_tree().get_nodes_in_group("selected_units")
	_ability_range = RangeRing.create(minf(ability.range, 12.0))
	if id in ENGINEERING_ROTATION:
		_ability_range.free()
		_ability_range = load("res://source/match/hud/EngineeringPreview.gd").new()
		_ability_range.kind = ENGINEERING_OPERATIONS[id]
	if _ability_range != null:
		hud.get_parent().add_child(_ability_range)
		_ability_range.global_position = units[0].global_position + Vector3.UP * .08
	set_process(true)
	prompt()
	hud._refresh_shortcuts()
	return true


func arm_commander() -> bool:
	if _blocked():
		return false
	var game = hud.get_parent()
	var issue = game.commander_support.disabled_reason(game._get_human_player())
	if not issue.is_empty():
		hud.show_notice(issue)
		return false
	hud.cancel_map_assignment()
	game._get_human_player().get_node("StructurePlacementHandler")._cancel_structure_placement()
	kind = "commander"
	_ability_range = RangeRing.create(
		game.commander_support.RADII[game.commander_support.power_for(game._get_human_player())]
	)
	game.add_child(_ability_range)
	set_process(true)
	prompt()
	return true


func _process(_delta):
	if kind == "commander":
		if _blocked():
			cancel()
			return
		var point = get_viewport().get_camera_3d().get_ray_intersection(
			get_viewport().get_mouse_position()
		)
		if point is Vector3 and point.is_finite() and is_instance_valid(_ability_range):
			_ability_range.position = point + Vector3.UP * .08
		return
	if kind != "ability":
		return
	var units = ability_units(ability_id).filter(
		func(unit): return unit.abilities.get_ability(ability_id).is_ready()
	)
	if (
		_blocked()
		or units.is_empty()
		or get_tree().get_nodes_in_group("selected_units") != _ability_selection
	):
		cancel()
	elif is_instance_valid(_ability_range):
		if _ability_range.has_method("update_placement"):
			_ability_range.update_placement(units[0], engineering_angle)
		else:
			_ability_range.global_position = units[0].global_position + Vector3.UP * .08


func _commit_ability(point, target) -> bool:
	if get_tree().paused:
		prompt("Resume the battle to use abilities.")
		return false
	var units = ability_units(ability_id).filter(
		func(unit): return unit.abilities.get_ability(ability_id).is_ready()
	)
	if units.is_empty() or get_tree().get_nodes_in_group("selected_units") != _ability_selection:
		cancel()
		return false
	var unit = units[0]
	var ability = unit.abilities.get_ability(ability_id)
	if ability_id == "frag_grenade" and not unit.abilities._valid_breach(target):
		prompt("Choose a visible neutral building garrisoned by enemies.")
		return false
	if ability.target_type == "target_unit" and target != null:
		if ability_id == "frag_grenade":
			if (
				not is_instance_valid(target)
				or not target.has_method("evacuate_breached")
				or not unit.abilities._valid_breach(target)
			):
				prompt("Choose an occupied enemy building to breach.")
				return false
		elif (
			not is_instance_valid(target)
			or not target is Node3D
			or not "player" in target
			or not "hp" in target
			or not hud.get_parent().battlefield.is_observed(unit.player, target)
		):
			prompt("Choose a visible enemy target.")
			return false
		point = target.global_position
	elif ability.target_type == "target_unit" and not ability.accepts_target_point:
		if ability_id == "frag_grenade":
			prompt("Choose an occupied enemy building to breach.")
		else:
			prompt("Choose a visible enemy target.")
		return false
	else:
		target = null
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
	# A farther first-selected unit must never hide a closer ready caster.
	var candidates = units.filter(
		func(candidate): return candidate.abilities.can_trigger(ability_id, point, target)
	)
	candidates.sort_custom(
		func(a, b):
			var left = ((a.global_position - point) * Vector3(1, 0, 1)).length_squared()
			var right = ((b.global_position - point) * Vector3(1, 0, 1)).length_squared()
			return (
				left < right
				if not is_equal_approx(left, right)
				else a.get_instance_id() < b.get_instance_id()
			)
	)
	if candidates.is_empty():
		prompt(tr("Choose a legal target within %.1f m.") % ability.range)
		return false
	unit = candidates[0]
	ability = unit.abilities.get_ability(ability_id)
	var accepted = false
	if ability_id == "dismantle_barrier":
		accepted = hud.get_parent().engineering.request_dismantle(
			unit, target, Bindings.held("shift_selecting")
		)
	elif ability_id in ENGINEERING_OPERATIONS:
		var operation = ENGINEERING_OPERATIONS[ability_id]
		accepted = hud.get_parent().engineering.request(
			unit, operation, point, engineering_angle, Bindings.held("shift_selecting")
		)
	else:
		accepted = unit.abilities.trigger(ability_id, point, target)
	if not accepted:
		if ability_id == "dismantle_barrier":
			prompt("Choose one of your field barricades.")
		elif ability_id == "frag_grenade":
			prompt("Choose an occupied enemy building to breach.")
		elif ability_id in ENGINEERING_OPERATIONS and ability_id != "sweep_mines":
			prompt(
				hud.get_parent().engineering.placement_error(
					unit, ENGINEERING_OPERATIONS[ability_id], point, engineering_angle
				)
			)
		else:
			prompt(tr("Choose a legal target within %.1f m.") % ability.range)
		return false
	last_cast = {"ability": ability_id, "unit": weakref(unit)}
	var title = ability.name
	cancel()
	hud.show_notice(tr(title))
	return true


## One synchronous HUD refresh may share this state. Action handlers always
## request a new state so selection, deaths and weapon changes are read live.
func eligibility_state() -> Dictionary:
	return {"selected": get_tree().get_nodes_in_group("selected_units")}


func _mobile_eligible(unit) -> bool:
	return (
		is_instance_valid(unit)
		and not unit.is_queued_for_deletion()
		and unit.is_in_group("controlled_units")
		and unit.hp > 0
		and unit.manual_orders != null
		and unit.movement_speed > 0
	)


## Buttons need existence, not a complete army/order list. In particular, avoid
## evaluating every selected unit's movement modifiers just to enable Move.
func has_eligible(command, state: Dictionary = {}) -> bool:
	if state.is_empty():
		state = eligibility_state()
	var combat = command not in ["move", "guard", "follow", "patrol"]
	var key = "has_armed" if combat else "has_mobile"
	if not state.has(key):
		state[key] = false
		for unit in state.selected:
			if not _mobile_eligible(unit):
				continue
			if (
				combat
				and (unit.attack_range == null or (unit.has_method("armed") and not unit.armed()))
			):
				continue
			state[key] = true
			break
	return state[key]


func eligible(command, state: Dictionary = {}):
	if state.is_empty():
		state = eligibility_state()
	if not state.has("mobile"):
		state.mobile = state.selected.filter(_mobile_eligible)
	var mobile = state.mobile
	if command in ["move", "guard", "follow", "patrol"]:
		return mobile
	if not state.has("armed"):
		state.armed = mobile.filter(
			func(unit):
				return unit.attack_range != null and (not unit.has_method("armed") or unit.armed())
		)
	var armed = state.armed
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


func cargo_return_state(eligibility: Dictionary = {}):
	if eligibility.is_empty():
		eligibility = eligibility_state()
	var loaded = eligibility.selected.filter(
		func(unit):
			return (
				is_instance_valid(unit)
				and unit.is_in_group("controlled_units")
				and unit.type == "Worker"
				and unit.resource_a + unit.resource_b > 0
				and _mobile_eligible(unit)
			)
	)
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


func recovery_state(eligibility: Dictionary = {}):
	if eligibility.is_empty():
		eligibility = eligibility_state()
	var wounded = eligibility.selected.filter(
		func(unit):
			return (
				is_instance_valid(unit)
				and unit.is_in_group("controlled_units")
				and unit.hp < unit.hp_max
				and _mobile_eligible(unit)
			)
	)
	var orders = []
	var missing = {}
	var services = {}
	var titles = {}
	var repair_sites = []
	if not wounded.is_empty():
		var sites = load("res://source/match/world/PointOfInterestCatalog.gd").sites(
			hud.get_parent()
		)
		repair_sites = sites.filter(func(site): return site.kind == "repair")
	for unit in wounded:
		var role = Repairs.facility_for_role(unit.type)
		var key = [unit.player, role]
		if not services.has(key):
			# Membership is indexed by the owner; completion, HP, capture and
			# service activation are revalidated for this refresh, never cached.
			services[key] = (unit.player.structure_candidates(role) + repair_sites).filter(
				func(facility): return Repairs.facility_eligible(facility, unit)
			)
		var nearest = null
		var distance = INF
		for facility in services[key]:
			var candidate = Utils.Match.Unit.Movement.path_distance_to(
				unit, facility.global_position_yless, Recover.ARRIVAL_RANGE
			)
			if candidate < distance:
				nearest = facility
				distance = candidate
		if nearest != null:
			orders.append([unit, Orders.target_order("recover", nearest)])
		else:
			if not titles.has(key):
				titles[key] = Factions.title(unit.player.faction, role)
			var title = titles[key]
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
	ability_id = ""
	_ability_selection.clear()
	if is_instance_valid(_ability_range):
		_ability_range.hide()
		if _ability_range.get_parent() != null:
			_ability_range.get_parent().remove_child(_ability_range)
		_ability_range.queue_free()
	_ability_range = null
	set_process(false)
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
	if kind == "commander":
		hud._assignment_hint.text = (
			(tr("Commander support: choose a target.") if message.is_empty() else tr(message))
			+ " [Esc]"
		)
		return
	if kind == "ability":
		var units = ability_units(ability_id)
		var title = (
			tr(units[0].abilities.get_ability(ability_id).name)
			if not units.is_empty()
			else tr("Ability")
		)
		hud._assignment_hint.text = (
			(title + ": " + tr("choose a target in range.") if message.is_empty() else tr(message))
			+ " %s / right-click cancels." % Bindings.label("toggle_match_menu")
		)
		if ability_id in ENGINEERING_ROTATION:
			hud._assignment_hint.text += (
				" " + tr("Rotate") + " [%s]" % Bindings.label("rotate_structure")
			)
		return
	hud._assignment_hint.text = (
		(
			(
				"Follow: choose a friendly unit."
				if kind == "follow"
				else (
					(
						tr("Force attack: choose a damageable unit or building.")
						if kind == "force_attack"
						else tr("Attack: choose an enemy, or empty ground to attack move.")
					)
					if kind in ["attack", "force_attack", "follow"]
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
	if event is InputEventKey:
		var focus = get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return false
		if not kind.is_empty() and Bindings.pressed(event, "toggle_match_menu"):
			cancel()
			get_viewport().set_input_as_handled()
			return true
		if Bindings.pressed(event, "stop_order"):
			var menus = hud.get_parent().find_child("UnitMenus")
			if is_instance_valid(menus) and menus.has_method("_stop_orders"):
				menus._stop_orders()
			else:
				cancel()
			get_viewport().set_input_as_handled()
			return true
		if Bindings.pressed(event, "hold_order"):
			var card = hud.get_parent().find_child("CommandCard")
			if is_instance_valid(card) and card.has_method("_on_hold"):
				card._on_hold()
			cancel()
			get_viewport().set_input_as_handled()
			return true
		if (
			kind == "ability"
			and ability_id in ENGINEERING_ROTATION
			and Bindings.pressed(event, "rotate_structure")
		):
			engineering_angle = fmod(engineering_angle + PI / 4.0, TAU)
			prompt(tr("Barricade angle · %d°") % roundi(rad_to_deg(engineering_angle)))
			get_viewport().set_input_as_handled()
			return true
		if (
			event.pressed
			and not event.echo
			and not event.ctrl_pressed
			and not event.alt_pressed
			and not event.meta_pressed
		):
			var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if code == KEY_G:
				var game = hud.get_parent()
				if (
					game != null
					and game.get("campaign_hero") != null
					and is_instance_valid(game.campaign_hero)
					and game.campaign_hero.alive()
				):
					if get_tree().paused:
						hud.show_notice("Resume the battle to use abilities.")
					elif game.campaign_hero.cooldown > 0.0:
						hud.show_notice("Cooling down")
					else:
						game.campaign_hero.activate()
						hud.show_notice(tr(game.campaign_hero.title()))
					get_viewport().set_input_as_handled()
					return true
			var key = {KEY_Q: "Q", KEY_W: "W", KEY_E: "E", KEY_R: "R", KEY_T: "T", KEY_Y: "Y"}.get(
				code, ""
			)
			var id = ability_for_key(key) if not key.is_empty() else ""
			var placement = hud.get_parent()._get_human_player().get_node(
				"StructurePlacementHandler"
			)
			if not id.is_empty() and not placement._structure_placement_started():
				activate_ability(id)
				get_viewport().set_input_as_handled()
				return true
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
		var target = (
			hud._pick_unit(event.position)
			if kind in ["attack", "force_attack", "follow", "ability"]
			else null
		)
		commit(point, target, Bindings.held("shift_selecting"))
	return true


func commit(point, target, append):
	if kind.is_empty() or _blocked():
		return false
	if kind == "ability":
		return _commit_ability(point, target)
	if kind == "commander":
		var game = hud.get_parent()
		var player = game._get_human_player()
		if not game.commander_support.activate(player, point):
			var issue = game.commander_support.disabled_reason(player)
			if issue.is_empty():
				issue = game.commander_support.target_error(player, point)
			prompt(issue if not issue.is_empty() else "Resume the battle to use abilities.")
			return false
		cancel()
		return true
	if kind == "attack" and target == null:
		kind = "attack_move"
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
	elif kind in ["attack", "force_attack"]:
		if (
			not is_instance_valid(target)
			or target.is_queued_for_deletion()
			or not (
				target.is_in_group("units")
				or target.is_in_group("neutral_targets")
				or target.is_in_group("points_of_interest")
			)
			or not hud.get_parent().battlefield.is_observed(units[0].player, target)
		):
			prompt("Choose a visible enemy or neutral target.")
			return false
		for unit in units:
			var forced = kind == "force_attack" or target.is_in_group("field_mines")
			if Rules.can_target(unit, target, forced):
				orders.append(
					[unit, Orders.target_order("force_attack" if forced else kind, target)]
				)
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
		var cohort = Cohesion.new(units)
		var heading = (
			(point - Utils.Match.Unit.Movement.calculate_aabb_crowd_pivot_yless(units)).normalized()
		)
		var routes = Planner.funnel_routes(units, point, heading, Planner.posture(units))
		for domain in [
			Constants.Match.Navigation.Domain.TERRAIN, Constants.Match.Navigation.Domain.AIR
		]:
			var members = units.filter(func(unit): return unit.movement_domain == domain)
			for pair in Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(
				members, point, null, Planner.posture(units)
			):
				var order_kind = kind
				if kind == "guard" or (kind == "attack_move" and pair[0].attack_range == null):
					order_kind = "move"
				var order = Orders.point_order(order_kind, pair[1])
				order.cohort = cohort
				order.waypoints = routes.get(pair[0], [])
				orders.append([pair[0], order])
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

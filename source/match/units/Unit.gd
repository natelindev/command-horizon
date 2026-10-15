extends Area3D

signal selected
signal deselected
signal hp_changed
signal action_changed(new_action)
signal action_updated
signal stance_changed(new_stance)

enum Stance { AGGRESSIVE, DEFENSIVE, HOLD_POSITION, HOLD_FIRE }

const MATERIAL_ALBEDO_TO_REPLACE = Color(0.99, 0.81, 0.48)
const MATERIAL_ALBEDO_TO_REPLACE_EPSILON = 0.05

var stance = Stance.AGGRESSIVE:
	set = _set_stance

var hp = null:
	set = _set_hp
var base_hp_max = null
var hp_max = null:
	set = _set_hp_max
var last_enemy_damage_time = -INF
var attack_damage = null
var attack_interval = null
var attack_range = null
var attack_domains = []
var aim_target = null
var weapon_charge_progress = -1.0
var weapon_charge_owner = null
var signature = null
var radius:
	get = _get_radius
var movement_domain:
	get = _get_movement_domain
var movement_speed:
	get = _get_movement_speed
var sight_range = null
var player:
	get:
		return get_parent()
var color:
	get:
		return player.color
var action = null:
	set = _set_action
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)
var type:
	get = _get_type

var program_squad = null
var manual_orders = null
var program = null
var _action_locked = false
var _cached_type = ""

@onready var _match = find_parent("Match")


func _ready():
	if _match != null and not _match.is_node_ready():
		await _match.ready
	if player != null:
		_setup_color()
		if has_node("Movement"):
			add_child(load("res://source/match/units/traits/TeamFootprint.gd").new(self))
	_setup_default_properties_from_constants()
	load("res://source/match/FactionCatalog.gd").apply_stats(self)
	base_hp_max = hp_max
	# Completed armor research scales the final base stats, so apply it last.
	if player != null and player.technology != null:
		player.technology.apply_unit(self)
	if (
		player != null
		and (type == "AdvancedTank" or (type == "CombatRobot" and player.faction == "helix"))
	):
		var preparation_visual = load("res://source/match/effects/WeaponPreparationVisual.gd").new()
		preparation_visual.name = "WeaponPreparationVisual"
		add_child(preparation_visual)
	if _match != null:
		assert(_safety_checks())
	if movement_speed > 0:
		manual_orders = load("res://source/match/orders/ManualOrders.gd").new()
		manual_orders.name = "ManualOrders"
		add_child(manual_orders)
	if (
		player.get_meta("skirmish", false)
		and type in ["Tank", "AdvancedTank", "CombatRobot", "RepairRobot", "Drone", "Helicopter"]
	):
		program = load("res://source/match/programs/UnitProgram.gd").new()
		program.name = "UnitProgram"
		add_child(program)
		if type in ["Tank", "AdvancedTank", "CombatRobot"]:
			signature = load("res://source/match/combat/SignatureState.gd").new()
			signature.name = "SignatureState"
			add_child(signature)


func receive_weapon_hit(source):
	var amount = load("res://source/match/combat/CombatRules.gd").damage(source, self)
	if amount > 0:
		last_enemy_damage_time = _match.simulation_time
		_match.combat_effects.impact(self, source, global_position + Vector3.UP * 0.5)
		var visuals = get_node_or_null("BastionVisuals")
		if visuals != null:
			visuals.hit_reaction(source.global_position)
		hp -= amount
		MatchSignals.unit_weapon_hit.emit(self, source)


func weapon_delay():
	return 0.0


func is_revealing():
	return is_in_group("revealed_units") and visible


func _set_hp(value):
	var old_hp = hp
	hp = max(0, value)
	if old_hp != null and hp < old_hp:
		MatchSignals.unit_damaged.emit(self)
	hp_changed.emit()
	if hp == 0:
		_handle_unit_death()


func _set_hp_max(value):
	hp_max = value
	hp_changed.emit()


func _get_radius():
	var movement = get_node_or_null("Movement")
	if movement != null:
		return movement.radius
	var obstacle = get_node_or_null("MovementObstacle")
	return obstacle.radius if obstacle != null else null


func _get_movement_domain():
	var movement = get_node_or_null("Movement")
	if movement != null:
		return movement.domain
	var obstacle = get_node_or_null("MovementObstacle")
	return obstacle.domain if obstacle != null else null


func _get_movement_speed():
	var movement = get_node_or_null("Movement")
	return movement.speed if movement != null else 0.0


func _is_movable():
	return _get_movement_speed() > 0.0


func _setup_color():
	var material = player.get_color_material()
	Utils.Match.traverse_node_tree_and_replace_materials_matching_albedo(
		find_child("Geometry"),
		MATERIAL_ALBEDO_TO_REPLACE,
		MATERIAL_ALBEDO_TO_REPLACE_EPSILON,
		material,
		true
	)


func _set_action(action_node):
	if not is_inside_tree() or _action_locked:
		if action_node != null:
			action_node.queue_free()
		return
	_action_locked = true
	_teardown_current_action()
	action = action_node
	if action != null:
		var action_copy = action  # bind() performs copy itself, but lets force copy just in case
		action.tree_exited.connect(_on_action_node_tree_exited.bind(action_copy))
		add_child(action_node)
	_action_locked = false
	action_changed.emit(action)


func _get_type():
	if _cached_type != "":
		return _cached_type
	var unit_script_path = get_script().resource_path
	var unit_file_name = unit_script_path.substr(unit_script_path.rfind("/") + 1)
	_cached_type = unit_file_name.split(".")[0]
	return _cached_type


func _teardown_current_action():
	if action != null and action.is_inside_tree():
		action.queue_free()
		remove_child(action)  # triggers _on_action_node_tree_exited immediately


func _safety_checks():
	if movement_domain == Constants.Match.Navigation.Domain.AIR:
		assert(
			(
				radius < Constants.Match.Air.Navmesh.MAX_AGENT_RADIUS
				or is_equal_approx(radius, Constants.Match.Air.Navmesh.MAX_AGENT_RADIUS)
			),
			"Unit radius exceeds the established limit"
		)
	elif movement_domain == Constants.Match.Navigation.Domain.TERRAIN:
		assert(
			(
				not _is_movable()
				or (
					radius < Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
					or is_equal_approx(radius, Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS)
				)
			),
			"Unit radius exceeds the established limit"
		)
	return true


func _handle_unit_death():
	if is_queued_for_deletion():
		return
	MatchSignals.unit_destroying.emit(self)
	if _match != null and _match.combat_effects != null:
		_match.combat_effects.destruction(self)
	tree_exited.connect(func(): MatchSignals.unit_died.emit(self))
	queue_free()


func _setup_default_properties_from_constants():
	var key = get_script().resource_path.replace(".gd", ".tscn")
	if not Constants.Match.Units.DEFAULT_PROPERTIES.has(key):
		return
	var default_properties = Constants.Match.Units.DEFAULT_PROPERTIES[key]
	for property in default_properties:
		set(property, default_properties[property])


func _on_action_node_tree_exited(action_node):
	assert(action_node == action, "unexpected action released")
	action = null


func issue_manual_order(order):
	if manual_orders != null:
		manual_orders.cancel()
	if program != null:
		program.manual_override()
	action = order


func _set_stance(new_stance):
	if stance != new_stance:
		stance = new_stance
		stance_changed.emit(stance)


func cycle_stance() -> int:
	var next = (int(stance) + 1) % 4
	stance = next
	return stance


func stance_name() -> String:
	match stance:
		Stance.AGGRESSIVE:
			return "Aggressive"
		Stance.DEFENSIVE:
			return "Defensive"
		Stance.HOLD_POSITION:
			return "Hold Position"
		Stance.HOLD_FIRE:
			return "Hold Fire"
	return "Aggressive"

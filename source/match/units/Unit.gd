extends Area3D

signal selected
signal deselected
signal hp_changed
signal action_changed(new_action)
signal action_updated
signal stance_changed(new_stance)
signal veterancy_changed

enum Stance { AGGRESSIVE, DEFENSIVE, HOLD_POSITION, HOLD_FIRE }

const MATERIAL_ALBEDO_TO_REPLACE = Color(0.99, 0.81, 0.48)
const MATERIAL_ALBEDO_TO_REPLACE_EPSILON = 0.05
const Veterancy = preload("res://source/match/combat/Veterancy.gd")

var experience = 0.0:
	set(value):
		var previous_rank = veterancy_rank
		experience = clampf(value, 0.0, Veterancy.MAX_EXPERIENCE) if is_finite(value) else 0.0
		_veterancy_rank = Veterancy.rank_for(experience)
		if veterancy_rank != previous_rank:
			veterancy_speed_factor = Veterancy.speed_factor(_veterancy_rank)
			veterancy_reload_factor = Veterancy.reload_factor(_veterancy_rank)
			var badge = get_node_or_null("VeteranBadge")
			if badge != null:
				badge.refresh()
			veterancy_changed.emit()
var veterancy_rank:
	get:
		return _veterancy_rank
# Derived only from experience; movement and weapon queries read them directly.
var veterancy_speed_factor: float = 1.0
var veterancy_reload_factor: float = 1.0

var stance = Stance.AGGRESSIVE:
	set = _set_stance

var hp = null:
	set = _set_hp
var base_hp_max = null
var hp_max = null:
	set = _set_hp_max
var last_enemy_damage_time = -INF
var attack_damage = null
var attack_interval = null:
	get:
		return attack_interval * veterancy_reload_factor if attack_interval != null else null
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

var manual_orders = null
var _action_locked = false
var _cached_type = ""
var _navigation_trait = null
var _veterancy_rank = 0
var _terrain_navigation = null
var _has_elevated_terrain = false
var _terrain_position = Vector2.INF
var _plateau_advantage = false

@onready var _match = find_parent("Match")


func _enter_tree():
	var game = find_parent("Match")
	if game != null and game.has_method("invalidate_unit_registry"):
		game.invalidate_unit_registry()
		# Exit callbacks can rebuild a snapshot before group membership is removed.
		tree_exited.connect(game.invalidate_unit_registry, CONNECT_ONE_SHOT)


func _exit_tree():
	var game = find_parent("Match")
	if game != null and game.has_method("invalidate_unit_registry"):
		game.invalidate_unit_registry()


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
		and (
			type in ["AdvancedTank", "RocketInfantry"]
			or (type == "CombatRobot" and player.faction == "helix")
		)
	):
		var preparation_visual = load("res://source/match/effects/WeaponPreparationVisual.gd").new()
		preparation_visual.name = "WeaponPreparationVisual"
		add_child(preparation_visual)
	if _match != null:
		assert(_safety_checks())
	if movement_speed > 0:
		if attack_damage != null and attack_damage > 0:
			add_child(load("res://source/match/units/traits/VeteranBadge.gd").new(self))
		manual_orders = load("res://source/match/orders/ManualOrders.gd").new()
		manual_orders.name = "ManualOrders"
		add_child(manual_orders)
	if player.get_meta("skirmish", false) and type in ["Tank", "AdvancedTank", "CombatRobot"]:
		signature = load("res://source/match/combat/SignatureState.gd").new()
		signature.name = "SignatureState"
		add_child(signature)


func receive_weapon_hit(source):
	receive_damage(source, _rules().damage(source, self))


# A projectile arrival. Damage uses the round's frozen weapon facts; splash
# passes the share of full damage that reached this body.
func receive_shot(shot, point = null, share = 1.0, presentation_weapon = {}):
	receive_damage(
		shot.feedback_source(), _rules().damage_from(shot, self) * share, point, presentation_weapon
	)


func receive_damage(source, amount, point = null, presentation_weapon = {}):
	if amount > 0 and hp > 0:
		var actual_damage = minf(amount, hp)
		Veterancy.award(source, self, actual_damage, amount >= hp)
		last_enemy_damage_time = _match.simulation_time
		_match.combat_effects.impact(
			self,
			source,
			point if point != null else global_position + Vector3.UP * 0.5,
			presentation_weapon
		)
		var visuals = get_node_or_null("BastionVisuals")
		if visuals != null:
			visuals.hit_reaction(source.global_position)
		hp -= amount
		MatchSignals.unit_weapon_hit.emit(self, source)


func terrain_advantage() -> bool:
	if _terrain_navigation == null:
		if _match == null or not _match.is_node_ready():
			return false
		_terrain_navigation = _match.navigation.terrain
		_has_elevated_terrain = _match.map.is_elevated()
	# Match terrain is immutable. Flat maps need no per-unit trait/position query.
	if not _has_elevated_terrain:
		return false
	if movement_domain != Constants.Match.Navigation.Domain.TERRAIN or has_meta("garrison_host"):
		return false
	var point = Vector2(global_position.x, global_position.z)
	# Authored terrain is immutable during a battle. Reuse the exact-position
	# result across sight, target acquisition and HUD queries; moving invalidates it.
	if point != _terrain_position:
		_terrain_position = point
		_plateau_advantage = _terrain_navigation.has_plateau_advantage(global_position)
	return _plateau_advantage


func effective_sight_range():
	if sight_range == null:
		return 0.0
	return sight_range + (minf(3.0, sight_range * 0.2) if terrain_advantage() else 0.0)


# Loaded at runtime: preloading combat rules here compiles autoload-dependent
# scripts before the autoloads exist.
static func _rules():
	return load("res://source/match/combat/CombatRules.gd")


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


# Radius/domain are live trait properties; resolve their fixed node only once.
# These getters also run before _ready while faction models are prepared.
func _get_navigation_trait():
	if not is_instance_valid(_navigation_trait):
		_navigation_trait = get_node_or_null("Movement")
		if _navigation_trait == null:
			_navigation_trait = get_node_or_null("MovementObstacle")
	return _navigation_trait


func _get_radius():
	var navigation_trait = _get_navigation_trait()
	return navigation_trait.radius if navigation_trait != null else null


func _get_movement_domain():
	var navigation_trait = _get_navigation_trait()
	return navigation_trait.domain if navigation_trait != null else null


func _get_movement_speed():
	var navigation_trait = _get_navigation_trait()
	return navigation_trait.speed if navigation_trait is NavigationAgent3D else 0.0


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
	action = _adapt_action(action_node)
	if action != null:
		var action_copy = action  # bind() performs copy itself, but lets force copy just in case
		action.tree_exited.connect(_on_action_node_tree_exited.bind(action_copy))
		add_child(action)
	_action_locked = false
	action_changed.emit(action)


# Every order source assigns actions through `action`. Units whose movement
# cannot use the generic actions (aircraft that cannot hover) replace them here;
# callers that keep a reference must read `unit.action` after assignment.
func _adapt_action(action_node):
	return action_node


# The domain weapons see. Aircraft on the ground are ground targets even though
# they navigate in the air domain.
func combat_domain():
	return movement_domain


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

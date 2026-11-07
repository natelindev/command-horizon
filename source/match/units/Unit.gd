# gdlint: disable=duplicated-load,max-public-methods
# Runtime loading avoids autoload-dependent preload cycles.
extends Area3D

signal selected
signal deselected
signal hp_changed
signal shields_changed
signal action_changed(new_action)
signal action_updated
signal stance_changed(new_stance)
signal veterancy_changed

enum Stance { AGGRESSIVE, DEFENSIVE, HOLD_POSITION, HOLD_FIRE }

const MATERIAL_ALBEDO_TO_REPLACE = Color(0.99, 0.81, 0.48)
const MATERIAL_ALBEDO_TO_REPLACE_EPSILON = 0.05
const Veterancy = preload("res://source/match/combat/Veterancy.gd")
const SignatureState = preload("res://source/match/combat/SignatureState.gd")
const UnitAbilities = preload("res://source/match/units/traits/UnitAbilities.gd")
const InfantrySuppression = preload("res://source/match/units/traits/InfantrySuppression.gd")
const Bastion = preload("res://source/match/BastionCatalog.gd")
const ShieldComponent = preload("res://source/match/units/traits/ShieldComponent.gd")

var experience: float = 0.0:
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
var veterancy_rank: int:
	get:
		return _veterancy_rank
# Derived only from experience; movement and weapon queries read them directly.
var veterancy_speed_factor: float = 1.0:
	set(value):
		veterancy_speed_factor = value
		if _native_state != null:
			_native_state.veterancy_speed = value
var veterancy_reload_factor: float = 1.0:
	set(value):
		veterancy_reload_factor = value
		if _native_state != null:
			_native_state.veterancy_reload = value

var stance = Stance.AGGRESSIVE:
	set = _set_stance

var hp = null:
	set = _set_hp
var base_hp_max = null
var hp_max = null:
	set = _set_hp_max
var last_enemy_damage_time: float = -INF
var shield_component: ShieldComponent = ShieldComponent.new()
# Keep the public unit/save/HUD interface while the trait owns shield state.
var shields: float:
	get:
		return shield_component.charge
	set(value):
		shield_component.charge = value
var shields_max: float:
	get:
		return shield_component.capacity
	set(value):
		shield_component.capacity = value
var last_shield_damage_time: float:
	get:
		return shield_component.last_damage_time
	set(value):
		shield_component.last_damage_time = value
var battlefield_salvage = null
var garrison_mount = null
var optical_cloak = null
var occupants:
	get:
		return garrison_mount.occupants if garrison_mount != null else []
var scrap_hardened_tiers: int = 0:
	set(value):
		scrap_hardened_tiers = value
		if _native_state != null:
			_native_state.scrap_tiers = value
var scrap_hardened_left: float = 0.0
var permanent_scrap_rank: int = 0
var damage_visual_band: int = 0
var regarrison_lock_left: float = 0.0
var suppression: InfantrySuppression:
	set(value):
		suppression = value
		if _native_state != null:
			_native_state.suppression = value
var attack_damage = null:
	set(value):
		attack_damage = value
		_base_attack_damage = value
		if _native_state != null:
			_native_state.base_damage = value
	get:
		if _native_state != null:
			return _native_state.attack_damage
		if attack_damage == null:
			return null
		var factor = abilities.damage_factor() if abilities != null else 1.0
		return attack_damage * factor * (1.0 + 0.15 * scrap_hardened_tiers)
var attack_interval = null:
	set(value):
		attack_interval = value
		_base_attack_interval = value
		if _native_state != null:
			_native_state.base_interval = value
	get:
		if _native_state != null:
			return _native_state.attack_interval
		return (
			(
				attack_interval
				* veterancy_reload_factor
				* (suppression.reload_factor() if suppression != null else 1.0)
			)
			if attack_interval != null
			else null
		)
var attack_range = null:
	set(value):
		attack_range = value
		_base_attack_range = value
		if _native_state != null:
			_native_state.base_range = value
	get:
		if _native_state != null:
			return _native_state.attack_range
		return (
			attack_range * abilities.range_factor()
			if attack_range != null and abilities != null
			else attack_range
		)
var attack_domains = []:
	set(value):
		attack_domains = value
		if _native_state != null:
			_native_state.domains = value
var aim_target = null
var weapon_charge_progress: float = -1.0
var weapon_charge_owner = null
var signature: SignatureState:
	set(value):
		signature = value
		if _native_state != null:
			_native_state.signature = value
var abilities: UnitAbilities:
	set(value):
		abilities = value
		if _native_state != null:
			_native_state.abilities = value
var radius:
	get = _get_radius
var movement_domain:
	get = _get_movement_domain
var movement_speed: float:
	get = _get_movement_speed
var sight_range = null:
	set(value):
		sight_range = value
		if _native_state != null:
			_native_state.sight_range = value
var player:
	get:
		return get_parent()
var color:
	get:
		return player.color
var action = null:
	set = _set_action
var global_position_yless: Vector3:
	get:
		return global_position * Vector3(1, 0, 1)
var type: String:
	get = _get_type

var manual_orders = null
var _action_locked: bool = false
var _cached_type: String = ""
var _navigation_trait = null
var _veterancy_rank: int = 0
var _terrain_navigation = null
var _has_elevated_terrain: bool = false
var _terrain_position: Vector2 = Vector2.INF
var _plateau_advantage: bool = false
var _native_state: RefCounted
# Preserve unmodified inputs for cold binding/rebinding. Native queries read
# resident values; setters publish changes before gameplay signals fire.
var _base_attack_damage = null
var _base_attack_interval = null
var _base_attack_range = null

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
	shield_component.changed.connect(func(): shields_changed.emit())
	if _match != null and not _match.is_node_ready():
		await _match.ready
	if player != null:
		_setup_color()
		if has_node("Movement"):
			add_child(load("res://source/match/units/traits/TeamFootprint.gd").new(self))
			if movement_domain != Constants.Match.Navigation.Domain.AIR:
				add_child(load("res://source/match/units/traits/UnitContactShadow.gd").new(self))
	_setup_default_properties_from_constants()
	load("res://source/match/FactionCatalog.gd").apply_stats(self)
	if _match != null and _match.combat_effects != null:
		_match.combat_effects.watch_unit(self)
	base_hp_max = hp_max
	var salvage_trait = load("res://source/match/units/traits/BattlefieldSalvage.gd")
	if salvage_trait.eligible(self):
		battlefield_salvage = salvage_trait.new(self)
		battlefield_salvage.name = "BattlefieldSalvage"
		add_child(battlefield_salvage)
	var mount_trait = load("res://source/match/units/traits/GarrisonMount.gd")
	if mount_trait.eligible(self):
		garrison_mount = mount_trait.new()
		garrison_mount.name = "GarrisonMount"
		add_child(garrison_mount)
	if player.faction == "helix" and type == "SniperInfantry":
		optical_cloak = load("res://source/match/units/traits/OpticalCloak.gd").new()
		optical_cloak.name = "OpticalCloak"
		add_child(optical_cloak)
		var cloak_visual = load("res://source/match/effects/OpticalCloakVisual.gd").new()
		cloak_visual.name = "OpticalCloakVisual"
		add_child(cloak_visual)
	load("res://source/match/units/traits/UnitOcclusion.gd").apply(self)
	# Completed armor research scales the final base stats, so apply it last.
	if player != null and player.technology != null:
		player.technology.apply_unit(self)
	var pressure_trait = InfantrySuppression
	if pressure_trait.eligible(self):
		suppression = pressure_trait.new()
		suppression.name = "InfantrySuppression"
		add_child(suppression)
		add_child(load("res://source/match/units/traits/SuppressionBadge.gd").new(self))
	var definitions = ability_definitions()
	if _match != null and "engineering" in _match and _match.engineering != null:
		definitions.append_array(_match.engineering.ability_definitions(self))
	if not definitions.is_empty():
		abilities = UnitAbilities.new()
		abilities.name = "UnitAbilities"
		add_child(abilities)
		abilities.setup(definitions)
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
		if _match.unit_state_store != null:
			_native_state = load("res://source/match/NativeUnitState.gd").bind(
				self, _match.unit_state_store
			)
	if movement_speed > 0:
		if attack_damage != null and attack_damage > 0:
			add_child(load("res://source/match/units/traits/VeteranBadge.gd").new(self))
		manual_orders = load("res://source/match/orders/ManualOrders.gd").new()
		manual_orders.name = "ManualOrders"
		add_child(manual_orders)
	if player.get_meta("skirmish", false) and type in ["Tank", "AdvancedTank", "CombatRobot"]:
		signature = SignatureState.new()
		signature.name = "SignatureState"
		add_child(signature)


func ability_definitions() -> Array:
	return []


func update_shields():
	var maximum = load("res://source/match/research/TechnologyCatalog.gd").shield_capacity(
		type, player.faction, player.technology.completed
	)
	shield_component.recharge_delay = (
		3.0
		if player.faction == "helix" and "plasma_shields" in player.technology.completed
		else 5.0
	)
	shield_component.set_capacity(maximum)


func _physics_process(delta):
	regarrison_lock_left = maxf(0.0, regarrison_lock_left - delta)
	if battlefield_salvage != null:
		battlefield_salvage.tick(delta)
	if _match == null or hp == null or hp <= 0 or shields_max <= 0 or shields >= shields_max:
		return
	if _match.simulation_time - shield_component.last_damage_time < shield_component.recharge_delay:
		return
	var factor = (
		_match.helix_support.shield_factor(self)
		if "helix_support" in _match and _match.helix_support != null
		else 1.0
	)
	shield_component.tick(delta, _match.simulation_time, factor)


func receive_weapon_hit(source):
	var weapons = load("res://source/match/combat/WeaponCatalog.gd")
	var weapon = weapons.profile(source, self)
	if (
		suppression != null
		and _rules().can_receive(source, self)
		and not load("res://source/match/Players.gd").allied(source.player, player)
	):
		suppression.add_pressure(weapons.suppression_hit(weapon, source.player))
	receive_damage(source, _rules().damage(source, self), null, weapon)


# A projectile arrival. Damage uses the round's frozen weapon facts; splash
# passes the share of full damage that reached this body.
func receive_shot(shot, point = null, share = 1.0, presentation_weapon = {}):
	receive_damage(
		shot.feedback_source(), _rules().damage_from(shot, self) * share, point, presentation_weapon
	)


func receive_damage(source, amount, point = null, presentation_weapon = {}):
	if amount > 0 and hp > 0:
		amount *= battlefield_salvage.damage_factor() if battlefield_salvage != null else 1.0
		if suppression != null:
			amount *= suppression.direct_damage_factor(presentation_weapon)
		last_enemy_damage_time = _match.simulation_time
		var impact_point = point if point != null else global_position + Vector3.UP * 0.5
		var before_shield = amount
		if presentation_weapon.get("shield_pierce", false):
			shield_component.last_damage_time = _match.simulation_time
		else:
			amount = shield_component.absorb(amount, _match.simulation_time)
		if amount < before_shield:
			if _match.combat_effects != null:
				_match.combat_effects.shield_impact(self, impact_point)
			if amount == 0:
				if _match.combat_audio != null:
					_match.combat_audio.impact(self, source, impact_point, presentation_weapon)
				# Damage-sensitive actions still react when the hull is protected.
				MatchSignals.unit_damaged.emit(self)
		var actual_damage = minf(amount, hp)
		Veterancy.award(source, self, actual_damage, amount >= hp)
		if amount > 0:
			if _match.combat_effects != null:
				_match.combat_effects.impact(self, source, impact_point, presentation_weapon)
			var visuals = get_node_or_null("BastionVisuals")
			if visuals != null:
				visuals.hit_reaction(
					source.global_position,
					(
						_match.combat_effects != null
						and _match.combat_effects.explosive_impact(source, presentation_weapon)
					)
				)
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


func effective_sight_range(target_point = null):
	if sight_range == null:
		return 0.0
	var downhill = target_point == null or global_position.y - target_point.y >= 1.5
	return sight_range * (1.3 if downhill and terrain_advantage() else 1.0)


func can_scavenge() -> bool:
	return battlefield_salvage != null and battlefield_salvage.can_scavenge()


func scavenge(wreck) -> bool:
	return battlefield_salvage != null and battlefield_salvage.scavenge(wreck)


func can_garrison(unit) -> bool:
	return garrison_mount != null and garrison_mount.can_garrison(unit)


func garrison_capacity() -> int:
	return garrison_mount.CAPACITY if garrison_mount != null else 0


func enter(unit, saved_slot = -1) -> bool:
	return garrison_mount != null and garrison_mount.enter(unit, saved_slot)


func leave(unit):
	if garrison_mount != null:
		garrison_mount.leave(unit)


func firing_origin(target_point) -> Vector3:
	return garrison_mount.firing_origin(target_point) if garrison_mount != null else global_position


# Loaded at runtime: preloading combat rules here compiles autoload-dependent
# scripts before the autoloads exist.
static func _rules():
	return load("res://source/match/combat/CombatRules.gd")


func weapon_delay():
	return 0.0


func is_revealing():
	if has_meta("garrison_host"):
		var host = get_meta("garrison_host")
		if is_instance_valid(host) and "garrison_mount" in host and host.garrison_mount != null:
			return host.is_revealing()
	return is_in_group("revealed_units") and visible


func _set_hp(value):
	var old_hp = hp
	hp = max(0, value)
	if _native_state != null:
		_native_state.hp = hp
	if old_hp != null and hp < old_hp:
		MatchSignals.unit_damaged.emit(self)
	hp_changed.emit()
	if hp == 0:
		_handle_unit_death()


func _set_hp_max(value):
	hp_max = value
	if _native_state != null:
		_native_state.hp_max = value
	hp_changed.emit()


# Radius/domain are live trait properties; resolve their fixed node only once.
# These getters also run before _ready while faction models are prepared.
func _get_navigation_trait():
	if not is_instance_valid(_navigation_trait):
		_navigation_trait = get_node_or_null("Movement")
		if _navigation_trait == null:
			_navigation_trait = get_node_or_null("MovementObstacle")
		if _native_state != null:
			_native_state.trait = _navigation_trait
			_native_state.domain = _navigation_trait.domain if _navigation_trait != null else null
	return _navigation_trait


func _get_radius():
	var navigation_trait = _get_navigation_trait()
	return navigation_trait.radius if navigation_trait != null else null


func _get_movement_domain():
	var navigation_trait = _get_navigation_trait()
	return navigation_trait.domain if navigation_trait != null else null


func _get_movement_speed() -> float:
	var base_speed: float
	if _native_state != null:
		base_speed = _native_state.speed()
	else:
		var navigation_trait = _get_navigation_trait()
		base_speed = navigation_trait.speed if navigation_trait is NavigationAgent3D else 0.0
	return base_speed


func movement_technology_factor() -> float:
	var owner_player = player
	if owner_player == null or owner_player.technology == null:
		return 1.0
	var completed = owner_player.technology.completed
	if completed.is_empty() or Bastion.is_infantry(type) or Bastion.is_aircraft(type):
		return 1.0
	if owner_player.faction == "frontier" and "high_octane" in completed:
		return 1.18
	if owner_player.faction == "helix" and "phase_thrusters" in completed:
		return 1.15
	if owner_player.faction == "bastion" and type == "Tank" and "iron_blitz" in completed:
		return 1.2
	return 1.0


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
		if has_meta("breach_pending"):
			action.process_mode = Node.PROCESS_MODE_DISABLED
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


func _get_type() -> String:
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
	if load("res://source/match/network/NetworkGate.gd").intercept_action(self, order):
		return
	if manual_orders != null:
		manual_orders.cancel()
	action = order


func _set_stance(new_stance):
	var gate = load("res://source/match/network/NetworkGate.gd")
	if gate.intercept(
		self, {"kind": "stance", "units": [gate.id_for(self)], "value": int(new_stance)}
	):
		return
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

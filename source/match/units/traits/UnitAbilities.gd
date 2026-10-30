# gdlint: disable=max-returns
extends Node

## Per-unit tactical ability state. Presentation and input can subscribe without
## owning cooldowns or changing base unit stats. All timers use simulation time.
signal ability_triggered(ability, target_point, target_unit)
signal ability_changed(ability)

const Players = preload("res://source/match/Players.gd")
const Terrain = preload("res://source/match/maps/terrain/TerrainModel.gd")

var abilities: Array = []
var _by_id: Dictionary = {}
var _siege_anchor: Ability
var _combat_sprint: Ability
@onready var unit = get_parent()


class Ability:
	extends RefCounted
	var id: String
	var name: String
	var description: String
	var key: String
	var target_type: String
	var cooldown: float
	var cooldown_left: float = 0.0
	var range: float
	var radius: float
	var is_active: bool = false
	var duration: float
	var active_left: float = 0.0
	var effect_position: Vector3 = Vector3.ZERO
	var accepts_target_point: bool = false
	var _manager: WeakRef

	func _init(manager, definition: Dictionary):
		_manager = weakref(manager)
		id = definition.id
		name = definition.name
		description = definition.description
		key = definition.key
		target_type = definition.target_type
		cooldown = definition.cooldown
		range = definition.get("range", 0.0)
		radius = definition.get("radius", 0.0)
		duration = definition.get("duration", 0.0)
		accepts_target_point = definition.get("accepts_target_point", false)

	func is_ready() -> bool:
		var manager = _manager.get_ref()
		return manager != null and cooldown_left <= 0.0 and manager.unit_available()

	func trigger(target_point: Vector3 = Vector3.INF, target_unit: Node = null) -> bool:
		var manager = _manager.get_ref()
		return manager != null and manager.trigger(id, target_point, target_unit)


func setup(definitions: Array):
	abilities.clear()
	_by_id.clear()
	for definition in definitions:
		assert(not _by_id.has(definition.id), "Duplicate unit ability")
		assert(definition.key in ["Q", "W", "E", "R"], "Invalid ability hotkey")
		assert(
			definition.target_type in ["instant", "target_point", "target_unit", "toggle"],
			"Invalid ability target type"
		)
		var ability = Ability.new(self, definition)
		abilities.append(ability)
		_by_id[ability.id] = ability
	_siege_anchor = _by_id.get("siege_anchor")
	_combat_sprint = _by_id.get("combat_sprint")
	set_physics_process(false)
	var game = unit.find_parent("Match")
	if game != null and game.combat_effects != null:
		game.combat_effects.watch_abilities(unit)


func get_ability(id: String):
	return _by_id.get(id)


func unit_available() -> bool:
	return (
		is_instance_valid(unit)
		and unit.is_inside_tree()
		and not unit.is_queued_for_deletion()
		and unit.hp != null
		and unit.hp > 0.0
		and (not unit.has_method("is_constructed") or unit.is_constructed())
		and not unit.has_meta("garrison_host")
	)


func availability_issue(id: String) -> String:
	var ability = get_ability(id)
	if ability == null or not unit_available():
		return "No selected unit has that ability ready."
	if ability.cooldown_left > 0.0:
		return "Ability is cooling down."
	if id in ["power_overdrive", "drone_chaff"]:
		return unit._match.helix_support.ability_issue(unit, id)
	if id == "scrap_mine" and not unit.player.has_completed_structure("CommandLab"):
		return "Complete a Relay workshop to deploy mines."
	if id == "field_barricade" and unit._match.engineering.cooldown_left(unit) > 0.0:
		return "Barricade deployment is cooling down."
	if (
		id in ["field_barricade", "scrap_mine"]
		and not unit.player.has_resources({"resource_a": 10 if id == "field_barricade" else 8})
	):
		return "Not enough Materials."
	return ""


func trigger(id: String, target_point: Vector3 = Vector3.INF, target_unit: Node = null) -> bool:
	var ability = get_ability(id)
	if ability == null or not ability.is_ready() or get_tree().paused:
		return false
	if ability.id == "dismantle_barrier":
		if not unit._match.engineering.can_service(unit, target_unit):
			return false
		target_point = target_unit.global_position
	elif ability.id == "frag_grenade":
		if (
			target_unit == null
			or not target_unit.has_method("evacuate_breached")
			or not _valid_breach(target_unit)
		):
			return false
		var radial = (unit.global_position - target_unit.global_position) * Vector3(1, 0, 1)
		target_point = target_unit.global_position + radial.normalized() * target_unit.radius
	elif ability.target_type == "target_unit":
		if target_unit != null:
			if not _valid_enemy(target_unit):
				return false
			target_point = target_unit.global_position
		elif not ability.accepts_target_point:
			return false
	if ability.target_type in ["target_unit", "target_point"]:
		if not target_point.is_finite() or not _in_range(ability, target_point):
			return false
		if ability.id == "frag_grenade" and not _throw_clear(target_point, target_unit):
			return false
	else:
		target_point = unit.global_position
	if not _execute(ability, target_point, target_unit):
		return false
	ability.cooldown_left = ability.cooldown
	_sync_smoke_group()
	set_physics_process(true)
	ability_triggered.emit(ability, target_point, target_unit)
	ability_changed.emit(ability)
	return true


func _in_range(ability, point: Vector3) -> bool:
	return (
		((point - unit.global_position) * Vector3(1, 0, 1)).length_squared()
		<= ability.range * ability.range
	)


func _valid_enemy(target) -> bool:
	# Explicit friendly-fire orders must never make abilities hurt allies.
	return (
		is_instance_valid(target)
		and target is Node3D
		and "player" in target
		and not Players.allied(unit.player, target.player)
		and load("res://source/match/combat/CombatRules.gd").can_receive(
			unit, target, target.is_in_group("destructible_obstacles")
		)
	)


func _execute(ability, point: Vector3, target: Node) -> bool:
	match ability.id:
		"frag_grenade":
			var game = unit.find_parent("Match")
			if game == null or game.grenade_system == null:
				return false
			return game.grenade_system.launch(
				unit,
				point,
				ability.radius,
				(
					target
					if is_instance_valid(target) and target.has_method("evacuate_breached")
					else null
				)
			)
		"dismantle_barrier":
			return unit._match.engineering.request_dismantle(unit, target)
		"power_overdrive":
			return unit._match.helix_support.toggle_overdrive(ability, unit)
		"drone_chaff":
			return unit._match.helix_support.activate_chaff(ability, unit)
		"field_barricade", "scrap_mine", "sweep_mines":
			var kind = {
				"field_barricade": "barricade", "scrap_mine": "mine", "sweep_mines": "sweep"
			}[ability.id]
			return unit._match.engineering.request(unit, kind, point)
		"combat_sprint", "smoke_screen", "shield_wall", "target_flare":
			ability.is_active = true
			ability.active_left = ability.duration
			# Smoke stays at its deployment point when the tank drives away;
			# flare illuminates its designated target area.
			ability.effect_position = (
				point if ability.id == "target_flare" else unit.global_position
			)
		"siege_anchor":
			ability.is_active = not ability.is_active
			if ability.is_active:
				var movement = unit.get_node_or_null("Movement")
				if movement != null:
					movement.stop()
		"guided_salvo", "emp_rocket":
			var game = unit.find_parent("Match")
			if game == null or game.projectile_system == null:
				return false
			var weapon_catalog = load("res://source/match/combat/WeaponCatalog.gd")
			var weapon = (
				weapon_catalog.EMP_ROCKET
				if ability.id == "emp_rocket"
				else weapon_catalog.GUIDED_SALVO
			)
			if game.projectile_system.launch(unit, target, weapon, Vector3.ZERO, point) == null:
				return false
			if ability.id == "emp_rocket" and is_instance_valid(target):
				if "shields" in target and target.shields > 0:
					target.shields = maxf(0.0, target.shields - 50.0)
					target.shields_changed.emit()
		_:
			return false
	return true


func _physics_process(delta: float):
	if not is_finite(delta) or delta <= 0.0:
		return
	var ticking = false
	for ability in abilities:
		var changed = ability.cooldown_left > 0.0 or ability.active_left > 0.0
		ability.cooldown_left = maxf(0.0, ability.cooldown_left - delta)
		if ability.active_left > 0.0:
			ability.active_left = maxf(0.0, ability.active_left - delta)
			if ability.active_left == 0.0:
				ability.is_active = false
		if changed:
			ability_changed.emit(ability)
		ticking = ticking or ability.cooldown_left > 0.0 or ability.active_left > 0.0
	set_physics_process(ticking)
	_sync_smoke_group()


func _sync_smoke_group():
	var smoke = get_ability("smoke_screen")
	if smoke != null and smoke.is_active and smoke.active_left > 0.0:
		add_to_group("active_smoke_screens")
	else:
		remove_from_group("active_smoke_screens")
	var flare = get_ability("target_flare")
	if flare != null and flare.is_active and flare.active_left > 0.0:
		add_to_group("active_target_flares")
	else:
		remove_from_group("active_target_flares")


func is_active(id: String) -> bool:
	var ability = get_ability(id)
	return ability != null and ability.is_active and unit_available()


func speed_factor() -> float:
	# Definitions stay fixed between setup calls. Retain the ability objects,
	# while reading their live state and availability on every modifier query.
	if _siege_anchor != null and _siege_anchor.is_active and unit_available():
		return 0.0
	var factor = 1.0
	if _combat_sprint != null and _combat_sprint.is_active and unit_available():
		factor *= 1.5
	var wall = get_ability("shield_wall")
	if wall != null and wall.is_active and unit_available():
		factor *= 0.7
	return factor


func range_factor() -> float:
	return 1.35 if _siege_anchor != null and _siege_anchor.is_active and unit_available() else 1.0


func damage_factor() -> float:
	return 1.3 if _siege_anchor != null and _siege_anchor.is_active and unit_available() else 1.0


## Snapshot-ready state, separate from definitions and scene references. The
## match save schema can opt into these records without serializing the trait.
func capture() -> Dictionary:
	var state = {}
	for ability in abilities:
		state[ability.id] = {
			"cooldown_left": ability.cooldown_left,
			"active_left": ability.active_left,
			"is_active": ability.is_active,
			"effect_position": ability.effect_position,
		}
	return state


func restore(state: Dictionary):
	var ticking = false
	for ability in abilities:
		var saved = state.get(ability.id, {})
		ability.cooldown_left = clampf(saved.get("cooldown_left", 0.0), 0.0, ability.cooldown)
		ability.active_left = clampf(saved.get("active_left", 0.0), 0.0, ability.duration)
		ability.is_active = (
			bool(saved.get("is_active", false))
			if ability.target_type == "toggle"
			else ability.active_left > 0.0
		)
		ability.effect_position = saved.get("effect_position", unit.global_position)
		ticking = ticking or ability.cooldown_left > 0.0 or ability.active_left > 0.0
		ability_changed.emit(ability)
	set_physics_process(ticking)
	_sync_smoke_group()


func _valid_breach(target) -> bool:
	var game = unit.find_parent("Match")
	return (
		is_instance_valid(target)
		and target.has_method("evacuate_breached")
		and target.hp > 0.0
		and not target.occupants.is_empty()
		and target.player != null
		and not Players.allied(unit.player, target.player)
		and game != null
		and game.battlefield.is_observed(unit.player, target)
	)


func _throw_clear(point: Vector3, target) -> bool:
	var game = unit.find_parent("Match")
	if game == null or game.battlefield == null:
		return false
	var start = unit.global_position + Vector3.UP * 0.8
	var end = point + Vector3.UP * 0.8
	if not game.battlefield.line_clear(start, end, unit, target):
		return false
	var terrain = game.map.terrain if "terrain" in game.map else null
	return terrain == null or _throw_terrain_clear(terrain, start, end)


func _throw_terrain_clear(terrain, start: Vector3, end: Vector3) -> bool:
	# Throw clearance is physical: the visibility endpoint allowance must not
	# permit short throws through an intervening wall or raised ground.
	var steps = maxi(1, ceili(start.distance_to(end) / 0.15))
	for index in range(steps + 1):
		var point = start.lerp(end, float(index) / steps)
		var flat = Vector2(point.x, point.z)
		var cell = terrain.cell_index(flat)
		if terrain.height_at(flat) > point.y:
			return false
		if terrain.flags[cell] & Terrain.SOLID and terrain.cover_tops[cell] > point.y:
			return false
	return true

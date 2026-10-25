extends Node

## Per-unit tactical ability state. Presentation and input can subscribe without
## owning cooldowns or changing base unit stats. All timers use simulation time.
signal ability_triggered(ability, target_point, target_unit)
signal ability_changed(ability)

var abilities: Array = []
var _by_id: Dictionary = {}
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


func trigger(id: String, target_point: Vector3 = Vector3.INF, target_unit: Node = null) -> bool:
	var ability = get_ability(id)
	if ability == null or not ability.is_ready() or get_tree().paused:
		return false
	if ability.target_type == "target_unit":
		if target_unit != null:
			if not _valid_enemy(target_unit):
				return false
			target_point = target_unit.global_position
		elif not ability.accepts_target_point:
			return false
	if ability.target_type in ["target_unit", "target_point"]:
		if not target_point.is_finite() or not _in_range(ability, target_point):
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
		and not load("res://source/match/Players.gd").allied(unit.player, target.player)
		and load("res://source/match/combat/CombatRules.gd").can_receive(
			unit, target, target.is_in_group("destructible_obstacles")
		)
	)


func _execute(ability, point: Vector3, target: Node) -> bool:
	match ability.id:
		"frag_grenade":
			var game = unit.find_parent("Match")
			if game == null or game.battlefield == null:
				return false
			for enemy in (
				game.battlefield.nearby_units(point, ability.radius)
				+ game.battlefield.nearby_obstacles(point, ability.radius)
			):
				if _valid_enemy(enemy):
					enemy.receive_damage(unit, 35.0, point, {"kind": "warhead"})
		"combat_sprint", "smoke_screen":
			ability.is_active = true
			ability.active_left = ability.duration
			# Smoke stays at its deployment point when the tank drives away.
			ability.effect_position = unit.global_position
		"siege_anchor":
			ability.is_active = not ability.is_active
			if ability.is_active:
				var movement = unit.get_node_or_null("Movement")
				if movement != null:
					movement.stop()
		"guided_salvo":
			var game = unit.find_parent("Match")
			if game == null or game.projectile_system == null:
				return false
			var weapon = load("res://source/match/combat/WeaponCatalog.gd").GUIDED_SALVO
			if game.projectile_system.launch(unit, target, weapon, Vector3.ZERO, point) == null:
				return false
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


func is_active(id: String) -> bool:
	var ability = get_ability(id)
	return ability != null and ability.is_active and unit_available()


func speed_factor() -> float:
	if is_active("siege_anchor"):
		return 0.0
	return 1.5 if is_active("combat_sprint") else 1.0


func range_factor() -> float:
	return 1.35 if is_active("siege_anchor") else 1.0


func damage_factor() -> float:
	return 1.3 if is_active("siege_anchor") else 1.0


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

extends "res://source/match/ambient/NeutralTarget.gd"

const Players = preload("res://source/match/Players.gd")
const Models = preload("res://source/match/world/TacticalModels.gd")

## Bounded, manager-owned target: public event supplies, an interceptable
## airdrop carrier, or an allied repair crate. No autonomous combat behavior.
var manager = null
var kind = "supply"
var record_id = ""
var consumed = false
var public_marker = false:
	set(value):
		public_marker = value
		_sync_beacon()


func _ready():
	_match = manager.game
	var carrier = kind == "carrier"
	var initial_hp = hp
	var maximum = 120.0 if carrier else (30.0 if kind == "repair" else initial_hp)
	configure_target("gull" if carrier else "car", 1.4 if carrier else .7, maximum, 1.2)
	hp = initial_hp
	type = "CargoCarrier" if carrier else "TacticalCargo"
	add_to_group("tactical_cargo")
	_model = Node3D.new()
	_model.name = "Geometry"
	add_child(_model)
	var color = player.color if player != null else Color("d5ab60")
	if carrier:
		Models.aircraft(_model, color, true)
	elif kind == "radar":
		Models.radar(_model)
	elif kind == "refined_core":
		Models.refined_core(_model)
	else:
		Models.cargo(_model, color, kind == "repair")
	_model_origin = _model.position
	_model_scale = _model.scale
	_sync_beacon()
	_refresh_visibility()


func can_collect(unit) -> bool:
	if consumed or hp <= 0 or kind == "carrier" or not is_instance_valid(unit):
		return false
	if unit.hp <= 0 or unit.has_meta("garrison_host") or unit.movement_speed <= 0:
		return false
	if unit.combat_domain() != Constants.Match.Navigation.Domain.TERRAIN:
		return false
	if kind == "repair":
		return (
			Players.allied(player, unit.player)
			and not load("res://source/match/BastionCatalog.gd").is_infantry(unit.type)
			and unit.hp < unit.hp_max
		)
	return true


func collect(unit, elapsed: float) -> bool:
	return can_collect(unit) and manager.collect(self, unit, elapsed)


func pickup_description() -> Array:
	return (
		manager.pickup_description(self)
		if manager != null and manager.has_method("pickup_description")
		else []
	)


func can_take_damage() -> bool:
	return kind in ["carrier", "repair"] and not consumed


func force_attack_only() -> bool:
	return not can_take_damage()


func receive_damage(source, amount, point = null, weapon = {}):
	if not can_take_damage() or amount <= 0:
		return
	if Players.allied(source.player, player):
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit()
	if hp <= 0:
		consumed = true
		collision_layer = 0
		input_ray_pickable = false
		manager.cargo_destroyed(self)
		queue_free()
	elif _match.combat_effects != null:
		_match.combat_effects.impact(self, source, point if point != null else position, weapon)


func receive_shot(shot, point = null, share = 1.0, presentation_weapon = {}):
	receive_damage(
		shot.feedback_source(), Rules.damage_from(shot, self) * share, point, presentation_weapon
	)


func receive_weapon_hit(source):
	receive_damage(source, Rules.damage(source, self))


func _physics_process(_delta):
	_refresh_visibility()


func _refresh_visibility():
	if _match == null or not _match.is_node_ready():
		return
	if public_marker:
		visible = not consumed
		input_ray_pickable = visible
	else:
		refresh_visibility(_match)
		visible = visible and not consumed


func _sync_beacon():
	if not is_inside_tree():
		return
	if public_marker and kind in ["supply", "radar"]:
		if not has_node("TacticalBeacon"):
			var beacon = load("res://source/match/world/TacticalBeacon.gd").new()
			beacon.name = "TacticalBeacon"
			add_child(beacon)
	elif has_node("TacticalBeacon"):
		get_node("TacticalBeacon").queue_free()


func dismiss():
	consumed = true
	hp = 0.0
	collision_layer = 0
	input_ray_pickable = false
	queue_free()

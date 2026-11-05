extends Node

## Stationary optics affect observation and weapon authority as well as drawing.
## Allies keep seeing the infiltrator; nearby hostile witnesses and target flares
## defeat its concealment through ordinary terrain and line-of-sight checks.
const Players = preload("res://source/match/Players.gd")
const DELAY = 3.0
const DETECTION_RANGE = 3.0
var idle_left: float = DELAY
var concealed: bool = false
var _previous = Vector3.ZERO
@onready var unit = get_parent()


func _ready():
	_previous = unit.global_position


func _physics_process(delta):
	advance(delta)


func advance(delta: float):
	var movement = unit.get_node_or_null("Movement")
	var moving = (
		movement != null
		and (movement._has_destination or movement.velocity.length_squared() > 0.01)
	)
	if (
		moving
		or unit.global_position.distance_squared_to(_previous) > 0.0025
		or unit.has_meta("garrison_host")
	):
		reveal()
	else:
		idle_left = maxf(0.0, idle_left - delta)
		concealed = idle_left == 0.0
	_previous = unit.global_position


func reveal():
	idle_left = DELAY
	concealed = false


func detected_by(observer) -> bool:
	if not concealed:
		return true
	if not is_instance_valid(observer) or not "player" in observer:
		return false
	if Players.allied(observer.player, unit.player) or _flare_reveals(observer.player):
		return true
	return (
		observer.global_position_yless.distance_squared_to(unit.global_position_yless)
		<= DETECTION_RANGE * DETECTION_RANGE
	)


func detected_by_player(player, battlefield) -> bool:
	if not concealed or Players.allied(player, unit.player) or _flare_reveals(player):
		return true
	for observer in battlefield.nearby_units(unit.global_position, DETECTION_RANGE):
		if not Players.allied(observer.player, player) or observer.hp <= 0.0:
			continue
		if detected_by(observer) and battlefield.can_observe(observer, unit):
			return true
	return false


func _flare_reveals(player) -> bool:
	for manager in get_tree().get_nodes_in_group("active_target_flares"):
		if not Players.allied(manager.unit.player, player) or not manager.is_active("target_flare"):
			continue
		var flare = manager.get_ability("target_flare")
		if (
			unit.global_position_yless.distance_squared_to(flare.effect_position * Vector3(1, 0, 1))
			<= flare.radius * flare.radius
		):
			return true
	return false

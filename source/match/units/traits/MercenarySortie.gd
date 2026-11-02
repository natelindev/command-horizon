extends Node

## Loaded external aircraft leave when their ammunition or fuel runs out. The
## airframe remains observable and vulnerable throughout its flight out.
var fuel_left = 90.0
var departing = false
var exit = Vector3.ZERO
var _unit


static func attach(unit, saved: Dictionary = {}):
	var sortie = unit.get_node_or_null("MercenarySortie")
	if sortie == null:
		sortie = new()
		sortie.name = "MercenarySortie"
		sortie._unit = unit
		unit.add_child(sortie)
	if not saved.is_empty():
		sortie.fuel_left = saved.fuel_left
		sortie.departing = saved.departing
		sortie.exit = saved.exit
	return sortie


func _physics_process(delta):
	if not is_instance_valid(_unit) or not _unit.is_node_ready() or _unit.hp <= 0.0:
		return
	fuel_left = maxf(0.0, fuel_left - delta)
	if not departing and (fuel_left <= 0.0 or not _has_ammunition()):
		withdraw()
	if not departing:
		return
	_unit.aim_target = null
	var movement = _unit.get_node("Movement")
	if _unit.type == "Helicopter":
		if not movement._has_destination or movement.target_position.distance_to(exit) > 1.0:
			movement.move(exit)
	else:
		movement.mode = "return"
		movement.strike_target = null
		movement._has_destination = true
	var point = _unit.global_position * Vector3(1, 0, 1)
	if point.distance_to(exit * Vector3(1, 0, 1)) <= 3.0:
		var player = _unit.player
		_unit.queue_free()
		player.emit_changed()


func withdraw():
	if departing:
		return
	departing = true
	_unit.aim_target = null
	_unit.action = null


func _has_ammunition() -> bool:
	return _unit.rockets > 0 if _unit.type == "Helicopter" else _unit.has_stores()


func status_text() -> String:
	return (
		tr("Mercenary departing")
		if departing
		else tr("Mercenary sortie · %d s fuel") % ceili(fuel_left)
	)


func capture_state() -> Dictionary:
	return {"fuel_left": fuel_left, "departing": departing, "exit": exit}

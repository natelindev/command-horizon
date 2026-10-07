extends Node3D

const RADIUS = 6.0
var cooldown = 0.0
var group_id = 0
var kind = ""
var sector = Vector3.ZERO
var setup_left = 2.0
var anchored = false
var window_left = 0.0
var precision_ready = false
var last_position = Vector3.ZERO
var _badge
@onready var unit = get_parent()


func _ready():
	last_position = unit.global_position
	_badge = Label3D.new()
	_badge.position = Vector3(0, 2.95, 0)
	_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge.font_size = 25
	_badge.pixel_size = 0.012
	add_child(_badge)
	refresh()
	set_physics_process(false)


func activate(id, point):
	group_id = id
	last_position = unit.global_position
	if unit.player.faction == "bastion":
		kind = "anchor"
		sector = point * Vector3(1, 0, 1)
		cooldown = 10.0
		setup_left = 2.0
		anchored = false
	elif unit.player.faction == "frontier":
		kind = "maneuver"
		cooldown = 25.0
		window_left = 6.0
	else:
		kind = "precision"
		cooldown = 8.0
		window_left = 2.0
		precision_ready = true
		if is_instance_valid(unit.weapon_charge_owner):
			unit.weapon_charge_owner.apply_precision_window()
	set_physics_process(true)
	refresh()


func _physics_process(delta):
	cooldown = maxf(0, cooldown - delta)
	if kind == "anchor":
		_update_anchor(delta)
	elif kind in ["precision", "maneuver"]:
		window_left = maxf(0, window_left - delta)
		if window_left == 0:
			kind = ""
			precision_ready = false
	if cooldown == 0 and kind == "":
		group_id = 0
		set_physics_process(false)
	refresh()


func _moving():
	return (
		unit.get_node("Movement")._has_destination
		or unit.global_position.distance_squared_to(last_position) > 0.0004
	)


func _update_anchor(delta):
	var inside = unit.global_position_yless.distance_to(sector) <= RADIUS
	var moved = _moving()
	if anchored and (moved or not inside):
		kind = ""
		anchored = false
	elif not anchored:
		setup_left = maxf(0, setup_left - delta) if inside and not moved else 2.0
		anchored = setup_left == 0
	last_position = unit.global_position


func damage_factor():
	if kind == "anchor":
		# Recheck at impact, even before this unit's next physics callback.
		_update_anchor(0.0)
		refresh()
	return (0.75 if _upgraded() else 0.85) if anchored and kind == "anchor" else 1.0


func preparation_time(base):
	if kind == "precision" and precision_ready and window_left > 0:
		precision_ready = false
		refresh()
		return base * (0.5 if _upgraded() else 0.8)
	return base


func refresh():
	if not is_instance_valid(_badge):
		return
	_badge.visible = kind != ""
	if kind == "anchor":
		_badge.text = (
			("ANCHORED −%d%%" % (25 if _upgraded() else 15))
			if anchored
			else "ANCHOR %.1f" % setup_left
		)
	elif kind == "maneuver":
		_badge.text = "MANEUVER +%d%% · %.1f" % [50 if _upgraded() else 35, window_left]
	else:
		_badge.text = "PRECISION READY" if precision_ready else "PRECISION"


func capture():
	return {
		"cooldown": cooldown,
		"group_id": group_id,
		"kind": kind,
		"sector": sector,
		"setup_left": setup_left,
		"anchored": anchored,
		"window_left": window_left,
		"precision_ready": precision_ready,
		"last_position": last_position
	}


func restore(state):
	for key in state:
		set(key, state[key])
	set_physics_process(cooldown > 0 or kind != "")
	refresh()


func _upgraded():
	return unit.player.technology != null and unit.player.technology.has_doctrine()


func speed_factor():
	return (1.5 if _upgraded() else 1.35) if kind == "maneuver" and window_left > 0 else 1.0

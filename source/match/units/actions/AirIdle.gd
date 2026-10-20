extends "res://source/match/units/actions/Action.gd"

# Default fixed-wing behavior. Airborne aircraft orbit their station and, by
# stance, strike enemies they can see; with empty stores they return to rearm.
# Parked aircraft stay on their stand unless they have a station to resume.

const AirStrike = preload("res://source/match/units/actions/AirStrike.gd")
const SCAN_INTERVAL = 0.5

var _scan_left = 0.0

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _flight = _unit.get_node("Movement")


func _ready():
	if restoring:
		return
	_flight.idle()


func is_idle():
	return true


func weapons_free():
	return true


func _physics_process(delta):
	if _flight.is_parked():
		if _unit.resume_station.is_finite() and _unit.sortie_ready(false):
			var point = _unit.resume_station
			_unit.resume_station = Vector3.INF
			_flight.fly_station(point, false)
		return
	if not _flight.is_airborne() or _flight.mode == "return":
		return
	if not _unit.has_stores():
		_unit.resume_station = _flight.station
		_flight.return_to_base()
		return
	_scan_left -= delta
	if _scan_left > 0.0:
		return
	_scan_left = SCAN_INTERVAL
	if _unit.stance in [_unit.Stance.AGGRESSIVE, _unit.Stance.DEFENSIVE]:
		var target = _unit.acquire_target()
		if target != null:
			_unit.action = AirStrike.new(target)

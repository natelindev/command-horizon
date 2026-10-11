extends Node3D

const Catalog = preload("res://source/match/ambient/AmbientCatalog.gd")
const ASSETS = {
	"car": "ambient/ResidentCar",
	"resident": "ambient/Resident",
	"fox": "ambient/Fox",
	"gull": "coastal/CoastalGull",
	"tug": "coastal/HarborTug"
}
var player = null
var entry = {}
var travel = 0.0
var stop_left = 0.0
var phase = 0.0
var yielding = false
var _limbs = []
var _wings = []
var _tail
var _model


func setup(definition):
	entry = definition
	name = entry.id
	travel = entry.start
	phase = fposmod(entry.start, TAU)
	_model = (load("res://assets/models/environment/%s.glb" % ASSETS[entry.kind]).instantiate())
	add_child(_model)
	for node in _model.find_children("*", "Node3D", true, false):
		if "Leg" in node.name and not "fur" in node.name:
			_limbs.append([node, -1.0 if ("Left" in node.name) != ("Back" in node.name) else 1.0])
		elif "Arm" in node.name:
			_limbs.append([node, 1.0 if "Left" in node.name else -1.0])
		elif node.name in ["LeftWing", "RightWing"]:
			_wings.append([node, 1.0 if node.name == "LeftWing" else -1.0])
		elif node.name == "Tail":
			_tail = node
	apply_pose(false)
	visible = false


func advance(delta, game):
	var speed = {"car": 2.8, "resident": .85, "fox": 1.2, "gull": 3.5, "tug": 1.3}[entry.kind]
	yielding = _blocked(game, speed)
	var walking = not yielding and stop_left <= 0
	stop_left = maxf(0.0, stop_left - delta)
	if walking:
		var previous = travel
		travel = fposmod(travel + speed * delta, entry.length)
		phase = fposmod(phase + delta * (8.0 if entry.kind == "fox" else 5.0), TAU)
		if entry.kind in ["resident", "fox"] and floori(previous / 9) != floori(travel / 9):
			stop_left = 2.5 if entry.kind == "fox" else 1.3
	apply_pose(walking)
	refresh_visibility(game)


func _blocked(game, speed):
	if entry.kind in ["gull", "tug"]:
		return false
	var ahead = Catalog.point(entry, travel + speed * 1.2)
	for unit in game.get_tree().get_nodes_in_group("units"):
		if unit.is_queued_for_deletion() or unit.movement_domain == 0:
			continue
		var obstacle = unit.get_node_or_null("MovementObstacle")
		var radius = obstacle.radius if obstacle != null else 1.0
		var distance = Vector2(unit.position.x - ahead.x, unit.position.z - ahead.z).length()
		if distance < radius + (2.0 if entry.kind == "car" else 1.0):
			return true
	if entry.kind == "car":
		for other in get_parent().actors:
			if (
				other != self
				and other.entry.kind == "car"
				and ahead.distance_to(other.position) < 2.6
			):
				return true
	return false


func apply_pose(walking):
	position = Catalog.point(entry, travel)
	var forward = Catalog.point(entry, travel + .25) - position
	rotation.y = atan2(forward.x, forward.z)
	# Keep stored phase and pause pose identical on restoration.
	for limb in _limbs:
		limb[0].rotation.x = sin(phase) * .45 * limb[1] if walking else 0.0
	for wing in _wings:
		wing[0].rotation.z = sin(phase) * .38 * wing[1]
	if entry.kind == "tug":
		_model.position.y = sin(phase * 2) * .045
		_model.rotation.z = sin(phase) * .025
	if is_instance_valid(_tail):
		_tail.rotation.y = sin(phase) * .22


func refresh_visibility(game):
	if not Globals.options.living_world:
		visible = false
		return
	visible = game.settings.visibility == game.settings.Visibility.FULL
	if not visible:
		for side in game.visible_players:
			if side != null and game.battlefield.is_observed(side, self):
				visible = true
				break


func capture():
	return {
		"id": entry.id,
		"travel": travel,
		"stop_left": stop_left,
		"phase": phase,
		"walking": _limbs.size() > 0 and _limbs[0][0].rotation.x != 0.0
	}


func restore(saved):
	travel = saved.travel
	stop_left = saved.stop_left
	phase = saved.phase
	apply_pose(saved.walking)

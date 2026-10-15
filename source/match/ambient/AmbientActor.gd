extends "res://source/match/ambient/NeutralTarget.gd"

const Catalog = preload("res://source/match/ambient/AmbientCatalog.gd")
const ASSETS = {
	"car": "ambient/ResidentCar",
	"resident": "ambient/Resident",
	"fox": "ambient/Fox",
	"gull": "coastal/CoastalGull",
	"tug": "coastal/HarborTug"
}
var entry = {}
var travel = 0.0
var stop_left = 0.0
var phase = 0.0
var yielding = false
var _limbs = []
var _wings = []
var _knees = []
var _elbows = []
var _wheels = []
var _head
var _walking = false
var _tail


func setup(definition, combat_enabled = true):
	interactive = combat_enabled
	entry = definition
	name = entry.id
	travel = entry.start
	phase = fposmod(entry.start, TAU)
	_model = (load("res://assets/models/environment/%s.glb" % ASSETS[entry.kind]).instantiate())
	add_child(_model)
	neutral_id = "neutral-" + entry.id
	var stats = Catalog.STATS[entry.kind]
	configure_target(entry.kind, stats.radius, stats.health, stats.height)
	load("res://source/match/ambient/NeutralDetails.gd").dress_actor(_model, entry)
	_model.scale *= Catalog.MODEL_SCALES[entry.kind]
	_model_scale = _model.scale
	_model_origin = _model.position
	for node in _model.find_children("*", "Node3D", true, false):
		if "Leg" in node.name and not "fur" in node.name:
			_limbs.append([node, -1.0 if ("Left" in node.name) != ("Back" in node.name) else 1.0])
		elif "Arm" in node.name:
			_limbs.append([node, 1.0 if "Left" in node.name else -1.0])
		elif node.name in ["LeftWing", "RightWing"]:
			_wings.append([node, 1.0 if node.name == "LeftWing" else -1.0])
		elif "Knee" in node.name:
			_knees.append([node, -1.0 if "Left" in node.name else 1.0])
		elif "Elbow" in node.name:
			_elbows.append(node)
		elif str(node.name).ends_with("Wheel"):
			_wheels.append(node)
		elif node.name == "HeadPivot":
			_head = node
		elif node.name == "Tail":
			_tail = node
	apply_pose(false)
	visible = false


func advance(delta, game):
	_match = game
	if advance_damage(delta):
		refresh_visibility(game)
		return
	var speed = Catalog.STATS[entry.kind].speed
	if panic_left > 0:
		speed *= 1.7 if entry.kind in ["resident", "fox", "gull"] else 1.25
		stop_left = 0
	yielding = _blocked(game, speed)
	var walking = not yielding and stop_left <= 0
	stop_left = maxf(0.0, stop_left - delta)
	var cadence = (8.0 if entry.kind == "fox" else 5.0) if walking else 1.4
	phase = fposmod(phase + delta * cadence * (1.6 if panic_left > 0 else 1.0), TAU)
	if walking:
		var previous = travel
		travel = fposmod(travel + speed * delta, entry.length)
		if (
			panic_left <= 0
			and entry.kind in ["resident", "fox"]
			and floori(previous / 9) != floori(travel / 9)
		):
			stop_left = 2.5 if entry.kind == "fox" else 1.3
	apply_pose(walking)
	refresh_visibility(game)


func _blocked(game, speed):
	if entry.kind in ["gull", "tug"]:
		return false
	var ahead = Catalog.point(entry, travel + speed * 1.2)
	for unit in game.battlefield.nearby_bodies(ahead, 2.0 if entry.kind == "car" else 1.0):
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
				and other.hp > 0
				and other.entry.kind == "car"
				and ahead.distance_to(other.position) < 2.6
			):
				return true
	return false


func apply_pose(walking):
	_walking = walking
	position = Catalog.point(entry, travel)
	var forward = Catalog.point(entry, travel + .25) - position
	rotation.y = atan2(forward.x, forward.z)
	_model.rotation.z = sin(hit_left * 50) * hit_left * .2
	# Keep stored phase and pause pose identical on restoration.
	for limb in _limbs:
		limb[0].rotation.x = sin(phase) * .45 * limb[1] if walking else 0.0
	for knee in _knees:
		knee[0].rotation.x = maxf(0, sin(phase) * knee[1]) * .65 if walking else 0.0
	for elbow in _elbows:
		elbow.rotation.x = -.5 if panic_left > 0 else -.12
	for wheel in _wheels:
		wheel.rotation.x = fposmod(travel / .285, TAU)
	if is_instance_valid(_head):
		_head.rotation.y = sin(phase * .5) * (.10 if walking else .35)
		_head.rotation.x = -.12 if panic_left > 0 else sin(phase) * .04
	if entry.kind == "resident":
		_model.position.y = absf(sin(phase)) * (.025 if walking else .006)
	for wing in _wings:
		wing[0].rotation.z = sin(phase) * .38 * wing[1]
	if entry.kind == "tug":
		_model.position.y = sin(phase * 2) * .045
		_model.rotation.z = sin(phase) * .025
	if is_instance_valid(_tail):
		_tail.rotation.y = sin(phase) * .22


func capture():
	return {
		"id": entry.id,
		"combat": capture_combat(),
		"travel": travel,
		"stop_left": stop_left,
		"phase": phase,
		"walking": _walking
	}


func restore(saved):
	travel = saved.travel
	stop_left = saved.stop_left
	phase = saved.phase
	apply_pose(saved.walking)
	if saved.has("combat"):
		restore_combat(saved.combat)
		if hp > 0:
			apply_pose(saved.walking)


func apply_death_pose():
	super()
	var settle = smoothstep(0, .9, death_age)
	for limb in _limbs:
		limb[0].rotation.x = settle * (.7 if entry.kind == "fox" else .3) * limb[1]
	for knee in _knees:
		knee[0].rotation.x = settle * .9
	for elbow in _elbows:
		elbow.rotation.x = -settle * .8
	for wing in _wings:
		wing[0].rotation.z = settle * 1.1 * wing[1]

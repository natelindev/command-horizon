extends Node3D

const Kit = preload("res://source/match/units/traits/InfantryEquipment.gd")
const Technology = preload("res://source/match/research/TechnologyCatalog.gd")
var state = "idle"
var progress = 0.0
var phase = 0.0
var portal = Vector3.ZERO
var _unit
var _bounds = AABB()
var _portal_root
var _scaffold
var _work_head
var _work_rest = Vector3.ZERO
var _lamps = []
var _doors = []
var _door_open = 0.0
var _sensor
var _sensor_rest = Vector3.ZERO
var _glow
var _metal
var _light_level = 0.0


func _ready():
	_unit = get_parent()
	_bounds = load("res://source/match/FactionCatalog.gd")._bounds(
		_unit.get_node("Geometry"), Transform3D.IDENTITY
	)
	_metal = Kit._material(Color("727f86"), .6)
	_glow = Kit._material(Color("303536"), .1)
	_glow.emission_enabled = true
	_glow.emission = Color("c6ad7d")
	_build_scaffold()
	_build_machinery()
	refresh(0.0)


func _process(delta):
	refresh(delta)


func refresh(delta = 0.0):
	if not is_instance_valid(_unit) or _unit.hp == null:
		return
	_read_activity()
	var working = state in ["construction", "production", "research"]
	var rate = _unit.player.production_factor() if _unit.is_constructed() else 1.0
	if working:
		phase += delta * rate
	_scaffold.visible = state == "construction"
	if _portal_root != null:
		_portal_root.visible = _unit.is_constructed()
	for level in _scaffold.get_children():
		level.visible = level.get_index() == 0 or progress > float(level.get_index() - 1) / 4.0
	# Practical fixtures stay in place. Only their illumination fades when work
	# starts or stops; machinery carries the activity instead of a chasing blink.
	var illumination = (1.0 if working else .25 if state == "blocked" else 0.0) * rate
	_light_level = (
		illumination if delta == 0.0 else move_toward(_light_level, illumination, delta * 1.8)
	)
	_glow.albedo_color = Color("303536").lerp(Color("ac9973"), _light_level)
	_glow.emission_energy_multiplier = .45 * _light_level
	if _work_head != null:
		_work_head.position = _work_rest
		if state in ["production", "construction"]:
			_work_head.position += Vector3(
				sin(phase * 1.6) * _unit.radius * .28, sin(phase * 2.3) * .10, 0
			)
	if _sensor != null and state == "research":
		_sensor.rotation = _sensor_rest + Vector3(0, phase * .65, 0)
	var queue = _unit.production_queue
	var departing = queue != null and is_instance_valid(queue.departure)
	_door_open = (
		(1.0 if departing else 0.0)
		if delta == 0.0
		else move_toward(_door_open, 1.0 if departing else 0.0, delta * 4.0)
	)
	for door in _doors:
		door.position.x = (
			door.get_meta("rest_x") + door.get_meta("side") * _door_open * door.get_meta("travel")
		)


func _read_activity():
	progress = 0.0
	if _unit.is_under_construction():
		state = "construction"
		progress = _unit._construction_progress
		return
	var queue = _unit.production_queue
	if queue != null and queue.size() > 0:
		progress = queue.get_elements()[0].progress()
		if queue.blocked_reason() != "":
			state = "blocked"
			return
		state = "production"
		return
	if _unit.type == "CommandLab":
		var player = _unit.player
		if player.coordination_left > 0:
			state = "research"
			progress = 1.0 - player.coordination_left / player.COORDINATION_DURATION
			return
		if player.technology != null and player.technology.active != "":
			state = "research"
			progress = (
				1.0 - player.technology.left / Technology.ITEMS[player.technology.active].seconds
			)
			return
	state = "idle"


func _build_scaffold():
	_scaffold = Node3D.new()
	_scaffold.name = "ConstructionScaffold"
	add_child(_scaffold)
	var width = minf(_unit.radius * .8, _bounds.size.x * .55)
	var depth = minf(_unit.radius * .8, _bounds.size.z * .55)
	var height = maxf(1.2, _bounds.size.y * .8)
	for index in range(5):
		var level = Node3D.new()
		_scaffold.add_child(level)
		var y = height * index / 4.0
		for side in [-1, 1]:
			Kit._box(
				level,
				"Crossbar",
				Vector3(0, y + .13, side * depth),
				Vector3(width * 2, .055, .055),
				_metal
			)
			Kit._box(
				level,
				"SideRail",
				Vector3(side * width, y + .13, 0),
				Vector3(.055, .055, depth * 2),
				_metal
			)
			for end in [-1, 1]:
				Kit._box(
					level,
					"Upright",
					Vector3(side * width, y + height / 8, end * depth),
					Vector3(.055, height / 4, .055),
					_metal
				)
		if index == 0:
			for side in [-1, 1]:
				_task_light(level, Vector3(side * width, .13, -depth - .05))


func _build_machinery():
	_sensor = _unit.find_child("*SensorPivot", true, false)
	if _sensor == null:
		_sensor = _unit.find_child("*RadarPivot", true, false)
	if _sensor != null:
		_sensor_rest = _sensor.rotation
		_task_light(_sensor, Vector3(0, -.12, -.04))
	var producing = _unit.production_queue != null
	if producing:
		_build_portal()
	var height = _bounds.end.y * .8
	if _unit.type in ["VehicleFactory", "RepairDepot"]:
		_work_head = Node3D.new()
		_work_head.name = "AssemblyHead"
		_work_rest = Vector3(0, height, 0)
		add_child(_work_head)
		Kit._box(_work_head, "Carriage", Vector3.ZERO, Vector3(.35, .2, .3), _metal)
		Kit._box(_work_head, "Tool", Vector3(0, -.28, 0), Vector3(.06, .48, .06), _metal)
		_task_light(_work_head, Vector3(0, -.04, -.18))


func _task_light(parent, point):
	var housing = Kit._box(parent, "TaskLightHousing", point, Vector3(.12, .065, .06), _metal)
	var lamp = Kit._box(
		housing, "TaskLightLens", Vector3(0, 0, -.031), Vector3(.08, .028, .012), _glow
	)
	_lamps.append(lamp)


func _build_portal():
	_portal_root = Node3D.new()
	_portal_root.name = "ProductionPortal"
	add_child(_portal_root)
	var infantry = _unit.type == "Barracks"
	var airborne = _unit.type == "AircraftFactory"
	portal = Vector3(0, 0, -_bounds.size.z * .40)
	if infantry:
		portal.z = -_bounds.size.z * .46
		portal.x = -_bounds.size.x * .235 if _unit.player.faction != "helix" else 0.0
	if airborne:
		portal = Vector3(
			0,
			{"bastion": .58, "helix": .38, "frontier": .18}[_unit.player.faction],
			-_bounds.size.z * .08
		)
		for side in [-1, 1]:
			_task_light(_portal_root, portal + Vector3(side * .75, .04, -.4))
		return
	var width = .82 if infantry else (1.55 if _unit.type == "CommandCenter" else 2.15)
	var height = 1.35 if infantry else 1.5
	var dark = Kit._material(Color("172229"), .1)
	Kit._box(
		_portal_root,
		"ExitApron",
		portal + Vector3(0, .025, -.3),
		Vector3(width + .3, .045, .85),
		_metal
	)
	if _unit.type == "VehicleFactory":
		return  # Authored factories already have open assembly bays.
	Kit._box(
		_portal_root,
		"DoorShadow",
		portal + Vector3(0, height * .5, .02),
		Vector3(width, height, .06),
		dark
	)
	Kit._box(
		_portal_root,
		"DoorLintel",
		portal + Vector3(0, height + .06, -.02),
		Vector3(width + .2, .12, .22),
		_metal
	)
	for side in [-1, 1]:
		_task_light(_portal_root, portal + Vector3(side * width * .28, height + .06, -.16))
	for side in [-1, 1]:
		Kit._box(
			_portal_root,
			"DoorJamb",
			portal + Vector3(side * (width + .1) * .5, height * .5, 0),
			Vector3(.1, height, .18),
			_metal
		)
		var door = Kit._box(
			_portal_root,
			"ExitDoor",
			portal + Vector3(side * width * .25, height * .5, -.06),
			Vector3(width * .48, height, .06),
			_metal
		)
		door.set_meta("rest_x", door.position.x)
		door.set_meta("side", side)
		door.set_meta("travel", width * .46)
		_doors.append(door)

extends Node3D

const Layout = preload("res://source/match/units/AirfieldLayout.gd")
const Kit = preload("res://source/match/units/traits/InfantryEquipment.gd")
const Technology = preload("res://source/match/research/TechnologyCatalog.gd")
var state = "idle"
var progress = 0.0
var phase = 0.0
var portal = Vector3.ZERO
# Local direction units leave the portal in.
var portal_direction = Vector3.FORWARD
var _unit
var _bounds = AABB()
var _portal_root
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
var _settled_idle = false
var _vented := false
var _beacon: MeshInstance3D
var _beacon_material: StandardMaterial3D
var _idle_phase = 0.0
var _idle_vent_timer = 0.0
var _rooftop_beacon: MeshInstance3D
var _rooftop_material: StandardMaterial3D
var _last_rooftop_energy = -1.0


func _ready():
	_unit = get_parent()
	_bounds = load("res://source/match/FactionCatalog.gd")._bounds(
		_unit.get_node("Geometry"), Transform3D.IDENTITY
	)
	_metal = Kit._material(Color("727f86"), .6)
	_metal = load("res://source/match/ObjectMaterials.gd").textured(_metal)
	_glow = Kit._material(Color("303536"), .1)
	_glow.emission_enabled = true
	_glow.emission = Color("c6ad7d")
	_build_machinery()
	refresh(0.0)


func _process(delta):
	refresh(delta)
	_advance_idle_life(delta)


func _advance_idle_life(delta: float):
	if not is_instance_valid(_unit) or _unit.hp == null or not _unit.is_constructed():
		return
	if get_tree().paused or not _unit.visible:
		return
	_idle_phase = fmod(_idle_phase + delta, TAU * 100.0)
	if _sensor != null and state != "research":
		_sensor.rotation = _sensor_rest + Vector3(0, _idle_phase * 0.24, 0)
	if _rooftop_material != null and _rooftop_beacon != null:
		if not _rooftop_beacon.visible:
			_rooftop_beacon.visible = true
		var energy: float = (
			0.45
			if Globals.options.reduced_flashes
			else 0.35 + (0.4 + 0.6 * (0.5 + 0.5 * sin(_idle_phase * 2.4))) * 0.75
		)
		if absf(energy - _last_rooftop_energy) > 0.01:
			_last_rooftop_energy = energy
			_rooftop_material.emission_energy_multiplier = energy
	if (
		_unit.type in ["PowerPlant", "VehicleFactory", "ForwardRefinery"]
		and DisplayServer.get_name() != "headless"
		and _unit._match != null
		and _unit._match.combat_effects != null
	):
		_idle_vent_timer += delta
		if _idle_vent_timer >= 2.2:
			_idle_vent_timer = 0.0
			var effects = _unit._match.combat_effects
			if effects.can_show_construction(_unit):
				var vent_point = to_global(Vector3(_unit.radius * 0.3, _bounds.end.y * 0.88, 0))
				effects.construction_puff(
					"smoke",
					vent_point,
					Vector3(0.08, 0.55, 0.05),
					Color(0.80, 0.84, 0.86, 0.16),
					0.42
				)


func refresh(delta = 0.0):
	if not is_instance_valid(_unit) or _unit.hp == null:
		return
	_read_activity()
	# Idle structures retain their last pose/materials. Still read state each frame
	# so construction, research and queued work wake the animation immediately.
	if state == "idle" and _settled_idle:
		return
	var working = state in ["construction", "production", "research", "repair"]
	var rate = (
		_unit.player.production_factor()
		if state in ["production", "research", "repair", "blocked"]
		else 1.0
	)
	if working:
		phase += delta * rate
	if _portal_root != null:
		_portal_root.visible = _unit.is_constructed()
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
		if state in ["production", "construction", "repair"]:
			_work_head.position += Vector3(
				sin(phase * 1.6) * _unit.radius * .28, sin(phase * 2.3) * .10, 0
			)
	if _sensor != null and state == "research":
		_sensor.rotation = _sensor_rest + Vector3(0, phase * .65, 0)
	var queue = _unit.production_queue
	var departing = queue != null and is_instance_valid(queue.departure)
	var preparing = false
	if state == "production" and queue != null and queue.size() > 0:
		var next = queue.get_elements()[0]
		preparing = (
			next.time_left
			<= load("res://source/match/effects/ProductionDeparture.gd").seconds(next) + 1.0
		)
	if _beacon != null:
		_beacon.visible = preparing or departing
		_beacon.rotation.y = phase * 3.5
		_beacon_material.emission_energy_multiplier = (
			.8 if Globals.options.reduced_flashes else 1.2 + .5 * sin(phase * 5.0)
		)
	if not departing:
		_vented = false
	elif not _vented:
		_vented = true
		var effects = _unit._match.combat_effects
		if effects.can_show_construction(_unit):
			for side in [-1, 1]:
				effects.construction_puff(
					"smoke",
					to_global(portal + Vector3(side * .7, .3, 0)),
					global_basis.x * side * .7 + Vector3.UP * .3,
					Color(.75, .81, .83, .22),
					.45
				)
	_door_open = (
		(1.0 if departing or preparing else 0.0)
		if delta == 0.0
		else move_toward(_door_open, 1.0 if departing or preparing else 0.0, delta * 4.0)
	)
	for door in _doors:
		door.position.x = (
			door.get_meta("rest_x") + door.get_meta("side") * _door_open * door.get_meta("travel")
		)

	_settled_idle = state == "idle" and _light_level == 0.0 and _door_open == 0.0


func _read_activity():
	progress = 0.0
	if _unit.is_under_construction():
		state = "construction"
		progress = _unit._construction_progress
		return
	if _unit.get_meta("service_used", 0) > 0:
		state = "repair"
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
	if (
		_unit.type
		in ["CommandCenter", "PowerPlant", "VehicleFactory", "AircraftFactory", "CommandLab"]
	):
		_rooftop_material = Kit._material(Color("e6b05c"), .2)
		_rooftop_material.emission_enabled = true
		_rooftop_material.emission = Color("f0a94f")
		_rooftop_beacon = Kit._box(
			self,
			"StatusBeacon",
			Vector3(_bounds.size.x * 0.28, _bounds.end.y + 0.08, _bounds.size.z * 0.24),
			Vector3(.11, .09, .11),
			_rooftop_material
		)
		_rooftop_beacon.visible = _unit.is_constructed()


func _task_light(parent, point):
	var housing = Kit._box(parent, "TaskLightHousing", point, Vector3(.12, .065, .06), _metal)
	var lamp = Kit._box(
		housing, "TaskLightLens", Vector3(0, 0, -.031), Vector3(.08, .028, .012), _glow
	)
	_lamps.append(lamp)


static func portal_layout(role: String, faction: String, bounds: AABB) -> Dictionary:
	var position = Vector3(0, 0, -bounds.size.z * .40)
	var direction = Vector3.FORWARD
	if role == "Barracks":
		position = Vector3(
			-bounds.size.x * .235 if faction != "helix" else 0, 0, -bounds.size.z * .46
		)
	elif role == "AircraftFactory":
		position = Layout.PAD_POINTS[0] + Vector3.UP * Layout.pad_height(faction, 0)
		direction = Vector3.RIGHT
	return {"position": position, "direction": direction}


func _build_portal():
	_portal_root = Node3D.new()
	_portal_root.name = "ProductionPortal"
	add_child(_portal_root)
	var infantry = _unit.type == "Barracks"
	var airborne = _unit.type == "AircraftFactory"
	var layout = portal_layout(_unit.type, _unit.player.faction, _bounds)
	portal = layout.position
	portal_direction = layout.direction
	if airborne:
		# Rotorcraft lift off the tower's helipad and leave away from the runway.
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
	_beacon_material = Kit._material(Color("d3a45e"), .2)
	_beacon_material.emission_enabled = true
	_beacon_material.emission = Color("e6ac50")
	_beacon = Kit._box(
		_portal_root,
		"DepartureBeacon",
		portal + Vector3(0, height + .22, 0),
		Vector3(.23, .12, .1),
		_beacon_material
	)
	_beacon.hide()
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

extends "res://source/match/environment/DestructibleObstacle.gd"

signal action_updated
var garrison_mount = null
var occupants:
	get:
		return garrison_mount.occupants if garrison_mount != null else []
var pending_evacuations:
	get:
		return garrison_mount.pending_evacuations if garrison_mount != null else []
var _maximum = 320.0


func _ready():
	type = "Bunker"
	radius = 2.0
	obstacle_height = 1.7
	light_barricade = false
	hp_max = 320.0
	hp = hp_max
	sight_range = 12.0
	add_to_group("field_bunkers")
	add_to_group("vision_sources")
	var geometry = Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	var concrete = StandardMaterial3D.new()
	concrete.albedo_color = Color("6b7066")
	concrete.roughness = 0.95
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color("161d1b")
	for part in [
		[Vector3(0, 0.45, 0), Vector3(3.5, 0.9, 3.5), concrete],
		[Vector3(0, 1.15, 0), Vector3(3.15, 0.6, 3.15), dark],
		[Vector3(0, 1.6, 0), Vector3(3.7, 0.35, 3.7), concrete],
	]:
		var mesh = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = part[1]
		mesh.position = part[0]
		mesh.material_override = part[2]
		geometry.add_child(mesh)
	super()
	selected.connect(func():
		for unit in occupants:
			if unit.is_in_group("controlled_units"):
				unit.get_node("Selection").select()
	)
	garrison_mount = load("res://source/match/units/traits/GarrisonMount.gd").new()
	garrison_mount.name = "GarrisonMount"
	garrison_mount.capacity = 6
	add_child(garrison_mount)
	refresh_doctrine()
	if _match != null:
		_match.battlefield.invalidate()


func refresh_doctrine():
	var completed = player.technology.completed if player.technology != null else []
	var maximum = 320.0 * (1.5 if "bunker_reinforcements" in completed else 1.0) * (1.3 if "fortress_doctrine" in completed else 1.0)
	if not is_equal_approx(_maximum, maximum):
		var ratio = hp / hp_max
		hp_max = maximum
		hp = maximum * ratio
		_maximum = maximum


func _physics_process(delta):
	super(delta)
	refresh_doctrine()
	if player.technology != null and "fortress_doctrine" in player.technology.completed and hp > 0.0:
		hp = minf(hp_max, hp + 4.0 * delta)


func is_constructed() -> bool:
	return hp > 0.0


func is_revealing() -> bool:
	return hp > 0.0


func can_garrison(unit) -> bool:
	return garrison_mount != null and garrison_mount.can_garrison(unit)


func enter(unit, saved_slot = -1) -> bool:
	return garrison_mount.enter(unit, saved_slot)


func leave(unit):
	garrison_mount.leave(unit)


func firing_origin(point: Vector3) -> Vector3:
	return garrison_mount.firing_origin(point)


func breach(presentation = true):
	if garrison_mount != null:
		garrison_mount._evacuate(true)
	super(presentation)

extends Area3D

## A neutral, explicitly attacked barrier. Navigation and sight use the same
## footprint; destruction removes both immediately and schedules a mesh rebake.
signal selected
signal deselected
signal hp_changed
signal destroyed

@export var hp_max: float = 80.0
@export var hp: float = 80.0:
	set(value):
		hp = maxf(0.0, value)
		hp_changed.emit()
		if hp == 0.0 and is_node_ready():
			breach()
@export var radius: float = 1.0
@export var obstacle_height: float = 1.5
@export var light_barricade: bool = true
@export var footprint = PackedVector2Array()
var neutral_id = ""
var player = null
var signature = null
var type = "DestructibleObstacle"
var interactive = true
var sight_range = null
var attack_range = null
var attack_damage = null
var attack_domains = []
var movement_speed = 0.0
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)
var _breached = false
var _obstacle: Footprint


class Footprint:
	extends NavigationObstacle3D
	var sight_height: float = 1.5
	var footprint = PackedVector2Array()


@onready var _match = find_parent("Match")


func _ready():
	add_to_group("destructible_obstacles")
	collision_layer = 2
	collision_mask = 0
	var collider = CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var shape
	if footprint.is_empty():
		shape = CylinderShape3D.new()
		shape.radius = radius
		shape.height = obstacle_height
	else:
		shape = BoxShape3D.new()
		shape.size = Vector3(2.5, obstacle_height, 0.55)
	collider.shape = shape
	collider.position.y = obstacle_height * 0.5
	add_child(collider)
	if not has_node("Geometry"):
		var geometry = MeshInstance3D.new()
		geometry.name = "Geometry"
		var mesh = BoxMesh.new()
		mesh.size = (
			Vector3(radius * 1.4, obstacle_height, radius * 1.4)
			if footprint.is_empty()
			else Vector3(2.5, obstacle_height, 0.55)
		)
		geometry.mesh = mesh
		geometry.position.y = obstacle_height * 0.5
		var material = StandardMaterial3D.new()
		material.albedo_color = Color("796953") if light_barricade else Color("797c7b")
		material.roughness = 0.95
		geometry.material_override = material
		add_child(geometry)
	var target = load("res://source/match/units/traits/Targetability.tscn").instantiate()
	target.radius = radius
	add_child(target)
	var health = load("res://source/match/units/traits/HealthBar.tscn").instantiate()
	health.position.y = obstacle_height + 0.35
	health.size = Vector2(60, 6)
	add_child(health)
	_obstacle = Footprint.new()
	_obstacle.name = "MovementObstacle"
	_obstacle.radius = radius
	_obstacle.height = obstacle_height
	_obstacle.affect_navigation_mesh = true
	_obstacle.avoidance_layers = Constants.Match.Navigation.AVOIDANCE_STATIC
	# Battlefield reads sight_height from all sight blockers.
	_obstacle.sight_height = obstacle_height
	_obstacle.footprint = footprint
	var outline = PackedVector3Array()
	if footprint.is_empty():
		for index in 16:
			var angle = index * TAU / 16.0
			outline.append(Vector3(cos(angle), 0, sin(angle)) * radius)
	else:
		for point in footprint:
			outline.append(Vector3(point.x, 0, point.y))
	_obstacle.vertices = outline
	add_child(_obstacle)
	_obstacle.add_to_group("sight_blockers")
	if hp <= 0.0:
		breach(false)
	else:
		_register_navigation()


func _register_navigation():
	if _match == null:
		return
	if not _match.is_node_ready():
		await _match.ready
	await _match.navigation.wait_until_synchronized(combat_domain())
	if _breached or not is_inside_tree() or is_queued_for_deletion():
		return
	# Keep authored barriers out of TerrainNavigation's immutable map cache.
	# Register them only after the initial ground mesh has been published.
	_obstacle.set_navigation_map(
		_match.navigation.get_navigation_map_rid_by_domain(combat_domain())
	)
	_obstacle.add_to_group("terrain_navigation_input")
	MatchSignals.schedule_navigation_rebake.emit(combat_domain())


func combat_domain():
	return Constants.Match.Navigation.Domain.TERRAIN


func force_attack_only() -> bool:
	return player == null


func receive_weapon_hit(source):
	receive_damage(source, _rules().damage(source, self))


func receive_shot(shot, point = null, share = 1.0, presentation_weapon = {}):
	receive_damage(
		shot.feedback_source(), _rules().damage_from(shot, self) * share, point, presentation_weapon
	)


func receive_damage(_source, amount, _point = null, _presentation_weapon = {}):
	if not _breached and is_finite(amount) and amount > 0.0:
		hp -= amount


func crush_by(vehicle) -> bool:
	if (
		_breached
		or not light_barricade
		or not is_instance_valid(vehicle)
		or vehicle.type not in ["Tank", "AdvancedTank"]
		or vehicle.hp <= 0.0
		or vehicle.combat_domain() != combat_domain()
		or absf(vehicle.global_position.y - global_position.y) > 1.0
		or not Utils.Match.Unit.Movement.units_adhere(vehicle, self)
	):
		return false
	hp = 0.0
	return true


func _physics_process(_delta):
	if _match == null or _breached:
		return
	var observed = _match.settings.visibility == _match.settings.Visibility.FULL
	visible = (
		observed
		or _match.visible_players.any(func(side): return _match.battlefield.is_observed(side, self))
	)
	input_ray_pickable = visible
	if not light_barricade:
		return
	for vehicle in _match.battlefield.nearby_units(global_position_yless, radius + 2.0):
		if vehicle.type not in ["Tank", "AdvancedTank"]:
			continue
		var movement = vehicle.get_node_or_null("Movement")
		if (
			movement != null
			and movement._has_destination
			and movement.velocity.dot(global_position_yless - vehicle.global_position_yless) > 0.01
		):
			if crush_by(vehicle):
				break


func breach(presentation = true):
	if _breached:
		return
	_breached = true
	if hp > 0.0:
		hp = 0.0
	if presentation and _match != null and _match.combat_effects != null:
		_match.combat_effects.obstacle_destruction(self)
	interactive = false
	collision_layer = 0
	input_ray_pickable = false
	get_node("CollisionShape3D").set_deferred("disabled", true)
	_obstacle.remove_from_group("sight_blockers")
	_obstacle.remove_from_group("terrain_navigation_input")
	_obstacle.affect_navigation_mesh = false
	_obstacle.avoidance_enabled = false
	hide()
	set_physics_process(false)
	MatchSignals.schedule_navigation_rebake.emit(combat_domain())
	if _match != null:
		_match.battlefield.invalidate()
	destroyed.emit()


func _exit_tree():
	if not _breached:
		MatchSignals.schedule_navigation_rebake.emit(combat_domain())


static func _rules():
	return load("res://source/match/combat/CombatRules.gd")

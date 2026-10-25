extends Area3D

## A deliberately selected target, never a navigation obstacle or auto-target.
signal selected
signal deselected
signal hp_changed
signal destroyed

var neutral_id = ""
var player = null
var manager = null
var type = "FieldMine"
var signature = null
var hp = 1.0
var hp_max = 1.0
var radius = 0.3
var obstacle_height = 0.22
var movement_speed = 0.0
var sight_range = null
var attack_range = null
var attack_damage = null
var attack_domains = []
var interactive = true
var deploy_left = 3.0
var arm_left = 2.0
var fuse_left = -1.0
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)
var _previous = {}
var _lamp = null


func _ready():
	add_to_group("field_mines")
	add_to_group("neutral_targets")
	add_to_group("engineering_entities")
	collision_layer = 2
	collision_mask = 0
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape = CylinderShape3D.new()
	shape.radius = radius
	shape.height = obstacle_height
	collision.shape = shape
	collision.position.y = obstacle_height * 0.5
	add_child(collision)
	var geometry = MeshInstance3D.new()
	geometry.name = "Geometry"
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = obstacle_height
	mesh.radial_segments = 8
	geometry.mesh = mesh
	geometry.position.y = obstacle_height * 0.5
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("5d5040")
	material.metallic = 0.65
	material.roughness = 0.7
	geometry.material_override = material
	add_child(geometry)
	_lamp = MeshInstance3D.new()
	var lamp_mesh = CylinderMesh.new()
	lamp_mesh.top_radius = 0.07
	lamp_mesh.bottom_radius = 0.07
	lamp_mesh.height = 0.03
	_lamp.mesh = lamp_mesh
	_lamp.position.y = obstacle_height + 0.02
	var lamp_material = StandardMaterial3D.new()
	lamp_material.albedo_color = Color("dab063")
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("dab063")
	_lamp.material_override = lamp_material
	add_child(_lamp)
	var target = load("res://source/match/units/traits/Targetability.tscn").instantiate()
	target.radius = 0.6
	add_child(target)
	refresh_visibility()


func combat_domain():
	return Constants.Match.Navigation.Domain.TERRAIN


func force_attack_only() -> bool:
	return true


func known_to(observer) -> bool:
	return manager != null and manager.observed_by(observer, self)


func receive_weapon_hit(source):
	if load("res://source/match/combat/CombatRules.gd").can_target(source, self):
		clear()


func receive_shot(_shot, _point = null, share = 1.0, _presentation_weapon = {}):
	if share > 0.0:
		clear()


func receive_damage(_source, amount, _point = null, _presentation_weapon = {}):
	if is_finite(amount) and amount > 0.0:
		clear()


func clear():
	if hp <= 0.0:
		return
	hp = 0.0
	interactive = false
	collision_layer = 0
	input_ray_pickable = false
	hide()
	hp_changed.emit()
	destroyed.emit()
	queue_free()


func advance(delta):
	if hp <= 0.0 or deploy_left > 0.0:
		return
	if arm_left > 0.0:
		var consumed = minf(delta, arm_left)
		arm_left -= consumed
		delta -= consumed
		if delta <= 0.0:
			remember_positions()
			return
	if fuse_left >= 0.0:
		fuse_left = maxf(0.0, fuse_left - delta)
		if fuse_left == 0.0:
			manager.detonate(self)
			return
	else:
		for unit in get_tree().get_nodes_in_group("units"):
			if not manager.can_trigger(unit, self):
				continue
			var point = unit.global_position_yless
			var previous = _previous.get(unit.get_instance_id(), point)
			var nearest = Geometry3D.get_closest_point_to_segment(
				global_position_yless, previous, point
			)
			if nearest.distance_squared_to(global_position_yless) <= 1.5 * 1.5:
				fuse_left = 0.35
				break
	remember_positions()


func remember_positions():
	_previous.clear()
	for unit in get_tree().get_nodes_in_group("units"):
		if manager.can_trigger(unit, self):
			_previous[unit.get_instance_id()] = unit.global_position_yless


func refresh_visibility():
	if manager == null or hp <= 0.0:
		return
	var game = manager.game
	visible = (
		game.settings.visibility == game.settings.Visibility.FULL
		or game.visible_players.any(func(side): return known_to(side))
	)
	input_ray_pickable = visible
	if _lamp != null:
		_lamp.visible = deploy_left > 0.0 or arm_left > 0.0 or fuse_left >= 0.0
		if fuse_left >= 0.0:
			_lamp.scale = Vector3.ONE * (1.0 + (0.35 - fuse_left) * 4.0)

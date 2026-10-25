extends Node3D

# Cosmetic rigid bodies collide only with terrain; they never enter gameplay queries.
const MAX_SCARS = 96
const MAX_DEBRIS = 32
const MAX_LIGHTS = 8
const SCAR_LIFETIME = 100.0
var scars = []
var debris = []
var lights = []
var _free_lights = []
var _random = RandomNumberGenerator.new()
var _chunk = BoxMesh.new()
var _ground = PlaneMesh.new()
var _metal = StandardMaterial3D.new()
var _physics_material = PhysicsMaterial.new()
var _brass = StandardMaterial3D.new()
var _case = CylinderMesh.new()


func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_random.seed = 49187
	_physics_material.friction = 0.85
	_physics_material.bounce = 0.18
	_chunk.size = Vector3.ONE
	_ground.size = Vector2.ONE
	_metal.albedo_color = Color("38352f")
	_metal.roughness = 0.88
	_metal.metallic = 0.35
	_brass.albedo_color = Color("ad8746")
	_brass.metallic = .7
	_brass.roughness = .38
	_case.top_radius = .5
	_case.bottom_radius = .5
	_case.height = 1.0
	_case.radial_segments = 8
	_case.rings = 1


func scar(point, radius):
	var game = get_parent().get_parent()
	var wear = game.battlefield_wear if game != null and "battlefield_wear" in game else null
	if wear != null:
		wear.scar(point, radius)
		return
	# Merge overlapping hits so sustained fire darkens one site without z-fighting.
	for entry in scars:
		if entry.node.position.distance_squared_to(point) < pow(radius * 0.45, 2):
			entry.age = 0.0
			entry.node.material_override.set_shader_parameter("opacity", 1.0)
			return
	_evict(scars, MAX_SCARS)
	var node = MeshInstance3D.new()
	node.mesh = _ground
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = preload("res://source/shaders/3d/battle_scar.gdshader")
	material.set_shader_parameter("seed", _random.randf_range(0, 100))
	node.material_override = material
	add_child(node)
	node.position = Vector3(point.x, 0.025 + _random.randf() * 0.012, point.z)
	node.rotation.y = _random.randf() * TAU
	node.scale = Vector3(radius * 2.0, 1.0, radius * _random.randf_range(1.6, 2.2))
	scars.append({"node": node, "age": 0.0})


func burst(point, strength, ground_hit = true):
	if ground_hit:
		scar(Vector3(point.x, 0, point.z), strength * 1.15)
	for _index in range(clampi(roundi(strength * 2), 2, 5)):
		_evict(debris, MAX_DEBRIS)
		var body = RigidBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 1  # Existing terrain collider; excludes units and navigation proxies.
		body.input_ray_pickable = false
		body.mass = _random.randf_range(0.15, 0.6)
		body.physics_material_override = _physics_material
		body.continuous_cd = true
		body.linear_damp = 0.18
		body.angular_damp = 0.7
		var size = _random.randf_range(0.045, 0.09) * sqrt(strength)
		var dimensions = Vector3(size, size * 0.7, size * _random.randf_range(1.2, 2.0))
		var mesh = MeshInstance3D.new()
		mesh.mesh = _chunk
		mesh.material_override = _metal
		mesh.scale = dimensions
		body.add_child(mesh)
		var collider = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = dimensions
		collider.shape = shape
		body.add_child(collider)
		body.position = (
			point
			+ Vector3(_random.randf_range(-0.15, 0.15), 0.05, _random.randf_range(-0.15, 0.15))
		)
		var angle = _random.randf() * TAU
		var speed = _random.randf_range(0.8, 2.2) * sqrt(strength)
		body.linear_velocity = Vector3(
			cos(angle) * speed, _random.randf_range(1.8, 3.6), sin(angle) * speed
		)
		body.angular_velocity = Vector3(_random.randf_range(-9, 9), _random.randf_range(-9, 9), 4)
		add_child(body)
		debris.append({"node": body, "mesh": mesh, "age": 0.0, "rest": dimensions})

	flash(point + Vector3.UP * 0.5, strength, Color("ffc078"))


# Brief unshadowed light. Optional flashes (muzzle fire) never displace blast lights and use
# at most half of the shared budget.
func flash(point, strength, color, optional = false):
	if Globals.options.reduced_flashes:
		return
	if optional and lights.size() >= MAX_LIGHTS / 2:
		return
	var light
	if not _free_lights.is_empty():
		light = _free_lights.pop_back()
	elif lights.size() >= MAX_LIGHTS:
		light = lights.pop_front().node
	else:
		light = OmniLight3D.new()
		light.shadow_enabled = false
		add_child(light)
	light.name = "MuzzleLight" if optional else "BlastLight"
	light.light_color = color
	light.omni_range = strength * 3.0 + 2.0
	light.light_energy = strength * (2.5 if optional else 1.5)
	light.position = point
	light.show()
	lights.append(
		{
			"node": light,
			"age": 0.0,
			"energy": light.light_energy,
			"duration": .085 if optional else .18
		}
	)


func clear_flashes():
	for entry in lights:
		entry.node.hide()
		_free_lights.append(entry.node)
	lights.clear()


func _evict(pool, limit):
	while pool.size() >= limit:
		var entry = pool.pop_front()
		entry.node.hide()
		if entry.node is RigidBody3D:
			entry.node.freeze = true
		entry.node.queue_free()


func advance(delta):
	for index in range(scars.size() - 1, -1, -1):
		var entry = scars[index]
		entry.age += delta
		entry.node.material_override.set_shader_parameter(
			"opacity", 1.0 - smoothstep(SCAR_LIFETIME - 15.0, SCAR_LIFETIME, entry.age)
		)
		if entry.age >= SCAR_LIFETIME:
			entry.node.queue_free()
			scars.remove_at(index)
	for index in range(debris.size() - 1, -1, -1):
		var entry = debris[index]
		entry.age += delta
		if entry.age > 2.8:
			entry.node.queue_free()
			debris.remove_at(index)
			continue
		# Fade only the mesh; never rescale or manually integrate a physics body.
		entry.mesh.scale = entry.rest * (1.0 - smoothstep(1.6, 2.8, entry.age))

	for index in range(lights.size() - 1, -1, -1):
		var entry = lights[index]
		entry.age += delta
		entry.node.light_energy = entry.energy * pow(maxf(0, 1.0 - entry.age / entry.duration), 2)
		if entry.age >= entry.duration or Globals.options.reduced_flashes:
			entry.node.hide()
			_free_lights.append(entry.node)
			lights.remove_at(index)


func casing(point: Vector3, direction: Vector3):
	# Share the existing bounded terrain-only debris budget.
	_evict(debris, MAX_DEBRIS)
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.input_ray_pickable = false
	body.mass = .18
	body.physics_material_override = _physics_material
	body.continuous_cd = true
	var mesh := MeshInstance3D.new()
	mesh.mesh = _case
	mesh.material_override = _brass
	var dimensions := Vector3(.085, .25, .085)
	mesh.scale = dimensions
	body.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	body.global_position = point
	body.linear_velocity = direction * 1.7 + Vector3.UP * 1.6
	body.angular_velocity = Vector3(6, 2, 9)
	debris.append({"node": body, "mesh": mesh, "age": 0.0, "rest": dimensions})


func detach_weapon(weapon: Node3D, velocity: Vector3):
	_evict(debris, MAX_DEBRIS)
	var world := weapon.global_transform
	var body := RigidBody3D.new()
	body.name = "DroppedWeapon"
	body.collision_layer = 0
	body.collision_mask = 1
	body.input_ray_pickable = false
	body.mass = .25
	body.continuous_cd = true
	body.physics_material_override = _physics_material
	body.angular_damp = .7
	add_child(body)
	body.global_transform = world.orthonormalized()
	weapon.reparent(body)
	weapon.transform = Transform3D(Basis.from_scale(world.basis.get_scale()), Vector3.ZERO)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.12, .12, .6)
	collider.shape = shape
	body.add_child(collider)
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(3, 5, 7)
	debris.append({"node": body, "mesh": weapon, "age": 0.0, "rest": weapon.scale})

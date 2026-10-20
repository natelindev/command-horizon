extends Node3D

# Draws every visible round in flight. One MultiMesh per visual kind holds a
# fixed pool of slots; transforms are written on the physics tick and the engine
# interpolates instances between ticks. Hidden slots are zero-scaled.

const CAPACITY = 384
# Saturated faction fire; glowing kinds are pushed above 1.0 so they bloom.
const FACTION_FIRE = {
	"bastion": Color("ffae45"),
	"helix": Color("54dcff"),
	"frontier": Color("c3f04f"),
}
const MOTOR = Color(1.0, 0.55, 0.22)
const GLOW = 1.35
# visual: [width, minimum length, length per m/s, glowing]
const SHAPES = {
	"tracer": [0.04, 0.35, 0.012, true],
	"heavy_tracer": [0.065, 0.3, 0.01, true],
	"slug": [0.12, 0.25, 0.005, true],
	"rocket": [0.09, 0.38, 0.0, true],
	"missile": [0.09, 0.44, 0.0, true],
	"bomb": [0.16, 0.5, 0.0, false],
}
var _pools = {}


class Pool:
	extends RefCounted
	var node = null
	var free = []
	var used = 0


func _ready():
	for visual in SHAPES:
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = _mesh(SHAPES[visual][3])
		multimesh.instance_count = CAPACITY
		multimesh.visible_instance_count = 0
		multimesh.physics_interpolation_quality = MultiMesh.INTERP_QUALITY_FAST
		var node = MultiMeshInstance3D.new()
		node.name = visual.capitalize().replace(" ", "")
		node.multimesh = multimesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(Vector3(-50, -5, -50), Vector3(400, 80, 400))
		add_child(node)
		var pool = Pool.new()
		pool.node = node
		_pools[visual] = pool


func _mesh(glowing):
	var mesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	if glowing:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color.WHITE
	else:
		material.albedo_color = Color(0.32, 0.33, 0.31)
		material.metallic = 0.4
		material.roughness = 0.55
	mesh.material = material
	return mesh


func add(round):
	var pool = _pools.get(round.weapon.get("visual", ""))
	if pool == null:
		return
	var slot = pool.free.pop_back() if not pool.free.is_empty() else pool.used
	if slot >= CAPACITY:
		return
	if slot == pool.used:
		pool.used += 1
		pool.node.multimesh.visible_instance_count = pool.used
	round.slot = slot
	var faction = round.shot.player.faction if "faction" in round.shot.player else ""
	var color = FACTION_FIRE.get(faction, FACTION_FIRE.bastion)
	if round.weapon.visual in ["rocket", "missile"]:
		color = MOTOR
	if SHAPES[round.weapon.visual][3]:
		color = Color(color.r * GLOW, color.g * GLOW, color.b * GLOW)
	else:
		color = Color.WHITE
	pool.node.multimesh.set_instance_color(slot, color)
	_place(pool, round)
	pool.node.multimesh.reset_instance_physics_interpolation(slot)


func update(round):
	var pool = _pools.get(round.weapon.get("visual", ""))
	if pool != null and round.slot >= 0:
		_place(pool, round)


func remove(round):
	var pool = _pools.get(round.weapon.get("visual", ""))
	if pool == null or round.slot < 0:
		return
	pool.node.multimesh.set_instance_transform(
		round.slot, Transform3D(Basis().scaled(Vector3.ZERO))
	)
	pool.node.multimesh.reset_instance_physics_interpolation(round.slot)
	pool.free.append(round.slot)
	round.slot = -1


func _place(pool, round):
	if not round.shown:
		pool.node.multimesh.set_instance_transform(
			round.slot, Transform3D(Basis().scaled(Vector3.ZERO), round.position)
		)
		return
	var shape = SHAPES[round.weapon.visual]
	var speed = round.velocity.length()
	var direction = round.velocity / speed if speed > 0.001 else Vector3.FORWARD
	var length = maxf(shape[1], speed * shape[2])
	var up = Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	var basis = Basis.looking_at(direction, up).scaled(Vector3(shape[0], shape[0], length))
	# The round's position is its nose; the streak trails behind it.
	pool.node.multimesh.set_instance_transform(
		round.slot, Transform3D(basis, round.position - direction * length * 0.5)
	)

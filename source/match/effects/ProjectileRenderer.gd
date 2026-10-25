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
const GLOW = 1.35
# visual: [width, minimum length, length per m/s]
const SHAPES = {
	"tracer": [0.04, 0.35, 0.012],
	"heavy_tracer": [0.065, 0.3, 0.01],
	"slug": [0.12, 0.25, 0.005],
	"rocket": [0.09, 0.38, 0.0],
	"missile": [0.09, 0.44, 0.0],
	"bomb": [0.16, 0.5, 0.0],
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
		multimesh.mesh = _mesh(visual)
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


# All meshes have their nose at -Z/2 and tail at +Z/2. Profiles store
# (axial position, radius, emission mask); twelve radial sides keep pools cheap.
func _mesh(visual):
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile = []
	match visual:
		"rocket", "missile":
			profile = [
				Vector3(-.5, 0, 0),
				Vector3(-.28, .46, 0),
				Vector3(-.2, .5, 0),
				Vector3(.29, .5, 0),
				Vector3(.35, .32, 0),
				Vector3(.47, .38, 0),
				Vector3(.47, .24, 1),
				Vector3(.43, 0, 1),
			]
			_fins(surface, .08 if visual == "missile" else .18, .44, .95, Color(.28, .32, .35, 0))
		"slug":
			profile = [
				Vector3(-.5, 0, 0),
				Vector3(-.43, .18, 0),
				Vector3(-.3, .37, 0),
				Vector3(-.12, .49, 0),
				Vector3(.31, .49, 0),
				Vector3(.36, .54, 0),
				Vector3(.43, .54, 0),
				Vector3(.47, .4, 1),
				Vector3(.5, 0, 1),
			]
		"bomb":
			profile = [
				Vector3(-.5, 0, 0),
				Vector3(-.45, .28, 0),
				Vector3(-.33, .47, 0),
				Vector3(-.12, .54, 0),
				Vector3(.08, .44, 0),
				Vector3(.27, .22, 0),
				Vector3(.48, .16, 0),
				Vector3(.5, 0, 0),
			]
			_fins(surface, .16, .47, .84, Color(.24, .28, .22, 0))
			# Closed annular shroud around the cruciform tail, including its inner wall.
			_lathe(
				surface,
				[
					Vector3(.28, .84, 0),
					Vector3(.48, .84, 0),
					Vector3(.48, .74, 0),
					Vector3(.28, .74, 0),
					Vector3(.28, .84, 0)
				],
				visual
			)
		_:
			profile = [
				Vector3(-.5, 0, 1),
				Vector3(-.39, .4, 1),
				Vector3(-.2, .5, 1),
				Vector3(.1, .32, 1),
				Vector3(.36, .12, 1),
				Vector3(.5, 0, 1),
			]
	_lathe(surface, profile, visual)
	surface.index()
	var mesh = surface.commit()
	var material = ShaderMaterial.new()
	material.shader = preload("res://source/shaders/3d/projectile.gdshader")
	mesh.surface_set_material(0, material)
	return mesh


func _vertex_color(visual, point):
	if visual in ["tracer", "heavy_tracer"]:
		var brightness = lerpf(.025, 1.0, pow(1.0 - (point.x + .5), 1.5))
		return Color(brightness, brightness, brightness, 1)
	if point.z > 0.0:
		return Color(1.0, .48, .12, point.z)
	if visual == "bomb":
		return Color(.28, .33, .22, 0)
	if visual == "slug":
		return Color(.56, .39, .18, 0)
	return Color(.5, .55, .57, 0) if point.x < .3 else Color(.14, .17, .19, 0)


func _lathe(surface, profile, visual):
	const SIDES = 12
	for ring in range(profile.size() - 1):
		var a = profile[ring]
		var b = profile[ring + 1]
		var slope = Vector2(b.x - a.x, b.y - a.y).normalized()
		for side in SIDES:
			var angles = [TAU * side / SIDES, TAU * (side + 1) / SIDES]
			# Clockwise winding; omit the collapsed triangle at each pointed end.
			var corners = []
			if a.y > 0:
				corners.append_array([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)])
			if b.y > 0:
				corners.append_array([Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)])
			for corner in corners:
				var point = a if corner.x == 0 else b
				var angle = angles[corner.y]
				surface.set_color(_vertex_color(visual, point))
				surface.set_normal(Vector3(cos(angle) * slope.x, sin(angle) * slope.x, -slope.y))
				surface.add_vertex(Vector3(cos(angle) * point.y, sin(angle) * point.y, point.x))


func _fins(surface, front, rear, span, color):
	# Four thin, closed swept wedges rather than camera-facing fin cards.
	for fin in 4:
		var rotation = Basis(Vector3.BACK, fin * TAU / 4)
		var points = []
		for thickness in [-.035, .035]:
			for point in [
				Vector3(.3, thickness, front),
				Vector3(span, thickness, rear - .06),
				Vector3(span, thickness, rear),
				Vector3(.3, thickness, rear)
			]:
				points.append(rotation * point)
		for face in [
			[3, 2, 1, 0], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]
		]:
			var normal = (
				(points[face[2]] - points[face[0]])
				. cross(points[face[1]] - points[face[0]])
				. normalized()
			)
			for corner in [0, 1, 2, 0, 2, 3]:
				surface.set_normal(normal)
				surface.set_color(color)
				surface.add_vertex(points[face[corner]])


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
	if round.weapon.visual in ["tracer", "heavy_tracer"]:
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
	var basis = (
		Basis.looking_at(direction, up) * Basis.from_scale(Vector3(shape[0], shape[0], length))
	)
	# The round's position is its nose; the streak trails behind it.
	pool.node.multimesh.set_instance_transform(
		round.slot, Transform3D(basis, round.position - direction * length * 0.5)
	)

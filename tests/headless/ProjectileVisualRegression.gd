extends SceneTree

var errors = []
var renderer_script
var system_script


class TrailRecorder:
	extends RefCounted
	var samples = []

	func trail(point, direction):
		samples.append({"point": point, "direction": direction})

	func can_show_point(_point):
		return false


class TransformCapture:
	extends RefCounted
	var transform = Transform3D.IDENTITY

	func set_instance_transform(_slot, value):
		transform = value


class EmptyField:
	extends RefCounted

	func nearby_units(_point, _reach, _unit = null, _player = null):
		return []

	func first_blocker(_start, _end, _shooter, _target):
		return {}


class Ground:
	extends RefCounted

	func height_at(_point):
		return 0.0


class PuffCapture:
	extends RefCounted
	var puffs = []

	func emit_particle(transform, velocity, color, _custom, _flags):
		puffs.append({"transform": transform, "velocity": velocity, "color": color})


class Stage:
	extends Node3D
	var combat_effects = TrailRecorder.new()
	var battlefield = EmptyField.new()
	var map = Ground.new()
	var restoring = false


class TestShot:
	extends RefCounted
	var player = {"faction": "helix"}
	var raw_damage = false

	func shooter():
		return null


func _initialize():
	_run.call_deferred()


func _run():
	renderer_script = load("res://source/match/effects/ProjectileRenderer.gd")
	system_script = load("res://source/match/combat/ProjectileSystem.gd")
	_meshes_and_pool()
	_trails()
	_exhaust()
	for error in errors:
		push_error(error)
	print("Projectile visuals: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _round(visual):
	var round = system_script.Round.new()
	round.weapon = {"visual": visual, "kind": visual, "gravity": 0.0}
	round.kind = visual
	round.shot = TestShot.new()
	round.shown = true
	round.velocity = Vector3(35, 0, 0)
	round.position = Vector3(10, 5, 10)
	round.life = 4.0
	return round


func _meshes_and_pool():
	var renderer = renderer_script.new()
	root.add_child(renderer)
	for visual in renderer.SHAPES:
		var pool = renderer._pools[visual]
		var mesh = pool.node.multimesh.mesh
		_check(
			mesh is ArrayMesh and mesh.get_surface_count() == 1,
			visual + " is not batched 3D geometry"
		)
		var arrays = mesh.surface_get_arrays(0)
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var colors = arrays[Mesh.ARRAY_COLOR]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var indices = arrays[Mesh.ARRAY_INDEX]
		_check(vertices.size() < 600 and indices.size() < 2200, visual + " geometry is too heavy")
		_check(
			Array(vertices).all(func(v): return v.is_finite()),
			visual + " contains invalid vertices"
		)
		for index in range(0, indices.size(), 3):
			var a = indices[index]
			var b = indices[index + 1]
			var c = indices[index + 2]
			var normal = (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
			_check(normal.length_squared() > .00000001, visual + " has a degenerate triangle")
			_check(
				normal.dot(normals[a] + normals[b] + normals[c]) > 0.0,
				visual + " winding disagrees with normals"
			)
		_check(is_equal_approx(mesh.get_aabb().position.z, -.5), visual + " nose is misaligned")
		if visual in ["rocket", "missile", "slug"]:
			_check(
				(
					Array(colors).any(func(c): return c.a == 0.0)
					and Array(colors).any(func(c): return c.a == 1.0)
				),
				visual + " lacks isolated emission"
			)
		if visual in ["rocket", "missile", "bomb"]:
			_check(
				mesh.get_aabb().size.x > 1.5 and mesh.get_aabb().size.y > 1.5,
				visual + " lacks cross fins"
			)
		if visual in ["tracer", "heavy_tracer"]:
			var nose = 0.0
			var tail = 0.0
			for index in vertices.size():
				if vertices[index].z < -.3:
					nose = maxf(nose, colors[index].r)
				if vertices[index].z > .3:
					tail = maxf(tail, colors[index].r)
			_check(nose > tail * 2.0, visual + " lacks a brighter nose")
		var round = _round(visual)
		var capture = TransformCapture.new()
		var capture_pool = {"node": {"multimesh": capture}}
		for direction in [Vector3.RIGHT, Vector3.UP, Vector3.DOWN, Vector3(1, 2, -3).normalized()]:
			round.velocity = direction * 35
			if round.slot < 0:
				renderer.add(round)
			else:
				renderer.update(round)
			# The headless dummy renderer does not retain MultiMesh transforms.
			renderer._place(capture_pool, round)
			var transform = capture.transform
			_check(
				(transform * Vector3(0, 0, -.5)).is_equal_approx(round.position),
				visual + " nose drifted on rotated flight"
			)
			_check(
				(-transform.basis.z.normalized()).is_equal_approx(direction),
				visual + " points away from velocity"
			)
		round.shown = false
		renderer.update(round)
		renderer._place(capture_pool, round)
		_check(
			capture.transform.basis == Basis.from_scale(Vector3.ZERO),
			"Hidden projectile remains visible"
		)
		renderer.remove(round)
		_check(round.slot == -1 and pool.free.size() == 1, "Slot was not returned")
		_check(
			pool.node.multimesh.physics_interpolation_quality == MultiMesh.INTERP_QUALITY_FAST,
			"Interpolation was lost"
		)
	var rounds = []
	for index in renderer.CAPACITY + 1:
		var round = _round("missile")
		renderer.add(round)
		rounds.append(round)
	_check(rounds[-1].slot == -1 and renderer._pools.missile.used == 384, "Pool exceeded capacity")
	var slot = rounds[17].slot
	renderer.remove(rounds[17])
	renderer.add(rounds[-1])
	_check(rounds[-1].slot == slot, "Saturated pool failed to reuse its free slot")
	renderer.free()


func _trails():
	var stage = Stage.new()
	root.add_child(stage)
	var system = system_script.new()
	stage.add_child(system)
	system.set_physics_process(false)
	system._tick = 1  # Keep the manually visible fixture between visibility checks.
	var round = _round("missile")
	round.burn = 1.0
	var start = round.position
	for tick in 12:
		system._step(round, 1.0 / 60.0)
	var samples = stage.combat_effects.samples
	_check(samples.size() >= 17, "35 m/s missile retained dotted 0.05s exhaust")
	_check(
		samples[0].point.is_equal_approx(start - Vector3.RIGHT * .44),
		"Exhaust does not start at the nozzle"
	)
	for index in range(1, samples.size()):
		_check(
			is_equal_approx(samples[index - 1].point.distance_to(samples[index].point), .4),
			"Trail spacing changed across ticks"
		)
	var count = samples.size()
	round.burn = 0.0
	system._step(round, .05)
	_check(samples.size() == count, "Burned-out motor kept emitting")
	round.burn = 1.0
	round.shown = false
	system._step(round, .05)
	_check(samples.size() == count, "Fog-hidden motor emitted a trail")
	round.shown = true
	round.burn = .005
	start = round.position
	system._step(round, .1)
	_check(samples.size() == count + 1, "Final partial burn was skipped or over-emitted")
	_check(samples[-1].point.x <= start.x + 35 * .005, "Exhaust extended beyond burnout")
	# A long segment is sub-stepped; a turn follows the new leg without bridging it.
	samples.clear()
	round.trail_distance = 0.0
	system._trail_segment(round, Vector3.ZERO, Vector3(3.5, 0, 0))
	_check(samples.size() == 9, "Long segment did not sub-step")
	round.velocity = Vector3.UP * 35
	system._trail_segment(round, Vector3(3.5, 0, 0), Vector3(3.5, 1, 0))
	_check(
		samples[-1].point.x == 3.5 and samples[-1].direction == Vector3.UP,
		"Turned trail bridged across the corner"
	)
	# Sweep into the ground within this tick: no samples past impact.
	samples.clear()
	round = _round("rocket")
	round.position = Vector3(10, .5, 10)
	round.velocity = Vector3(35, -10, 0)
	round.burn = 1.0
	system._step(round, .1)
	_check(
		not samples.is_empty() and samples.all(func(s): return s.point.x < 11.75),
		"Trail extended past ground contact"
	)
	stage.free()


func _exhaust():
	var stage = Stage.new()
	root.add_child(stage)
	var effects = load("res://source/match/effects/CombatEffects.gd").new()
	stage.add_child(effects)
	effects._headless = false
	var core = PuffCapture.new()
	var smoke = PuffCapture.new()
	effects._emitters = {"exhaust": core, "trail_smoke": smoke}
	var options = root.get_node("Globals").options
	var original = options.reduced_flashes
	options.reduced_flashes = false
	effects.trail(Vector3(2, 1, 3), Vector3.RIGHT)
	_check(core.puffs.size() == 1 and smoke.puffs.size() == 1, "Motor lacks layered fire and smoke")
	_check(smoke.puffs[0].transform.basis.x.length() * .85 > .4, "New smoke puffs cannot overlap")
	_check(
		core.puffs[0].velocity.x < smoke.puffs[0].velocity.x, "Exhaust core has no rearward punch"
	)
	options.reduced_flashes = true
	effects.trail(Vector3(2, 1, 3), Vector3.RIGHT)
	_check(
		core.puffs.size() == 1 and smoke.puffs.size() == 2,
		"Reduced flashes did not retain only smoke"
	)
	paused = true
	effects.trail(Vector3(2, 1, 3), Vector3.RIGHT)
	_check(smoke.puffs.size() == 2, "Paused motor kept emitting")
	paused = false
	stage.restoring = true
	effects.trail(Vector3(2, 1, 3), Vector3.RIGHT)
	_check(smoke.puffs.size() == 2, "Restoring match emitted a trail")
	options.reduced_flashes = original
	# Restore the headless lifecycle before freeing the fake GPU emitters.
	effects._headless = true
	effects._emitters.clear()
	stage.free()


func _check(condition, message):
	if not condition:
		errors.append(message)

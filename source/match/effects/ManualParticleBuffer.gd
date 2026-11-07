extends MultiMeshInstance3D

## Compatibility rendering cannot manually emit GPUParticles. A bounded instance
## ring keeps the same emission budgets and advances trajectories in the vertex
## shader; CPU work is proportional to emissions, not every live particle/frame.
var amount = 0
var lifetime = 1.0
var speed_scale = 1.0
var _clock = 0.0
var _last_emission = -INF
var _next = 0
var _surface: ShaderMaterial


func setup(kind, capacity, seconds, gravity, glow = 0.0, roughness = 0.0, metalness = -1.0):
	amount = capacity
	lifetime = seconds
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-64, -16, -64), Vector3(384, 80, 384))
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	_surface = ShaderMaterial.new()
	var mesh
	if metalness >= 0.0:
		_surface.shader = load("res://source/shaders/3d/manual_combat_debris.gdshader")
		_surface.set_shader_parameter("metalness", metalness)
		_surface.set_shader_parameter("soil", kind == "clod")
		mesh = BoxMesh.new()
	else:
		_surface.shader = load("res://source/shaders/3d/manual_combat_particle.gdshader")
		_surface.set_shader_parameter("glow", glow)
		_surface.set_shader_parameter("rough_edge", roughness)
		_surface.set_shader_parameter("flame", kind == "fire")
		_surface.set_shader_parameter("exhaust", kind == "exhaust")
		_surface.set_shader_parameter(
			"vapor", kind in ["smoke", "dust", "trail_smoke", "foam", "mist"]
		)
		_surface.set_shader_parameter(
			"billow", kind in ["smoke", "dust", "trail_smoke", "foam", "mist"]
		)
		_surface.set_shader_parameter(
			"fade_in",
			.06 if kind == "smoke" else (.025 if kind in ["dust", "trail_smoke"] else 0.0)
		)
		_surface.set_shader_parameter("grounded", kind in ["dust", "spark"])
		_surface.set_shader_parameter("directional", kind in ["dust", "exhaust", "spark"])
		_surface.set_shader_parameter("damping", 1.1 if kind == "dust" else .45)
		_surface.set_shader_parameter(
			"growth_start",
			(
				.85
				if kind == "trail_smoke"
				else (.35 if kind in ["smoke", "dust", "foam", "mist"] else 1.0)
			)
		)
		_surface.set_shader_parameter(
			"growth_end",
			(
				2.8
				if kind == "trail_smoke"
				else (
					1.15
					if kind in ["smoke", "foam", "mist"]
					else (1.65 if kind in ["dust", "flash"] else .35)
				)
			)
		)
		_surface.set_shader_parameter(
			"elongation",
			(
				4.0
				if kind == "exhaust"
				else (2.5 if kind == "spark" else (1.7 if kind == "dust" else 1.0))
			)
		)
		mesh = QuadMesh.new()
		mesh.size = Vector2.ONE
	_surface.set_shader_parameter("particle_lifetime", lifetime)
	_surface.set_shader_parameter("gravity", gravity)
	mesh.material = _surface
	multimesh.mesh = mesh
	multimesh.instance_count = amount
	multimesh.visible_instance_count = 0
	visible = false
	set_process(false)


func emit_particle(pose, velocity, color, custom, _flags):
	var size = pose.basis.x.length()
	var seed = fposmod(
		sin((pose.origin + velocity).dot(Vector3(12.9898, 78.233, 39.425))) * 43758.5453, 1.0
	)
	# The draw shader interprets these columns as velocity/size/ground metadata.
	# Birth time lives in the full-precision transform rather than Compatibility's
	# half-precision custom color, preserving brief flashes in long matches too.
	var data = Transform3D(
		Basis(velocity, Vector3(size, custom.r, 0), Vector3(_clock, 0, 1)), pose.origin
	)
	multimesh.set_instance_transform(_next, data)
	multimesh.set_instance_color(_next, color)
	multimesh.set_instance_custom_data(_next, Color(0, seed, 0, 0))
	multimesh.visible_instance_count = mini(amount, multimesh.visible_instance_count + 1)
	_next = (_next + 1) % amount
	_last_emission = _clock
	visible = true
	set_process(true)


func is_inactive():
	return _clock - _last_emission >= lifetime


func _process(delta):
	if get_tree().paused or speed_scale <= 0.0:
		return
	_clock += delta * speed_scale
	_surface.set_shader_parameter("particle_clock", _clock)
	if is_inactive():
		visible = false
		set_process(false)

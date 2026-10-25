extends Node

## Cosmetic history is bounded independently of unit population and gameplay RNG.
## Repaint in small batches when old marks are retired or a save is restored.
const MAX_MARKS = 2048
const RETIRE_BATCH = 128
const DRAW_BUDGET = 32
const RESOLUTION = 2048
const VEHICLES = ["Tank", "AdvancedTank", "AntiAirVehicle", "CombatRobot"]
var marks = []
var texture: DrawableTexture2D
var material: ShaderMaterial
var _game
var _terrain: MeshInstance3D
var _stamps = []
var _white: ImageTexture
var _last = {}
var _cursor = 0
var _drawn = 0
var _elapsed = 0.0
var _repainting = false


func _ready():
	name = "BattlefieldWear"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent()
	Globals.options.changed.connect(apply_options)
	apply_options()


func enabled():
	return Globals.options.battlefield_wear and Globals.options.graphics_ground_detail


func apply_options():
	if (
		enabled()
		and not marks.is_empty()
		and DisplayServer.get_name() != "headless"
		and texture == null
	):
		_create_texture()
	if is_instance_valid(_terrain):
		_terrain.material_overlay = material if enabled() and not marks.is_empty() else null
	if not enabled():
		_last.clear()


func _create_texture():
	_terrain = _game.map.get_node_or_null("Geometry/Terrain")
	if _terrain == null:
		return
	texture = DrawableTexture2D.new()
	texture.setup(
		RESOLUTION, RESOLUTION, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color.TRANSPARENT
	)
	var image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(image)
	# Immutable materials: deferred blits must never share changing stamp uniforms.
	for kind in 2:
		for angle in 32:
			var stamp = ShaderMaterial.new()
			stamp.shader = preload("res://source/shaders/3d/wear_stamp.gdshader")
			stamp.set_shader_parameter("angle", angle * TAU / 32.0)
			stamp.set_shader_parameter("tracks", kind == 0)
			_stamps.append(stamp)
	material = ShaderMaterial.new()
	material.shader = preload("res://source/shaders/3d/battlefield_wear.gdshader")
	material.set_shader_parameter("wear_map", texture)
	material.set_shader_parameter("map_size", _game.map.size)
	_drawn = 0


func _process(delta):
	if _game.restoring:
		return
	if enabled():
		if not get_tree().paused:
			_elapsed += delta
		if _elapsed >= .2:
			_elapsed = 0.0
			_sample_vehicles()
		_paint()


func _sample_vehicles():
	var units = _game.get_units()
	if units.is_empty():
		return
	var live = {}
	for unit in units:
		live[unit.get_instance_id()] = true
	for id in _last.keys():
		if not live.has(id):
			_last.erase(id)
	# Round robin avoids favoring the first player's vehicles in a large battle.
	for index in mini(32, units.size()):
		var unit = units[(_cursor + index) % units.size()]
		if unit.type not in VEHICLES:
			continue
		sample_vehicle(unit)
	_cursor = (_cursor + 32) % units.size()


func sample_vehicle(unit):
	var id = unit.get_instance_id()
	if not enabled() or not unit.visible or not _game.combat_audio._observed(unit):
		_last.erase(id)
		return
	var point = Vector2(unit.global_position.x, unit.global_position.z)
	if not _last.has(id):
		_last[id] = point
		return
	var distance = point.distance_to(_last[id])
	if distance < .7:
		return
	var direction = point - _last[id]
	_last[id] = point
	# Don't draw a trail across teleports, unseen travel, or long sampling gaps.
	if distance > 4.0:
		return
	add_mark(point, clampf(unit.radius * 1.4, .65, 1.8), direction.angle(), 0)


func scar(point: Vector3, radius: float):
	if enabled() and _observed_point(point):
		add_mark(
			Vector2(point.x, point.z), clampf(radius, .3, 6.0), fposmod(point.x + point.z, TAU), 1
		)


func _observed_point(point):
	if _game.settings.visibility == _game.settings.Visibility.FULL:
		return true
	var human = _game._get_human_player()
	if human == null:
		return false
	point.y = _game.map.height_at(Vector2(point.x, point.z)) + .8
	var observers = _game.get_observers()
	for observer in observers:
		if (
			"player" in observer
			and observer.player == human
			and _game.battlefield.can_observe_point(observer, point)
		):
			return true
	return false


func add_mark(point: Vector2, radius: float, angle: float, kind: int):
	if not Rect2(Vector2.ZERO, _game.map.size).has_point(point):
		return
	if marks.size() >= MAX_MARKS:
		marks = marks.slice(RETIRE_BATCH)
		_reset_texture()
	marks.append({"x": point.x, "z": point.y, "radius": radius, "angle": angle, "kind": kind})


func _reset_texture():
	_drawn = 0
	if texture != null:
		# Keep the previous ground visible while rebuilding the bounded history.
		# At most two 16 MiB textures exist; swapping avoids a flash of clean ground.
		texture = DrawableTexture2D.new()
		texture.setup(
			RESOLUTION, RESOLUTION, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color.TRANSPARENT
		)
		_repainting = true


func _paint():
	if texture == null and not marks.is_empty() and DisplayServer.get_name() != "headless":
		_create_texture()
	if texture == null:
		return
	_terrain.material_overlay = material if enabled() and not marks.is_empty() else null
	var end = mini(marks.size(), _drawn + DRAW_BUDGET)
	while _drawn < end:
		var mark = marks[_drawn]
		var scale = Vector2(RESOLUTION, RESOLUTION) / _game.map.size
		var extent = Vector2.ONE * mark.radius * scale
		var rect = Rect2i(
			Vector2i(Vector2(mark.x, mark.z) * scale - extent),
			Vector2i(extent * 2).max(Vector2i.ONE)
		)
		var direction = posmod(roundi(mark.angle / TAU * 32), 32)
		texture.blit_rect(rect, _white, Color.WHITE, 0, _stamps[mark.kind * 32 + direction])
		_drawn += 1
	if _repainting and _drawn == marks.size():
		material.set_shader_parameter("wear_map", texture)
		_repainting = false


func capture():
	return marks.duplicate(true)


func restore(saved):
	marks = saved.duplicate(true)
	_last.clear()
	_reset_texture()

extends SceneTree

# Records contact sheets of every mobile unit role for each faction: idle, start,
# cruise, turn, stop, attack (or work loop), hit reaction and destruction. Run
# without --headless and with --fixed-fps 60; optional user arguments:
#   -- --stage=after --factions=bastion,helix --roles=Tank,Infantry
const Catalog = preload("res://source/match/BastionCatalog.gd")
const ROLES = [
	"Infantry",
	"RocketInfantry",
	"SniperInfantry",
	"AssaultInfantry",
	"Hero",
	"Worker",
	"Tank",
	"AdvancedTank",
	"RepairRobot",
	"CombatRobot",
	"Drone",
	"Helicopter",
	"SupplyTruck",
	"Squad",
]
const FACTIONS = ["bastion", "helix", "frontier"]
const TILE = 400
const SHEET_TILE = 220
const COLUMNS = 6
const BASE = Vector3(36, 0, 14)

var resource_script
var moving_script
var attacking_script
var collecting_script
var repairing_script
var _game
var _human
var _enemy
var _camera
var _label
var _stage = "before"
var _rows = []
var _row_names = []
var _output = ""


func _initialize():
	call_deferred("_run")


func _run():
	var factions = FACTIONS
	var roles = ROLES
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			_stage = argument.trim_prefix("--stage=")
		elif argument.begins_with("--factions="):
			factions = Array(argument.trim_prefix("--factions=").split(","))
		elif argument.begins_with("--roles="):
			roles = Array(argument.trim_prefix("--roles=").split(","))
	# Action scripts reference autoloads, so load them after the tree is ready.
	resource_script = load("res://source/match/units/non-player/ResourceUnit.gd")
	moving_script = load("res://source/match/units/actions/Moving.gd")
	attacking_script = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	collecting_script = load("res://source/match/units/actions/CollectingResourcesWhileInRange.gd")
	repairing_script = load("res://source/match/units/actions/Repairing.gd")
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_output = "res://art/animation/%s/" % _stage
	DirAccess.make_dir_recursive_absolute(_output)
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "day_cycle": false, "time_of_day": 0, "weather": 1})
	for faction in factions:
		for role in roles:
			if role == "Squad":
				continue
			await _fixture(faction)
			await _record(role)
			_save_sheet("%s-%s" % [faction, role])
			await _close()
		if "Squad" in roles:
			await _fixture(faction)
			await _record_squad()
			_save_sheet("%s-squad" % faction)
			await _close()
	options.restore(original)
	print("Unit animation capture complete: ", _output)
	quit()


func _fixture(faction):
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if side == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = faction if side == 0 else ("helix" if faction != "helix" else "bastion")
		player.color = Color("e3ad48") if side == 0 else Color("38c8ce")
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	await _frames(40)
	var players = get_nodes_in_group("players")
	_human = players[0]
	_enemy = players[1]
	for side in players:
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
		else:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)
	_game.find_child("Minimap", true, false).set_physics_process(false)
	for layer in _game.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	_camera = Camera3D.new()
	_game.add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.rotation_degrees = Vector3(-30, 0, 0)
	_camera.make_current()
	var overlay = CanvasLayer.new()
	overlay.layer = 20
	_game.add_child(overlay)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	overlay.add_child(_label)
	_rows = []
	_row_names = []
	await _frames(5)


func _close():
	_game.queue_free()
	_game = null
	await _frames(6)


func _frames(count):
	for frame in range(count):
		await process_frame


func _spawn(role, player, point, facing = Vector3.RIGHT):
	var unit = load(Catalog.scene_path(role)).instantiate()
	var basis = Basis.looking_at(facing, Vector3.UP)
	_game._setup_and_spawn_unit(unit, Transform3D(basis, point), player, false)
	return unit


func _focus(point, extent):
	_camera.size = extent
	_camera.global_position = point + _camera.global_basis.z * 30.0


func _record(role):
	var airborne = role in ["Drone", "Helicopter"]
	var infantry = Catalog.is_infantry(role)
	var extent = 4.5 if infantry else (8.0 if not airborne else 6.5)
	var unit = _spawn(role, _human, BASE)
	await _frames(30)
	if unit.has_method("set_physics_process") and unit.get("hp_max") != null:
		unit.hp_max = 100000
		unit.hp = 100000
	unit.action = null
	await _frames(10)
	var visual = unit.get_node("BastionVisuals")
	# Idle: ambient breathing, then the long-idle gesture forced early.
	_focus(unit.global_position, extent)
	var row = _new_row("idle")
	for index in range(COLUMNS):
		if index == 2:
			visual._quiet_time = visual.motion.idle_delay
		await _capture(row, unit, "idle" if index < 2 else "idle gesture")
		await _frames(30 if index >= 2 else 20)
	# Start: issue a move order along +X from rest.
	var origin = unit.global_position
	unit.action = moving_script.new(origin + Vector3(9, 0, 0))
	_focus(origin + Vector3(0.6, 0, 0), extent)
	row = _new_row("start")
	for index in range(COLUMNS):
		await _capture(row, unit, "start +%d" % (index * 4))
		await _frames(4)
	await _frames(30)
	_focus(unit.global_position + Vector3(0.5, 0, 0), extent)
	row = _new_row("cruise")
	for index in range(COLUMNS):
		await _capture(row, unit, "cruise +%d" % (index * 3))
		await _frames(3)
	# Turn toward the camera.
	var turn_point = unit.global_position + Vector3(1.0, 0, 6.0)
	unit.action = moving_script.new(turn_point)
	_focus(unit.global_position + Vector3(0.4, 0, 0.8), extent)
	row = _new_row("turn")
	for index in range(COLUMNS):
		await _capture(row, unit, "turn +%d" % (index * 5))
		await _frames(5)
	for wait in range(240):
		if unit.global_position_yless.distance_to(turn_point * Vector3(1, 0, 1)) < 1.4:
			break
		await process_frame
	_focus(turn_point, extent)
	row = _new_row("stop")
	for index in range(COLUMNS):
		await _capture(row, unit, "stop +%d" % (index * 6))
		await _frames(6)
	await _frames(30)
	if role == "Worker":
		await _record_gathering(unit, extent)
	elif role == "RepairRobot":
		await _record_repair(unit, extent)
	elif unit.attack_damage != null and unit.attack_damage > 0:
		await _record_attack(unit, extent)
	await _record_hit(unit, extent)
	await _record_death(unit, extent)


func _record_attack(unit, extent):
	var target_role = "Drone" if unit.attack_domains == [0] else "Tank"
	var reach = minf(unit.attack_range * 0.7, 6.5)
	var target = _spawn(
		target_role, _enemy, unit.global_position + Vector3(-reach, 0, -1.0), Vector3.LEFT
	)
	await _frames(20)
	target.process_mode = Node.PROCESS_MODE_DISABLED
	target.hp_max = 100000
	target.hp = 100000
	var visual = unit.get_node("BastionVisuals")
	_focus(unit.global_position, extent)
	var row = _new_row("aim")
	unit.action = attacking_script.new(target)
	var fired = false
	var captured = 0
	for frame in range(480):
		if visual._recoil > 0.9:
			fired = true
			break
		if captured < 2 and frame % 6 == 0:
			await _capture(row, unit, "acquire +%d" % frame)
			captured += 1
		await process_frame
	for index in range(COLUMNS - captured):
		await _capture(row, unit, ("shot +%d" % (index * 3)) if fired else "no shot")
		await _frames(3)
	# Second shot captured on a fresh row so cadence and variation can be compared.
	row = _new_row("fire")
	for frame in range(480):
		if visual._recoil > 0.9 and frame > 2:
			break
		await process_frame
	for index in range(COLUMNS):
		await _capture(row, unit, "shot2 +%d" % (index * 2))
		await _frames(2)
	unit.action = null
	target.queue_free()
	await _frames(30)


func _record_gathering(unit, extent):
	var nearest = null
	for node in _game.find_children("*", "Area3D", true, false):
		if is_instance_of(node, resource_script) and node.can_harvest(unit):
			if (
				nearest == null
				or (
					node.global_position.distance_to(unit.global_position)
					< nearest.global_position.distance_to(unit.global_position)
				)
			):
				nearest = node
	if nearest == null:
		return
	unit.global_position = (
		nearest.global_position
		+ (unit.global_position - nearest.global_position).normalized() * (nearest.radius + 0.9)
	)
	unit.global_position.y = 0
	await _frames(4)
	unit.action = collecting_script.new(nearest)
	await _frames(20)
	_focus(unit.global_position, extent)
	var row = _new_row("gather")
	for index in range(COLUMNS):
		await _capture(row, unit, "gather +%d" % (index * 12))
		await _frames(12)
	unit.action = null
	await _frames(10)


func _record_repair(unit, extent):
	var patient = _spawn("Tank", _human, unit.global_position + Vector3(-2.4, 0, 0))
	await _frames(20)
	patient.process_mode = Node.PROCESS_MODE_DISABLED
	patient.hp = patient.hp_max * 0.4
	_game.repair_service.set_physics_process(true)
	unit.action = repairing_script.new(patient)
	await _frames(40)
	_focus(unit.global_position + Vector3(-1.0, 0, 0), extent)
	var row = _new_row("repair")
	for index in range(COLUMNS):
		await _capture(row, unit, "repair +%d" % (index * 12))
		await _frames(12)
	unit.action = null
	_game.repair_service.set_physics_process(false)
	patient.queue_free()
	await _frames(10)


func _record_hit(unit, extent):
	var source = _spawn("Tank", _enemy, unit.global_position + Vector3(6, 0, 0), Vector3.LEFT)
	await _frames(10)
	source.process_mode = Node.PROCESS_MODE_DISABLED
	_focus(unit.global_position, extent)
	var row = _new_row("hit")
	unit.receive_weapon_hit(source)
	for index in range(COLUMNS):
		await _capture(row, unit, "hit +%d" % (index * 3))
		await _frames(3)
	source.queue_free()
	await _frames(20)


func _record_death(unit, extent):
	var point = unit.global_position
	_focus(point, extent)
	var row = _new_row("death")
	await _capture(row, unit, "alive")
	unit.hp = 0
	for index in range(COLUMNS - 1):
		await _frames([2, 8, 12, 18, 30][index])
		await _capture(row, null, "death", point)
	await _frames(20)


func _record_squad():
	var squad = []
	for index in range(8):
		var unit = _spawn(
			"Infantry", _human, BASE + Vector3(index % 4 * 0.9, 0, index / 4 * 0.9), Vector3.RIGHT
		)
		squad.append(unit)
	await _frames(40)
	for unit in squad:
		unit.action = null
	await _frames(20)
	var center = BASE + Vector3(1.35, 0, 0.45)
	_focus(center, 5.0)
	var row = _new_row("squad idle")
	for unit in squad:
		var visual = unit.get_node("BastionVisuals")
		visual._quiet_time = visual.motion.idle_delay
	for index in range(COLUMNS):
		await _capture(row, null, "squad idle +%d" % (index * 20), center, 1.6)
		await _frames(20)
	for index in range(squad.size()):
		squad[index].action = moving_script.new(squad[index].global_position + Vector3(8, 0, 0))
	await _frames(30)
	row = _new_row("squad move")
	for index in range(COLUMNS):
		# Track the squad's centre so every soldier stays in frame.
		center = Vector3.ZERO
		for unit in squad:
			center += unit.global_position / squad.size()
		_focus(center, 6.0)
		await _capture(row, null, "squad move +%d" % (index * 4), center, 1.6)
		await _frames(4)


func _new_row(name):
	print("  row ", name)
	_rows.append([])
	_row_names.append(name)
	return _rows.size() - 1


func _capture(row, unit, caption, point = Vector3.INF, scale = 1.0):
	if unit != null and is_instance_valid(unit):
		point = unit.global_position
	var screen = _camera.unproject_position(point + Vector3.UP * 0.4)
	var size = int(TILE * scale)
	var rect = Rect2i(Vector2i(screen) - Vector2i(size / 2, size / 2), Vector2i(size, size))
	rect.position = rect.position.clamp(Vector2i.ZERO, Vector2i(1440, 900) - rect.size)
	_label.position = Vector2(rect.position) + Vector2(8, 4)
	_label.text = caption
	# Flush the new camera and caption before reading the render target. A forced
	# draw in this same script callback can otherwise return the previous pose.
	await process_frame
	RenderingServer.force_draw(false)
	var image = root.get_texture().get_image().get_region(rect)
	image.resize(SHEET_TILE, SHEET_TILE, Image.INTERPOLATE_LANCZOS)
	_rows[row].append(image)


func _save_sheet(name):
	var sheet = Image.create(
		SHEET_TILE * COLUMNS, SHEET_TILE * maxi(1, _rows.size()), false, Image.FORMAT_RGBA8
	)
	sheet.fill(Color("15181b"))
	for row in range(_rows.size()):
		for column in range(_rows[row].size()):
			var image = _rows[row][column]
			image.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(
				image,
				Rect2i(Vector2i.ZERO, image.get_size()),
				Vector2i(column * SHEET_TILE, row * SHEET_TILE)
			)
	sheet.save_png(_output + name + ".png")
	print("Saved ", name, " rows=", _row_names)

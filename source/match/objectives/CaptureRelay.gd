extends Area3D

signal captured(player)

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")
const CAPTURE_SECONDS = 10.0
const RADIUS = 3.0
var label_title = "RELAY"
var captured_by = null
var candidate = null
var progress = 0.0
var contested = false
var sight_range = 27.0
var hp = 1.0
# Set by elevated maps so the relay settles on the ground, not the nav surface.
var path_height_offset = 0.0
var player:
	get:
		return captured_by
var _lamp: StandardMaterial3D
var _label: Label3D
var _rotor: Node3D
var _halo: MeshInstance3D
var _halo_material: StandardMaterial3D
var _capture_ring
var _vision_ring
var _anim_phase = 0.0
@onready var _match = find_parent("Match")


func _init():
	collision_layer = 0
	collision_mask = 0


func _enter_tree():
	_invalidate_registry()
	var game = find_parent("Match")
	if game != null and game.has_method("invalidate_vision_registry"):
		tree_exited.connect(game.invalidate_vision_registry, CONNECT_ONE_SHOT)


func _exit_tree():
	_invalidate_registry()


func _invalidate_registry():
	var game = find_parent("Match")
	if game != null and game.has_method("invalidate_vision_registry"):
		game.invalidate_vision_registry()


func _ready():
	add_to_group("vision_sources")
	_invalidate_registry()
	_build_model()
	var obstacle = load("res://source/match/units/traits/MovementObstacle.tscn").instantiate()
	obstacle.radius = 0.85
	obstacle.path_height_offset = path_height_offset
	obstacle.affect_navigation_mesh = true
	add_child(obstacle)


func _physics_process(delta):
	if _match == null or not _match.is_node_ready():
		return
	var presence = _capture_presence()
	var infantry = presence.infantry
	var combatants = presence.combatants
	var defending = captured_by if captured_by != null else candidate
	contested = (
		combatants.size() > 1
		or (defending != null and combatants.any(func(side): return side != defending))
	)
	# A single opposing infantry force may recapture an owned relay; defenders contest it.
	if infantry.size() == 1 and combatants.size() == 1:
		var side = infantry[0]
		if side != captured_by:
			if candidate != side:
				candidate = side
				progress = 0.0
			progress += delta
			if progress >= CAPTURE_SECONDS:
				captured_by = side
				candidate = null
				progress = 0.0
				contested = false
				_match.battlefield.invalidate()
				captured.emit(side)
		elif candidate != null:
			candidate = null
			progress = 0.0
	_update_presentation()


func _capture_presence():
	if _match == null or _match.battlefield == null:
		return {"infantry": [], "combatants": []}
	var nearby = _match.battlefield.nearby_units(global_position, RADIUS)
	var infantry = []
	var combatants = []
	for unit in nearby:
		if unit.is_queued_for_deletion() or unit.hp <= 0:
			continue
		if unit.movement_domain != Constants.Match.Navigation.Domain.TERRAIN:
			continue
		if unit.movement_speed <= 0 or unit.attack_range == null:
			continue
		if unit.player not in combatants:
			combatants.append(unit.player)
		if InfantryRoster.is_infantry(unit.type) and unit.player not in infantry:
			infantry.append(unit.player)
	# Allied armies count as one side. Prefer the owner/candidate so allies
	# reinforce a held site instead of taking ownership from one another.
	var sides = []
	for side in [captured_by, candidate] + infantry + combatants:
		if side != null and not sides.any(func(other): return other.is_allied_with(side)):
			sides.append(side)
	var allied_infantry = []
	var allied_combatants = []
	for side in sides:
		if infantry.any(func(other): return side.is_allied_with(other)):
			allied_infantry.append(side)
		if combatants.any(func(other): return side.is_allied_with(other)):
			allied_combatants.append(side)
	return {"infantry": allied_infantry, "combatants": allied_combatants}


func capture_side():
	# Ownership contention can suspend scoring while a sole opposing infantry force
	# is actively recapturing. Derive activity from occupancy, including paused loads.
	var presence = _capture_presence()
	if presence.infantry.size() == 1 and presence.combatants.size() == 1:
		if presence.infantry[0] != captured_by:
			return presence.infantry[0]
	return null


func needs_infantry(viewer):
	var presence = _capture_presence()
	return (
		captured_by != viewer
		and presence.combatants.size() == 1
		and presence.combatants[0] == viewer
		and viewer not in presence.infantry
	)


func capture_status(viewer):
	var active = capture_side()
	if active != null:
		var elapsed = progress if candidate == active else 0.0
		var action = tr("Enemy capture")
		if active == viewer:
			action = tr("Capturing") if captured_by == null else tr("Recapturing")
		return tr("%s %d / 10 s") % [action, int(elapsed)]
	if needs_infantry(viewer):
		return tr("Infantry needed")
	if contested:
		return tr("Contested")
	if candidate != null and progress > 0:
		return tr("Capture held %d / 10 s") % int(progress)
	if captured_by != null:
		return tr("Secured") if captured_by == viewer else tr("Enemy owned")
	return tr("Unclaimed")


func capture_help(viewer):
	var text = "Infantry within 3 m capture in 10 seconds. Opposing ground combatants pause capture."
	if needs_infantry(viewer):
		text += " Move infantry within 3 m to capture; armor cannot change ownership."
	elif contested and capture_side() != viewer:
		text += " Clear opposing ground units to restore uncontested control."
	if candidate != null and progress > 0:
		text += (
			" %s capture progress: %d / 10 s; retained while vacant or contested."
			% ["Your" if candidate == viewer else "Enemy", int(progress)]
		)
	if captured_by != null:
		text += (
			" Current owner: %s. Ownership changes when capture completes."
			% ("you" if captured_by == viewer else "enemy")
		)
	return text


func is_revealing():
	return captured_by != null and captured_by in _match.visible_players


func _update_presentation():
	var was_revealed = is_in_group("revealed_units")
	if is_revealing():
		add_to_group("revealed_units")
	else:
		remove_from_group("revealed_units")
	if was_revealed != is_in_group("revealed_units"):
		_match.invalidate_group_registry("revealed_units")
	_lamp.albedo_color = captured_by.color if captured_by != null else Color("d0baa0")
	_lamp.emission = _lamp.albedo_color * 0.7
	if _halo_material != null:
		_halo_material.albedo_color = _lamp.albedo_color
		_halo_material.emission = _lamp.albedo_color * (1.2 if captured_by != null else 0.45)
	if is_instance_valid(_capture_ring):
		_capture_ring.visible = captured_by == null or candidate != null or contested
		_capture_ring.color = (
			candidate.color if candidate != null else Color(0.88, 0.80, 0.56, 0.65)
		)
	if is_instance_valid(_vision_ring):
		var human = _match._get_human_player() if _match != null else null
		_vision_ring.visible = (
			captured_by != null and human != null and captured_by.is_allied_with(human)
		)
		if _vision_ring.visible:
			_vision_ring.color = Color(
				captured_by.color.r, captured_by.color.g, captured_by.color.b, 0.28
			)
	_label.text = tr(label_title) + " · " + capture_status(_match._get_human_player()).to_upper()
	if contested or candidate != null:
		_label.modulate = Color("f5cf7d")
	elif captured_by != null:
		_label.modulate = Color("f2ecd8").lerp(captured_by.color, 0.45)
	else:
		_label.modulate = Color("f2ecd8")


func _process(delta: float):
	if get_tree().paused:
		return
	var speed = 1.8 if captured_by != null else 0.7
	_anim_phase = fmod(_anim_phase + delta * speed, TAU)
	if is_instance_valid(_rotor):
		_rotor.rotation.y = _anim_phase
	if is_instance_valid(_halo):
		var pulse = 1.0 + 0.08 * sin(_anim_phase * 2.0)
		_halo.scale = Vector3(pulse, 1.0, pulse)


func _build_model():
	var concrete = StandardMaterial3D.new()
	concrete.albedo_color = Color("646864")
	concrete.roughness = 0.85
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color("46525a")
	steel.metallic = 0.65
	steel.roughness = 0.45
	var dish_mat = StandardMaterial3D.new()
	dish_mat.albedo_color = Color("cfd4d6")
	dish_mat.metallic = 0.35
	dish_mat.roughness = 0.35
	_lamp = StandardMaterial3D.new()
	_lamp.emission_enabled = true
	_halo_material = StandardMaterial3D.new()
	_halo_material.emission_enabled = true
	_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Concrete base pad + armored plinth + mast.
	_cyl(0.95, 0.22, Vector3(0, 0.11, 0), concrete, 8)
	_box(Vector3(1.15, 0.65, 1.15), Vector3(0, 0.52, 0), steel)
	_cyl(0.28, 2.3, Vector3(0, 1.9, 0), steel, 8)
	_cyl(0.36, 0.28, Vector3(0, 1.65, 0), _lamp, 12)
	# Rotating twin-wing surveillance radar head.
	_rotor = Node3D.new()
	_rotor.name = "RelayRotor"
	_rotor.position = Vector3(0, 3.15, 0)
	add_child(_rotor)
	_box_into(_rotor, Vector3(1.75, 0.26, 0.48), Vector3(0, 0, 0), dish_mat)
	_box_into(_rotor, Vector3(1.82, 0.10, 0.54), Vector3(0, 0, 0), _lamp)
	for x in [-0.62, 0.62]:
		_box_into(_rotor, Vector3(0.08, 0.95, 0.08), Vector3(x, 0.55, 0), steel)
	_halo = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.48
	torus.outer_radius = 0.58
	_halo.mesh = torus
	_halo.position = Vector3(0, 3.55, 0)
	_halo.material_override = _halo_material
	add_child(_halo)
	var circle_scene = load("res://source/generic-scenes-and-nodes/3d/Circle3D.tscn")
	_capture_ring = circle_scene.instantiate()
	_capture_ring.radius = RADIUS
	_capture_ring.width = 0.08
	_capture_ring.position = Vector3(0, 0.06, 0)
	add_child(_capture_ring)
	_vision_ring = circle_scene.instantiate()
	_vision_ring.radius = sight_range
	_vision_ring.width = 0.05
	_vision_ring.position = Vector3(0, 0.05, 0)
	_vision_ring.visible = false
	add_child(_vision_ring)
	_label = Label3D.new()
	_label.font = load("res://assets/fonts/NotoSansSC.ttf")
	_label.position = Vector3(0, 5.1, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 12
	_label.outline_render_priority = 11
	_label.font_size = 42
	_label.outline_size = 10
	_label.outline_modulate = Color("0b1318")
	_label.modulate = Color("f2ecd8")
	_label.pixel_size = 0.013
	add_child(_label)
	_update_presentation()


func _cyl(radius_val, height_val, point, material, sides = 12):
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius_val
	mesh.bottom_radius = radius_val
	mesh.height = height_val
	mesh.radial_segments = sides
	node.mesh = mesh
	node.position = point
	node.material_override = material
	add_child(node)
	return node


func _box_into(parent, size, point, material):
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = point
	node.material_override = material
	parent.add_child(node)
	return node


func _box(size, point, material):
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = point
	node.material_override = material
	add_child(node)

extends Node3D

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")

signal captured(player)

const CAPTURE_SECONDS = 10.0
const RADIUS = 3.0
var label_title = "RELAY"
var captured_by = null
var candidate = null
var progress = 0.0
var contested = false
var sight_range = 9.0
var hp = 1.0
var player:
	get:
		return captured_by
var _lamp: StandardMaterial3D
var _label: Label3D
@onready var _match = find_parent("Match")


func _ready():
	add_to_group("vision_sources")
	_build_model()
	var obstacle = load("res://source/match/units/traits/MovementObstacle.tscn").instantiate()
	obstacle.radius = 0.85
	obstacle.affect_navigation_mesh = true
	add_child(obstacle)


func _physics_process(delta):
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
	if _match.battlefield == null:
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
	return {"infantry": infantry, "combatants": combatants}


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
		var action = "Enemy capture"
		if active == viewer:
			action = "Capturing" if captured_by == null else "Recapturing"
		return "%s %d / 10 s" % [action, int(elapsed)]
	if needs_infantry(viewer):
		return "Infantry needed"
	if contested:
		return "Contested"
	if candidate != null and progress > 0:
		return "Capture held %d / 10 s" % int(progress)
	if captured_by != null:
		return "Secured" if captured_by == viewer else "Enemy owned"
	return "Unclaimed"


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
	if is_revealing():
		add_to_group("revealed_units")
	else:
		remove_from_group("revealed_units")
	_lamp.albedo_color = captured_by.color if captured_by != null else Color("d0baa0")
	_lamp.emission = _lamp.albedo_color * 0.7
	_label.text = label_title + " · " + capture_status(_match._get_human_player()).to_upper()


func _build_model():
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color("46525a")
	steel.metallic = 0.65
	steel.roughness = 0.45
	_lamp = StandardMaterial3D.new()
	_lamp.emission_enabled = true
	_box(Vector3(1.4, 0.25, 1.4), Vector3(0, 0.13, 0), steel)
	_box(Vector3(0.45, 2.4, 0.45), Vector3(0, 1.3, 0), steel)
	_box(Vector3(1.6, 0.25, 0.5), Vector3(0, 2.5, 0), _lamp)
	for x in [-0.5, 0.5]:
		_box(Vector3(0.08, 1.1, 0.08), Vector3(x, 3.05, 0), steel)
	_label = Label3D.new()
	_label.position = Vector3(0, 4.0, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.outline_size = 10
	_label.outline_modulate = Color("15232c")
	_label.pixel_size = 0.015
	add_child(_label)
	_update_presentation()


func _box(size, point, material):
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = point
	node.material_override = material
	add_child(node)

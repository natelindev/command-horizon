extends "res://source/match/environment/DestructibleObstacle.gd"

## Persistent gameplay cover. Cosmetic collapse never moves the camera or changes
## the footprint; engineers salvage it and heavy ground vehicles can bulldoze it.
const COLLAPSE_SECONDS = 1.5
var source_role = "Barracks"
var source_faction = "bastion"
var materials = 0
var age = 0.0
var _smoke_left = 0.0
var _settled = false
var _model: Node3D
var _rubble: Node3D


static func from_structure(unit):
	var ruin = load("res://source/match/world/StructureRuin.gd").new()
	ruin.source_role = unit.type
	ruin.source_faction = unit.player.faction
	ruin.position = unit.global_position
	ruin.rotation.y = unit.rotation.y
	ruin.radius = unit.radius * .85
	var cost = _factions().cost(unit.player, unit.type, true)
	ruin.materials = maxi(1, floori(cost.resource_a * .25))
	return ruin


func _ready():
	type = "StructureRuin"
	obstacle_height = .8
	light_barricade = true
	add_to_group("structure_ruins")
	_build_geometry()
	super()
	destroyed.connect(queue_free)
	_pose()
	_settled = age >= COLLAPSE_SECONDS
	if age == 0.0 and _match != null:
		_match.combat_effects.structural_failure(self, false)


func _build_geometry():
	var geometry = Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	var factions = _factions()
	var prototype = load(factions.scene_path(source_faction, source_role)).instantiate()
	factions.prepare_model(prototype, source_faction)
	_model = load("res://source/match/rendering/UnitBatchRenderer.gd").duplicate_geometry(
		prototype.get_node("Geometry"), 0
	)
	prototype.free()
	geometry.add_child(_model)
	var charred = StandardMaterial3D.new()
	charred.albedo_color = Color("79736b")
	charred.vertex_color_use_as_albedo = true
	charred.roughness = .95
	charred.metallic = .2
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = charred
		mesh.material_overlay = null
		for surface in mesh.get_surface_override_material_count():
			mesh.set_surface_override_material(surface, null)
	_rubble = Node3D.new()
	geometry.add_child(_rubble)
	var random = RandomNumberGenerator.new()
	random.seed = source_role.hash() + source_faction.hash()
	var concrete = StandardMaterial3D.new()
	concrete.albedo_color = Color("625e54")
	concrete.roughness = 1.0
	for index in 10:
		var chunk = MeshInstance3D.new()
		chunk.mesh = BoxMesh.new()
		chunk.mesh.size = Vector3(
			random.randf_range(.25, .6), random.randf_range(.12, .35), random.randf_range(.2, .55)
		)
		chunk.material_override = concrete
		var angle = index * TAU / 10.0
		chunk.position = Vector3(cos(angle), 0, sin(angle)) * radius * random.randf_range(.65, 1.05)
		chunk.position.y = .08
		chunk.rotation = Vector3(random.randf_range(-.4, .4), angle, random.randf_range(-.4, .4))
		_rubble.add_child(chunk)


func _physics_process(delta):
	age += delta
	if age < COLLAPSE_SECONDS or not _settled:
		_pose()
	if not _settled and age >= COLLAPSE_SECONDS:
		_settled = true
		_match.combat_effects.structural_failure(self, true)
	_smoke_left -= delta
	if age < 30.0 and _smoke_left <= 0.0:
		_smoke_left = .8
		_match.combat_effects.ruin_smoke(self)
	super(delta)


func _pose():
	var progress = clampf((age - .15) / (COLLAPSE_SECONDS - .15), 0.0, 1.0)
	var fall = progress * progress
	_model.scale.y = lerpf(1.0, .18, fall)
	_model.rotation.z = sin(progress * PI) * .08
	_model.position.y = -fall * .12
	_rubble.scale = Vector3.ONE * maxf(.001, fall)


func can_collect(unit) -> bool:
	return (
		not _breached
		and hp > 0.0
		and age >= COLLAPSE_SECONDS
		and is_instance_valid(unit)
		and unit.hp > 0.0
		and not unit.has_meta("garrison_host")
		and unit.type in ["Worker", "Tank", "AdvancedTank"]
		and unit.combat_domain() == combat_domain()
	)


func pickup_description() -> Array:
	var lines = [tr("Ruins · %s") % _factions().title(source_faction, source_role)]
	if age < COLLAPSE_SECONDS:
		lines.append(tr("Collapsing · %.1f s remaining") % (COLLAPSE_SECONDS - age))
	else:
		lines.append(
			tr("%d M salvage · 2 s collection") % _salvage_amount(_match._get_human_player())
		)
		lines.append(tr("Engineers salvage; heavy vehicles clear without salvage."))
	lines.append(tr("Nearby infantry gain 20% directional cover against small arms."))
	return lines


func collect(unit, elapsed: float) -> bool:
	if (
		not can_collect(unit)
		or elapsed < 2.0
		or unit.global_position_yless.distance_to(global_position_yless) > radius + unit.radius + .7
		or not _match.battlefield.is_observed(unit.player, self)
	):
		return false
	var amount = _salvage_amount(unit.player) if unit.type == "Worker" else 0
	materials = 0
	if amount > 0:
		unit.player.add_resources({"resource_a": amount})
		MatchSignals.resources_mined.emit(unit, "materials", amount)
	breach()
	return true


func _salvage_amount(player) -> int:
	if (
		player != null
		and player.faction == "frontier"
		and player.technology != null
		and "scrap_cannibalization" in player.technology.completed
	):
		return floori(materials * 1.5)
	return materials


func capture_state() -> Dictionary:
	return {
		"source_role": source_role,
		"source_faction": source_faction,
		"materials": materials,
		"age": age
	}


func restore_state(saved: Dictionary):
	source_role = saved.source_role
	source_faction = saved.source_faction
	materials = saved.materials
	age = saved.age


static func _factions():
	return load("res://source/match/FactionCatalog.gd")

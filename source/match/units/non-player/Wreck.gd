extends "res://source/match/units/non-player/ResourceA.gd"

const Factions = preload("res://source/match/FactionCatalog.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")
var wreck_role = "Tank"
var wreck_faction = "bastion"
var salvage_left = 180.0
var player = null
var _elapsed = 0.0
@onready var game = find_parent("Match")


func _ready():
	add_to_group("salvage_wrecks")
	var geometry = get_node("Geometry")
	for child in geometry.get_children():
		child.free()
	var prototype = load(Catalog.scene_path(wreck_role)).instantiate()
	Factions.prepare_model(prototype, wreck_faction)
	var model = prototype.get_node("Geometry").duplicate()
	prototype.free()
	var bounds = Factions._bounds(model, Transform3D.IDENTITY)
	var factor = .9  # Retain the source vehicle scale; only compress the damaged hull.
	model.scale *= Vector3(factor, factor * .55, factor)
	model.position.y = -bounds.position.y * factor * .55
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("605b4a")
	material.metallic = .4
	material.roughness = .9
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
	geometry.add_child(model)
	load("res://source/match/ObjectMaterials.gd").apply(model)
	geometry.rotation.y = fmod(position.x * 31 + position.z * 73, TAU)
	_refresh()


func _physics_process(delta):
	salvage_left = maxf(0, salvage_left - delta)
	if salvage_left == 0:
		queue_free()
	_elapsed += delta
	if _elapsed >= .2:
		_elapsed = 0
		_refresh()


func can_harvest(worker):
	return (
		worker.type == "Worker"
		and worker.hp > 0
		and not worker.is_queued_for_deletion()
		and worker.player.faction == "frontier"
		and resource_a > 0
		and salvage_left > 0.0
		and known_to(worker.player)
		and not is_queued_for_deletion()
	)


func known_to(observer):
	return game.battlefield.is_observed(observer, self)


func _refresh():
	visible = (
		game.settings.visibility == game.settings.Visibility.FULL
		or game.visible_players.any(known_to)
	)


# Check and debit synchronously so two orders in one frame cannot reuse scrap.
func consume_by(unit) -> bool:
	if (
		is_queued_for_deletion()
		or salvage_left <= 0.0
		or resource_a <= 0
		or not known_to(unit.player)
		or not Utils.Match.Unit.Movement.units_adhere(unit, self)
	):
		return false
	resource_a = 0
	return true


func dismantle(worker) -> bool:
	if not can_harvest(worker) or not Utils.Match.Unit.Movement.units_adhere(worker, self):
		return false
	var amount = resource_a
	if not consume_by(worker):
		return false
	if (
		worker.player != null
		and worker.player.technology != null
		and "scrap_cannibalization" in worker.player.technology.completed
	):
		amount = floori(amount * 1.43)
		var center = global_position
		for ally in worker.player.get_children():
			if (
				ally.is_in_group("units")
				and ally.hp != null
				and ally.hp_max != null
				and ally.hp > 0
				and ally.global_position.distance_squared_to(center) <= 64.0
			):
				ally.hp = minf(ally.hp_max, ally.hp + 25.0)
	worker.player.resource_a += amount
	MatchSignals.resources_mined.emit(worker, "materials", amount)
	return true

extends Node

## Event-driven doctrine effects use ordinary unit damage, placement and spawn
## paths. Their only persistent state is the researched doctrine itself.
var _emitting_flash = false
@onready var technology = get_parent()
@onready var player = technology.get_parent()
@onready var game = player.find_parent("Match")


func _ready():
	MatchSignals.unit_destroying.connect(_on_destroying)


func watch(unit):
	if unit.player != player or unit.has_meta("doctrine_shield_hook"):
		return
	unit.set_meta("doctrine_shield_hook", true)
	unit.shield_component.broken.connect(_shield_broken.bind(weakref(unit)))


func _shield_broken(reference: WeakRef):
	if _emitting_flash or "phase_overload" not in technology.completed or game == null:
		return
	var source = reference.get_ref()
	if not is_instance_valid(source) or source.hp <= 0.0:
		return
	_emitting_flash = true
	for target in game.battlefield.nearby_units(source.global_position, 3.5, null, player):
		if player.is_allied_with(target.player) or target.hp <= 0.0:
			continue
		target.shield_component.drain(30.0, game.simulation_time)
		if target.suppression != null:
			target.suppression.add_pressure(20.0)
		var movement = target.get_node_or_null("Movement")
		if movement != null and movement.has_method("apply_ion_stall"):
			movement.apply_ion_stall(1.0)
	game.combat_effects.airburst(source.global_position + Vector3.UP, 3.5, Color("5cddff"))
	_emitting_flash = false


func _on_destroying(unit):
	if (
		game == null or unit.player != player or "guerrilla_insurgency" not in technology.completed
		or not unit.has_method("is_constructed") or not unit.is_constructed()
	):
		return
	var catalog = load("res://source/match/FactionCatalog.gd")
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var navigation = game.navigation.get_navigation_map_rid_by_domain(1)
	var obstacles = get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units")
	var remaining = mini(3, 100 - player.population(true))
	for ring in [unit.radius + 1.5, unit.radius + 3.0, unit.radius + 4.5]:
		for index in 12:
			if remaining <= 0:
				return
			var point = unit.global_position + Vector3(cos(index * TAU / 12), 0.0, sin(index * TAU / 12)) * ring
			point = game.map.ground_point(Vector2(point.x, point.z))
			if placement.validate_agent_placement_position(point, 0.4, obstacles, navigation, game.map) != placement.VALID:
				continue
			var militia = load(catalog.scene_path(player.faction, "Infantry")).instantiate()
			MatchSignals.setup_and_spawn_unit.emit(militia, Transform3D(Basis(), point), player)
			obstacles.append(militia)
			remaining -= 1

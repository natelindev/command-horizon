# gdlint: disable=max-returns
extends Node

## The Scrap Yard hires loaded aircraft from outside the battlefield. Contracts
## buy one controllable sortie; no Frontier airfield or rearming is implied.
const ROLES = ["Helicopter", "Fighter", "Bomber"]
const COOLDOWN = 20.0
const FUEL_SECONDS = 90.0
const Factions = preload("res://source/match/FactionCatalog.gd")
const Bastion = preload("res://source/match/BastionCatalog.gd")
const Sortie = preload("res://source/match/units/traits/MercenarySortie.gd")
var cooldown_left = 0.0
var _last_second = 0


static func get_for(player):
	var contracts = player.get_node_or_null("AirContracts")
	if contracts == null:
		contracts = new()
		contracts.name = "AirContracts"
		player.add_child(contracts)
	return contracts


func _physics_process(delta):
	cooldown_left = maxf(0.0, cooldown_left - delta)
	var second = ceili(cooldown_left)
	if second != _last_second:
		_last_second = second
		get_parent().emit_changed()


func disabled_reason(role: String) -> String:
	var player = get_parent()
	if role not in ROLES or player.faction != "frontier":
		return "Aircraft contracts are exclusive to Frontier."
	if not player.has_completed_structure("CommandLab"):
		return "Requires a completed Scrap Yard."
	if get_tree().paused:
		return "Resume the battle to hire aircraft."
	if cooldown_left > 0.0:
		return tr("Next aircraft contract · %d s") % ceili(cooldown_left)
	if player.population(true) >= Bastion.POPULATION_LIMIT:
		return "Requires one free population slot."
	var cost = Factions.cost(player, role)
	if not player.has_resources(cost):
		return tr("Requires %d Materials and %d Electronics.") % [cost.resource_a, cost.resource_b]
	if _entry(role).is_empty():
		return "Clear the aircraft entry corridor."
	return ""


func hire(role: String):
	var player = get_parent()
	if load("res://source/match/network/NetworkGate.gd").intercept(
		player, {"kind": "hire_aircraft", "role": role}
	):
		return null
	if disabled_reason(role) != "":
		return null
	var arrival = _entry(role)
	if arrival.is_empty():
		return null
	var game = player.find_parent("Match")
	var cost = Factions.cost(player, role)
	var unit = load(Factions.scene_path(player.faction, role)).instantiate()
	Sortie.attach(unit, {"fuel_left": FUEL_SECONDS, "departing": false, "exit": arrival.exit})
	player.resource_a -= cost.resource_a
	player.resource_b -= cost.resource_b
	cooldown_left = COOLDOWN
	var facing = Basis.looking_at(arrival.direction, Vector3.UP)
	game._setup_and_spawn_unit(unit, Transform3D(facing, arrival.point), player, false)
	_move_inward.call_deferred(unit, arrival.station)
	player.emit_changed()
	return unit


func _move_inward(unit, point: Vector3):
	if not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return
	if not unit.is_node_ready():
		await unit.ready
	if not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return
	unit.action = load("res://source/match/units/actions/Moving.gd").new(point)


func _entry(role: String) -> Dictionary:
	var player = get_parent()
	var game = player.find_parent("Match")
	if game == null or game.map == null:
		return {}
	var labs = player.live_units().filter(
		func(unit): return unit.type == "CommandLab" and unit.is_constructed() and unit.hp > 0.0
	)
	if labs.is_empty():
		return {}
	var home = labs[0].global_position * Vector3(1, 0, 1)
	var size = game.map.size
	var candidates = [
		{
			"point": Vector3(3.0, 0, clampf(home.z, 8, size.y - 8)),
			"direction": Vector3.RIGHT,
			"exit": Vector3(0.5, 0, clampf(home.z, 8, size.y - 8))
		},
		{
			"point": Vector3(size.x - 3.0, 0, clampf(home.z, 8, size.y - 8)),
			"direction": Vector3.LEFT,
			"exit": Vector3(size.x - 0.5, 0, clampf(home.z, 8, size.y - 8))
		},
		{
			"point": Vector3(clampf(home.x, 8, size.x - 8), 0, 3.0),
			"direction": Vector3.BACK,
			"exit": Vector3(clampf(home.x, 8, size.x - 8), 0, 0.5)
		},
		{
			"point": Vector3(clampf(home.x, 8, size.x - 8), 0, size.y - 3.0),
			"direction": Vector3.FORWARD,
			"exit": Vector3(clampf(home.x, 8, size.x - 8), 0, size.y - 0.5)
		},
	]
	candidates.sort_custom(
		func(a, b): return a.point.distance_squared_to(home) < b.point.distance_squared_to(home)
	)
	var height = 3.5 if role == "Helicopter" else 5.2
	for candidate in candidates:
		var point = candidate.point
		point.y = game.map.height_at(Vector2(point.x, point.z)) + height
		if game.map.has_method("flight_height_at"):
			point.y = maxf(point.y, game.map.flight_height_at(point, point.y))
		if game.battlefield.nearby_units(point * Vector3(1, 0, 1), 3.0).any(
			func(other):
				return (
					other.movement_domain == Constants.Match.Navigation.Domain.AIR
					and absf(other.global_position.y - point.y) < 2.0
				)
		):
			continue
		candidate.point = point
		candidate.exit.y = point.y
		candidate.station = (home + candidate.direction * 10.0).clamp(
			Vector3(10, 0, 10), Vector3(size.x - 10, 0, size.y - 10)
		)
		return candidate
	return {}

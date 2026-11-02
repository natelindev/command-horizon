# gdlint: disable=max-returns,max-file-lines
extends Node3D

const Players = preload("res://source/match/Players.gd")
const Placement = preload("res://source/match/utils/UnitPlacementUtils.gd")
const Footprint = preload("res://source/match/utils/Footprint.gd")
const CAP = 12
const KINDS = ["barricade", "bunker", "tank_trap", "mine"]
const DEPLOY_REACH = 3.0
const SWEEP_RADIUS = 12.0
const BARRICADE_FOOTPRINT = [
	Vector2(-1.25, -0.275), Vector2(1.25, -0.275), Vector2(1.25, 0.275), Vector2(-1.25, 0.275)
]

var _next_id = 1
var _cooldowns = {}
var _reservations = {}
var _detection_tick = 0.0
var _eliminated = {}
@onready var game = get_parent()


func _ready():
	if game.has_signal("player_eliminated"):
		game.player_eliminated.connect(dispose_owner)


static func ability_definitions(unit) -> Array:
	var result = []
	if unit.type == "Worker":
		if unit.player.faction == "bastion":
			(
				result
				. append(
					{
						"id": "dismantle_barrier",
						"name": "Dismantle barricade",
						"key": "R",
						"description":
						"Dismantle an owned barricade in 2 seconds. No resource refund.",
						"target_type": "target_unit",
						"cooldown": 0.0,
						"range": 100000.0,
					}
				)
			)
		result.append(
			{
				"id": "sweep_mines",
				"name": "Clear mine area",
				"key": "E",
				"description": "Search a 12 m area and disarm discovered mines. 1 s per mine.",
				"target_type": "target_point",
				"cooldown": 0.0,
				"range": 100000.0,
				"radius": 12.0
			}
		)
		if unit.player.faction in ["bastion", "frontier"]:
			result.append(
				{
					"id": "field_barricade" if unit.player.faction == "bastion" else "scrap_barricade",
					"name": "Sandbag barricade" if unit.player.faction == "bastion" else "Scrap barricade",
					"key": "Q",
					"description":
					"Instant forward barrier. Bastion: 10 M; Frontier: 6 M; limit 12.",
					"target_type": "target_point",
					"cooldown": 0.0,
					"range": 100000.0
				}
			)
	if unit.type == "Worker" and unit.player.faction == "bastion":
		result.append({"id": "field_bunker", "name": "Deploy bunker", "key": "T", "description": "Deploy a concrete pillbox with six protected infantry firing ports. 35 M / 10 E; limit 12.", "target_type": "target_point", "cooldown": 0.0, "range": 100000.0})
		result.append({"id": "field_tank_trap", "name": "Tank traps", "key": "Y", "description": "Deploy uncrushable steel tank traps. 8 M; limit 12.", "target_type": "target_point", "cooldown": 0.0, "range": 100000.0})
	if unit.player.faction == "frontier" and unit.type in ["Worker", "Tank"]:
		result.append(
			{
				"id": "scrap_mine",
				"name": "Scrap mine",
				"key": "W",
				"description":
				"Deploy a concealed mine. 8 M; 3 s deployment, 2 s arming; limit 12.",
				"target_type": "target_point",
				"cooldown": 0.0,
				"range": 100000.0
			}
		)
	return result


func request_dismantle(unit, target, append = false) -> bool:
	if not can_service(unit, target) or unit.manual_orders == null or get_tree().paused:
		return false
	return unit.manual_orders.submit(unit.manual_orders.target_order("dismantle", target), append)


static func can_service(unit, target) -> bool:
	return (
		_living(unit)
		and unit.type == "Worker"
		and not unit.has_meta("garrison_host")
		and _living(target)
		and target.is_in_group("engineering_entities")
		and not target.is_in_group("field_mines")
		and target.player == unit.player
	)


func request(unit, kind, point, angle = 0.0, append = false) -> bool:
	if not _living(unit) or unit.manual_orders == null or get_tree().paused:
		return false
	if kind == "sweep":
		if unit.type != "Worker" or not point.is_finite() or not _point_inside(point):
			return false
		return unit.manual_orders.submit({"kind": "sweep", "point": point}, append)
	var issue = placement_error(unit, kind, point, angle, "", unit if not append else null)
	if issue != "":
		_notice(unit, issue)
		return false
	var token = _allocate_id("reservation")
	var order = {
		"kind": "engineering",
		"point": point,
		"engineering_kind": kind,
		"angle": angle,
		"reservation": token
	}
	if not unit.manual_orders.submit(order, append):
		return false
	_reservations[token] = {
		"unit": unit, "kind": kind, "point": point, "angle": angle, "mine": null
	}
	return true


func placement_error(unit, kind, point, angle = 0.0, ignore = "", replacing = null) -> String:
	if not _living(unit) or unit.has_meta("garrison_host") or kind not in KINDS:
		return "This unit cannot deploy field equipment."
	if kind in ["bunker", "tank_trap"] and (unit.type != "Worker" or unit.player.faction != "bastion"):
		return "Bastion workers deploy defensive emplacements."
	if kind == "barricade" and (unit.type != "Worker" or unit.player.faction not in ["bastion", "frontier"]):
		return "Bastion and Frontier workers deploy barricades."
	if kind == "mine":
		if unit.player.faction != "frontier" or unit.type not in ["Worker", "Tank"]:
			return "Frontier workers and Outriders deploy scrap mines."
		if not unit.player.has_completed_structure("CommandLab"):
			return "Complete a Relay workshop to deploy mines."
	if not point.is_finite() or not is_finite(angle) or not _point_inside(point):
		return "Choose reachable ground inside the battlefield."
	if not unit.player.has_resources(deployment_cost(unit.player, kind)):
		return "Not enough Materials."
	if count_for(unit.player, kind, ignore, replacing) >= limit_for(unit.player, kind):
		return "Field equipment limit reached (%d)." % limit_for(unit.player, kind)
	if not _observed_point(unit.player, point):
		return "Choose observed ground."
	if not reachable(unit, point):
		return "The deployment position is unreachable."
	var radius = 2.1 if kind == "bunker" else (1.3 if kind != "mine" else 0.3)
	var occupants = get_tree().get_nodes_in_group("units")
	occupants += get_tree().get_nodes_in_group("resource_units")
	occupants += get_tree().get_nodes_in_group("neutral_buildings")
	occupants += get_tree().get_nodes_in_group("destructible_obstacles")
	for other in occupants:
		if not _living(other) or other.is_in_group("salvage_wrecks"):
			continue
		if (
			other.has_method("combat_domain")
			and other.combat_domain() == Constants.Match.Navigation.Domain.AIR
		):
			continue
		var clearance = radius
		if other.has_method("is_constructed") or other.is_in_group("neutral_buildings"):
			clearance += 4.0  # Keep all exit and capture approaches open.
		elif other.is_in_group("resource_units"):
			clearance += 2.5
		if Footprint.reach_distance(other, point) < other.radius + clearance:
			return "Keep unit, production, resource and capture access clear."
	for reservation in _reservations:
		var pending = _reservations[reservation]
		if reservation == ignore or pending.unit == replacing:
			continue
		if not _living(pending.unit) or not Players.allied(unit.player, pending.unit.player):
			continue
		var spacing = 3.0 if kind == "mine" else 6.0
		if _flat_distance(pending.point, point) < spacing:
			return "This ground is reserved for another deployment."
	for mine in get_tree().get_nodes_in_group("field_mines"):
		if mine.hp > 0 and Players.allied(unit.player, mine.player):
			if _flat_distance(mine.global_position, point) < 3.0:
				return "Keep allied mines at least 3 m apart."
	if game.has_method("field_position_reserved") and game.field_position_reserved(point, radius):
		return "Keep the event landing area clear."
	var nav = _navigation()
	var terrain = game.map
	if kind != "mine":
		var outline = Footprint.outline_at(
			PackedVector2Array([Vector2(-2,-2),Vector2(2,-2),Vector2(2,2),Vector2(-2,2)] if kind == "bunker" else BARRICADE_FOOTPRINT), Transform3D(Basis(Vector3.UP, angle), point)
		)
		if Placement.validate_footprint_placement(outline, [], nav, terrain) != Placement.VALID:
			return "The barrier needs level, navigable ground."
		# A conservative clear perimeter preserves a tank-width bypass on both
		# sides. It rejects narrow bridges/chokes before the dynamic bake occurs.
		if not _clear_perimeter(point, 5.0 if kind == "bunker" else 3.5):
			return "The barrier would close a route or bridge approach."
	else:
		if (
			Placement.validate_agent_placement_position(point, radius, [], nav, terrain)
			!= Placement.VALID
		):
			return "The mine needs level, navigable ground."
	return ""


func count_for(player, kind, ignore = "", replacing = null) -> int:
	var count = 0
	for entity in get_tree().get_nodes_in_group("engineering_entities"):
		if entity.player == player and entity.hp > 0 and not entity.is_queued_for_deletion():
			if kind == entity.get_meta("engineering_kind", "mine" if entity.is_in_group("field_mines") else "barricade"):
				count += 1
	for token in _reservations:
		var pending = _reservations[token]
		if token != ignore and pending.unit != replacing and _living(pending.unit):
			if (
				pending.unit.player == player
				and pending.kind == kind
				and not is_instance_valid(pending.mine)
			):
				count += 1
	return count


static func deployment_cost(player, kind: String) -> Dictionary:
	if kind == "bunker":
		return {"resource_a": 35, "resource_b": 10}
	if kind == "barricade":
		return {"resource_a": 6 if player.faction == "frontier" else 10}
	return {"resource_a": 8}


static func limit_for(player, kind: String) -> int:
	return CAP * (2 if kind == "mine" and player.technology != null and "guerrilla_insurgency" in player.technology.completed else 1)


func cooldown_left(unit) -> float:
	return _cooldowns.get(unit, 0.0)


func begin_deployment(unit, token):
	if not _reservations.has(token):
		return null
	var pending = _reservations[token]
	if pending.unit != unit or _flat_distance(unit.global_position, pending.point) > DEPLOY_REACH:
		return null
	var issue = placement_error(unit, pending.kind, pending.point, pending.angle, token)
	if issue != "":
		_notice(unit, issue)
		return null
	if pending.kind != "mine":
		var barrier = _spawn_emplacement(unit.player, pending.kind, pending.point, pending.angle, _allocate_id(pending.kind))
		unit.player.subtract_resources(deployment_cost(unit.player, pending.kind))
		_reservations.erase(token)
		return barrier
	var mine = _spawn_mine(unit.player, pending.point, _allocate_id("mine"))
	unit.player.subtract_resources({"resource_a": 8})
	pending.mine = mine
	return mine


func release(token):
	if not _reservations.has(token):
		return
	var mine = _reservations[token].mine
	if is_instance_valid(mine) and mine.deploy_left > 0.0:
		mine.clear()
	_reservations.erase(token)


func complete_deployment(token):
	_reservations.erase(token)


func cancel_orders(unit):
	for token in _reservations.keys():
		if _reservations[token].unit == unit:
			release(token)


func _spawn_barricade(player, point, angle, id):
	var barrier = load("res://source/match/environment/DestructibleObstacle.gd").new()
	barrier.name = id
	barrier.neutral_id = id
	barrier.player = player
	barrier.position = point
	barrier.rotation.y = angle
	barrier.radius = 1.25
	barrier.obstacle_height = 0.8
	barrier.footprint = PackedVector2Array(BARRICADE_FOOTPRINT)
	barrier.set_meta("engineering_kind", "barricade")
	barrier.add_to_group("engineering_entities")
	barrier.add_to_group("neutral_targets")
	add_child(barrier)
	barrier.destroyed.connect(barrier.queue_free)
	_refresh_barrier(barrier)
	return barrier


func _spawn_emplacement(player, kind: String, point: Vector3, angle: float, id: String):
	if kind == "barricade":
		return _spawn_barricade(player, point, angle, id)
	var entity = load("res://source/match/world/FieldBunker.gd").new() if kind == "bunker" else load("res://source/match/environment/DestructibleObstacle.gd").new()
	entity.name = id
	entity.neutral_id = id
	entity.player = player
	entity.position = point
	entity.rotation.y = angle
	entity.set_meta("engineering_kind", kind)
	entity.add_to_group("engineering_entities")
	entity.add_to_group("neutral_targets")
	if kind == "tank_trap":
		entity.radius = 1.25
		entity.obstacle_height = 1.2
		entity.hp_max = 200.0
		entity.hp = 200.0
		entity.light_barricade = false
		var geometry = Node3D.new()
		geometry.name = "Geometry"
		var steel = StandardMaterial3D.new()
		steel.albedo_color = Color("424c48")
		steel.metallic = 0.75
		steel.roughness = 0.8
		for angle_z in [PI / 4.0, -PI / 4.0]:
			var mesh = MeshInstance3D.new()
			mesh.mesh = BoxMesh.new()
			mesh.mesh.size = Vector3(2.7, 0.22, 0.26)
			mesh.rotation.z = angle_z
			mesh.position.y = 0.65
			mesh.material_override = steel
			geometry.add_child(mesh)
		entity.add_child(geometry)
	add_child(entity)
	entity.destroyed.connect(entity.queue_free)
	return entity


func _refresh_barrier(barrier):
	var maximum = 160.0 if barrier.player.faction == "bastion" and barrier.player.technology != null and "fortress_doctrine" in barrier.player.technology.completed else 80.0
	if not is_equal_approx(barrier.hp_max, maximum):
		var ratio = barrier.hp / barrier.hp_max
		barrier.hp_max = maximum
		barrier.hp = maximum * ratio


func _spawn_mine(player, point, id):
	var mine = load("res://source/match/world/FieldMine.gd").new()
	mine.name = id
	mine.neutral_id = id
	mine.player = player
	mine.manager = self
	mine.position = point
	add_child(mine)
	return mine


func observed_by(player, mine) -> bool:
	if not _living(mine):
		return false
	if Players.allied(player, mine.player):
		return true
	for observer in get_tree().get_nodes_in_group("units"):
		if not _living(observer) or not Players.allied(observer.player, player):
			continue
		if observer.has_meta("garrison_host"):
			continue
		var exposed = mine.deploy_left > 0.0 or mine.arm_left > 0.0 or mine.fuse_left >= 0.0
		if not exposed and observer.movement_speed <= 0.0:
			continue
		var reach = (
			float(observer.sight_range) if exposed else (12.0 if observer.type == "Worker" else 6.0)
		)
		if _flat_distance(observer.global_position, mine.global_position) > reach:
			continue
		var origin = observer.global_position + Vector3.UP * 0.8
		var target = mine.global_position + Vector3.UP * 0.2
		if (
			game.battlefield._terrain_visible(observer, origin, target, mine)
			and game.battlefield.line_clear(origin, target, observer, mine)
		):
			return true
	return false


func known_mines(player, center, radius = SWEEP_RADIUS) -> Array:
	var result = []
	for mine in get_tree().get_nodes_in_group("field_mines"):
		if not _living(mine) or Players.allied(player, mine.player):
			continue
		# No ordering or movement decision reads a concealed position: location
		# filtering happens only after the observation/detector query succeeds.
		if observed_by(player, mine) and _flat_distance(center, mine.global_position) <= radius:
			result.append(mine)
	return result


func can_trigger(unit, mine) -> bool:
	return (
		_living(unit)
		and not unit.has_meta("garrison_host")
		and unit.type != "Worker"
		and unit.movement_speed > 0.0
		and unit.attack_range != null
		and unit.combat_domain() == Constants.Match.Navigation.Domain.TERRAIN
		and absf(unit.global_position.y - mine.global_position.y) <= 1.0
		and not Players.allied(unit.player, mine.player)
	)


func detonate(mine):
	var point = mine.global_position
	var owner = mine.player
	mine.clear()
	var upgraded = owner.technology != null and "concealed_claymores" in owner.technology.completed
	var blast_radius = 5.0 if upgraded else 2.5
	var damage = 90.0 if upgraded else 45.0
	for unit in game.battlefield.nearby_units(point, blast_radius):
		if not _living(unit) or unit.movement_speed <= 0.0 or unit.has_meta("garrison_host"):
			continue
		if (
			unit.combat_domain() != Constants.Match.Navigation.Domain.TERRAIN
			or Players.allied(owner, unit.player)
		):
			continue
		var distance = _flat_distance(point, unit.global_position)
		if distance > blast_radius or absf(unit.global_position.y - point.y) > 1.0:
			continue
		var armor = load("res://source/match/combat/CombatRules.gd").armor_for(unit.type)
		var factor = [0.75, 1.0, 0.60, 0.0][armor]
		unit.receive_damage(
			mine, damage * lerpf(1.0, 0.25, distance / blast_radius) * factor, point, {"kind": "warhead"}
		)
	if (
		game.combat_effects != null
		and not game.combat_effects._headless
		and _observed_point(game._get_human_player(), point)
	):
		game.combat_effects._explosion(point, 0.65, true)


func dispose_owner(player):
	_eliminated[player] = true
	for token in _reservations.keys():
		if _living(_reservations[token].unit) and _reservations[token].unit.player == player:
			release(token)
	for entity in get_tree().get_nodes_in_group("engineering_entities"):
		if entity.player != player or entity.hp <= 0:
			continue
		if entity.is_in_group("field_mines"):
			if entity.fuse_left < 0.0:
				entity.clear()
		else:
			entity.breach(false)


func _physics_process(delta):
	if not is_finite(delta) or delta <= 0.0 or game.restoring:
		return
	for unit in _cooldowns.keys():
		if not _living(unit) or _cooldowns[unit] <= delta:
			_cooldowns.erase(unit)
		else:
			_cooldowns[unit] -= delta
	for token in _reservations.keys():
		if not _living(_reservations[token].unit):
			release(token)
	_detection_tick += delta
	var refresh = _detection_tick >= 0.15
	if refresh:
		_detection_tick = 0.0
	for entity in get_tree().get_nodes_in_group("engineering_entities"):
		if entity.get_meta("engineering_kind", "") == "barricade":
			_refresh_barrier(entity)
	for mine in get_tree().get_nodes_in_group("field_mines"):
		mine.advance(delta)
		if refresh:
			mine.refresh_visibility()


func reachable(unit, point) -> bool:
	var path = NavigationServer3D.map_get_path(_navigation(), unit.global_position, point, true)
	return not path.is_empty() and _flat_distance(path[path.size() - 1], point) < 0.3


func search_points(center) -> Array:
	# Cover the disc with a fixed grid. Visiting these actual points discovers
	# mines behind intervening walls without deriving routes from hidden mines.
	var result = [center]
	for z in [-9.0, -3.0, 3.0, 9.0]:
		var row = []
		for x in [-9.0, -3.0, 3.0, 9.0]:
			if Vector2(x, z).length() <= SWEEP_RADIUS:
				row.append(game.map.ground_point(Vector2(center.x + x, center.z + z)))
		if result.size() % 2 == 0:
			row.reverse()
		result.append_array(row)
	return result


func _clear_perimeter(point, radius) -> bool:
	var nav = _navigation()
	var barriers = get_tree().get_nodes_in_group("destructible_obstacles")
	var previous = Vector3.INF
	for index in 33:
		var angle = float(index) * TAU / 32.0
		var test = game.map.ground_point(
			Vector2(point.x + cos(angle) * radius, point.z + sin(angle) * radius)
		)
		if not _point_inside(test) or not Placement._is_navigable(test + Vector3.UP * 0.5, nav):
			return false
		if absf(test.y - point.y) > 0.6:
			return false
		# Newly deployed barriers may precede the coalesced navigation rebake.
		# Preserve clearance against their live footprint in that same frame.
		for barrier in barriers:
			if _living(barrier) and Footprint.reach_distance(barrier, test) < barrier.radius + 1.25:
				return false
		if previous.is_finite():
			var path = NavigationServer3D.map_get_path(nav, previous, test, true)
			if path.is_empty() or _path_length(path) > previous.distance_to(test) + 0.5:
				return false
		previous = test
	return true


func _observed_point(player, point) -> bool:
	for observer in get_tree().get_nodes_in_group("units"):
		if _living(observer) and Players.allied(observer.player, player):
			if game.battlefield.can_observe_point(observer, point + Vector3.UP * 0.8):
				return true
	return false


func _navigation():
	return game.navigation.get_navigation_map_rid_by_domain(
		Constants.Match.Navigation.Domain.TERRAIN
	)


func _point_inside(point) -> bool:
	return (
		point.x >= 0 and point.z >= 0 and point.x <= game.map.size.x and point.z <= game.map.size.y
	)


func _allocate_id(kind):
	var id = "engineering-%s-%d" % [kind, _next_id]
	_next_id += 1
	return id


func _notice(unit, message):
	if unit.is_in_group("controlled_units") and game.hud != null:
		game.hud.show_notice(message)


static func _living(entity) -> bool:
	return (
		is_instance_valid(entity)
		and not entity.is_queued_for_deletion()
		and (not "hp" in entity or (entity.hp != null and entity.hp > 0))
	)


static func _flat_distance(first, second) -> float:
	return ((first - second) * Vector3(1, 0, 1)).length()


static func _path_length(path) -> float:
	var length = 0.0
	for index in range(1, path.size()):
		length += path[index - 1].distance_to(path[index])
	return length


func capture_state(reference: Callable) -> Dictionary:
	var result = {"next_id": _next_id, "entities": [], "cooldowns": [], "reservations": []}
	for entity in get_tree().get_nodes_in_group("engineering_entities"):
		if not _living(entity):
			continue
		var saved = {
			"id": entity.neutral_id,
			"owner": reference.call(entity.player),
			"kind": entity.get_meta("engineering_kind", "mine" if entity.is_in_group("field_mines") else "barricade"),
			"point": entity.global_position,
			"angle": entity.rotation.y,
			"hp": entity.hp
		}
		if saved.kind == "mine":
			saved.merge(
				{
					"deploy_left": entity.deploy_left,
					"arm_left": entity.arm_left,
					"fuse_left": entity.fuse_left
				}
			)
		if saved.kind == "bunker":
			saved["garrison"] = entity.garrison_mount.capture(reference)
		result.entities.append(saved)
	for unit in _cooldowns:
		if _living(unit):
			result.cooldowns.append({"unit": reference.call(unit), "left": _cooldowns[unit]})
	for token in _reservations:
		var pending = _reservations[token]
		if _living(pending.unit):
			result.reservations.append(
				{
					"id": token,
					"unit": reference.call(pending.unit),
					"kind": pending.kind,
					"point": pending.point,
					"angle": pending.angle,
					"mine": pending.mine.neutral_id if is_instance_valid(pending.mine) else ""
				}
			)
	return result


func restore_state(saved: Dictionary, entities: Dictionary):
	_next_id = saved.get("next_id", 1)
	_cooldowns.clear()
	_reservations.clear()
	for record in saved.get("entities", []):
		var owner = entities.get(record.owner)
		if owner == null:
			continue
		var entity
		if record.kind == "mine":
			entity = _spawn_mine(owner, record.point, record.id)
			entity.deploy_left = record.deploy_left
			entity.arm_left = record.arm_left
			entity.fuse_left = record.fuse_left
			entity.remember_positions()
		else:
			entity = _spawn_emplacement(owner, record.kind, record.point, record.angle, record.id)
			entity.hp = record.hp
		entities[record.id] = entity
	for record in saved.get("entities", []):
		if record.kind == "bunker" and entities.has(record.id):
			entities[record.id].garrison_mount.restore(record.get("garrison", {"occupants": [], "slots": [], "evacuating": []}), entities)
	for record in saved.get("cooldowns", []):
		if entities.has(record.unit):
			_cooldowns[entities[record.unit]] = record.left
	for record in saved.get("reservations", []):
		if entities.has(record.unit):
			_reservations[record.id] = {
				"unit": entities[record.unit],
				"kind": record.kind,
				"point": record.point,
				"angle": record.angle,
				"mine": entities.get(record.mine)
			}

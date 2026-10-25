# gdlint: disable=max-returns,max-file-lines
extends Node3D

signal announced(text: String, point: Vector3)

const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
const Ground = preload("res://source/match/maps/terrain/TerrainModel.gd")
const Players = preload("res://source/match/Players.gd")
const Footprint = preload("res://source/match/utils/Footprint.gd")
const Models = preload("res://source/match/world/TacticalModels.gd")
const TIMES = [300.0, 660.0]
const WARNING = 45.0
const REACH = 2.0
const PERFORMANCE = 12.0
const TITLES = {
	"desert": "Supply aircraft",
	"industrial": "Freight delivery",
	"coastal": "Drifting supplies",
	"alpine": "Radar terminal"
}

var occurrences = []
var radar = []
var _sites = []
var _claims = []
var _actors = []
var _notice_text = ""
var _notice_point = Vector3.ZERO
var _notice_left = 0.0
@onready var game = get_parent()


static func supported(map_path: String) -> bool:
	return not Registry.definition(map_path).get("events", []).is_empty()


func _ready():
	process_priority = 100
	if not game.restoring:
		initialize()


func initialize():
	occurrences.clear()
	_sites = Registry.layout(game.settings.map_path).get("events", [])
	if not game.settings.battlefield_events or _sites.is_empty():
		return
	if game.settings.mission_id != "" and not game.map.get_meta("battlefield_events", false):
		return
	var kind = _sites[0].kind
	var rotation = posmod(game.settings.match_seed, _sites.size())
	for index in TIMES.size():
		var event = {
			"id": "event-%d" % index,
			"kind": kind,
			"state": "scheduled",
			"scheduled_at": TIMES[index],
			"warning_delivered": false,
			"activation_delivered": false,
			"expires_at": 0.0,
			"cargos": []
		}
		for site_index in _sites.size():
			var point = _ground_point(_sites[site_index].position)
			var share = posmod(site_index - rotation - index, _sites.size())
			event.cargos.append(
				{
					"id": "%s-%d" % [event.id, site_index],
					"point": point,
					"materials": _share(10 if kind in ["desert", "coastal"] else 0, share),
					"electronics": _share(0 if kind == "alpine" else 5, share),
					"status": "pending",
					"claimant": null,
					"node": null
				}
			)
		occurrences.append(event)


func _share(total: int, index: int) -> int:
	return total / _sites.size() + (1 if index < total % _sites.size() else 0)


func _physics_process(delta):
	if get_tree().paused:
		return
	_resolve_claims()
	_notice_left = maxf(0.0, _notice_left - delta)
	for snapshot in radar:
		snapshot.left = maxf(0.0, snapshot.left - delta)
	radar = radar.filter(func(snapshot): return snapshot.left > 0.0)
	for event in occurrences:
		if event.state == "scheduled" and game.simulation_time >= event.scheduled_at - WARNING:
			event.state = "announced"
			if not event.warning_delivered:
				event.warning_delivered = true
				_notify(tr("%s in 45 seconds") % tr(TITLES[event.kind]), event.cargos[0].point)
		if event.state == "announced" and game.simulation_time >= event.scheduled_at:
			_activate(event)
		if event.state == "active" and game.simulation_time >= event.expires_at:
			event.state = "expired"
			for cargo in event.cargos:
				if cargo.status == "available":
					cargo.status = "cancelled"
					_dismiss(cargo)
	_update_actors()


func _activate(event):
	event.state = "active"
	event.expires_at = event.scheduled_at + (60.0 if event.kind == "alpine" else 180.0)
	var available = 0
	for index in event.cargos.size():
		var cargo = event.cargos[index]
		var point = _choose_point(index, int(event.id.get_slice("-", 1)))
		if point == null:
			cargo.status = "cancelled"
			continue
		cargo.point = point
		cargo.status = "available"
		_spawn(cargo, event.kind)
		available += 1
	if not event.activation_delivered:
		event.activation_delivered = true
		_notify(
			(
				tr("%s available") % tr(TITLES[event.kind])
				if available > 0
				else tr("Delivery cancelled: landing areas blocked")
			),
			event.cargos[0].point
		)
	if available == 0:
		event.state = "expired"
	elif available < event.cargos.size():
		_notify(tr("Some delivery areas are blocked"), event.cargos[0].point, false)
	_make_actors(event)


func _choose_point(site_index: int, occurrence: int):
	var site = _sites[site_index]
	var candidates = [site.position]
	for point in site.get("candidates", []):
		candidates.append(point)
	var start = posmod(game.settings.match_seed + occurrence, candidates.size())
	for offset in candidates.size():
		var point = _ground_point(candidates[(start + offset) % candidates.size()])
		if legal_point(point):
			return point
	return null


func legal_point(point: Vector3) -> bool:
	if not "terrain" in game.map or game.map.terrain == null:
		return false
	var flat = Vector2(point.x, point.z)
	var model = game.map.terrain
	if not Rect2(Vector2(2, 2), model.size - Vector2(4, 4)).has_point(flat):
		return false
	for offset in [
		Vector2.ZERO, Vector2(1.3, 0), Vector2(-1.3, 0), Vector2(0, 1.3), Vector2(0, -1.3)
	]:
		if (
			model.flag_at(flat + offset)
			& (Ground.WATER | Ground.SOLID | Ground.BARRIER | Ground.BRIDGE | Ground.RAMP)
		):
			return false
		if absf(model.height_at(flat + offset) - point.y) > .2:
			return false
	var nav = game.navigation.terrain
	var closest = nav.closest_point(point)
	if Vector2(closest.x, closest.z).distance_to(flat) > .75:
		return false
	# A valid terminal belongs to the common navigation component, including
	# multi-start maps. Merely being close to one polygon is insufficient.
	for base in game.map.layout.bases:
		var start = nav.closest_point(_ground_point(base.start))
		var path = NavigationServer3D.map_get_path(nav.navigation_map_rid, start, closest, true)
		if path.is_empty() or path[-1].distance_to(closest) > 1.0:
			return false
	var occupants = get_tree().get_nodes_in_group("units")
	occupants += get_tree().get_nodes_in_group("resource_units")
	occupants += get_tree().get_nodes_in_group("neutral_buildings")
	occupants += get_tree().get_nodes_in_group("destructible_obstacles")
	for other in occupants:
		if (
			not is_instance_valid(other)
			or other.is_queued_for_deletion()
			or ("hp" in other and other.hp <= 0)
		):
			continue
		if (
			other.has_method("combat_domain")
			and other.combat_domain() != Constants.Match.Navigation.Domain.TERRAIN
		):
			continue
		var clearance = 1.3
		if other.has_method("is_constructed") or other.is_in_group("neutral_buildings"):
			clearance += 4.0
		elif other.is_in_group("resource_units"):
			clearance += 2.5
		if Footprint.reach_distance(other, point) < other.radius + clearance:
			return false
	for key in ["sites", "relays", "garrisons"]:
		for entry in game.map.layout.get(key, []):
			if flat.distance_to(entry.position) < entry.get("radius", 3.0) + 5.0:
				return false
	return true


func _ground_point(point: Vector2) -> Vector3:
	return Vector3(point.x, game.map.height_at(point), point.y)


func _spawn(cargo, kind):
	var node = load("res://source/match/world/TacticalCargo.gd").new()
	node.manager = self
	node.kind = "radar" if kind == "alpine" else "supply"
	node.record_id = cargo.id
	node.neutral_id = cargo.id
	node.public_marker = true
	node.position = cargo.point
	add_child(node)
	cargo.node = node


func collect(node, unit, _elapsed: float) -> bool:
	if get_tree().paused or not is_instance_valid(node) or not node.can_collect(unit):
		return false
	if Footprint.reach_distance(unit, node.global_position) > unit.radius + node.radius + REACH:
		return false
	for event in occurrences:
		if event.state != "active" or game.simulation_time >= event.expires_at:
			continue
		for cargo in event.cargos:
			if cargo.node == node and cargo.status == "available":
				if not _claims.any(func(claim): return claim.cargo == cargo and claim.unit == unit):
					_claims.append({"event": event, "cargo": cargo, "unit": unit})
				return true
	return false


func _resolve_claims(flush = false):
	if get_tree().paused and not flush:
		return
	_claims.sort_custom(func(a, b): return _claim_key(a.unit) < _claim_key(b.unit))
	for claim in _claims:
		var unit = claim.unit
		var cargo = claim.cargo
		var event = claim.event
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.hp <= 0:
			continue
		if cargo.status != "available" or not is_instance_valid(cargo.node):
			continue
		if (
			not cargo.node.can_collect(unit)
			or event.state != "active"
			or game.simulation_time >= event.expires_at
		):
			continue
		if Footprint.reach_distance(unit, cargo.point) > unit.radius + cargo.node.radius + REACH:
			continue
		cargo.status = "claimed"
		cargo.claimant = unit.player
		_dismiss(cargo)
		if event.kind == "alpine":
			_snapshot(unit.player)
			for other in event.cargos:
				if other.status == "available":
					other.status = "cancelled"
					_dismiss(other)
		else:
			unit.player.add_resources(
				{"resource_a": cargo.materials, "resource_b": cargo.electronics}
			)
		if not event.cargos.any(func(other): return other.status == "available"):
			event.state = "claimed"
	_claims.clear()


func _claim_key(unit) -> String:
	if not is_instance_valid(unit):
		return "~"
	return "%012d:%s" % [unit.get_meta("visual_seed", 0), unit.get_path()]


func _snapshot(player):
	var points = []
	for unit in game.get_cached_group("units"):
		if unit.hp <= 0 or unit.movement_speed <= 0 or Players.allied(player, unit.player):
			continue
		points.append(unit.global_position)
	radar.append({"player": player, "left": 3.0, "points": points})


func _dismiss(cargo):
	if is_instance_valid(cargo.get("node")):
		cargo.node.dismiss()
	cargo.node = null


func cargo_destroyed(_node):
	pass  # Event supplies and terminals are indestructible.


func _notify(text, point, ping = true):
	_notice_text = text
	_notice_point = point
	_notice_left = 8.0
	announced.emit(text, point)
	if ping:
		MatchSignals.tactical_ping.emit(point)


func hud_status() -> Dictionary:
	if _notice_left > 0.0:
		return {"text": _notice_text, "point": _notice_point}
	for event in occurrences:
		if event.state in ["announced", "active"]:
			var seconds = maxi(
				0,
				ceili(
					(
						(event.scheduled_at if event.state == "announced" else event.expires_at)
						- game.simulation_time
					)
				)
			)
			return {
				"text": "%s · %d:%02d" % [tr(TITLES[event.kind]), seconds / 60, seconds % 60],
				"point": event.cargos[0].point
			}
	return {"text": "", "point": null}


func minimap_markers(_player) -> Array:
	var result = []
	for event in occurrences:
		if event.state not in ["announced", "active"]:
			continue
		for cargo in event.cargos:
			if cargo.status in ["pending", "available"]:
				result.append({"point": cargo.point, "kind": event.kind})
	return result


func radar_blips(player) -> Array:
	var result = []
	for snapshot in radar:
		if snapshot.left > 0.0 and Players.allied(player, snapshot.player):
			result.append_array(snapshot.points)
	return result


func position_reserved(point: Vector3, radius: float) -> bool:
	for event in occurrences:
		if event.state not in ["announced", "active"]:
			continue
		for index in event.cargos.size():
			if event.cargos[index].status not in ["pending", "available"]:
				continue
			var choices = [_sites[index].position]
			choices.append_array(_sites[index].get("candidates", []))
			for choice in choices:
				if Vector2(point.x, point.z).distance_to(choice) < radius + 2.0:
					return true
	return false


func flush():
	_resolve_claims(true)


func capture_state(reference: Callable) -> Dictionary:
	if occurrences.is_empty():
		return {}
	var records = []
	for event in occurrences:
		var saved = event.duplicate(true)
		for cargo in saved.cargos:
			cargo.erase("node")
			cargo.claimant = (
				reference.call(cargo.claimant) if is_instance_valid(cargo.claimant) else ""
			)
		records.append(saved)
	var scans = []
	for snapshot in radar:
		var player = reference.call(snapshot.player)
		if player != "":
			scans.append(
				{"player": player, "left": snapshot.left, "points": snapshot.points.duplicate()}
			)
	return {"occurrences": records, "radar": scans}


func restore_state(saved: Dictionary, entities: Dictionary):
	for event in occurrences:
		for cargo in event.cargos:
			_dismiss(cargo)
	for actor in _actors:
		actor.node.queue_free()
	_actors.clear()
	_claims.clear()
	occurrences.clear()
	radar.clear()
	_sites = Registry.layout(game.settings.map_path).get("events", [])
	for record in saved.get("occurrences", []):
		var event = record.duplicate(true)
		for cargo in event.cargos:
			cargo.claimant = entities.get(cargo.claimant)
			cargo.node = null
			if cargo.status == "available":
				_spawn(cargo, event.kind)
				entities[cargo.id] = cargo.node
		occurrences.append(event)
		if event.activation_delivered and game.simulation_time - event.scheduled_at < PERFORMANCE:
			_make_actors(event)
	for snapshot in saved.get("radar", []):
		if entities.has(snapshot.player):
			radar.append(
				{
					"player": entities[snapshot.player],
					"left": snapshot.left,
					"points": snapshot.points.duplicate()
				}
			)
	_update_actors()


func _make_actors(event):
	if DisplayServer.get_name() == "headless" or event.kind == "alpine":
		return
	for index in _sites.size():
		var actor = Node3D.new()
		add_child(actor)
		var kind = event.kind
		if kind == "desert":
			Models.aircraft(actor, Color("b9ac7e"))
		elif kind == "industrial":
			_actor_box(actor, Vector3.ZERO, Vector3(1.4, .8, 3.2), Color("ac7c42"))
			_actor_box(actor, Vector3(0, .3, 3.8), Vector3(1.4, 1.2, 3.0), Color("47565e"))
			_actor_box(actor, Vector3(0, .3, 7.3), Vector3(1.4, 1.2, 3.0), Color("726b4d"))
			_actor_box(actor, Vector3(0, .65, .8), Vector3(1.35, .6, 1.1), Color("374a53"))
			for carriage in [0.0, 3.8, 7.3]:
				_actor_box(actor, Vector3(0, -.4, carriage), Vector3(1.5, .2, 3.0), Color("242c32"))
				for axle in [-.9, .9]:
					for side in [-1, 1]:
						_actor_wheel(actor, Vector3(side * .75, -.48, carriage + axle))
		else:
			_actor_box(actor, Vector3.ZERO, Vector3(1.4, .8, 3.2), Color("ac7c42"))
			_actor_box(actor, Vector3(0, .46, 0), Vector3(1.5, .15, 3.3), Color("475e66"))
			_actor_box(actor, Vector3(0, 0, 0), Vector3(.14, 1.0, 3.4), Color("d5c194"))
		_actors.append({"node": actor, "event": event, "site": index})


func _actor_wheel(parent, point):
	var mesh = MeshInstance3D.new()
	var shape = CylinderMesh.new()
	shape.top_radius = .3
	shape.bottom_radius = .3
	shape.height = .15
	shape.radial_segments = 10
	mesh.mesh = shape
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("263139")
	material.metallic = .7
	mesh.material_override = material
	mesh.rotation.z = PI / 2.0
	mesh.position = point
	parent.add_child(mesh)


func _actor_box(parent, point, size, color):
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .8
	mesh.material_override = material
	mesh.position = point
	parent.add_child(mesh)


func _update_actors():
	for record in _actors.duplicate():
		var age = game.simulation_time - record.event.scheduled_at
		if age >= PERFORMANCE:
			record.node.queue_free()
			_actors.erase(record)
			continue
		var route = _sites[record.site].get("route", [])
		if route.size() < 2:
			continue
		var progress = clampf(age / PERFORMANCE, 0.0, .9999) * (route.size() - 1)
		var index = int(progress)
		var flat = route[index].lerp(route[index + 1], fmod(progress, 1.0))
		var point = _ground_point(flat)
		point.y += 9.0 if record.event.kind == "desert" else .65
		record.node.position = point
		var direction = route[index + 1] - route[index]
		record.node.rotation.y = atan2(-direction.x, -direction.y)

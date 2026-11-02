# gdlint: disable=max-returns
extends Node

## Player charges and committed simulation outcomes outlive their enabling lab.
const Players = preload("res://source/match/Players.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")
const Placement = preload("res://source/match/utils/UnitPlacementUtils.gd")
const Footprint = preload("res://source/match/utils/Footprint.gd")
const Shot = preload("res://source/match/combat/Shot.gd")
const COSTS = {
	"barrage": {"resource_a": 50, "resource_b": 30},
	"emp": {"resource_a": 50, "resource_b": 30},
	"airdrop": {"resource_a": 45, "resource_b": 15},
}
const POWERS = {"bastion": "barrage", "helix": "emp", "frontier": "airdrop"}
const TITLES = {
	"barrage": "Heavy artillery barrage", "emp": "Orbital EMP surge", "airdrop": "Smuggler airdrop"
}
const COOLDOWNS = {"barrage": 150.0, "emp": 150.0, "airdrop": 120.0}
const RADII = {"barrage": 6.0, "emp": 8.0, "airdrop": 6.0}
const CELL = 2.0
var serial = 0
var states = {}
var pending: Array = []
var emp: Dictionary = {}
var crates: Array = []
var explored: Dictionary = {}
var _exploration_left = 0.0
var _markers = {}
var _status_markers = {}
@onready var game = get_parent()


func _ready():
	if game.has_signal("player_eliminated"):
		game.player_eliminated.connect(dispose_owner)


func power_for(player) -> String:
	return POWERS.get(player.faction, "barrage")


func cost_for(player) -> Dictionary:
	return COSTS[power_for(player)]


func state(player) -> Dictionary:
	if not states.has(player):
		states[player] = {"started": false, "left": 60.0}
	return states[player]


func disabled_reason(player) -> String:
	if not player.has_completed_structure("CommandLab"):
		return "Requires a completed command lab."
	var charge = state(player)
	if not charge.started or charge.left > 0:
		return tr("Commander support recharging · %.0f s") % charge.left
	var power = player.power_totals()
	if power.x < power.y:
		return "Requires adequate power."
	var cost = cost_for(player)
	if not player.has_resources(cost):
		return tr("Requires %d Materials and %d Electronics.") % [cost.resource_a, cost.resource_b]
	if player.logistics < 25.0:
		return "Requires 25 Logistics."
	if power_for(player) == "airdrop" and player.population(true) + 2 > Catalog.POPULATION_LIMIT:
		return "Requires two free population slots."
	return ""


func observes(player, point: Vector3) -> bool:
	if game.settings.visibility == game.settings.Visibility.FULL:
		return true
	for observer in game.get_observers():
		if (
			Players.allied(observer.player, player)
			and game.battlefield.can_observe_point(observer, point + Vector3.UP * .8)
		):
			return true
	return false


func was_explored(player, point: Vector3) -> bool:
	return observes(player, point) or explored.get(player, {}).has(_cell(point))


func target_error(player, point) -> String:
	if (
		not point is Vector3
		or not point.is_finite()
		or point.x < 0
		or point.z < 0
		or point.x > game.map.size.x
		or point.z > game.map.size.y
	):
		return "Choose a point inside the battlefield."
	if power_for(player) == "airdrop":
		if not was_explored(player, point):
			return "Choose explored ground."
		if landing_positions(point).size() != 2:
			return "The landing zone needs room for two vehicles."
	elif not observes(player, point):
		return "Choose currently visible ground."
	return ""


func activate(player, point) -> bool:
	var gate = load("res://source/match/network/NetworkGate.gd")
	if gate.intercept(player, {"kind": "commander", "point": gate.Protocol.quantize(point)}):
		return true
	if (
		get_tree().paused
		or not disabled_reason(player).is_empty()
		or not target_error(player, point).is_empty()
	):
		return false
	var kind = power_for(player)
	var pattern = []
	if kind == "barrage":
		# Freeze a deterministic dispersed pattern at commitment, not at each impact.
		var phase = fmod(float(serial) * 2.39996323, TAU)
		for index in 6:
			var offset = (
				Vector2.from_angle(phase + index * TAU / 6.0) * (1.2 if index == 0 else 3.6)
			)
			var landing = (Vector2(point.x, point.z) + offset).clamp(Vector2.ZERO, game.map.size)
			pattern.append(game.map.ground_point(landing))
	var record = {
		"id": "commander:%d" % serial,
		"owner": player,
		"kind": kind,
		"point": game.map.ground_point(Vector2(point.x, point.z)),
		"age": 0.0,
		"index": 0,
		"pattern": pattern,
		"carrier": null
	}
	serial += 1
	pending.append(record)
	state(player).left = COOLDOWNS[kind]
	player.subtract_resources(cost_for(player))
	player.spend_logistics(25.0)
	_announce(TITLES[kind], point)
	return true


func reserved(player) -> int:
	var count = 0
	for record in pending:
		if record.owner == player and record.kind == "airdrop":
			count += 2
	return count


func speed_factor(unit) -> float:
	return (
		.60
		if (
			emp.get(unit, 0.0) > 0.0
			and unit.get_node_or_null("Movement") != null
			and not Catalog.is_infantry(unit.type)
		)
		else 1.0
	)


func disabled(unit) -> bool:
	return emp.get(unit, 0.0) > 0.0 and unit.type in ["AntiGroundTurret", "AntiAirTurret"]


func _physics_process(delta):
	if game.restoring:
		return
	for player in game.get_cached_group("players"):
		var charge = state(player)
		if not charge.started and player.has_completed_structure("CommandLab"):
			charge.started = true
		if charge.started:
			charge.left = maxf(0.0, charge.left - delta)
	for unit in emp.keys():
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.hp <= 0:
			emp.erase(unit)
		else:
			emp[unit] = maxf(0, emp[unit] - delta)
			if emp[unit] <= 0:
				emp.erase(unit)
	for record in pending.duplicate():
		record.age += delta
		match record.kind:
			"barrage":
				while record.index < 6 and record.age >= 3.5 + record.index * .6:
					_barrage_impact(record, record.pattern[record.index])
					record.index += 1
				if record.index == 6:
					_finish(record)
			"emp":
				if record.age >= 2.5:
					_emp_impact(record)
					_finish(record)
			"airdrop":
				_advance_airdrop(record)
	for crate in crates.duplicate():
		crate.left = maxf(0, crate.left - delta)
		if not is_instance_valid(crate.node) or crate.node.consumed:
			crates.erase(crate)
		elif crate.left == 0:
			crate.node.dismiss()
			crates.erase(crate)
	_exploration_left -= delta
	if _exploration_left <= 0:
		_exploration_left = .5
		_record_exploration()
	_refresh_markers()


func _hostile_ground(owner, target) -> bool:
	return (
		is_instance_valid(target)
		and not target.is_queued_for_deletion()
		and target.hp > 0
		and target.player != null
		and not Players.allied(owner, target.player)
		and not target.has_meta("garrison_host")
		and target.combat_domain() == Constants.Match.Navigation.Domain.TERRAIN
	)


func _barrage_targets(point) -> Array:
	var targets = game.battlefield.nearby_combat_targets(point, 2.5)
	# Include a structure when its footprint touches the blast, while preserving
	# mobile blast reach and the shared targeting queries used by ordinary weapons.
	var structures = (
		game.battlefield.nearby_bodies(point, 2.5)
		+ get_tree().get_nodes_in_group("footprinted_structures")
	)
	for target in structures:
		if (
			not is_instance_valid(target)
			or target.is_queued_for_deletion()
			or target.player == null
			or target.movement_speed > 0
			or target in targets
		):
			continue
		if Footprint.reach_distance(target, point) <= 2.5 + target.radius:
			targets.append(target)
	return targets


func _barrage_impact(record, point):
	var source = Shot.new()
	source.player = record.owner
	source.type = "AdvancedTank"
	source.origin = point + Vector3.UP * 10
	for target in _barrage_targets(point):
		if not _hostile_ground(record.owner, target):
			continue
		var distance = target.global_position_yless.distance_to(point * Vector3(1, 0, 1))
		var factor = (
			.75
			if Catalog.is_infantry(target.type)
			else (1.25 if target.movement_speed == 0 else 1.0)
		)
		target.receive_damage(
			source,
			80.0 * factor * lerpf(1.0, .25, clampf(distance / 2.5, 0, 1)),
			point,
			{"kind": "warhead"}
		)
	if game.combat_effects != null:
		game.combat_effects.grenade_impact(point, 2.5, record.owner)


func _emp_impact(record):
	for unit in game.battlefield.nearby_units(record.point, 8.0):
		if not _hostile_ground(record.owner, unit) or unit.attack_range == null:
			continue
		unit.shield_component.drain(unit.shields_max, game.simulation_time)
		if (
			not Catalog.is_infantry(unit.type)
			and (unit.movement_speed > 0 or unit.type in ["AntiGroundTurret", "AntiAirTurret"])
		):
			emp[unit] = maxf(emp.get(unit, 0), 6.0)
	if game.combat_effects != null:
		_emp_visual(record.point)
	if game.combat_audio != null and game.combat_audio.has_method("commander_emp"):
		game.combat_audio.commander_emp(record.point)


func _emp_visual(point: Vector3):
	if DisplayServer.get_name() == "headless" or not game.combat_effects.can_show_point(point):
		return
	var wave = load("res://source/match/effects/TacticalRangeRing.gd").create(8.0)
	var material = wave.material_override
	material.albedo_color = Color(.2, .85, 1.0, .65)
	wave.scale = Vector3.ONE * .1
	game.add_child(wave)
	wave.position = point + Vector3.UP * .15
	var tween = wave.create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector3.ONE, .5)
	tween.tween_property(material, "albedo_color:a", 0.0, .5)
	tween.chain().tween_callback(wave.queue_free)


func landing_positions(point: Vector3) -> Array:
	var result = []
	var rid = game.navigation.get_navigation_map_rid_by_domain(
		Constants.Match.Navigation.Domain.TERRAIN
	)
	var center = NavigationServer3D.map_get_closest_point(rid, point)
	if Vector2(center.x - point.x, center.z - point.z).length() > .2:
		return result
	var bodies = (
		game.get_units()
		+ get_tree().get_nodes_in_group("resource_units")
		+ get_tree().get_nodes_in_group("destructible_obstacles")
		+ get_tree().get_nodes_in_group("neutral_buildings")
	)
	for ring in range(0, 4):
		for index in 1 if ring == 0 else 12:
			var offset = Vector2.from_angle(index * TAU / 12.0) * ring * 1.8
			var candidate = game.map.ground_point(Vector2(point.x, point.z) + offset)
			if (
				Placement.validate_agent_placement_position(candidate, .9, bodies, rid, game.map)
				!= Placement.VALID
			):
				continue
			if result.any(func(other): return other.distance_to(candidate) < 2.0):
				continue
			var path = game.navigation.path_query.path(rid, center, candidate)
			if (
				path.is_empty()
				or path[-1].distance_to(candidate + Vector3.UP * Placement.SURFACE_LIFT) > 1.0
			):
				continue
			result.append(candidate)
			if result.size() == 2:
				return result
	return result


func _advance_airdrop(record):
	if record.age < 4.0:
		return
	if record.carrier == null:
		record.carrier = _cargo(
			record.id + ":carrier",
			record.id,
			"carrier",
			record.owner,
			record.point + Vector3.UP * 7,
			120.0
		)
	if not is_instance_valid(record.carrier) or record.carrier.consumed or record.carrier.hp <= 0:
		_finish(record)
		return
	record.carrier.position = (
		record.point + Vector3.UP * lerpf(7.0, 1.0, clampf((record.age - 4.0) / 3.0, 0, 1))
	)
	if record.age < 7.0:
		return
	var positions = landing_positions(record.point)
	if positions.size() != 2:
		if record.age >= 12.0:
			_finish(record)
		return
	# Reserve both positions synchronously before creating either body.
	pending.erase(record)
	record.carrier.dismiss()
	for position in positions:
		var unit = load(Catalog.scene_path("Tank")).instantiate()
		game._setup_and_spawn_unit(unit, Transform3D(Basis.IDENTITY, position), record.owner)
	var crate = _cargo(record.id + ":repair", record.id, "repair", record.owner, record.point, 30.0)
	crates.append({"node": crate, "left": 60.0})
	record.owner.emit_changed()


func _cargo(id, record_id, kind, player, point, health):
	var cargo = load("res://source/match/world/TacticalCargo.gd").new()
	cargo.manager = self
	cargo.neutral_id = id
	cargo.record_id = record_id
	cargo.kind = kind
	cargo.player = player
	cargo.hp = health
	cargo.position = point
	game.add_child(cargo)
	game.battlefield.invalidate()
	return cargo


func collect(cargo, unit, elapsed: float) -> bool:
	if cargo.kind != "repair" or not cargo.can_collect(unit) or elapsed < 2.0:
		return false
	unit.hp = minf(unit.hp_max, unit.hp + unit.hp_max * .35)
	cargo.dismiss()
	return true


func cargo_destroyed(cargo):
	for record in pending.duplicate():
		if record.carrier == cargo:
			pending.erase(record)
			record.owner.emit_changed()


func _finish(record):
	pending.erase(record)
	if is_instance_valid(record.carrier) and not record.carrier.consumed:
		record.carrier.dismiss()
	record.owner.emit_changed()


func dispose_owner(player):
	for record in pending.duplicate():
		if record.owner == player and record.kind == "airdrop":
			_finish(record)


func _cell(point: Vector3) -> int:
	var width = ceili(game.map.size.x / CELL)
	var height = ceili(game.map.size.y / CELL)
	return (
		clampi(floori(point.z / CELL), 0, height - 1) * width
		+ clampi(floori(point.x / CELL), 0, width - 1)
	)


func _record_exploration():
	# Exploration is independent of GPU fog and never grants current targeting sight.
	var players = game.get_cached_group("players")
	var width = ceili(game.map.size.x / CELL)
	var height = ceili(game.map.size.y / CELL)
	var allies = {}
	for owner in players:
		allies[owner] = players.filter(func(player): return Players.allied(player, owner))
		if not explored.has(owner):
			explored[owner] = {}
	for observer in game.get_observers():
		if observer.hp == null or observer.hp <= 0 or observer.sight_range == null:
			continue
		var owner = observer.player
		if not allies.has(owner):
			continue
		var reach = float(
			(
				observer.effective_sight_range()
				if observer.has_method("effective_sight_range")
				else observer.sight_range
			)
		)
		if observer.has_meta("garrison_host"):
			reach += observer.get_meta("garrison_host").radius + 2.0
		if game.battlefield.native_exploration:
			var cells: Array = game.battlefield._native_visibility.explore_cells(
				observer, explored[owner], Vector2i(width, height), CELL, reach, game.map
			)
			for key in cells:
				for player in allies[owner]:
					explored[player][key] = true
			continue
		var origin = Vector2(observer.global_position.x, observer.global_position.z)
		for x in range(
			maxi(0, floori((origin.x - reach) / CELL)),
			mini(width, ceili((origin.x + reach) / CELL))
		):
			for z in range(
				maxi(0, floori((origin.y - reach) / CELL)),
				mini(height, ceili((origin.y + reach) / CELL))
			):
				var key = z * width + x
				if explored[owner].has(key):
					continue
				var flat = Vector2(x + .5, z + .5) * CELL
				if flat.distance_squared_to(origin) > reach * reach:
					continue
				var point = game.map.ground_point(flat)
				if game.battlefield.can_observe_point(observer, point + Vector3.UP * .8):
					for player in allies[owner]:
						explored[player][key] = true


func _announce(title, point):
	if "hud" in game and is_instance_valid(game.hud):
		game.hud.show_notice(title)
	MatchSignals.tactical_ping.emit(point)
	if game.combat_audio != null and game.combat_audio.has_method("commander_warning"):
		game.combat_audio.commander_warning(TITLES.find_key(title), point)


func _refresh_markers():
	if DisplayServer.get_name() == "headless":
		return
	_refresh_status_markers()
	var wanted = {}
	for record in pending:
		wanted[record.id] = true
		if not _markers.has(record.id):
			var root = Node3D.new()
			var disk = MeshInstance3D.new()
			var mesh = CylinderMesh.new()
			mesh.top_radius = RADII[record.kind]
			mesh.bottom_radius = mesh.top_radius
			mesh.height = .035
			disk.mesh = mesh
			var material = StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.render_priority = 10
			material.albedo_color = {
				"barrage": Color(1, .32, .15, .20),
				"emp": Color(.15, .8, 1, .20),
				"airdrop": Color(.5, 1, .6, .20)
			}[record.kind]
			disk.material_override = material
			disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(disk)
			var label = Label3D.new()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.render_priority = 10
			label.position.y = 1.5
			label.font_size = 38
			label.pixel_size = .012
			label.text = tr(TITLES[record.kind])
			root.add_child(label)
			game.add_child(root)
			root.position = record.point + Vector3.UP * .1
			_markers[record.id] = root
	for id in _markers.keys():
		if not wanted.has(id):
			_markers[id].queue_free()
			_markers.erase(id)


func _refresh_status_markers():
	for unit in emp:
		if not is_instance_valid(unit):
			continue
		if not _status_markers.has(unit):
			var label = Label3D.new()
			label.text = "EMP"
			label.font_size = 26
			label.pixel_size = .012
			label.modulate = Color("8be3ed")
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			game.add_child(label)
			_status_markers[unit] = label
		var marker = _status_markers[unit]
		marker.position = unit.global_position + Vector3.UP * (2.0 + unit.radius)
		marker.visible = (
			game.settings.visibility == game.settings.Visibility.FULL
			or game.battlefield.is_observed(game.visible_player, unit)
		)
	for unit in _status_markers.keys():
		if not emp.has(unit):
			_status_markers[unit].queue_free()
			_status_markers.erase(unit)


func capture_state(reference: Callable) -> Dictionary:
	var charges = []
	for player in states:
		if reference.call(player) == "":
			continue
		charges.append(
			{
				"player": reference.call(player),
				"started": states[player].started,
				"left": states[player].left
			}
		)
	var effects = []
	for record in pending:
		var saved = record.duplicate()
		saved.owner = reference.call(record.owner)
		saved.carrier = _capture_cargo(record.carrier) if is_instance_valid(record.carrier) else {}
		effects.append(saved)
	var statuses = []
	for unit in emp:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			statuses.append({"unit": reference.call(unit), "left": emp[unit]})
	var supplies = []
	for crate in crates:
		if is_instance_valid(crate.node) and not crate.node.consumed:
			supplies.append(
				{
					"owner": reference.call(crate.node.player),
					"cargo": _capture_cargo(crate.node),
					"left": crate.left
				}
			)
	var terrain = []
	for player in explored:
		if reference.call(player) == "":
			continue
		terrain.append({"player": reference.call(player), "cells": explored[player].keys()})
	return {
		"serial": serial,
		"states": charges,
		"pending": effects,
		"emp": statuses,
		"crates": supplies,
		"explored": terrain
	}


func _capture_cargo(cargo) -> Dictionary:
	return {
		"id": cargo.neutral_id,
		"record_id": cargo.record_id,
		"kind": cargo.kind,
		"point": cargo.position,
		"hp": cargo.hp
	}


func restore_state(saved: Dictionary, entities: Dictionary):
	for record in pending.duplicate():
		_finish(record)
	for crate in crates:
		if is_instance_valid(crate.node):
			crate.node.dismiss()
	states.clear()
	emp.clear()
	crates.clear()
	explored.clear()
	serial = saved.serial
	for charge in saved.states:
		states[entities[charge.player]] = {"started": charge.started, "left": charge.left}
	for record in saved.pending:
		var restored = record.duplicate(true)
		restored.owner = entities[record.owner]
		restored.carrier = null
		if not record.carrier.is_empty():
			var cargo = record.carrier
			restored.carrier = _cargo(
				cargo.id, cargo.record_id, cargo.kind, restored.owner, cargo.point, cargo.hp
			)
			entities[cargo.id] = restored.carrier
		pending.append(restored)
	for status in saved.emp:
		if entities.has(status.unit):
			emp[entities[status.unit]] = status.left
	for supply in saved.crates:
		var cargo = supply.cargo
		var node = _cargo(
			cargo.id, cargo.record_id, cargo.kind, entities[supply.owner], cargo.point, cargo.hp
		)
		entities[cargo.id] = node
		crates.append({"node": node, "left": supply.left})
	for entry in saved.explored:
		explored[entities[entry.player]] = {}
		for cell in entry.cells:
			explored[entities[entry.player]][int(cell)] = true
	_refresh_markers()

extends Node3D

## Derive persistent presentation from live/saved state, never from an extra timer.
const Aura = preload("res://source/match/effects/AbilityAura.gd")
const MAX_AURAS = 48
var active = {}
var _drones = {}
var _clock = 0.0
var _refresh_left = 0.0


func watch(unit):
	if unit.abilities.get_ability("drone_chaff") != null:
		_drones[unit.get_instance_id()] = weakref(unit)


func advance(delta):
	var effects = get_parent()
	var game = effects.get_parent()
	if game.restoring:
		clear()
		return
	_clock += delta
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = .15
		_sync(game, effects)
	for key in active:
		var entry = active[key]
		var target = entry.target.get_ref() if entry.target != null else null
		var shown = (
			effects._can_show(target) and effects._camera_sees(target.global_position)
			if entry.kind != "overhaul"
			else (
				effects._camera_sees(entry.point)
				and game.combat_audio.point_observed(entry.point, entry.owner)
			)
		)
		# _can_show intentionally rejects pause for emissions; existing poses remain.
		if get_tree().paused:
			shown = (
				(
					is_instance_valid(target)
					and target.is_visible_in_tree()
					and game.combat_audio._observed(target)
				)
				if entry.kind != "overhaul"
				else shown
			)
		entry.node.visible = shown
		if is_instance_valid(target) and entry.kind != "overhaul":
			entry.node.global_transform = (
				target.get_global_transform_interpolated()
				if get_tree().physics_interpolation and target.can_process()
				else target.global_transform
			)
		entry.node.advance(_clock, Globals.options.reduced_flashes)
		entry.node.update_beacon_visibility(effects, entry.owner)
		if shown and delta > 0.0:
			entry.emit_left -= delta
			if entry.emit_left <= 0.0:
				entry.emit_left = .65
				entry.node.emit_haze(effects)


func _sync(game, effects):
	var wanted = {}
	for player in get_tree().get_nodes_in_group("players"):
		if not game.is_ancestor_of(player):
			continue
		for boost in player.production_boosts:
			var unit = boost.target.get_ref()
			if (
				boost.left > 0.0
				and is_instance_valid(unit)
				and unit.hp > 0
				and not unit.is_queued_for_deletion()
			):
				var key = "flux:%d" % unit.get_instance_id()
				wanted[key] = true
				if effects._can_show(unit) or get_tree().paused:
					_ensure(key, "flux", unit, unit.global_position, player, unit.radius)
		for boost in player.harvesting_boosts:
			if boost.left <= 0.0:
				continue
			var point: Vector3 = boost.field
			point.y = game.map.height_at(Vector2(point.x, point.z))
			var key = "overhaul:%d:%s" % [player.get_instance_id(), str(boost.field)]
			wanted[key] = true
			if game.combat_audio.point_observed(point, player):
				if not active.has(key):
					_ensure(key, "overhaul", null, point, player, _field_radius(boost))
	for id in _drones.keys():
		var unit = _drones[id].get_ref()
		if not is_instance_valid(unit) or unit.is_queued_for_deletion():
			_drones.erase(id)
			continue
		if unit.hp <= 0 or not unit.abilities.is_active("drone_chaff"):
			continue
		var key = "chaff:%d" % id
		wanted[key] = true
		if effects._can_show(unit) or get_tree().paused:
			_ensure(key, "chaff", unit, unit.global_position, unit.player, 2.2)
	for key in active.keys():
		if not wanted.has(key):
			active[key].node.hide()
			active[key].node.queue_free()
			active.erase(key)


func _field_radius(boost) -> float:
	# Anchored boosts follow the entire deposit field, even beyond the legacy
	# point radius. Derive the perimeter once, then retain it after depletion.
	if not boost.anchored:
		return 10.0
	var radius = 2.0
	for deposit in get_tree().get_nodes_in_group("resource_units"):
		if "harvest_origin" in deposit and deposit.harvest_origin.is_equal_approx(boost.field):
			radius = maxf(
				radius, deposit.global_position_yless.distance_to(boost.field) + deposit.radius + .6
			)
	return radius


func _ensure(key, kind, unit, point, owner, radius):
	if active.has(key) or active.size() >= MAX_AURAS:
		return
	var aura = Aura.new()
	add_child(aura)
	aura.setup(kind, radius, unit, get_parent().get_parent().map)
	aura.global_position = point
	active[key] = {
		"node": aura,
		"kind": kind,
		"point": point,
		"owner": owner,
		"target": weakref(unit) if unit != null else null,
		"emit_left": .65
	}


func clear():
	for entry in active.values():
		entry.node.hide()
		entry.node.queue_free()
	active.clear()
	_refresh_left = 0.0

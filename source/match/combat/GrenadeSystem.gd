extends Node

## A throw commits its payload independently of the thrower's lifetime.
const FUSE = 0.6
const DAMAGE = 28.0
const BREACH_DAMAGE = 42.0
const Shot = preload("res://source/match/combat/Shot.gd")
var serial: int = 0
var pending: Array = []
@onready var game = get_parent()


func launch(unit, point: Vector3, radius: float, building = null) -> bool:
	var shot = Shot.from(unit, unit.global_position)
	shot.attack_damage = DAMAGE
	shot.raw_damage = true
	shot.force_attack = false
	pending.append(
		{
			"serial": serial,
			"shot": shot,
			"point": point,
			"radius": radius,
			"building": weakref(building) if is_instance_valid(building) else null,
			"left": FUSE
		}
	)
	serial += 1
	return true


func _physics_process(delta: float):
	if not is_finite(delta) or delta <= 0.0:
		return
	for grenade in pending.duplicate():
		grenade.left = maxf(0.0, grenade.left - delta)
		if grenade.left <= 0.000001:
			pending.erase(grenade)
			_impact(grenade)


func _enemy(shot, target) -> bool:
	return (
		is_instance_valid(target)
		and target.hp > 0.0
		and "player" in target
		and target.player != null
		and not load("res://source/match/Players.gd").allied(shot.player, target.player)
	)


func _impact(grenade):
	var building = grenade.building.get_ref() if grenade.building != null else null
	var hit = {}
	if is_instance_valid(building) and building.hp > 0.0:
		var survivors = []
		for occupant in building.occupants.duplicate():
			if not _enemy(grenade.shot, occupant):
				continue
			hit[occupant] = true
			occupant.receive_damage(
				grenade.shot.feedback_source(), BREACH_DAMAGE, grenade.point, {"kind": "warhead"}
			)
			if is_instance_valid(occupant) and occupant.hp > 0.0:
				survivors.append(occupant)
		building.evacuate_breached(survivors)
	for target in (
		game.battlefield.nearby_units(grenade.point, grenade.radius)
		+ game.battlefield.nearby_obstacles(grenade.point, grenade.radius)
	):
		if hit.has(target) or target == building or not _enemy(grenade.shot, target):
			continue
		if target.has_meta("garrison_host"):
			continue
		target.receive_damage(
			grenade.shot.feedback_source(), DAMAGE, grenade.point, {"kind": "warhead"}
		)
	if game.combat_effects != null:
		game.combat_effects.grenade_impact(grenade.point, grenade.radius, grenade.shot.player)


func capture(reference) -> Dictionary:
	var records = []
	for grenade in pending:
		var shot = grenade.shot
		var building = grenade.building.get_ref() if grenade.building != null else null
		records.append(
			{
				"serial": grenade.serial,
				"player": reference.call(shot.player),
				"shooter": reference.call(shot.shooter()),
				"type": shot.type,
				"origin": shot.origin,
				"point": grenade.point,
				"radius": grenade.radius,
				"building": reference.call(building),
				"left": grenade.left
			}
		)
	return {"serial": serial, "pending": records}


func restore(saved: Dictionary, entities: Dictionary):
	pending.clear()
	serial = saved.get("serial", 0)
	for record in saved.get("pending", []):
		var player = entities.get(record.player)
		if player == null:
			continue
		var shot = Shot.new()
		shot.player = player
		shot.type = record.type
		shot.origin = record.origin
		shot.attack_damage = DAMAGE
		shot.raw_damage = true
		var shooter = entities.get(record.shooter)
		shot._shooter = weakref(shooter) if is_instance_valid(shooter) else null
		var building = entities.get(record.building)
		pending.append(
			{
				"serial": record.serial,
				"shot": shot,
				"point": record.point,
				"radius": record.radius,
				"left": record.left,
				"building": weakref(building) if is_instance_valid(building) else null
			}
		)
		if game.combat_effects != null:
			game.combat_effects.grenade_flight(record.origin, record.point, record.left, player)

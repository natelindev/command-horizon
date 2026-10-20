# gdlint: disable=max-returns
extends Node3D

# Owns every in-flight round as plain data and flies it with simple physics:
# gravity, motor thrust and drag; guided missiles steer with a turn-rate limit.
# Each tick a round sweeps the segment it travelled against its target (in the
# target's moving frame, so fast aircraft cannot tunnel through), other legal
# enemies, sight blockers and the ground. Rounds can miss. They survive their
# shooter, and pausing the tree pauses this node.

const Shot = preload("res://source/match/combat/Shot.gd")
const Rules = preload("res://source/match/combat/CombatRules.gd")
const Weapons = preload("res://source/match/combat/WeaponCatalog.gd")
const Battlefield = preload("res://source/match/combat/Battlefield.gd")
const KINDS = ["bullet", "shell", "rocket", "missile", "bomb"]
const MAX_FLIGHT = 4.0
const SIGHT_HEIGHT = 0.8
# A near miss delivers at most this share of a direct hit, falling linearly to
# zero at the weapon's splash radius.
const SPLASH_SHARE = 0.5
const HEAVY_VISUALS = ["slug", "rocket", "missile", "bomb"]
const VISIBILITY_TICKS = 6

var rounds_fired = 0
var renderer = null
var _rounds = []
var _by_target = {}
var _hitboxes = {}
var _random = RandomNumberGenerator.new()
var _human = null
var _tick = 0

@onready var _match = get_parent()


class Round:
	extends RefCounted
	var kind = ""
	var weapon = {}
	var shot = null
	var target = null
	var target_id = 0
	var target_base = Vector3.INF
	var position = Vector3.ZERO
	var velocity = Vector3.ZERO
	var age = 0.0
	var life = 0.0
	var burn = 0.0
	var serial = 0
	var shown = false
	var trail_clock = 0.0
	var slot = -1


func _ready():
	if DisplayServer.get_name() != "headless":
		renderer = load("res://source/match/effects/ProjectileRenderer.gd").new()
		renderer.name = "ProjectileRenderer"
		add_child(renderer)


func fire(unit, target):
	# Actions can start from signals on a unit that is not processing (a frozen
	# scene or a held test unit). Its shot would previously never advance.
	if not unit.can_process():
		return null
	return launch(unit, target)


# Fires one round from the unit's weapon regardless of its processing state.
# Aircraft name the store they release and add their own velocity to it.
# A bomb needs no target: a started stick keeps falling across the area.
func launch(unit, target, weapon = null, carrier_velocity = Vector3.ZERO):
	var aimed = is_instance_valid(target)
	if not aimed and (weapon == null or weapon.kind != "bomb"):
		return null
	var visuals = unit.get_node_or_null("BastionVisuals")
	if visuals != null:
		visuals.fire_recoil()
	if weapon == null:
		weapon = Weapons.profile(unit, target)
	var aim = center_of(target) if aimed else unit.global_position + Vector3.DOWN
	var muzzle = muzzle_of(unit, aim)
	# A low muzzle can sit behind a small obstacle that the firing check's sight
	# line clears; launch along that line instead of into the obstacle.
	if (
		aimed
		and not unit.has_meta("garrison_host")
		and not _match.battlefield.first_blocker(muzzle, aim, unit, target).is_empty()
	):
		muzzle = unit.global_position + Vector3.UP * SIGHT_HEIGHT
	var round = Round.new()
	round.weapon = weapon
	round.kind = weapon.kind
	round.shot = Shot.from(unit, unit.global_position)
	round.shot.attack_damage *= weapon.get("damage_scale", 1.0)
	if unit.has_method("expend_round"):
		unit.expend_round()
	round.target = target if aimed else null
	round.target_id = target.get_instance_id() if aimed else 0
	round.position = muzzle
	round.serial = rounds_fired
	rounds_fired += 1
	_random.seed = hash([_seed(), round.serial])
	round.velocity = (
		carrier_velocity
		+ _launch_velocity(weapon, muzzle, aim, velocity_of(target) if aimed else Vector3.ZERO)
	)
	round.burn = weapon.get("burn", 0.0)
	round.life = Weapons.lifetime(weapon, muzzle.distance_to(aim))
	var rail = round.kind == "rail"
	_match.combat_effects.shot(
		unit, muzzle, aim, 0.16, round.kind in ["rocket", "missile"], target, rail and _shown(round)
	)
	if rail:
		_fly_rail(round, unit)
		return round
	_add(round)
	return round


static func muzzle_of(unit, point):
	if unit.has_meta("garrison_host"):
		return unit.get_meta("garrison_host").firing_origin(point)
	var marker = unit.get_node_or_null("ProjectileOrigin")
	return marker.global_position if marker != null else unit.global_position + Vector3.UP


func center_of(unit):
	var box = hitbox(unit)
	return unit.global_position + Vector3.UP * (box.y + box.z * 0.5)


# Vector3(radius, bottom offset, height) of the body a round can strike.
func hitbox(unit):
	var key = unit.get_instance_id()
	if _hitboxes.has(key):
		return _hitboxes[key]
	var box = Vector3(unit.radius if "radius" in unit and unit.radius != null else 0.5, 0, 1.2)
	var collider = unit.get_node_or_null("CollisionShape3D")
	if collider != null and collider.shape is CylinderShape3D:
		var height = collider.shape.height
		box = Vector3(collider.shape.radius, collider.position.y - height * 0.5, height)
	elif collider != null and collider.shape is BoxShape3D:
		var size = collider.shape.size
		box = Vector3(minf(size.x, size.z) * 0.5, collider.position.y - size.y * 0.5, size.y)
	_hitboxes[key] = box
	return box


static func velocity_of(unit):
	var movement = unit.get_node_or_null("Movement")
	if movement == null or not "velocity" in movement:
		return Vector3.ZERO
	if movement.has_method("flight_velocity"):
		return movement.flight_velocity()
	if "_has_destination" in movement and not movement._has_destination:
		return Vector3.ZERO
	return movement.velocity


func _launch_velocity(weapon, muzzle, aim, target_velocity):
	var speed = weapon.speed
	var gravity = Weapons.GRAVITY * _gravity_scale(weapon)
	var average = speed
	if weapon.has("max_speed"):
		average = (speed + weapon.max_speed) * 0.5
	var point = aim
	# Lead the target from its current velocity; turning targets will escape.
	for _index in range(3):
		point = aim + target_velocity * (muzzle.distance_to(point) / maxf(average, 0.1))
	var direction = ballistic_direction(muzzle, point, average, gravity)
	var spread = weapon.get("spread", 0.0)
	if spread > 0.0:
		var side = direction.cross(Vector3.UP)
		side = Vector3.RIGHT if side.length_squared() < 0.0001 else side.normalized()
		var lift = side.cross(direction).normalized()
		direction = (
			(direction + side * _random.randfn(0.0, spread) + lift * _random.randfn(0.0, spread))
			. normalized()
		)
	return direction * speed


# Low-angle launch direction that reaches `point` at `speed` under `gravity`.
static func ballistic_direction(origin, point, speed, gravity):
	var offset = point - origin
	var flat = Vector3(offset.x, 0, offset.z)
	var distance = flat.length()
	if gravity < 0.0001 or distance < 0.001:
		return offset.normalized()
	var speed_squared = speed * speed
	var discriminant = (
		speed_squared * speed_squared
		- gravity * (gravity * distance * distance + 2.0 * offset.y * speed_squared)
	)
	var angle = PI / 4.0
	if discriminant >= 0.0:
		angle = atan((speed_squared - sqrt(discriminant)) / (gravity * distance))
	return (flat / distance * cos(angle) + Vector3.UP * sin(angle)).normalized()


static func _gravity_scale(weapon):
	return weapon.get("gravity", 1.0 if weapon.kind in ["bullet", "shell", "bomb"] else 0.0)


func _add(round):
	_rounds.append(round)
	if round.target_id != 0:
		if not _by_target.has(round.target_id):
			_by_target[round.target_id] = []
		_by_target[round.target_id].append(round)
	round.shown = _shown(round)
	if renderer != null:
		renderer.add(round)


func _remove(round):
	_rounds.erase(round)
	var aimed = _by_target.get(round.target_id, [])
	aimed.erase(round)
	if aimed.is_empty():
		_by_target.erase(round.target_id)
	if renderer != null:
		renderer.remove(round)


func _physics_process(delta):
	_tick += 1
	if _tick % 300 == 0:
		_hitboxes.clear()
	# Rounds resolve in fire order. A resolution never adds or reorders rounds.
	for round in _rounds.duplicate():
		_step(round, delta)


func _step(round, delta):
	var start = round.position
	_integrate(round, delta)
	round.age += delta
	var end = round.position
	var contact = _sweep(round, start, end)
	if not contact.is_empty():
		_remove(round)
		_detonate(round, contact.point, contact.get("body"), contact.get("ground", false))
		return
	if round.age >= round.life or not _inside_map(end):
		_remove(round)
		if round.kind == "missile" or round.weapon.get("fuse", 0.0) > 0.0:
			_detonate(round, end, null, false)
		return
	if _tick % VISIBILITY_TICKS == round.serial % VISIBILITY_TICKS:
		round.shown = _shown(round)
	if round.shown and round.kind in ["rocket", "missile"] and round.burn > 0.0:
		round.trail_clock += delta
		if round.trail_clock >= 0.05:
			round.trail_clock = 0.0
			_match.combat_effects.trail(end, round.velocity.normalized())
	if renderer != null:
		renderer.update(round)


func _integrate(round, delta):
	var weapon = round.weapon
	var velocity = round.velocity
	var speed = velocity.length()
	var direction = velocity / maxf(speed, 0.0001)
	if round.kind == "missile" and _live(round.target):
		direction = _steer(round, direction, speed, delta)
	if round.burn > 0.0:
		round.burn -= delta
		speed = minf(speed + weapon.get("thrust", 0.0) * delta, weapon.get("max_speed", speed))
	speed = maxf(0.0, speed - speed * weapon.get("drag", 0.0) * delta)
	velocity = direction * speed
	velocity += Vector3.DOWN * Weapons.GRAVITY * _gravity_scale(weapon) * delta
	round.velocity = velocity
	round.position += velocity * delta


# Lead pursuit: turn toward the predicted intercept by at most the missile's
# turn rate. A target that out-turns or outruns it is missed.
func _steer(round, direction, speed, delta):
	var aim = center_of(round.target)
	var closing = maxf(speed, 1.0)
	var predicted = aim + velocity_of(round.target) * (round.position.distance_to(aim) / closing)
	var desired = round.position.direction_to(predicted)
	var angle = direction.angle_to(desired)
	if angle < 0.0001:
		return direction
	var step = minf(1.0, round.weapon.get("turn", 0.0) * delta / angle)
	return direction.slerp(desired, step).normalized()


func _sweep(round, start, end):
	var best_t = INF
	var best = {}
	var target = round.target
	var shooter = round.shot.shooter()
	if _live(target):
		var box = hitbox(target)
		var base = target.global_position
		var previous = round.target_base if round.target_base != Vector3.INF else base
		round.target_base = base
		# Sweep in the target's frame: remove its own movement during the tick.
		var relative_end = end - (base - previous)
		if Rules.can_receive(round.shot, target):
			var t = _body_entry(start, relative_end, previous, box)
			if t >= 0.0:
				best_t = t
				best = {"body": target}
			var fuse = round.weapon.get("fuse", 0.0)
			if best.is_empty() and fuse > 0.0:
				var center = previous + Vector3.UP * (box.y + box.z * 0.5)
				var closest = Geometry3D.get_closest_point_to_segment(center, start, relative_end)
				if closest.distance_to(center) <= fuse + box.x:
					best_t = (
						start.distance_to(closest) / maxf(start.distance_to(relative_end), 0.0001)
					)
					best = {"body": target}
	if round.kind != "missile":
		var middle = (start + end) * 0.5
		var reach = start.distance_to(end) * 0.5 + 1.5
		var flat = Vector3(middle.x, 0, middle.z)
		for body in _match.battlefield.nearby_units(flat, reach, null, round.shot.player):
			if body == target or not Rules.can_receive(round.shot, body):
				continue
			var t = _body_entry(start, end, body.global_position, hitbox(body))
			if t >= 0.0 and t < best_t:
				best_t = t
				best = {"body": body}
	var blocker = _match.battlefield.first_blocker(start, end, shooter, target)
	if not blocker.is_empty() and blocker.t < best_t:
		best_t = blocker.t
		best = {"body": blocker.body}
	var ground_start = start.y - _ground_height(start)
	var ground_end = end.y - _ground_height(end)
	if ground_end <= 0.0:
		var t = 0.0 if ground_start <= 0.0 else ground_start / (ground_start - ground_end)
		if t < best_t:
			best_t = t
			best = {"ground": true}
	if best.is_empty():
		return best
	best.point = start.lerp(end, clampf(best_t, 0.0, 1.0))
	return best


static func _body_entry(start, end, base, box):
	return Battlefield.segment_cylinder_entry(start, end, base + Vector3.UP * box.y, box.x, box.z)


func _detonate(round, point, body, ground):
	var hit = body if body != null and Rules.can_receive(round.shot, body) else null
	if hit != null:
		hit.receive_shot(round.shot, point)
	var splash = round.weapon.get("splash", 0.0)
	if splash > 0.0:
		var flat = Vector3(point.x, 0, point.z)
		for unit in _match.battlefield.nearby_units(flat, splash + 2.0, null, round.shot.player):
			if unit == hit or not Rules.can_receive(round.shot, unit):
				continue
			var gap = _gap(point, unit)
			if gap < splash:
				unit.receive_shot(round.shot, point, SPLASH_SHARE * (1.0 - gap / splash))
	if not round.shown or not _match.combat_effects.can_show_point(point):
		return
	# Heavy warheads explode whatever they strike; a direct hit by lighter rounds
	# already shows the target's impact effect.
	if splash >= 2.0 or round.kind == "warhead":
		_match.combat_effects.warhead(point, maxf(splash, 2.0), ground or point.y < 0.4)
		return
	if hit != null:
		return
	var color = _match.combat_effects.FACTION_FIRE.get(
		round.shot.player.faction if "faction" in round.shot.player else "", Color("ffd9a0")
	)
	if not ground and body == null and point.y - _ground_height(point) > 0.6:
		_match.combat_effects.airburst(point, 0.8 if round.kind == "missile" else 0.5, color)
	else:
		_match.combat_effects.miss(
			point, ground or point.y < 0.4, round.weapon.visual in HEAVY_VISUALS, color
		)


func _gap(point, unit):
	var box = hitbox(unit)
	var base = unit.global_position
	var flat = maxf(0.0, Vector2(point.x - base.x, point.z - base.z).length() - box.x)
	var low = base.y + box.y
	var vertical = maxf(0.0, maxf(low - point.y, point.y - (low + box.z)))
	return Vector2(flat, vertical).length()


# A body that is itself the warhead (kamikaze drone) striking at `point`.
func detonate(unit, target, point, weapon):
	var round = Round.new()
	round.kind = weapon.kind
	round.weapon = weapon
	round.shot = Shot.from(unit, unit.global_position)
	round.shot.attack_damage *= weapon.get("damage_scale", 1.0)
	round.target = target if _live(target) else null
	round.serial = rounds_fired
	rounds_fired += 1
	round.shown = _shown(round)
	var body = target if _live(target) and point.distance_to(center_of(target)) < 2.0 else null
	_detonate(round, point, body, point.y - _ground_height(point) < 0.3)


# Hypervelocity slugs cross their range within a tick: resolve the whole line.
func _fly_rail(round, unit):
	var reach = Rules.range_for(unit, round.target) + 2.0
	var end = round.position + round.velocity.normalized() * reach
	var contact = _sweep(round, round.position, end)
	if not contact.is_empty():
		_detonate(round, contact.point, contact.get("body"), contact.get("ground", false))


func _line_of_fire(round):
	var shooter = round.shot.shooter()
	var battlefield = _match.battlefield
	if shooter != null:
		return battlefield.has_line_of_fire(shooter, round.target)
	return battlefield.line_clear(
		round.shot.origin + Vector3.UP * SIGHT_HEIGHT,
		round.target.global_position + Vector3.UP * SIGHT_HEIGHT,
		null,
		round.target
	)


func _ground_height(point):
	var map = _match.map
	if map != null and map.has_method("height_at"):
		return map.height_at(Vector2(point.x, point.z))
	return 0.0


func _inside_map(point):
	var map = _match.map
	if map == null or not "size" in map:
		return true
	return (
		point.x >= -4.0
		and point.z >= -4.0
		and point.x <= map.size.x + 4.0
		and point.z <= map.size.y + 4.0
		and point.y < 60.0
	)


func _shown(round):
	if renderer == null and DisplayServer.get_name() == "headless":
		return false
	var audio = _match.combat_audio
	if audio == null:
		return true
	var shooter = round.shot.shooter()
	return (
		(shooter != null and audio._observed(shooter))
		or (_live(round.target) and audio._observed(round.target))
	)


func _seed():
	return _match.settings.match_seed if _match.settings != null else 0


func _live(target):
	return is_instance_valid(target) and not target.is_queued_for_deletion()


# Damage from this player's rounds already flying at each target. Rounds that
# cannot reach it through blockers are excluded so they do not suppress new fire.
func incoming_damage(player, targets):
	var incoming = {}
	for target in targets:
		for round in _by_target.get(target.get_instance_id(), []):
			if round.shot.player != player or not _line_of_fire(round):
				continue
			incoming[target] = incoming.get(target, 0.0) + Rules.damage_from(round.shot, target)
	return incoming


func rounds_at(target):
	return _by_target.get(target.get_instance_id(), []).duplicate() if _live(target) else []


func round_count():
	return _rounds.size()


func capture(reference):
	var flying = []
	for round in _rounds:
		var target = reference.call(round.target)
		var player = reference.call(round.shot.player)
		if player.is_empty():
			continue
		(
			flying
			. append(
				{
					"kind": round.kind,
					"weapon": round.weapon.get("id", ""),
					"player": player,
					"shooter": reference.call(round.shot.shooter()),
					"type": round.shot.type,
					"damage": round.shot.attack_damage,
					"domains": round.shot.attack_domains.duplicate(),
					"mode": round.shot.weapon_mode,
					"origin": round.shot.origin,
					"target": target,
					"target_base": round.target_base if round.target_base.is_finite() else null,
					"position": round.position,
					"velocity": round.velocity,
					"age": round.age,
					"life": round.life,
					"burn": maxf(0.0, round.burn),
					"serial": round.serial,
				}
			)
		)
	return {"serial": rounds_fired, "flying": flying}


func restore(saved, entities):
	clear()
	rounds_fired = saved.serial
	for record in saved.flying:
		var target = entities.get(record.target)
		var player = entities.get(record.player)
		if player == null:
			continue
		if not _live(target):
			target = null
		var shot = Shot.new()
		shot.player = player
		shot.type = record.type
		shot.attack_damage = float(record.damage)
		shot.attack_domains = record.domains.duplicate()
		shot.weapon_mode = record.mode
		shot.origin = record.origin
		var shooter = entities.get(record.shooter)
		if shooter != null:
			shot._shooter = weakref(shooter)
		var round = Round.new()
		round.kind = record.kind
		round.weapon = Weapons.by_id(record.weapon)
		round.shot = shot
		round.target = target
		round.target_id = target.get_instance_id() if target != null else 0
		round.target_base = record.target_base if record.target_base != null else Vector3.INF
		round.position = record.position
		round.velocity = record.velocity
		round.age = float(record.age)
		round.life = float(record.life)
		round.burn = float(record.burn)
		round.serial = record.serial
		_add(round)


func clear():
	for round in _rounds.duplicate():
		_remove(round)
	_rounds.clear()
	_by_target.clear()

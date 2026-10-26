extends RefCounted

## Tactical decisions use current allied observations and the same public
## orders/ability checks as human input. No private mine or projectile lists.
const Moving = preload("res://source/match/units/actions/Moving.gd")
const Following = preload("res://source/match/units/actions/Following.gd")
const Engineering = preload("res://source/match/units/actions/EngineeringAction.gd")
const Orders = preload("res://source/match/orders/ManualOrders.gd")
const Labor = preload("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
const Production = preload("res://source/match/players/skirmish-ai/SkirmishProduction.gd")
const Economy = preload("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
const Weapons = preload("res://source/match/combat/WeaponCatalog.gd")


static func command(game, player, units, observed) -> Array:
	var claimed = units.filter(_working)
	var enabled = player.profile().signatures
	if player.profile().retreat_health > 0.0:
		_withdraw_suppressed(game, player, units, observed, claimed)
	if enabled:
		_use_grenades(game, player, units, observed)
		_overdrive(game, player, units)
		_field_engineering(game, player, units, observed, claimed)
		_commander(game, player, units, observed)
	_kites(game, player, units, observed, claimed, enabled)
	_cargo(game, player, units, observed, claimed)
	return claimed


static func _working(unit) -> bool:
	if unit.action is Engineering:
		return true
	if (
		unit.action != null
		and unit.action.get_script().resource_path.ends_with("CollectTacticalCargo.gd")
	):
		return true
	return (
		unit.manual_orders != null
		and unit.manual_orders.pending.any(
			func(order): return order.kind in ["engineering", "sweep", "collect_tactical"]
		)
	)


static func _withdraw_suppressed(game, _player, units, observed, claimed):
	for unit in units:
		if unit in claimed or unit.suppression == null or unit.suppression.band == 0:
			continue
		# Pinned infantry crawl out under ordinary movement rules. A partially
		# suppressed but healthy squad keeps its assignment unless badly hurt.
		if unit.suppression.band < 2 and unit.hp > unit.hp_max * 0.5:
			continue
		var threats = observed.filter(
			func(enemy):
				return (
					enemy.attack_range != null
					and enemy.global_position_yless.distance_to(unit.global_position_yless) < 18.0
				)
		)
		claimed.append(unit)
		if threats.is_empty():
			continue
		threats.sort_custom(
			func(a, b):
				return (
					a.global_position.distance_squared_to(unit.global_position)
					< b.global_position.distance_squared_to(unit.global_position)
				)
		)
		var away = (unit.global_position_yless - threats[0].global_position_yless).normalized()
		var headquarters = Economy.headquarters(units, unit.global_position_yless)
		if headquarters != null:
			var home = headquarters.global_position_yless - unit.global_position_yless
			if home.length() > 3.0 and home.normalized().dot(away) > 0.0:
				away = (away + home.normalized()).normalized()
		var candidate = unit.global_position + away * 8.0
		var nav = game.navigation.get_navigation_map_rid_by_domain(1)
		candidate = NavigationServer3D.map_get_closest_point(nav, candidate)
		if not Economy.danger(candidate * Vector3(1, 0, 1), unit, threats):
			_move(unit, candidate)
		elif unit.suppression.band >= 2:
			_move(unit, candidate)


static func _use_grenades(game, player, units, observed):
	# Cluster membership is independent of the thrower. Build it lazily once,
	# then reject distant targets before invoking the ability's full validation.
	var clusters = null
	for unit in units:
		if unit.abilities == null:
			continue
		var grenade = unit.abilities.get_ability("frag_grenade")
		if grenade == null or not grenade.is_ready():
			continue
		var used = false
		for building in game.get_tree().get_nodes_in_group("neutral_buildings"):
			if (
				game.battlefield.is_observed(player, building)
				and unit.abilities._valid_breach(building)
			):
				if unit.abilities.trigger("frag_grenade", building.global_position, building):
					used = true
					break
		if used:
			continue
		if clusters == null:
			clusters = _grenade_clusters(game, observed)
		for contact in clusters:
			if not unit.abilities._in_range(grenade, contact.global_position):
				continue
			if unit.abilities.trigger("frag_grenade", contact.global_position):
				break


static func _grenade_clusters(game, observed) -> Array:
	var ground = {}
	for contact in observed:
		if contact.combat_domain() == 1:
			ground[contact] = true
	var result = []
	for contact in ground:
		for neighbor in game.battlefield.nearby_units(contact.global_position, 3.0):
			if neighbor != contact and ground.has(neighbor):
				result.append(contact)
				break
	return result


static func _overdrive(game, player, units):
	if player.faction != "helix":
		return
	for generator in units:
		if generator.type != "PowerPlant" or generator.abilities == null:
			continue
		var ability = generator.abilities.get_ability("power_overdrive")
		if ability == null:
			continue
		var power = player.power_totals()
		var need = units.any(
			func(unit):
				return (
					unit.shields_max > 0.0
					and unit.shields < unit.shields_max
					and (
						unit.global_position_yless.distance_to(generator.global_position_yless)
						<= 12.0
					)
				)
		)
		if ability.is_active and (power.x < power.y or not need):
			generator.abilities.trigger("power_overdrive")
		elif (
			not ability.is_active
			and need
			and power.x >= power.y + game.helix_support.OVERDRIVE_DEMAND
		):
			generator.abilities.trigger("power_overdrive")


static func _kites(game, player, units, observed, claimed, enabled):
	if player.faction != "helix":
		return
	var army = units.filter(
		func(unit):
			return (
				unit.movement_speed > 0.0
				and unit.attack_range != null
				and unit.type != "Drone"
				and unit.hp > unit.hp_max * 0.3
			)
	)
	for drone in units:
		if drone.type != "Drone":
			continue
		if drone not in claimed:
			claimed.append(drone)
		drone.stance = drone.Stance.HOLD_FIRE
		if not army.is_empty():
			army.sort_custom(
				func(a, b):
					var a_engaged = game.battlefield.observed_enemies_near(a, 16.0).size() > 0
					var b_engaged = game.battlefield.observed_enemies_near(b, 16.0).size() > 0
					if a_engaged != b_engaged:
						return a_engaged
					return (
						a.global_position.distance_squared_to(drone.global_position)
						< b.global_position.distance_squared_to(drone.global_position)
					)
			)
			var current = drone.action._target_unit if drone.action is Following else null
			if current not in army:
				drone.issue_manual_order(Following.new(army[0]))
		if enabled and drone.abilities != null:
			var threatened = observed.any(
				func(enemy):
					return (
						enemy.attack_range != null
						and Weapons.profile(enemy, drone).kind == "missile"
						and (
							enemy.global_position_yless.distance_to(drone.global_position_yless)
							<= enemy.attack_range + 10.0
						)
					)
			)
			if threatened:
				drone.abilities.trigger("drone_chaff")


static func _field_engineering(game, player, units, observed, claimed):
	if game.engineering == null:
		return
	var workers = units.filter(func(unit): return unit.type == "Worker" and unit not in claimed)
	var free = workers.filter(func(worker): return _idle(worker) or Labor.handoff_ready(worker))
	# Clearance is a deliberate tactical assignment to a currently detected
	# hazard near our economy. Merely seeing a mine leaves combat orders alone.
	for asset in units:
		if asset.type != "Worker" and asset.type != "CommandCenter":
			continue
		var mines = game.engineering.known_mines(player, asset.global_position, 15.0)
		if mines.is_empty() or free.is_empty():
			continue
		free.sort_custom(
			func(a, b):
				return (
					a.position.distance_squared_to(mines[0].global_position)
					< b.position.distance_squared_to(mines[0].global_position)
				)
		)
		var worker = free[0]
		if not Economy.danger(mines[0].global_position_yless, worker, observed):
			if game.engineering.request(
				worker, "sweep", mines[0].global_position, 0.0, Labor.handoff_ready(worker)
			):
				claimed.append(worker)
				return
	if units.any(func(unit): return unit.action is Engineering) or player.resource_a < 100:
		return
	if player.faction not in ["bastion", "frontier"]:
		return
	var kind = "barricade" if player.faction == "bastion" else "mine"
	if game.engineering.count_for(player, kind) >= 3:
		return
	if kind == "mine" and not player.has_completed_structure("CommandLab"):
		return
	var centers = units.filter(func(unit): return unit.type == "CommandCenter")
	if centers.is_empty():
		return
	var headquarters = centers[0]
	var guards = units.filter(
		func(unit):
			return (
				unit.attack_range != null
				and unit.movement_speed > 0
				and unit.type != "Drone"
				and (
					unit.global_position_yless.distance_to(headquarters.global_position_yless)
					<= 24.0
				)
			)
	)
	if guards.size() < 2 or free.is_empty():
		return
	var reserve = Production.reserve(player, units, "")
	if player.resource_a < reserve.x + 30:
		return
	var worker = free[0]
	var direction = (
		(
			Vector3(game.map.size.x * 0.5, 0, game.map.size.y * 0.5)
			- headquarters.global_position_yless
		)
		. normalized()
	)
	if not observed.is_empty():
		direction = (
			(observed[0].global_position_yless - headquarters.global_position_yless).normalized()
		)
	var lateral = direction.rotated(Vector3.UP, PI * 0.5)
	for offset in [-5.0, 0.0, 5.0]:
		var point = (
			headquarters.global_position
			+ direction * (headquarters.radius + 8.0)
			+ lateral * offset
		)
		point = game.map.ground_point(Vector2(point.x, point.z))
		var angle = atan2(direction.x, direction.z)
		if Economy.danger(point * Vector3(1, 0, 1), worker, observed):
			continue
		if game.engineering.placement_error(worker, kind, point, angle) != "":
			continue
		if game.engineering.request(worker, kind, point, angle, Labor.handoff_ready(worker)):
			claimed.append(worker)
			return


static func _cargo(game, player, units, observed, claimed):
	if Production.under_raid(game, player, units):
		return
	var candidates = units.filter(
		func(unit):
			return (
				unit not in claimed
				and _idle(unit)
				and unit.movement_speed > 0.0
				and unit.combat_domain() == 1
				and unit.type != "Worker"
				and unit.hp > unit.hp_max * 0.6
			)
	)
	for cargo in game.get_tree().get_nodes_in_group("tactical_cargo"):
		if (
			cargo.kind == "carrier"
			or (not cargo.public_marker and not game.battlefield.is_observed(player, cargo))
		):
			continue
		for unit in candidates:
			if (
				not cargo.can_collect(unit)
				or unit.global_position.distance_to(cargo.global_position) > 12.0
			):
				continue
			if Economy.danger(cargo.global_position_yless, unit, observed):
				continue
			if observed.any(
				func(enemy):
					return (
						enemy.global_position_yless.distance_to(cargo.global_position_yless) < 14.0
					)
			):
				continue
			if unit.manual_orders.submit(
				Orders.target_order("collect_tactical", cargo), false, false
			):
				claimed.append(unit)
				return


static func _commander(game, player, units, observed):
	var support = game.commander_support
	if support == null or support.disabled_reason(player) != "":
		return
	var reserve = Production.reserve(player, units, "")
	var cost = support.cost_for(player)
	if (
		player.resource_a < reserve.x + cost.resource_a
		or player.resource_b < reserve.y + cost.resource_b
	):
		return
	var kind = support.power_for(player)
	if kind == "airdrop":
		var anchors = units.filter(
			func(unit):
				return unit.type in ["Tank", "AdvancedTank", "CommandCenter"] and unit.hp > 0
		)
		for anchor in anchors:
			for offset in [Vector3(5, 0, 0), Vector3(-5, 0, 0), Vector3(0, 0, 5)]:
				var point = anchor.global_position + offset
				if observed.any(
					func(enemy):
						return (
							enemy.attack_range != null
							and (
								enemy.global_position_yless.distance_to(point * Vector3(1, 0, 1))
								< enemy.attack_range + 5.0
							)
						)
				):
					continue
				if support.activate(player, point):
					return
		return
	var best = null
	var best_score = 2.5
	for target in observed:
		if target.combat_domain() != 1:
			continue
		var score = 0.0
		for enemy in observed:
			if (
				enemy.combat_domain() != 1
				or (
					enemy.global_position_yless.distance_to(target.global_position_yless)
					> (8.0 if kind == "emp" else 5.0)
				)
			):
				continue
			if kind == "emp":
				score += (
					1.0
					if (
						enemy.shields > 0
						or (
							enemy.type
							in [
								"Tank",
								"AdvancedTank",
								"CombatRobot",
								"AntiAirVehicle",
								"AntiGroundTurret",
								"AntiAirTurret"
							]
						)
					)
					else 0.0
				)
			else:
				score += 1.5 if enemy.has_method("is_constructed") else 1.0
		if score > best_score:
			best = target
			best_score = score
	if best != null:
		support.activate(player, best.global_position)


static func _idle(unit) -> bool:
	return unit.action == null or (unit.action.has_method("is_idle") and unit.action.is_idle())


static func _move(unit, point):
	if unit.action is Moving and unit.action._target_position.distance_to(point) < 3.0:
		return
	unit.issue_manual_order(Moving.new(point))

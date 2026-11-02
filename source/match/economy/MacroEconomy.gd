extends RefCounted


## Player-directed macro effects; active targets are persisted by the snapshot.
static func definitions(faction: String) -> Array:
	if faction == "bastion":
		return [
			{
				"id": "industrial_overhaul",
				"name": "Industrial Overhaul",
				"key": "Q",
				"description":
				(
					"Workers at the targeted resource field harvest 30% faster for 30 seconds. "
					+ "Recharges in 60 seconds."
				),
				"target_type": "target_point",
				"cooldown": 60.0,
				"range": 1000.0,
				"radius": 8.0,
				"duration": 30.0,
			}
		]
	if faction == "helix":
		return [
			{
				"id": "flux_resonance",
				"name": "Flux Resonance",
				"key": "Q",
				"description":
				"Spend 25 Nexus Energy to accelerate a friendly factory or lab by 50% for 25 seconds.",
				"target_type": "target_unit",
				"cooldown": 25.0,
				"range": 1000.0,
				"duration": 25.0,
			}
		]
	return []


static func execute(unit, ability, point: Vector3, target) -> bool:
	var player = unit.player
	if ability.id == "flux_resonance":
		if (
			not valid_facility(player, target)
			or not unit.has_method("spend_energy")
			or not unit.spend_energy(25.0)
		):
			return false
		player.production_boosts = player.production_boosts.filter(
			func(boost): return boost.target.get_ref() != target
		)
		player.production_boosts.append({"target": weakref(target), "left": 25.0})
		player.emit_changed()
		return true
	if ability.id == "industrial_overhaul":
		var game = unit._match
		var nearest = null
		var distance = 64.0
		for deposit in game.get_tree().get_nodes_in_group("resource_units"):
			if (
				deposit.is_queued_for_deletion()
				or deposit.is_in_group("salvage_wrecks")
				or not deposit.has_method("can_harvest")
			):
				continue
			var squared = deposit.global_position_yless.distance_squared_to(
				point * Vector3(1, 0, 1)
			)
			if squared < distance:
				distance = squared
				nearest = deposit
		if nearest == null or not game.battlefield.is_observed(player, nearest):
			return false
		(
			player
			. harvesting_boosts
			. append(
				{
					"target": weakref(nearest),
					"field":
					(
						nearest.harvest_origin
						if nearest.harvest_origin.is_finite()
						else nearest.global_position_yless
					),
					"anchored": nearest.harvest_origin.is_finite(),
					"left": 30.0,
				}
			)
		)
		return true
	return false


static func valid_facility(player, target) -> bool:
	return (
		is_instance_valid(target)
		and "player" in target
		and target.player == player
		and "hp" in target
		and target.hp > 0
		and not target.is_queued_for_deletion()
		and target.has_method("is_constructed")
		and target.is_constructed()
		and target.type in ["Barracks", "VehicleFactory", "AircraftFactory", "CommandLab"]
	)

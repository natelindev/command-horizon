extends RefCounted

## Independently read applied live values, rather than trusting the cached wire
## state. This catches mapping errors and accidental client-side simulation.
const Protocol = preload("res://source/match/network/NetworkProtocol.gd")


static func expected(snapshot: Dictionary) -> String:
	var core = {"players": [], "units": [], "resources": [], "obstacles": [], "engineering": []}
	var hosts = {}
	for unit in snapshot.units:
		for rider in unit.get("garrison_mount", {}).get("occupants", []):
			hosts[rider] = unit.id
	for entity in snapshot.engineering.entities:
		for rider in entity.get("garrison", {}).get("occupants", []):
			hosts[rider] = entity.id
	for building in snapshot.neutral_buildings:
		for rider in building.occupants:
			hosts[rider] = building.id
	for side in snapshot.players:
		core.players.append(
			{
				"id": side.id,
				"a": side.resource_a,
				"b": side.resource_b,
				"research": side.technology,
				"logistics": side.economy.logistics
			}
		)
	for unit in snapshot.units:
		core.units.append(
			{
				"id": unit.id,
				"player": unit.player,
				"role": unit.role,
				"position": unit.position,
				"rotation": unit.rotation,
				"hp": unit.hp,
				"shield": unit.get("plasma_shield", {}).get("charge", 0.0),
				"host": hosts.get(unit.id, ""),
				"jobs": unit.production.get("jobs", [])
			}
		)
	for resource in snapshot.resources:
		core.resources.append(
			{
				"id": resource.id,
				"kind": resource.kind,
				"amount": resource.amount,
				"position": resource.position
			}
		)
	for obstacle in snapshot.get("obstacles", []):
		core.obstacles.append({"id": obstacle.id, "hp": obstacle.hp, "position": obstacle.position})
	for entity in snapshot.engineering.entities:
		core.engineering.append({"id": entity.id, "hp": entity.hp, "position": entity.point})
	return Protocol.canonical_hash(_native(core))


static func live(replica) -> String:
	var core = {"players": [], "units": [], "resources": [], "obstacles": [], "engineering": []}
	for side in replica.state.players:
		var player = replica.entities.get(side.id)
		if not is_instance_valid(player):
			return ""
		core.players.append(
			{
				"id": side.id,
				"a": player.resource_a,
				"b": player.resource_b,
				"research": player.technology.capture(),
				"logistics": player.logistics
			}
		)
	for saved in replica.state.units:
		var unit = replica.entities.get(saved.id)
		if not is_instance_valid(unit):
			return ""
		var host = unit.get_meta("garrison_host") if unit.has_meta("garrison_host") else null
		var host_id = ""
		if is_instance_valid(host):
			for id in replica.entities:
				if replica.entities[id] == host:
					host_id = id
					break
		var jobs = []
		if "production_queue" in unit and unit.production_queue != null:
			for job in unit.production_queue._queue:
				jobs.append(
					{
						"role":
						load("res://source/match/BastionCatalog.gd").type_from_path(
							job.unit_prototype.resource_path
						),
						"time_total": job.time_total,
						"time_left": job.time_left,
						"paid_cost": job.paid_cost,
						"departure_endpoint": job.departure_endpoint,
						"assembly_started": job.assembly_started,
						"assembly_bonus": job.assembly_bonus,
						"batch_count": job.batch_count
					}
				)
		core.units.append(
			{
				"id": saved.id,
				"player": saved.player,
				"role": unit.type,
				"position": unit.position,
				"rotation": unit.rotation,
				"hp": unit.hp,
				"shield": unit.shields,
				"host": host_id,
				"jobs": jobs
			}
		)
	for saved in replica.state.resources:
		var resource = replica.entities.get(saved.id)
		if not is_instance_valid(resource):
			return ""
		core.resources.append(
			{
				"id": saved.id,
				"kind": saved.kind,
				"amount": resource.get(saved.kind),
				"position": resource.position
			}
		)
	for saved in replica.state.get("obstacles", []):
		var obstacle = replica.entities.get(saved.id)
		if not is_instance_valid(obstacle):
			return ""
		core.obstacles.append({"id": saved.id, "hp": obstacle.hp, "position": obstacle.position})
	for saved in replica.state.engineering.entities:
		var entity = replica.entities.get(saved.id)
		if not is_instance_valid(entity):
			return ""
		core.engineering.append({"id": saved.id, "hp": entity.hp, "position": entity.position})
	return Protocol.canonical_hash(_native(core))


static func _native(value):
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Dictionary:
		var result = {}
		for key in value:
			result[key] = _native(value[key])
		return result
	if value is Array:
		return value.map(_native)
	return value

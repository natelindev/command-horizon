extends SceneTree

## One-time repository archive conversion, v20 -> v21. Runtime loading stays strict.
## Existing unit/resource IDs and exact encoded legacy values are retained.
var converted = []
var errors = []


func _initialize():
	call_deferred("_run")


func _run():
	var store = load("res://source/match/saves/SaveFile.gd").new()
	var definitions = load("res://source/match/saves/GameplayDepthSchema.gd").new()
	for directory in ["res://docs/playtests", "res://tests/fixtures"]:
		for path in _json_files(directory):
			var envelope = JSON.parse_string(FileAccess.get_file_as_string(path))
			if (
				not envelope is Dictionary
				or not envelope.get("format") is String
				or envelope.format != "open-rts-match"
			):
				continue
			var data = store.read_file(path)
			if data == null:
				errors.append(path + ": " + store.error)
				continue
			if data.snapshot_version == 21:
				if _ensure_abilities(data, definitions):
					if not store.write_file(path, data):
						errors.append(path + ": " + store.error)
				converted.append(path)  # Refresh checksums after an interrupted earlier run.
				continue
			if data.snapshot_version != 20:
				errors.append(path + ": expected v20 archive")
				continue
			var before_units = data.units.map(func(unit): return unit.id)
			var before_resources = data.resources.map(func(resource): return resource.id)
			data.snapshot_version = 21
			# Preserve the historical event-free encounter instead of replaying missed events.
			data.settings.battlefield_events = false
			data.grenades = {"serial": 0, "pending": []}
			data.engineering = {"next_id": 1, "entities": [], "cooldowns": [], "reservations": []}
			data.commander = definitions.commander_defaults()
			data.events = {}
			var units = {}
			for unit in data.units:
				units[unit.id] = unit
				var faction = data.settings.players[int(unit.player.trim_prefix("player-"))].faction
				unit.permanent_scrap_rank = unit.get("scrap_hardened", {}).get("tiers", 0)
				unit.damage_visual_band = 0
				unit.regarrison_lock_left = 0.0
				unit.suppression = {}
				if (
					load("res://source/match/BastionCatalog.gd").is_infantry(unit.role)
					and unit.role != "Hero"
				):
					unit.suppression = {
						"meter": 0.0, "band": 0, "recovery_left": 0.0, "near_misses": []
					}
				unit.abilities = {}
				for ability in definitions.definitions(unit.role, faction):
					unit.abilities[ability.id] = {
						"cooldown_left": 0.0,
						"active_left": 0.0,
						"is_active": false,
						"effect_position": Vector3.ZERO
					}
				if not unit.production.is_empty():
					unit.production.assembly_state = {
						"last_completed_role": "", "completed_streak": 0, "idle_grace_left": 0.0
					}
					for index in unit.production.jobs.size():
						var job = unit.production.jobs[index]
						job.assembly_started = index == 0 and job.time_left < job.time_total
						job.assembly_bonus = 0.0
				if unit.role == "Drone" and faction == "helix":
					_remove_helix_attack(unit)
			for building in data.neutral_buildings:
				building.entry_points = building.occupants.map(func(id): return units[id].position)
				building.evacuating = []
			for round in data.rounds.flying:
				round.suppression = []
			if (
				before_units != data.units.map(func(unit): return unit.id)
				or before_resources != data.resources.map(func(resource): return resource.id)
			):
				errors.append(path + ": entity identities changed")
				continue
			if not store.write_file(path, data):
				errors.append(path + ": " + store.error)
				continue
			converted.append(path)
	_update_manifests()
	for error in errors:
		push_error(error)
	print(
		(
			"Gameplay depth archive conversion: %d converted, %d errors"
			% [converted.size(), errors.size()]
		)
	)
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _remove_helix_attack(unit):
	var attacks = [
		"DroneDive", "AutoAttacking", "AttackingWhileInRange", "AttackMoving", "WaitingForTargets"
	]
	if unit.action.get("kind", "") in attacks:
		unit.action = {}
		unit.weapon_left = 0.0
		unit.movement._has_destination = false
		unit.movement.velocity = Vector3.ZERO
		unit.movement.target_position = unit.position
	if not unit.orders.is_empty():
		if unit.orders.current.get("kind", "") in ["attack", "force_attack", "attack_move"]:
			unit.orders.current = {}
		unit.orders.pending = unit.orders.pending.filter(
			func(order): return order.kind not in ["attack", "force_attack", "attack_move"]
		)
		unit.orders._engaged = (
			not unit.orders.current.is_empty() or not unit.orders.pending.is_empty()
		)


func _json_files(path):
	var result = []
	var directory = DirAccess.open(path)
	if directory == null:
		return result
	for file in directory.get_files():
		if file.ends_with(".json"):
			result.append(path.path_join(file))
	for child in directory.get_directories():
		result.append_array(_json_files(path.path_join(child)))
	return result


func _update_manifests():
	var manifests = {}
	for path in converted:
		var manifest = path.get_base_dir().path_join("SHA256SUMS")
		if FileAccess.file_exists(manifest):
			manifests[manifest] = true
	for manifest in manifests:
		var lines = FileAccess.get_file_as_string(manifest).split("\n")
		for index in lines.size():
			var parts = lines[index].strip_edges().split(" ", false)
			if parts.size() != 2:
				continue
			var path = manifest.get_base_dir().path_join(parts[1].trim_prefix("*"))
			if path in converted:
				lines[index] = FileAccess.get_sha256(path) + "  " + parts[1]
		var file = FileAccess.open(manifest, FileAccess.WRITE)
		file.store_string("\n".join(lines))


func _ensure_abilities(data, definitions) -> bool:
	var changed = false
	for unit in data.units:
		var faction = data.settings.players[int(unit.player.trim_prefix("player-"))].faction
		var expected = definitions.definitions(unit.role, faction)
		var ids = expected.map(func(ability): return ability.id)
		for id in unit.abilities.keys():
			if id not in ids:
				unit.abilities.erase(id)
				changed = true
		for ability in expected:
			if not unit.abilities.has(ability.id):
				unit.abilities[ability.id] = {
					"cooldown_left": 0.0,
					"active_left": 0.0,
					"is_active": false,
					"effect_position": Vector3.ZERO
				}
				changed = true
	return changed

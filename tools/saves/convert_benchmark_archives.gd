extends SceneTree

## Repository-only v21 -> v22 conversion. Runtime loading remains version-strict.
## Default invocation checks without writing; --write commits validated snapshots.
const OLD_HP = {
	"MercenaryLancer": 50,
	"MercenaryRanger": 30,
	"MercenaryWarden": 85,
	"Hero": 110,
	"AssaultInfantry": 38,
	"SniperInfantry": 20,
	"RocketInfantry": 32,
	"SupplyTruck": 180,
	"Infantry": 22,
	"RepairRobot": 45,
	"CombatRobot": 65,
	"AdvancedTank": 145,
	"Barracks": 220,
	"PowerPlant": 160,
	"CommandLab": 220,
	"RepairDepot": 260,
	"Drone": 25,
	"Worker": 35,
	"AntiAirVehicle": 70,
	"Fighter": 45,
	"Bomber": 90,
	"Helicopter": 50,
	"Tank": 115,
	"CommandCenter": 500,
	"VehicleFactory": 320,
	"AircraftFactory": 300,
	"AntiGroundTurret": 120,
	"AntiAirTurret": 100,
}
const OLD_SHIELDS = {
	"Infantry": 15.0,
	"RocketInfantry": 15.0,
	"SniperInfantry": 15.0,
	"AssaultInfantry": 15.0,
	"Hero": 15.0,
	"Tank": 30.0,
	"CombatRobot": 35.0,
	"AdvancedTank": 40.0,
	"Helicopter": 25.0,
	"Fighter": 25.0,
	"Bomber": 25.0,
	"AntiAirVehicle": 25.0,
	"Drone": 15.0,
}
var _catalog
var _technology
var _definitions
var _sites
var _store
var _schema
var _converted = []
var _manifest_paths = []
var _checked = 0
var _current = 0
var _errors = []
var _refunds = Vector2i.ZERO
var _write = false


func _initialize():
	call_deferred("_run")


func _run():
	print(
		"bin: " + JSON.stringify(OS.get_executable_path().replace(OS.get_environment("HOME"), "~"))
	)
	print("description: Validate or convert repository battle archives from v21 to v22")
	var arguments = OS.get_cmdline_user_args()
	if "--help" in arguments:
		print("flags: --write commits validated files; --help shows this reference")
		print("default: check-only; current v22 contract defaults are reconciled before validation")
		print("examples[2]:")
		print(
			"  Godot --headless --no-header --path . --script tools/saves/convert_benchmark_archives.gd"
		)
		print(
			(
				"  Godot --headless --no-header --path . --script "
				+ "tools/saves/convert_benchmark_archives.gd -- --write"
			)
		)
		quit(0)
		return
	for argument in arguments:
		if argument != "--write":
			print("error: " + JSON.stringify("Unknown argument: " + argument))
			print("help: Run the converter with --help")
			quit(2)
			return
	_write = "--write" in arguments
	_catalog = load("res://source/match/FactionCatalog.gd")
	_technology = load("res://source/match/research/TechnologyCatalog.gd")
	_definitions = load("res://source/match/saves/GameplayDepthSchema.gd").new()
	_sites = load("res://source/match/world/PointOfInterestCatalog.gd")
	_store = load("res://source/match/saves/SaveFile.gd").new()
	_schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	for directory in ["res://docs/playtests", "res://tests/fixtures"]:
		for path in _json_files(directory):
			var envelope = JSON.parse_string(FileAccess.get_file_as_string(path))
			if (
				not envelope is Dictionary
				or not envelope.get("format") is String
				or envelope.format != "open-rts-match"
			):
				continue
			_checked += 1
			var data = _store.read_file(path)
			if data == null:
				_errors.append({"path": path, "reason": _store.error})
				continue
			if data.snapshot_version == 22:
				_manifest_paths.append(path)
				_current += 1
				var preserved = _identity_state(data)
				var reconciled = _contract_defaults(data)
				if preserved != _identity_state(data):
					_errors.append(
						{"path": path, "reason": "Reconciliation changed identities or balances"}
					)
					continue
				if not _schema.validate(data):
					_errors.append({"path": path, "reason": _schema.error})
				elif reconciled:
					if _write and not _store.write_file(path, data):
						_errors.append({"path": path, "reason": _store.error})
					else:
						_converted.append(path)
				continue
			if data.snapshot_version != 21:
				_errors.append({"path": path, "reason": "Expected v21 or current v22"})
				continue
			var units_before = data.units.map(func(unit): return unit.id)
			var resources_before = data.resources.map(func(resource): return resource.id)
			_convert(data)
			_contract_defaults(data)
			if (
				units_before != data.units.map(func(unit): return unit.id)
				or resources_before != data.resources.map(func(resource): return resource.id)
			):
				_errors.append({"path": path, "reason": "Unit or resource identities changed"})
				continue
			if not _schema.validate(data):
				_errors.append({"path": path, "reason": _schema.error})
				continue
			if _write and not _store.write_file(path, data):
				_errors.append({"path": path, "reason": _store.error})
				continue
			_converted.append(path)
			_manifest_paths.append(path)
			if _checked % 25 == 0:
				await process_frame
	if _write:
		_update_manifests()
	print("mode: " + ("write" if _write else "check"))
	print("archives: %d" % _checked)
	print("current: %d" % _current)
	print("converted: %d" % _converted.size())
	print("refunds[2]: %d,%d" % [_refunds.x, _refunds.y])
	print("errors[%d]{path,reason}:" % _errors.size())
	for entry in _errors:
		print("  " + JSON.stringify(entry.path) + "," + JSON.stringify(entry.reason))
	if not _write and _errors.is_empty() and not _converted.is_empty():
		print("help: Re-run with --write to commit these validated conversions")
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _contract_defaults(data) -> bool:
	var changed = false
	for mark in data.battlefield_wear:
		if mark.kind == 1 and not mark.has("left"):
			mark.left = 180.0
			changed = true
	for side in data.players:
		if not side.economy.has("air_contract_left"):
			side.economy.air_contract_left = 0.0
			changed = true
	for unit in data.units:
		if not unit.benchmark.has("mercenary"):
			unit.benchmark.mercenary = {}
			changed = true
	for index in data.events.get("occurrences", []).size():
		var event = data.events.occurrences[index]
		var count = event.cargos.size()
		if count == 0:
			continue
		var budget = load("res://source/match/world/BattlefieldEvents.gd").reward_budget(event.kind)
		var rotation = posmod(data.settings.match_seed, count)
		for cargo_index in count:
			var cargo = event.cargos[cargo_index]
			var share = posmod(cargo_index - rotation - index, count)
			var materials = budget.x / count + (1 if share < budget.x % count else 0)
			var electronics = budget.y / count + (1 if share < budget.y % count else 0)
			if cargo.materials != materials or cargo.electronics != electronics:
				cargo.materials = materials
				cargo.electronics = electronics
				changed = true
	return changed


func _identity_state(data) -> PackedByteArray:
	# Contract-only reconciliation must not relocate armies, change deposits,
	# replay claimed deliveries, or touch money already awarded in the archive.
	var events = []
	for event in data.events.get("occurrences", []):
		var cargos = []
		for cargo in event.cargos:
			cargos.append([cargo.id, cargo.point, cargo.status, cargo.claimant])
		events.append([event.id, cargos])
	return var_to_bytes(
		[
			data.units.map(func(unit): return [unit.id, unit.position, unit.rotation]),
			data.resources,
			data.players.map(func(side): return [side.id, side.resource_a, side.resource_b]),
			events
		]
	)


func _convert(data):
	data.snapshot_version = 22
	var old_completed = {}
	for side in data.players:
		old_completed[side.id] = side.technology.completed.duplicate()
		var faction = _faction(data, side.id)
		_prune_research(side, faction)
		side.economy = {
			"logistics": 25.0,
			"logistics_left": 5.0,
			"market_pressure": 0.0,
			"harvesting": [],
			"production": []
		}
	for unit in data.units:
		var faction = _faction(data, unit.player)
		var side = data.players[int(unit.player.trim_prefix("player-"))]
		var old_maximum = _old_health(faction, unit.role, old_completed[unit.player])
		var maximum = (
			_catalog.base_health(faction, unit.role)
			* _technology.health_factor(unit.role, side.technology.completed)
		)
		unit.hp = maximum * clampf(float(unit.hp) / maxf(1.0, old_maximum), 0.0, 1.0)
		unit.benchmark = {
			"tactics":
			(
				{}
				if unit.construction != null
				else {"formation": "line", "cohesion_enabled": false, "cohesion_members": []}
			),
			"ion_stall_left": 0.0,
			"refinery_remainder": 0.0,
			"hq_energy": 50.0 if unit.role == "CommandCenter" and faction == "helix" else 0.0,
			"shield_withdrawing": false,
			"cloak_left": 3.0 if faction == "helix" and unit.role == "SniperInfantry" else 0.0,
			"prism_target": "",
			"prism_seconds": 0.0,
		}
		var shield_maximum = _technology.shield_capacity(
			unit.role, faction, side.technology.completed
		)
		if shield_maximum > 0.0:
			var old = unit.get("plasma_shield", {})
			var old_capacity = OLD_SHIELDS.get(unit.role, 0.0)
			unit.plasma_shield = {
				"charge":
				(
					shield_maximum * clampf(old.charge / old_capacity, 0.0, 1.0)
					if not old.is_empty() and old_capacity > 0.0
					else shield_maximum
				),
				"damage_age": old.get("damage_age", unit.damage_age),
			}
		else:
			unit.erase("plasma_shield")
		unit.deployment = (
			{"deployment_left": 2.0, "deployment_position": unit.position}
			if faction == "bastion" and unit.role == "AdvancedTank"
			else {}
		)
		_reconcile_abilities(unit, faction)
		_convert_action(unit.action)
		if not unit.production.is_empty():
			var kept = []
			for job in unit.production.jobs:
				if not _catalog.roster(faction).allows(job.role):
					_refund(side, job.paid_cost)
					continue
				job.batch_count = 1
				kept.append(job)
			unit.production.jobs = kept
	_convert_sites(data)


func _old_health(faction, role, completed) -> float:
	var maximum = float(OLD_HP.get(role, 1.0))
	if role not in _catalog.Bastion.STRUCTURES:
		var factor = 1.0
		if faction == "helix":
			factor = 0.8
		elif faction == "frontier":
			factor = (
				1.1
				if role in _catalog.Bastion.INFANTRY_ROLES
				else (0.7 if _catalog.Bastion.is_aircraft(role) else 0.85)
			)
		maximum = roundf(maximum * factor)
	return (
		maximum
		* (
			1.0 + 0.1 * _technology.rank("armor", completed)
			if role in _technology.COMBAT_ROLES
			else 1.0
		)
	)


func _prune_research(side, faction):
	var state = side.technology
	var retained = state.completed.filter(func(id): return _technology.available(id, faction))
	for id in state.completed:
		if id not in retained:
			_refund(side, _price(id))
	var changed = true
	while changed:
		changed = false
		for id in retained.duplicate():
			if not _requirements_met(id, retained, side.coordination_unlocked):
				retained.erase(id)
				_refund(side, _price(id))
				changed = true
	state.completed = retained
	var planned = retained.duplicate()
	if side.coordination_unlocked or side.coordination_left > 0.0:
		planned.append("coordination")
	if state.active != "":
		if (
			not _technology.available(state.active, faction)
			or not _requirements_met(state.active, planned, side.coordination_unlocked)
		):
			_refund(side, state.paid)
			state.active = ""
			state.left = -1.0
			state.paid = {}
		else:
			planned.append(state.active)
	var queued = []
	for entry in state.queued:
		if (
			not _technology.available(entry.id, faction)
			or not _requirements_met(entry.id, planned, "coordination" in planned)
		):
			_refund(side, entry.paid)
			continue
		queued.append(entry)
		planned.append(entry.id)
	state.queued = queued


func _requirements_met(id, planned, coordinated) -> bool:
	return _technology.requirements(id).all(
		func(required): return coordinated if required == "coordination" else required in planned
	)


func _price(id) -> Dictionary:
	var price = _technology.cost(id)
	return {"resource_a": price.x, "resource_b": price.y}


func _refund(side, price):
	for resource in ["resource_a", "resource_b"]:
		side[resource] += int(price.get(resource, 0))
	_refunds += Vector2i(int(price.get("resource_a", 0)), int(price.get("resource_b", 0)))


func _reconcile_abilities(unit, faction):
	var expected = _definitions.definitions(unit.role, faction)
	var ids = expected.map(func(ability): return ability.id)
	for id in unit.abilities.keys():
		if id not in ids:
			unit.abilities.erase(id)
	for ability in expected:
		if not unit.abilities.has(ability.id):
			unit.abilities[ability.id] = {
				"cooldown_left": 0.0,
				"active_left": 0.0,
				"is_active": false,
				"effect_position": Vector3.ZERO
			}


func _convert_action(action):
	if action.is_empty():
		return
	if action.kind == "CollectingResourcesSequentially":
		action.state["_phase_left"] = 0.0
	if action.kind == "Moving":
		action.children["_shot"] = {}
	if (
		action.kind == "Garrisoning"
		and action.references.get("_target_unit", "").begins_with("poi-")
	):
		action.state._capture_elapsed = minf(action.state.get("_capture_elapsed", 0.0), 11.999)
	for child in action.get("children", {}).values():
		_convert_action(child)


func _convert_sites(data):
	var definitions = _sites.definitions(data.settings.map_path)
	var existing = data.mission.get("points_of_interest", [])
	for index in existing.size():
		var record = existing[index]
		record.radar_left = 0.0
		record.radar_points = []
		if index < definitions.size() and definitions[index].kind in ["refinery", "data_relay"]:
			record.progress = minf(record.progress, 11.999)
	for index in range(existing.size(), definitions.size()):
		existing.append(
			{
				"id": "poi-%d" % index,
				"hp": 300.0,
				"owner": "",
				"candidate": "",
				"progress": 0.0,
				"contested": false,
				"income_left": 4.0,
				"stock_a": 600,
				"stock_b": 300,
				"radar_left": 0.0,
				"radar_points": [],
				"jobs": []
			}
		)
	if not definitions.is_empty():
		data.mission.points_of_interest = existing


func _faction(data, id) -> String:
	return data.settings.players[int(id.trim_prefix("player-"))].faction


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
	for path in _manifest_paths:
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
			if path in _manifest_paths:
				lines[index] = FileAccess.get_sha256(path) + "  " + parts[1]
		var file = FileAccess.open(manifest, FileAccess.WRITE)
		file.store_string("\n".join(lines))

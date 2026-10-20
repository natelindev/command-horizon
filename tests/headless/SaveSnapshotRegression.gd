extends "res://tests/headless/CampaignRegression.gd"

const Snapshot = preload("res://source/match/saves/MatchSnapshot.gd")
const SaveFile = preload("res://source/match/saves/SaveFile.gd")
const Values = preload("res://source/match/saves/SaveValue.gd")
const SCALE_ORDERS = 8
var save_path = ""


func _run():
	save_path = "user://snapshot-regression-%d.json" % OS.get_process_id()
	path = "user://snapshot-campaign-%d.json" % OS.get_process_id()
	_value_safety()
	await _make_match()
	var builder = Snapshot.new()
	_check(builder.capture(game) == null, "Captured an unpaused simulation")
	var human = game._get_human_player()
	human.resource_a = 1000
	human.resource_b = 1000
	game._spawn("CommandLab", human, Vector3(23, 0, 8))
	await _frames(5)
	var tanks = _units(human, "Tank")
	var workers = _units(human, "Worker")
	var deposit = get_nodes_in_group("resource_units")[0]
	workers[0].issue_manual_order(
		load("res://source/match/units/actions/CollectingResourcesSequentially.gd").new(deposit)
	)
	var lab = load("res://source/match/units/CommandLab.tscn").instantiate()
	game._setup_and_spawn_unit(lab, Transform3D(Basis(), Vector3(15, 0, 32)), human, true)
	workers[1].issue_manual_order(load("res://source/match/units/actions/Constructing.gd").new(lab))
	var tank = tanks[0]
	var guard_point = Vector3(26, 0, 27)
	_check(
		load("res://source/match/orders/UnitBehavior.gd").guard(tank, guard_point),
		"Could not post the snapshot guard"
	)
	human.coordination_unlocked = true
	tanks[1].manual_orders.submit({"kind": "move", "point": Vector3(32, 0, 25)})
	tanks[1].manual_orders.submit({"kind": "move", "point": Vector3(28, 0, 22)}, true)
	await _frames(330)
	_check(workers[0].resource_a > 0, "Harvest fixture has no cargo")
	var enemy_hq = game._spawn("CommandCenter", game._enemy, Vector3(70, 0, 55))
	var visibility = game.get_node("Handlers/UnitVisibilityHandler")
	visibility._create_dummy_structure(enemy_hq)
	enemy_hq.hp = 0
	await _frames(3)
	var factory = _units(human, "VehicleFactory")[0]
	var job = factory.production_queue.produce(load("res://source/match/units/Tank.tscn"))
	_check(job != null, "Could not queue paid production")
	job.time_left = 9.25
	human.coordination_unlocked = false
	human.coordination_left = 12.5
	tank.last_enemy_damage_time = game.simulation_time - 1.25
	tank.set_meta("next_attack_availability_time", int(game.simulation_time * 1000) + 1750)
	# Explicit queued reference and an in-flight shot must not serialize instance IDs.
	var enemy = _units(game._enemy, "Infantry")[0]
	var orders = load("res://source/match/orders/ManualOrders.gd")
	tanks[1].manual_orders.submit(orders.target_order("attack", enemy), true)
	var rocket = game.projectile_system.launch(tank, enemy)
	rocket.life = 0.375
	game.phase = 2
	game.hold_seconds = 17.25
	game.defence_time = 23.5
	game.waves_warned = 2
	game.waves_sent = 1
	paused = true
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Capture failed: " + builder.error)
	if snapshot == null:
		await _finish_checks()
		return
	_check(snapshot.snapshot_version == Snapshot.VERSION, "Capture wrote another version")
	var store = SaveFile.new()
	_check(store.write_file(save_path, snapshot), "Write failed: " + store.error)
	_check(store.write_file(save_path, snapshot), "Valid slot replacement failed: " + store.error)
	var restored = store.read_file(save_path)
	if restored != snapshot:
		_difference(snapshot, restored, "match")
	_check(restored == snapshot, "Disk round trip changed match state or types")
	if DisplayServer.get_name() != "headless":
		_check(snapshot.fog.available, "Rendered exploration history missing")
		var image = Image.new()
		_check(
			image.load_png_from_buffer(Marshalls.base64_to_raw(snapshot.fog.png)) == OK,
			"Exploration image could not decode"
		)
		_check(image.get_width() == 160 and image.get_height() == 128, "Fog dimensions changed")
		_check(
			image.get_pixel(28, 30).r > image.get_pixel(150, 120).r,
			"Explored base and unexplored terrain lost their distinction"
		)
	var saved = snapshot.units.filter(func(item): return item.id == builder._reference(tank))[0]
	_check(saved.stance == tank.Stance.HOLD_POSITION, "Guard stance lost")
	_check(
		saved.position.distance_to(guard_point) < 2.5 and saved.orders.current.is_empty(),
		"Guard post did not settle before capture"
	)
	var saved_id = saved.id
	var flying = snapshot.rounds.flying.filter(func(round): return round.shooter == saved_id)
	var queued = snapshot.units.filter(func(item): return item.id == builder._reference(tanks[1]))[0]
	var attacks = (queued.orders.pending + [queued.orders.current]).filter(
		func(order): return order.get("kind") == "attack"
	)
	_check(
		attacks.size() == 1 and attacks[0].target == builder._reference(enemy),
		"Queued attack lost its target reference"
	)
	var saved_pending = queued.orders.pending.size()
	_check(
		(
			flying.size() == 1
			and flying[0].life - flying[0].age == 0.375
			and flying[0].target == builder._reference(enemy)
			and flying[0].damage == tank.attack_damage
		),
		"In-flight damage lost"
	)
	_check(abs(saved.weapon_left - 1.75) < 0.002, "Weapon cooldown is not a remaining duration")
	_check(is_equal_approx(saved.damage_age, 1.25), "Combat repair suppression lost")
	_check(snapshot.players[0].coordination_left == 12.5, "Research duration lost")
	_check(snapshot.players[0]._lab_research, "Lab research unlock lost")
	_check(
		snapshot.mission.hold_seconds == 17.25 and snapshot.mission.waves_warned == 2,
		"Mission progression lost"
	)
	var factory_id = builder._reference(factory)
	var saved_factory = snapshot.units.filter(func(item): return item.id == factory_id)[0]
	_check(saved_factory.production.jobs.size() == 1, "Queued production was not saved")
	_check(saved_factory.production.jobs[0].paid_cost == job.paid_cost, "Paid refund cost lost")
	_check(snapshot.structure_memory.size() == 1, "Last-known destroyed structure was lost")
	_check(snapshot.structure_memory[0].entity == "", "Dead structure retained a live reference")
	var paid = saved_factory.production.jobs[0].paid_cost.duplicate()
	job.paid_cost.resource_a += 1000
	tanks[1].manual_orders.pending.clear()
	_check(saved_factory.production.jobs[0].paid_cost == paid, "Snapshot aliases the paid job")
	_check(queued.orders.pending.size() == saved_pending, "Snapshot aliases live orders")
	job.paid_cost = paid
	var time = game.simulation_time
	await _frames(15)
	_check(
		game.simulation_time == time and job.time_left == 9.25,
		"Capturing advanced the paused match"
	)
	_file_safety(store, snapshot)
	if DisplayServer.get_name() == "headless":
		await _scale_capture()
	await _finish_checks()


func _scale_capture():
	paused = false
	game.queue_free()
	await _frames(5)
	await _make_match()
	paused = true
	var queued = 0
	for side in [game._get_human_player(), game._enemy]:
		while side.population() < 100:
			var index = side.population()
			game._spawn("Tank", side, Vector3(5 + (index % 15) * 4, 0, 5 + (index / 15) * 4))
		for unit in side.get_children():
			if not "type" in unit or unit.type != "Tank":
				continue
			for step in SCALE_ORDERS:
				var point = Vector3(10 + step * 3, 0, 10 + (queued % 15) * 3)
				unit.manual_orders.submit({"kind": "move", "point": point}, step > 0, false)
			queued += 1
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "200-unit capture exceeded bounds: " + builder.error)
	DirAccess.remove_absolute(save_path)  # Dispose only this test's intentionally corrupt slot.
	var store = SaveFile.new()
	if snapshot != null:
		_check(store.write_file(save_path, snapshot), "200-unit save failed: " + store.error)
		_check(store.read_file(save_path) == snapshot, "200-unit snapshot changed on disk")
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file != null:
			print(
				"SAVE SCALE: 200 mobiles; ",
				queued,
				" tanks with ",
				SCALE_ORDERS,
				"-order queues; bytes=",
				file.get_length()
			)
	return queued


func _value_safety():
	var codec = Values.new()
	var value = {
		"precise": 0.1 + 0.2,
		"big": 9223372036854775807,
		"small": -9223372036854775807 - 1,
		"vector": Vector3(1.25, 0, -2),
		"color": Color(0.25, 0.5, 0.75, 1),
		"state": {"int": "player text", "$type": "record", "list": [null, false, 3, 3.0]}
	}
	var encoded = codec.encode(value)
	var parser = JSON.new()
	_check(parser.parse(JSON.stringify(encoded, "", false, true)) == OK, "Typed save JSON failed")
	_check(
		codec.decode(parser.data) == value and codec.error.is_empty(),
		"64-bit or tagged player state lost"
	)
	for bad in [
		["object", "res://bad.gd"],
		["float", "ffffffffffffffff"],
		["int", "9223372036854775808"],
		["int", "01"],
		["record", [["x", ["null"]], ["x", ["bool", true]]]],
		["vec3", [1, 2, "3"]]
	]:
		codec.decode(bad)
		_check(not codec.error.is_empty(), "Invalid serialized value accepted")
	codec.encode(Vector3.INF)
	_check(not codec.error.is_empty(), "Nonfinite position accepted")
	var object = RefCounted.new()
	codec.encode({"object": object})
	_check(not codec.error.is_empty(), "Engine object entered a save")
	var nested = []
	for level in range(40):
		nested = [nested]
	codec.encode(nested)
	_check(not codec.error.is_empty(), "Unbounded nesting accepted")


func _difference(left, right, location):
	if left is Dictionary and right is Dictionary:
		for key in left:
			if left[key] != right.get(key):
				_difference(left[key], right.get(key), location + "." + str(key))
				return
	elif left is Array and right is Array and left.size() == right.size():
		for index in range(left.size()):
			if left[index] != right[index]:
				_difference(left[index], right[index], location + "[%d]" % index)
				return
	else:
		print("Snapshot mismatch ", location, ": ", left, " / ", right)


func _file_safety(store, snapshot):
	var original = FileAccess.get_file_as_string(save_path)
	var parser = JSON.new()
	parser.parse(original)
	var envelope = parser.data
	envelope.schema = 999
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	_check(store.read_file(save_path) == null, "Future format accepted")
	var future = FileAccess.get_file_as_string(save_path)
	_check(not store.write_file(save_path, snapshot), "Future save overwritten")
	_check(FileAccess.get_file_as_string(save_path) == future, "Future source changed")
	envelope.schema = 1
	envelope.payload += " "
	file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	_check(store.read_file(save_path) == null, "Checksum damage accepted")
	_check(not store.write_file(save_path, snapshot), "Corrupt slot overwritten")


func _finish_checks():
	paused = false
	game.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".tmp")
	for message in errors:
		push_error(message)
	if errors.is_empty():
		print(
			(
				"PASS: inert typed saves, exact snapshot, paid jobs/orders/stances/projectiles; "
				+ "pause and corruption preservation"
			)
		)
	quit(0 if errors.is_empty() else 1)

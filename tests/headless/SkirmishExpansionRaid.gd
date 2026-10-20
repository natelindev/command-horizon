extends "res://tests/headless/SkirmishExpansionRegression.gd"

var raid_deadline = 0


func _initialize():
	raid_deadline = Time.get_ticks_msec() + 600000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > raid_deadline:
		push_error("Expansion raid wall-clock timeout")
		quit(1)
	return false


func _review_expansion(player, field, label):
	var guards = economy.guards(player._units()).filter(
		func(unit): return unit.position.distance_to(field.position) < 10
	)
	_check(not guards.is_empty(), "Raid fixture lacks an established field guard")
	if guards.is_empty():
		return
	var raider = load(catalog.scene_path("Infantry")).instantiate()
	var point = guards[0].position + Vector3(3, 0, 0)
	game._setup_and_spawn_unit(raider, Transform3D(Basis(), point), game._get_human_player(), false)
	raider.issue_manual_order(attack_move.new(field.global_position_yless))
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(player, raider), "Expansion raider not observed")
	var before = player.resource_b
	var stock = field.resource_b
	# Engineers may spread across neighbouring deposits; conserve the total stock.
	var total_stock = _finite_stock().y
	var workers = _units(player, "Worker")
	var cargo_before = _cargo(workers)
	var start = game.simulation_time
	game.hud._toggle_pause()
	var cleared = -1.0
	for frame in 7200:
		if frame % 90 == 0:
			player._harvest(player._units())
			player._command_army(player._units())
			_check(
				player._army_groups.size() <= player.difficulty + 1,
				"Field raid/resumption exceeded the global task budget"
			)
		if cleared < 0 and (not is_instance_valid(raider) or raider.hp <= 0):
			cleared = game.simulation_time - start
		if (
			cleared >= 0
			and player.resource_b >= before + cargo_before + 4
			and field.resource_b <= stock - 4
		):
			break
		await physics_frame
	game.hud._toggle_pause()
	_check(cleared >= 0, "Field guard failed to defeat an actual infantry raider")
	_check(
		workers.all(func(unit): return is_instance_valid(unit) and unit.hp > 0),
		"Field raid killed a protected engineer"
	)
	_check(
		player.resource_b >= before + cargo_before + 4,
		"New post-raid field cargo never reached the HQ"
	)
	_check(field.resource_b <= stock - 4, "Post-raid income did not consume new field stock")
	_check(
		(
			total_stock - _finite_stock().y
			== player.resource_b - before + _cargo(workers) - cargo_before
		),
		"Raid income failed finite-stock conservation including in-transit cargo"
	)
	print(
		"EXPANSION RAID ",
		label,
		" cleared=",
		cleared,
		" income=",
		player.resource_b - before,
		" elapsed=",
		game.simulation_time - start
	)


func _cargo(workers):
	var result = 0
	for worker in workers:
		if is_instance_valid(worker):
			result += worker.resource_b
	return result

extends "res://tests/headless/HQCountdownRegression.gd"

var Factions
var Combat


func _run():
	Factions = load("res://source/match/FactionCatalog.gd")
	Combat = load("res://source/match/combat/CombatRules.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _mirror(faction)
		var owner = game._get_human_player()
		var enemy = get_nodes_in_group("players").filter(func(p): return p != owner)[0]
		var tank = _site_spawn("Tank", enemy, Vector3(35, 0, 50), false)
		await _frames(2)
		for role in Factions.Bastion.STRUCTURES:
			var site = _site_spawn(role, owner, Vector3(30, 0, 50), true)
			await _frames(2)
			var starting_hp = site.hp
			_check(
				starting_hp == floorf(site.hp_max * .25), faction + role + ": fragile foundation"
			)
			_check(not site.is_constructed(), "Foundation has completed-building services")
			var damage = Combat.damage(tank, site)
			site.receive_weapon_hit(tank)
			_check(
				site.hp > 0 and not site.is_queued_for_deletion(),
				role + ": first shot destroys site"
			)
			_check(
				is_equal_approx(site.hp, starting_hp - damage), "Foundation silently ignores damage"
			)
			if site.is_queued_for_deletion():
				await _frames(2)
				continue
			for step in 100:
				site.construct(.01)
			_check(site.is_constructed(), "Incremental construction failed to finish")
			_check(
				is_equal_approx(site.hp, site.hp_max - damage), "Completion lost damage or added HP"
			)
			site.queue_free()
			await _frames(2)
			var intact = _site_spawn(role, owner, Vector3(30, 0, 50), true)
			await _frames(2)
			intact.construct(.333)
			intact.construct(1.0)
			_check(intact.hp == intact.hp_max, "Undamaged construction does not reach full HP")
			intact.queue_free()
			await _frames(2)
		await _real_attack_and_reload(owner, tank)
		await _foundation_archives()
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Foundation durability: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _site_spawn(role, owner, point, foundation):
	var unit = load(Factions.Bastion.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), owner, foundation)
	return unit


func _real_attack_and_reload(owner, tank):
	var site = _site_spawn("PowerPlant", owner, Vector3(30, 0, 50), true)
	await _frames(3)
	var initial_hp = site.hp
	tank.action = load("res://source/match/units/actions/AttackingWhileInRange.gd").new(site)
	paused = false
	await _frames(35)
	game.hud.pause_after_load()
	_check(
		is_instance_valid(site) and not site.is_queued_for_deletion(),
		"Immediate enemy fire killed new site"
	)
	if not is_instance_valid(site) or site.is_queued_for_deletion():
		return
	_check(site.hp < initial_hp and site.hp > 0, "Real enemy weapon never hit foundation")
	tank.action = null
	site.construct(.37)
	var saved_hp = site.hp
	var progress = site._construction_progress
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var site_id = builder._reference(site)
	var tank_id = builder._reference(tank)
	var restore = Restore.new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Damaged foundation save failed")
	if not loaded.ok:
		return
	game = loaded.game
	site = restore.entities[site_id]
	tank = restore.entities[tank_id]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	_check(
		site.hp == saved_hp and site._construction_progress == progress,
		"Load heals/damages foundation"
	)
	var earned_hp = floorf(progress * (site.hp_max - initial_hp))
	var lost_hp = initial_hp + earned_hp - saved_hp
	site.construct(1.0)
	_check(is_equal_approx(site.hp, site.hp_max - lost_hp), "Resumed build erased saved damage")
	var owner_after = site.player
	site.queue_free()
	await _frames(3)
	var victim = _site_spawn("PowerPlant", owner_after, Vector3(30, 0, 50), true)
	await _frames(2)
	var funds = Vector2(owner_after.resource_a, owner_after.resource_b)
	var hits = 0
	while victim.hp > 0 and hits < 30:
		victim.receive_weapon_hit(tank)
		hits += 1
	_check(
		hits > 1 and victim.is_queued_for_deletion(),
		"Foundation cannot be destroyed by sustained fire"
	)
	_check(
		Vector2(owner_after.resource_a, owner_after.resource_b) == funds,
		"Enemy destruction refunded resources"
	)
	await _frames(3)
	print(
		"PASS ",
		owner_after.faction,
		": all 9 roles, enemy fire, save/load, continued construction and destruction"
	)


func _foundation_archives():
	var owner = game._get_human_player()
	var fixtures = []
	for index in 3:
		var site = _site_spawn("CommandCenter", owner, Vector3(18 + index * 7, 0, 65), true)
		await _frames(2)
		var progress = [0.0, .43, .81][index]
		if progress > 0:
			site.construct(progress)
		# A pristine new foundation, an undamaged partial build, and a damaged one.
		if index == 2:
			site.hp -= 13
		fixtures.append(site)
	var health = fixtures.map(func(site): return site.hp)
	var progress = fixtures.map(func(site): return site._construction_progress)
	var restore = Restore.new()
	for reload in 2:
		var builder = Snapshot.new()
		var data = builder.capture(game)
		var ids = fixtures.map(func(site): return builder._reference(site))
		var loaded = await restore.restore(self, data)
		_check(loaded.ok, "Foundation archive was rejected")
		if not loaded.ok:
			return
		game = loaded.game
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		fixtures = ids.map(func(id): return restore.entities[id])
		for index in fixtures.size():
			_check(
				(
					fixtures[index].hp == health[index]
					and is_equal_approx(fixtures[index]._construction_progress, progress[index])
				),
				"Foundation reload changed health or construction progress"
			)
	for index in fixtures.size():
		var damage = 13 if index == 2 else 0
		fixtures[index].construct(1.0)
		_check(
			fixtures[index].hp == fixtures[index].hp_max - damage,
			"Reloaded construction finished with incorrect HP"
		)
	print("PASS foundation archives: zero/partial/damaged, repeated reload, completion")

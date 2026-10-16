extends "res://tests/headless/HeroCampaignRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://hero-ability-%d.json" % OS.get_process_id()
	for id in ["bastion_cinder_ford", "helix_pruning", "frontier_wren"]:
		paused = false
		await _make_operation(id)
		var hero = game.campaign_hero
		var role = "Infantry" if hero.unit.player.faction != "frontier" else "Tank"
		var owner = game._enemy if hero.unit.player.faction == "helix" else hero.unit.player
		var target = game._spawn(role, owner, hero.unit.position + Vector3(3, 0, 0))
		target.hp = target.hp_max * .5
		var hp = target.hp
		_check(hero.activate(), "Hero ability did not activate: " + id)
		_check(hero.cooldown == 30, "Ability cooldown missing: " + id)
		_check(
			target.hp < hp if owner == game._enemy else target.hp > hp,
			"Ability had no effect: " + id
		)
		if owner == game._enemy:
			_check(
				target.last_enemy_damage_time == game.simulation_time,
				"Ability damage bypassed combat bookkeeping"
			)
		_check(not hero.activate(), "Ability bypassed cooldown: " + id)
		hero.step(30)
		paused = true
		_check(not hero.activate(), "Ability works during pause: " + id)
		paused = false
		hero.unit.hp = 0
		hero.step(0)
		_check(game.result == "Defeat", "Hero loss not enforced: " + id)
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Hero abilities: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)

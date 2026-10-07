extends "res://tests/headless/AuthoredGuardRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		for mode in ["lua", "visual"]:
			active_mode = mode
			for role in Records.ARMED:
				active_role = role
				await _setup(faction)
				_check(
					game.battlefield.can_fire(guard, raider),
					"Role fixture cannot fire: " + faction + " " + role
				)
				var point = guard.position
				var hp = raider.hp
				_start_guard()
				await _frames(240)
				_check(raider.hp < hp, "Guard role never fired: " + faction + " " + role)
				_check(
					guard.position.distance_to(point) < .25,
					"Guard role moved from legal firing position: " + role
				)
				_check(guard.program.mode == "Running", "Guard role stopped: " + role)
				print("GUARD ROLE ", faction, " ", mode, " ", role, " damage=", hp - raider.hp)
				game.queue_free()
				await _frames(5)
		for role in ["Drone", "RepairRobot"]:
			active_role = role
			await _setup(faction)
			var point = guard.position
			_check(
				not Records.validate(Records.visual("Invalid role", 1, Visual.starter(1), [role])),
				"Visual guard accepted unarmed role"
			)
			_check(
				(
					guard
					. program
					. configure_lua(
						"return function(s,m) return {intent={kind='guard'},state=m} end"
					)
					. ok
				),
				"Unarmed guard Lua did not compile"
			)
			_check(guard.program.run(), "Unarmed guard Lua did not start")
			await _frames(90)
			_check(
				guard.program.mode == "Waiting" and "armed unit" in guard.program.reason,
				"Unarmed Lua guard did not wait"
			)
			_check(guard.position.distance_to(point) < .25, "Unarmed Lua guard moved")
			game.queue_free()
			await _frames(5)
	for error in errors:
		push_error(error)
	print("Authored guard roles: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)

extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		for role in [
			"Worker", "Tank", "AntiAirVehicle", "AdvancedTank", "RepairRobot", "CombatRobot"
		]:
			var unit = _spawn(role, 0, Vector3(30, 0, 12))
			var visual = unit.get_node("BastionVisuals")
			var transform = unit.global_transform
			var speed = unit.movement_speed
			for state in [
				[1.0, 0], [.49, 1], [.51, 1], [.54, 0], [.24, 2], [.27, 2], [.29, 1], [.54, 0]
			]:
				unit.hp = unit.hp_max * state[0]
				visual._update_damage(.21)
				visual._advance_pose(.1)
				_check(
					unit.damage_visual_band == state[1],
					"%s/%s damage hysteresis %s" % [faction, role, state]
				)
				_check(
					unit.global_transform == transform and unit.movement_speed == speed,
					"Damage decoration changed simulation"
				)
			if faction == "frontier" and role in ["Tank", "AntiAirVehicle", "AdvancedTank"]:
				_check(
					visual._scrap_plates.size() == 2,
					"%s missing generated permanent plate ranks" % role
				)
				for rank in 3:
					unit.permanent_scrap_rank = rank
					unit.scrap_hardened_tiers = 0
					unit.scrap_hardened_left = 0
					visual._sync_scrap_plates()
					for plate in visual._scrap_plates:
						for mesh in plate.meshes:
							_check(
								mesh.visible == (rank >= plate.rank),
								"Plate visibility follows temporary buff"
							)
			unit.hp = 0
			visual._update_damage(.21)
			_check(unit.damage_visual_band == 0, "Dead unit retains damage decoration")
			unit.queue_free()
		for role in ["Infantry", "Drone", "Helicopter"]:
			var unit = _spawn(role, 0, Vector3(30, 0, 12))
			unit.hp = unit.hp_max * .2
			unit.get_node("BastionVisuals")._update_damage(.21)
			_check(unit.damage_visual_band == 0, "Ground-machine band applied to " + role)
			unit.queue_free()
		await _close()
	for message in _errors:
		push_error(message)
	print("Vehicle damage visuals regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)

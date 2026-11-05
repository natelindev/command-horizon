extends "res://tests/headless/CampaignRegression.gd"

const Catalog = preload("res://source/match/campaign/CampaignCatalog.gd")


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://progression-upgrade-test-%d.json" % OS.get_process_id()
	var hub_path = path + ".hub"

	# 1. Test Sequential Unlocking
	var progress = Progress.new()
	progress.read_progress(path)
	_check(
		progress.is_operation_unlocked("first_orders", "bastion"),
		"First Bastion mission should be unlocked by default"
	)
	_check(
		not progress.is_operation_unlocked("supply_line", "bastion"),
		"Second Bastion mission should be locked initially"
	)
	_check(
		progress.next_uncompleted_operation("bastion") == "first_orders",
		"Next uncompleted operation should be first_orders"
	)

	# Complete first_orders
	_check(progress.record_victory(false, path), "Failed to record first orders victory")
	_check(
		progress.is_operation_unlocked("supply_line", "bastion"),
		"Second Bastion mission should unlock after completing first"
	)
	_check(
		progress.next_uncompleted_operation("bastion") == "supply_line",
		"Next uncompleted operation should advance to supply_line"
	)
	_check(
		not progress.is_operation_unlocked("split_signal", "bastion"),
		"Third mission should still be locked"
	)

	# 2. Test Catalog next_operation
	_check(
		Catalog.next_operation("first_orders") == "supply_line",
		"next_operation from first_orders should be supply_line"
	)
	_check(
		Catalog.next_operation("supply_line") == "split_signal",
		"next_operation from supply_line should be split_signal"
	)
	_check(
		Catalog.next_operation("command_horizon") == "",
		"next_operation from final mission should be empty"
	)

	# 3. Test Tech Points Economy
	var state = load("res://source/match/campaign/CampaignHubState.gd").new()
	state.read_state(hub_path)
	_check(
		state.total_points_earned("bastion", progress) == 100,
		"Completing one mission should award 100 points, got %d"
		% state.total_points_earned("bastion", progress)
	)
	_check(
		state.points_available("bastion", progress) == 100,
		"100 points should be available"
	)

	# Add a commendation (+50 bonus points)
	state.commendations.append("supply_line")
	state.save_state(hub_path)
	_check(
		state.total_points_earned("bastion", progress) == 150,
		"Mission + commendation should equal 150 points"
	)
	_check(
		state.points_available("bastion", progress) == 150,
		"150 points should be available with commendation"
	)

	# 4. Test Upgrade Requirements and Purchasing
	_check(
		not state.can_purchase_upgrade("bastion", "weapons_2", progress),
		"weapons_2 should require weapons_1 prerequisite"
	)
	_check(
		state.can_purchase_upgrade("bastion", "weapons_1", progress),
		"weapons_1 should be purchasable with 150 pts (costs 100)"
	)
	_check(
		state.purchase_upgrade("bastion", "weapons_1", hub_path, progress),
		"purchase_upgrade weapons_1 should succeed"
	)
	_check(
		state.has_upgrade("bastion", "weapons_1"),
		"State should reflect weapons_1 upgrade"
	)
	_check(
		state.points_spent("bastion") == 100,
		"Spent points should be 100"
	)
	_check(
		state.points_available("bastion", progress) == 50,
		"Available points should be 50 after spending 100"
	)
	_check(
		not state.can_purchase_upgrade("bastion", "weapons_2", progress),
		"weapons_2 should not be purchasable with only 50 points (costs 150)"
	)

	# 5. Test Respec / Refund
	_check(
		state.reset_upgrades("bastion", hub_path),
		"reset_upgrades should succeed"
	)
	_check(
		not state.has_upgrade("bastion", "weapons_1"),
		"weapons_1 should be cleared after reset"
	)
	_check(
		state.points_spent("bastion") == 0 and state.points_available("bastion", progress) == 150,
		"All points should be refunded after reset"
	)

	# Re-buy weapons_1 and tandem_rockets (after adding supply_line victory for more points)
	_check(progress.record_supply_victory(path), "Failed to record supply line victory")
	_check(
		state.total_points_earned("bastion", progress) == 250,
		"2 completed operations + 1 commendation should equal 250 pts"
	)
	_check(
		state.purchase_upgrade("bastion", "weapons_1", hub_path, progress),
		"Re-buying weapons_1 should succeed"
	)
	_check(
		state.purchase_upgrade("bastion", "tandem_rockets", hub_path, progress),
		"Buying tandem_rockets for 150 pts should succeed"
	)
	_check(
		state.points_available("bastion", progress) == 0,
		"All 250 points should now be spent"
	)

	# 6. Test Upgrade Application in Match
	await _make_match()
	var human = game._get_human_player()
	# Apply upgrades from hub
	state.apply_to_campaign(game)
	_check(
		"weapons_1" in human.technology.completed,
		"weapons_1 upgrade should be applied to match player"
	)
	_check(
		"tandem_rockets" in human.technology.completed,
		"tandem_rockets upgrade should be applied to match player"
	)
	_check(
		is_equal_approx(human.technology.damage_factor("Infantry"), 1.1),
		"Infantry damage factor should be +10% (1.1) with weapons_1"
	)

	# 7. Test Victory Debrief and Auto-Prompt Button
	game.finished = true
	game.result = "Victory"
	game.hud.show_result("Victory")
	await _frames(5)

	var next_btn = game.hud._overlay.find_child("NextOperationButton", true, false)
	_check(
		next_btn != null and next_btn.is_visible_in_tree(),
		"Victory overlay must include NextOperationButton"
	)
	_check(
		next_btn.text.contains("Supply Line"),
		"NextOperationButton text should contain next operation name (Supply Line)"
	)

	var debrief = game.hud._overlay.find_child("StoryDebrief", true, false)
	_check(
		debrief != null and debrief.text.contains("Upgrade Points"),
		"Debrief should include Campaign Upgrade Points earned"
	)

	game.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(hub_path)

	for message in errors:
		push_error(message)
	print("Campaign progression and upgrades: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)

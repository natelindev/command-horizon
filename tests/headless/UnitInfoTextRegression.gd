extends "res://tests/headless/SaveRestoreEdges.gd"

var info_labels = {}
var walker
var artillery
var rocket
var soldier
var shelter
var site
var diagnostics
var commander
var review_center = Vector3.ZERO


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "language": "en"})
	await _info_fixture()
	_check(not diagnostics.visible, "Diagnostic mode must start off in every build")
	_check(not diagnostics.is_physics_processing(), "Hidden diagnostics still formats statistics")
	_check(info_labels.has("garrison"), "The fixture has no neutral-building status label")
	_assert_hidden()
	var initial_text = _texts()
	_update_hidden_state()
	_check(_texts() == initial_text, "Hidden unit status still formats text")
	_assert_hidden()
	_check(
		site._label.visible and not site._label.text.is_empty(), "Objective/site text was hidden"
	)
	_check(walker.get_node("VeteranBadge").visible, "Veterancy badge was hidden with text")
	_check(walker.get_node("HealthBar").visible, "Selected health bar was hidden with text")
	var modes = game.find_child("UnitMenus", true, false)._weapon_modes
	_check(modes != null and modes.is_visible_in_tree(), "Weapon-mode HUD was removed")
	game.hud.select_units([rocket])
	rocket.get_node("WeaponPreparationVisual").refresh()
	_assert_hidden()
	await _toggle_info()
	_check(diagnostics.visible, "F1 did not enable diagnostics while paused")
	for kind in info_labels:
		_check(info_labels[kind].visible, "Diagnostic caption is missing: " + kind)
	_check(walker._mode_badge.text == "Anti-air", "F1 showed a stale weapon mode")
	_check(info_labels.charge.text == "CHARGE 65%", "F1 showed stale preparation progress")
	_check(info_labels.lock.text == "LOCK 70%", "F1 showed stale lock progress")
	_check(info_labels.deploy.text == "DEPLOY 0.5", "F1 showed stale deployment progress")
	_check(info_labels.signature.text == "PRECISION READY", "F1 showed stale signature state")
	_check(info_labels.action.text == "Moving", "F1 showed a stale action")
	if shelter != null:
		_check("1 /" in info_labels.garrison.text, "F1 showed stale garrison occupancy")
	var spawned = _info_unit("CombatRobot", review_center + Vector3(8, 0, 4))
	await _frames(3)
	_check(spawned._mode_badge.visible, "A unit spawned in diagnostic mode lost its caption")
	walker.hide()
	_check(not walker._mode_badge.is_visible_in_tree(), "Diagnostic text bypassed unit visibility")
	walker.show()
	await _toggle_info()
	_assert_hidden()
	_check(not spawned._mode_badge.visible, "F1 left a newly spawned unit caption visible")
	var previous_text = _texts()
	_check(
		walker.request_weapon_mode("precision"), "Could not switch back while captions are hidden"
	)
	walker._physics_process(2.0)
	walker.signature.kind = ""
	walker.signature.precision_ready = false
	walker.signature.refresh()
	walker.weapon_charge_progress = -1
	walker.get_node("WeaponPreparationVisual").refresh()
	rocket.weapon_charge_progress = -1
	rocket.get_node("WeaponPreparationVisual").refresh()
	artillery.deployment_left = 0
	game.hud.select_units([])
	artillery.get_node("WeaponPreparationVisual").refresh()
	walker.issue_manual_order(null)
	if shelter != null:
		shelter.leave(soldier)
	_check(_texts() == previous_text, "Inactive diagnostic captions still update while hidden")
	await _toggle_info()
	_check(walker._mode_badge.text == "Precision", "Mode change while hidden was lost")
	for kind in ["signature", "charge", "deploy", "lock"]:
		_check(not info_labels[kind].visible, "Inactive status reappeared on F1: " + kind)
	_check(
		info_labels.action.text == ("" if walker.action == null else str(walker.action)),
		"F1 showed a stale action after the current order changed"
	)
	_check(site._label.visible, "F1 changed an objective/location label")
	await _toggle_info()
	_assert_hidden()
	commander.free()
	paused = false
	game.queue_free()
	await _frames(5)
	await _skirmish("helix")
	_check(not game.get_node("Debug/DiagnosticHUD").visible, "Diagnostics leaked into a new match")
	game.queue_free()
	await _frames(5)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Unit info text regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _info_fixture(map_path = "res://source/match/maps/battlefields/EmberworksMap.tscn"):
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("helix", map_path)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var sites = game.map.points_of_interest
	var camps = sites.filter(func(value): return value.kind == "mercenary")
	site = camps[0] if not camps.is_empty() else sites[0]
	review_center = site.global_position + Vector3(-4, 0, 7)
	walker = _info_unit("CombatRobot", review_center)
	var bastion = get_nodes_in_group("players").filter(func(side): return side.faction == "bastion")[0]
	artillery = _info_unit("AdvancedTank", review_center + Vector3(4, 0, 0), bastion)
	_check(
		artillery.scene_file_path == "res://source/match/units/faction/SiegeColossus.tscn",
		"Deployment diagnostics did not exercise the actual Bastion siege roster"
	)
	rocket = _info_unit("RocketInfantry", review_center + Vector3(-3, 0, 2))
	soldier = _info_unit("Infantry", review_center + Vector3(-5, 0, 2))
	await _frames(10)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	paused = true
	diagnostics = game.get_node("Debug/DiagnosticHUD")
	var caption = load("res://source/match/units/traits/debug/ActionCaption.tscn").instantiate()
	walker.add_child(caption)
	commander = load("res://source/match/campaign/CampaignOpposition.gd").new()
	commander.boss = walker
	commander._label_boss()
	info_labels = {
		"mode": walker._mode_badge,
		"signature": walker.signature._badge,
		"charge": walker.get_node("WeaponPreparationVisual")._label,
		"deploy": artillery.get_node("WeaponPreparationVisual")._label,
		"lock": rocket.get_node("WeaponPreparationVisual")._label,
		"action": caption,
		"commander": commander._boss_label,
	}
	var buildings = game.get_node("NeutralWorld").buildings
	if not buildings.is_empty():
		shelter = buildings[0]
		info_labels.garrison = shelter._label
	walker.experience = 300
	walker.hp = walker.hp_max * .6
	game.hud.select_units([walker])
	await _frames(3)


func _update_hidden_state():
	_check(walker.request_weapon_mode("interception"), "Hidden mode change was rejected")
	walker._physics_process(2.0)
	walker.signature.activate(1, walker.global_position)
	walker.weapon_charge_progress = .65
	walker.get_node("WeaponPreparationVisual").refresh()
	artillery.deployment_left = .5
	artillery.get_node("WeaponPreparationVisual").refresh()
	rocket.weapon_charge_progress = .7
	rocket.get_node("WeaponPreparationVisual").refresh()
	walker.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(review_center + Vector3(4, 0, 4))
	)
	if shelter != null:
		_check(shelter.enter(soldier), "Could not change hidden garrison occupancy")


func _info_unit(role, point, owner = null):
	if owner == null:
		owner = game._get_human_player()
	var path = load("res://source/match/FactionCatalog.gd").scene_path(owner.faction, role)
	var unit = load(path).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), owner, true)
	return unit


func _toggle_info():
	for pressed in [true, false]:
		var key = InputEventKey.new()
		key.keycode = KEY_F1
		key.physical_keycode = KEY_F1
		key.pressed = pressed
		root.push_input(key, false)
		await _frames(2)


func _texts():
	var result = {}
	for kind in info_labels:
		result[kind] = info_labels[kind].text
	return result


func _assert_hidden():
	for kind in info_labels:
		_check(not info_labels[kind].visible, "Ordinary play shows floating unit text: " + kind)

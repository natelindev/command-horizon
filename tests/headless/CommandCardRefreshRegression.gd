extends "res://tests/headless/MechanicsRegression.gd"


## Repeated HUD refresh must retain focus without caching executable state.
func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _open("bastion")
	var infantry = _spawn("Infantry", _human, Vector3(30, 0, 30))
	var first = _spawn("AssaultInfantry", _human, Vector3(32, 0, 30))
	var second = _spawn("AssaultInfantry", _human, Vector3(34, 0, 30))
	var tank = _spawn("Tank", _human, Vector3(36, 0, 30))
	var drone = _spawn("Drone", _human, Vector3(38, 0, 30))
	var worker = _spawn("Worker", _human, Vector3(40, 0, 30))
	await _frames(4)
	if "--native-unit-state" in OS.get_cmdline_user_args():
		_check(
			[infantry, first, second, tank, drone, worker].all(
				func(unit): return unit._native_state != null
			),
			"Command card native fixture did not bind actual unit state"
		)
	var card = load("res://source/match/hud/CommandCard.gd").new()
	root.add_child(card)
	var direct = _game.hud.direct_orders
	_check_order_presence(direct, [worker, tank, drone])
	_game.hud.select_units([first])
	card.update_layout([first], direct)
	var focused = card._slots[0][1]
	var exits = [0]
	focused.focus_exited.connect(func(): exits[0] += 1)
	focused.grab_focus()
	for index in 20:
		card.update_layout([first], direct)
	_check(
		root.gui_get_focus_owner() == focused and exits[0] == 0,
		"Unchanged command refresh discarded keyboard focus"
	)
	_check(focused.pressed.get_connections().size() == 1, "Refresh duplicated action handlers")

	# Another selection can have the same layout while owning different state.
	_game.hud.select_units([second])
	card.update_layout([second], direct)
	card._slots[2][1].pressed.emit()
	_check(
		(
			second.abilities.is_active("combat_sprint")
			and not first.abilities.is_active("combat_sprint")
		),
		"Cached command layout activated the previous selection"
	)
	second.abilities._physics_process(10.8)
	card._process(.11)
	_check(
		card._slots[2][1].disabled and card._slots[2][1].get_node("AbilityCooldown").text == "4.2s",
		"Live cooldown did not refresh within 100 ms"
	)
	second.abilities._physics_process(4.2)
	card._process(.11)
	_check(not card._slots[2][1].disabled, "Completed cooldown remained cached")
	second.remove_from_group("controlled_units")
	card._slots[2][1].pressed.emit()
	_check(
		not second.abilities.is_active("combat_sprint"),
		"Ownership loss between refresh and click activated an ability"
	)
	card._process(.11)
	_check(card._slots[2][1].disabled, "Ownership loss left live ability readiness enabled")
	card.update_layout([second], direct)
	_check(not card._slots[2][1].visible, "Ownership loss retained the ability row")
	second.add_to_group("controlled_units")
	card.update_layout([second], direct)
	second.set_meta("garrison_host", tank)
	card._slots[2][1].pressed.emit()
	_check(
		not second.abilities.is_active("combat_sprint"), "Garrisoned unit executed a stale click"
	)
	card.update_layout([second], direct)
	_check(not card._slots[2][1].visible, "Garrisoned unit retained an ability slot")
	second.remove_meta("garrison_host")
	card.update_layout([second], direct)
	second.hp = 0.0
	card._slots[2][1].pressed.emit()
	_check(not second.abilities.is_active("combat_sprint"), "Dead unit executed a stale click")
	card.update_layout([second], direct)
	_check(
		card._slots.all(func(row): return row.all(func(button): return not button.visible)),
		"Dead selection retained command controls"
	)
	var later = _spawn("AssaultInfantry", _human, Vector3(34, 0, 32))
	await _frames(2)
	_game.hud.select_units([first, later])
	var first_sprint = first.abilities.get_ability("combat_sprint")
	first_sprint.cooldown_left = 5.0
	card.update_layout([first, later], direct)
	_check(not card._slots[2][1].disabled, "Later ready member was ignored")
	_check(later.abilities.trigger("combat_sprint"), "Mixed toggle fixture failed")
	card._process(.11)
	_check(
		(
			card._slots[2][1].disabled
			and card._slots[2][1].button_pressed
			and card._slots[2][1].get_node("AbilityCooldown").text == "5.0s"
		),
		"Mixed selection lost its active toggle or minimum cooldown"
	)
	first_sprint.cooldown_left = 0.0
	card._process(.11)
	_check(
		not card._slots[2][1].disabled and card._slots[2][1].button_pressed,
		"Early ready member hid a later active toggle"
	)

	_game.hud.select_units([infantry])
	card.update_layout([infantry], direct)
	var grenade = infantry.abilities.get_ability("frag_grenade")
	card._slots[2][0].grab_focus()
	grenade.key = "R"
	grenade.name = "Hold position"
	card.update_layout([infantry], direct)
	_check(
		(
			card._slots[2][3].caption == "Hold position"
			and card._slots[2][3].badge == "R"
			and card._slots[2][0].modulate.a == 0.0
		),
		"Changed ability definition did not replace its previous slot"
	)
	_check(root.gui_get_focus_owner() == card._slots[2][3], "Moved ability lost keyboard focus")
	var old_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	card.update_layout([infantry], direct)
	_check(
		(
			card._slots[0][2].tooltip_text
			== tr(
				"Hold position · Stop moving and fire at enemies in range. Cancels current and queued orders."
			)
		),
		"Locale change retained the previous command tooltip"
	)
	card.update_layout([tank], direct)
	_check(
		(
			card._slots[2][0].tooltip_text.begins_with("烟幕掩护 [Q]")
			and card._slots[2][0].tooltip_text.contains("部署半径 6 米的烟幕，持续 7 秒。")
		),
		"Smoke-screen caption or description did not localize"
	)
	TranslationServer.set_locale(old_locale)
	var old_events = InputMap.action_get_events("move_order")
	InputMap.action_erase_events("move_order")
	var key = InputEventKey.new()
	key.physical_keycode = KEY_F8
	InputMap.action_add_event("move_order", key)
	card.update_layout([infantry], direct)
	_check(card._slots[0][0].badge == "F8", "Changed binding retained the previous badge")
	InputMap.action_erase_events("move_order")
	for event in old_events:
		InputMap.action_add_event("move_order", event)

	# Weapon/mobility eligibility can change without changing the visible rows.
	_game.hud.select_units([drone])
	card.update_layout([drone], direct)
	_check(not card.order_slot("attack").disabled, "Armed drone lacked attack controls")
	_human.faction = "helix"
	_check_order_presence(direct, [worker, drone])
	_game.hud.select_units([drone])
	card.update_layout([drone], direct)
	_check(card.order_slot("attack").disabled, "Weapon eligibility remained cached")
	card.order_slot("attack").pressed.emit()
	_check(direct.kind.is_empty(), "Unarmed unit executed a stale attack click")
	_human.faction = "bastion"
	var movement = drone.get_node("Movement")
	var speed = movement.speed
	movement.speed = 0.0
	_check_order_presence(direct, [drone])
	card.update_layout([drone], direct)
	_check(card.order_slot("move").disabled, "Immobilized unit retained move eligibility")
	movement.speed = speed
	_check_order_presence(direct, [drone])
	card.update_layout([drone], direct)
	_check(not card.order_slot("move").disabled, "Recovered mobility remained cached")
	_game.hud.select_units([worker])
	var materials = _human.resource_a
	_human.resource_a = 0
	card.update_layout([worker], direct)
	_check(card._slots[2][0].disabled, "Unfunded deployment remained ready")
	_human.resource_a = materials
	card.update_layout([worker], direct)
	_check(not card._slots[2][0].disabled, "Restored deployment resources remained cached")
	card.abilities_only = true
	card.update_layout([infantry], direct)
	_check(
		not card._slots[0][0].visible and card._slots[2][3].visible,
		"Abilities-only layout retained ordinary controls"
	)
	card.update_layout([], direct)
	_check(
		card._slots.all(func(row): return row.all(func(button): return not button.visible)),
		"Empty selection retained cached controls"
	)
	# Local execution uses the same live recipient rules as network dispatch.
	var headquarters = _human.structure_candidates("CommandCenter")[0]
	var removed = _spawn("Infantry", _human, Vector3(34, 0, 34))
	await _frames(2)
	card.abilities_only = false
	card.update_layout([first, tank, removed, headquarters])
	_check(card._manual_order_units().size() == 3, "Structure entered the manual-order recipients")
	first.set_meta("garrison_host", tank)
	_check(
		card._manual_order_units() == [tank, removed],
		"Garrisoned unit remained an executable ordinary-command recipient"
	)
	first.remove_meta("garrison_host")
	removed.queue_free()
	await _frames(2)
	first.remove_from_group("controlled_units")
	_check_order_presence(direct, [first, tank, headquarters])
	first.stance = first.Stance.AGGRESSIVE
	tank.stance = tank.Stance.AGGRESSIVE
	card._on_stop()
	card._on_hold()
	_check(
		(
			card._manual_order_units() == [tank]
			and tank.stance == tank.Stance.HOLD_POSITION
			and first.stance == first.Stance.AGGRESSIVE
		),
		"Local command included a removed, captured or non-executing unit"
	)
	first.add_to_group("controlled_units")
	card.queue_free()
	await _clear()
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Command card live refresh: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _check_order_presence(direct, units):
	_game.hud.select_units(units)
	var state = direct.eligibility_state()
	for command in direct.COMMANDS:
		_check(
			direct.has_eligible(command, state) == (not direct.eligible(command).is_empty()),
			"HUD presence differs from live recipients for " + command
		)
	_check(not state.has("mobile"), "Button presence unnecessarily materialized the whole army")

# gdlint: disable=duplicated-load
extends "res://tests/headless/CombatRegression.gd"


class Foundation:
	extends Node3D
	var hp = 100.0
	var constructed = false

	func is_constructed():
		return constructed


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if index == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(p): return p != _human)[0]
	_enemy.set_process(false)
	await _frames(60)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)
	await _test_definitions_and_readiness()
	await _clear()
	await _test_grenade()
	await _clear()
	await _test_timed_effects()
	await _clear()
	await _test_siege()
	await _clear()
	await _test_salvo()
	await _clear()
	await _test_smoke_damage()
	await _clear()
	await _test_command_card()
	await _clear()
	await _test_ability_orders()
	await _clear()
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Unit abilities: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _test_smoke_damage():
	var tank = _spawn("Tank", _human, Vector3(40, 0, 8))
	var ally = _spawn("Tank", _human, Vector3(46, 0, 8))
	var shooter = _spawn("Infantry", _enemy, Vector3(44, 0, 8))
	var enemy = _spawn("Tank", _enemy, Vector3(42, 0, 8))
	await _frames(5)
	var rules = load("res://source/match/combat/CombatRules.gd")
	var shot = load("res://source/match/combat/Shot.gd").from(shooter, shooter.global_position)
	var base = rules.damage(shooter, ally)
	_check(tank.abilities.trigger("smoke_screen"), "Smoke damage fixture did not activate")
	_check(
		is_equal_approx(rules.damage(shooter, ally), base * .5),
		"Smoke edge did not halve ranged damage"
	)
	_check(is_equal_approx(rules.damage_from(shot, ally), base * .5), "Frozen shot bypassed smoke")
	shot.raw_damage = true
	_check(
		rules.damage_from(shot, ally) == shot.attack_damage * .5, "Ability rocket bypassed smoke"
	)
	_check(rules.smoke_damage_factor(enemy) == 1.0, "Enemy benefited from friendly smoke")
	_check(rules.smoke_damage_factor(tank) == .5, "Deploying tank is not protected")
	ally.global_position.x += .01
	_check(rules.damage(shooter, ally) == base, "Smoke protected beyond six metres")
	ally.global_position.x -= .01
	tank.global_position += Vector3(12, 0, 0)
	_check(rules.damage(shooter, ally) == base * .5, "Smoke followed moving tank")
	var second = _spawn("Tank", _human, Vector3(44, 0, 8))
	await _frames(3)
	second.abilities.trigger("smoke_screen")
	_check(rules.damage(shooter, ally) == base * .5, "Overlapping smoke stacked reduction")
	second.hp = 0
	_check(rules.damage(shooter, ally) == base * .5, "Dead second emitter removed first smoke")
	tank.abilities._physics_process(7.0)
	_check(rules.damage(shooter, ally) == base, "Expired or dead smoke still protected target")
	var smoke = tank.abilities.get_ability("smoke_screen")
	tank.abilities.restore(
		{"smoke_screen": {"active_left": 2.0, "effect_position": ally.global_position}}
	)
	_check(rules.damage(shooter, ally) == base * .5, "Restored smoke not registered")
	_check(smoke.active_left == 2.0, "Smoke restore changed timer")


func _select_ability_units(units):
	if units.is_empty():
		root.get_node("MatchSignals").deselect_all_units.emit()
	else:
		_game.hud.select_units(units)
	await _frames(3)


func _ability_key(code, down = true):
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	return event


func _test_command_card():
	var infantry = _spawn("Infantry", _human, Vector3(40, 0, 8))
	var assault = _spawn("AssaultInfantry", _human, Vector3(40, 0, 10))
	var tank = _spawn("AdvancedTank", _human, Vector3(40, 0, 12))
	var enemy = _spawn("Infantry", _enemy, Vector3(44, 0, 8))
	await _select_ability_units([infantry, assault, tank])
	var card = load("res://source/match/hud/CommandCard.gd").new()
	root.add_child(card)
	card.update_layout([infantry, assault, tank, enemy], _game.hud.direct_orders)
	for column in 3:
		var slot = card._slots[2][column]
		_check(slot.visible and not slot.disabled, "Missing ready ability column %d" % column)
		_check(slot.badge == ["Q", "W", "E"][column], "Incorrect QWER column badge")
		var ability = [infantry, assault, tank][column].abilities.abilities[0]
		var description = (
			tr("%s [%s]\n%s\nRange: %.1f m · Radius: %.1f m · Cooldown: %.1f s")
			% [
				tr(ability.name),
				ability.key,
				tr(ability.description),
				ability.range,
				ability.radius,
				ability.cooldown
			]
		)
		if ability.id == "frag_grenade":
			description = (
				tr("%s [%s]\n%s\nRange: %.1f m · Cooldown: %.1f s")
				% [
					tr(ability.name),
					ability.key,
					tr(ability.description),
					ability.range,
					ability.cooldown
				]
			)
			_check(
				not slot.tooltip_text.contains("Radius:"),
				"Garrison frag advertises exterior radius"
			)
		_check(slot.tooltip_text.contains(description), "Incomplete ability tooltip")
	_check(
		card._slots[2][3].disabled and card._slots[2][3].badge.is_empty(),
		"Unused ability slot is populated"
	)
	_check(
		card._slots[0][0].caption == "Move" and card._slots[1][0].caption == "Atk Move",
		"Abilities replaced existing orders"
	)
	card._slots[2][1].pressed.emit()
	_check(assault.abilities.is_active("combat_sprint"), "Instant command-card activation failed")
	assault.abilities._physics_process(10.8)
	card._process(.2)
	var sprint_slot = card._slots[2][1]
	_check(
		sprint_slot.disabled and sprint_slot.get_node("AbilityCooldown").text == "4.2s",
		"Cooldown overlay did not update"
	)
	assault.abilities._physics_process(4.2)
	card._process(.2)
	_check(
		not sprint_slot.disabled and not sprint_slot.get_node("AbilityCooldown").visible,
		"Cooldown overlay did not clear"
	)
	card._slots[2][2].pressed.emit()
	_check(
		card._slots[2][2].button_pressed and tank.abilities.is_active("siege_anchor"),
		"Active toggle did not highlight"
	)
	card._slots[2][0].pressed.emit()
	_check(
		_game.hud.direct_orders.ability_id == "frag_grenade",
		"Targeted command-card activation did not arm"
	)
	_game.hud.direct_orders.cancel()
	card.update_layout([enemy], _game.hud.direct_orders)
	_check(not card._slots[2][0].visible, "Enemy selection exposed ability controls")
	infantry.set_meta("garrison_host", tank)
	card.update_layout([infantry], _game.hud.direct_orders)
	_check(not card._slots[2][0].visible, "Unavailable garrison ability occupied a hotkey slot")
	infantry.remove_meta("garrison_host")
	card.queue_free()
	await _frames(2)


func _test_ability_orders():
	var first = _spawn("Infantry", _human, Vector3(40, 0, 8))
	var second = _spawn("Infantry", _human, Vector3(40, 0, 10))
	var enemy = _spawn("Tank", _enemy, Vector3(46, 0, 8))
	var fixture = load("res://tests/headless/GrenadeFixture.gd")
	var building = fixture.building(_game, Vector3(46, 0, 11))
	var occupant = _spawn("Infantry", _enemy, Vector3(46, 0, 11))
	_check(fixture.occupy(building, occupant), "Order fixture garrison rejected")
	await _select_ability_units([first, second])
	var commands = _game.hud.direct_orders
	_check(commands.handle_input(_ability_key(KEY_Q)), "Q hotkey was not handled")
	_check(
		commands.kind == "ability" and commands.ability_id == "frag_grenade",
		"Q did not arm grenade"
	)
	_check(
		(
			is_instance_valid(commands._ability_range)
			and commands._ability_range.mesh.outer_radius > 10
		),
		"Ability range ring missing"
	)
	_check(
		_game.hud.command_feedback._glyph_kind(commands.kind) == "attack",
		"Ability targeting cursor was not mapped"
	)
	_check(not commands.commit(Vector3(55, 0, 8), null, false), "Out-of-range ability committed")
	_check(
		commands.kind == "ability" and first.abilities.get_ability("frag_grenade").is_ready(),
		"Rejected target consumed ability or targeting"
	)
	var enemy_hp_before_grenade = enemy.hp
	var occupant_hp = occupant.hp
	_check(not commands.commit(enemy.global_position, null, false), "Grenade accepted ground point")
	_check(not commands.commit(enemy.global_position, enemy, false), "Grenade accepted tank")
	_check(
		commands.kind == "ability" and first.abilities.get_ability("frag_grenade").is_ready(),
		"Rejected non-garrison target consumed ability or targeting"
	)
	_check(commands.commit(building.global_position, building, false), "Garrison target rejected")
	commands.arm_ability("frag_grenade")
	_check(
		commands.commit(building.global_position, building, true),
		"Next ready caster was not selected"
	)
	_check(_game.grenade_system.pending.size() == 2, "Next ready caster did not throw")
	_game.grenade_system._physics_process(0.6)
	_check(enemy.hp == enemy_hp_before_grenade, "Garrison grenade damaged exterior tank")
	_check(occupant.hp == occupant_hp - 15, "Follow-up grenade hit evacuated occupant")
	first.abilities.restore({})
	commands.arm_ability("frag_grenade")
	var right = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	_check(
		commands.handle_input(right) and commands.kind.is_empty(),
		"Right-click did not cancel ability"
	)
	right.pressed = false
	commands.handle_input(right)
	commands.arm_ability("frag_grenade")
	_game.hud._unhandled_input(_ability_key(KEY_ESCAPE))
	_check(
		commands.kind.is_empty() and _game.hud._overlay == null,
		"Escape opened menu instead of cancelling"
	)
	commands.arm_ability("frag_grenade")
	paused = true
	_check(
		not commands.commit(Vector3(45, 0, 13), null, false), "Paused targeting executed an ability"
	)
	_check(
		first.abilities.get_ability("frag_grenade").is_ready(), "Paused targeting consumed cooldown"
	)
	paused = false
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = _game.get_node("IsometricCamera3D").unproject_position(Vector3(45, 0, 13))
	click.pressed = true
	_check(commands.handle_input(click), "Ability map click was not handled")
	_check(
		commands.kind == "ability" and first.abilities.get_ability("frag_grenade").is_ready(),
		"Map click executed a garrison-only ability"
	)
	click.pressed = false
	commands.handle_input(click)
	commands.cancel()
	first.abilities.restore({})
	commands.arm_ability("frag_grenade")
	await _select_ability_units([second])
	_check(commands.kind.is_empty(), "Selection change retained armed ability")
	first.queue_free()
	second.queue_free()
	await _frames(2)
	var r1 = _spawn("RocketInfantry", _human, Vector3(40, 0, 8))
	var r2 = _spawn("RocketInfantry", _human, Vector3(40, 0, 10))
	await _select_ability_units([r1, r2])
	commands.arm_ability("guided_salvo")
	enemy.hp_max = 250.0
	enemy.hp = 250.0
	var before = enemy.hp
	_check(commands.commit(enemy.global_position, enemy, false), "Salvo target rejected")
	_check(commands.kind.is_empty(), "Accepted salvo retained targeting")
	await _frames(25)
	_check(enemy.hp < before, "Target cast damage")
	_check(
		r2.abilities.get_ability("guided_salvo").is_ready(),
		"Targeted cast consumed all selected cooldowns"
	)
	commands.arm_ability("guided_salvo")
	_check(
		commands.commit(enemy.global_position, enemy, true), "Next ready caster was not selected"
	)
	r1.queue_free()
	r2.queue_free()
	await _frames(2)
	var assault = _spawn("AssaultInfantry", _human, Vector3(40, 0, 14))
	var other_assault = _spawn("AssaultInfantry", _human, Vector3(42, 0, 14))
	await _select_ability_units([assault, other_assault])
	_game.hud._unhandled_input(_ability_key(KEY_W))
	_check(
		(
			(
				int(assault.abilities.is_active("combat_sprint"))
				+ int(other_assault.abilities.is_active("combat_sprint"))
			)
			== 1
		),
		"HUD W did not smart-cast exactly one instant ability"
	)
	_game.hud._unhandled_input(_ability_key(KEY_W))
	_check(
		(
			assault.abilities.is_active("combat_sprint")
			and other_assault.abilities.is_active("combat_sprint")
		),
		"Repeated W did not select the remaining ready caster"
	)
	assault.abilities.restore({})
	_game.hud._open_menu()
	_check(
		(
			not commands.handle_input(_ability_key(KEY_W))
			and not assault.abilities.is_active("combat_sprint")
		),
		"Modal leaked ability hotkey"
	)
	_game.hud._close_menu()
	var tank = _spawn("Tank", _human, Vector3(40, 0, 18))
	await _select_ability_units([tank])
	var chord = _ability_key(KEY_Q)
	chord.ctrl_pressed = true
	_check(not commands.handle_input(chord), "Ability intercepted a modified shortcut")
	var placement = _human.get_node("StructurePlacementHandler")
	root.get_node("MatchSignals").place_structure.emit(
		load("res://source/match/units/PowerPlant.tscn")
	)
	_check(
		not commands.handle_input(_ability_key(KEY_Q)),
		"Ability hotkey interrupted building placement"
	)
	placement._cancel_structure_placement()
	_check(
		_game.hud.ability_owns_camera_binding("rotate_map_clockwise"),
		"Selected Q ability did not suppress camera binding"
	)
	root.push_input(_ability_key(KEY_Q), true)
	await _frames(2)
	root.push_input(_ability_key(KEY_Q, false), true)
	_check(tank.abilities.is_active("smoke_screen"), "Viewport Q dispatch did not deploy smoke")
	var rocket = _spawn("RocketInfantry", _human, Vector3(40, 0, 8))
	await _select_ability_units([rocket])
	_check(commands.arm_ability("guided_salvo"), "Unit targeting did not arm")
	_check(
		not commands.commit(tank.global_position, tank, false),
		"Targeted ability accepted allied unit"
	)
	enemy.global_position = Vector3(60, 0, 60)
	_check(not commands.commit(null, enemy, false), "Targeted ability accepted hidden enemy")
	enemy.global_position = Vector3(46, 0, 8)
	_check(commands.commit(null, enemy, false), "Legal enemy target rejected")
	rocket.abilities.restore({})
	commands.arm_ability("guided_salvo")
	_check(commands.commit(Vector3(46, 0, 8), null, false), "Salvo ground-point fallback rejected")
	building.get_parent().queue_free()
	await _select_ability_units([])
	_check(
		not commands.handle_input(_ability_key(KEY_Q)), "Q consumed without an ability selection"
	)


func _test_definitions_and_readiness():
	var expected = {
		"Infantry": ["frag_grenade", "Q", "target_unit", 12.0],
		"AssaultInfantry": ["combat_sprint", "W", "instant", 15.0],
		"Tank": ["smoke_screen", "Q", "instant", 20.0],
		"AdvancedTank": ["siege_anchor", "E", "toggle", 4.0],
		"RocketInfantry": ["guided_salvo", "Q", "target_unit", 14.0],
	}
	for role in expected:
		var unit = _spawn(role, _human, Vector3(40, 0, 8))
		_check(unit.abilities != null, role + " missing ability trait")
		var ability = unit.abilities.get_ability(expected[role][0])
		_check(unit.abilities.abilities.size() == 1, role + " inherited an unrelated ability")
		_check(ability.key == expected[role][1], role + " hotkey")
		_check(ability.target_type == expected[role][2], role + " target type")
		_check(ability.cooldown == expected[role][3] and ability.is_ready(), role + " readiness")
		_check(not unit.abilities.trigger("missing"), "Unknown ability activated")
	for role in ["SniperInfantry", "CombatRobot", "Barracks", "Helicopter"]:
		_check(
			_spawn(role, _human, Vector3(45, 0, 8)).abilities == null,
			role + " got an inherited ability"
		)
	var foundation = Foundation.new()
	root.add_child(foundation)
	var manager = load("res://source/match/units/traits/UnitAbilities.gd").new()
	foundation.add_child(manager)
	manager.setup(_test_units[1].ability_definitions())
	var sprint = manager.get_ability("combat_sprint")
	_check(not sprint.is_ready() and not sprint.trigger(), "Unconstructed unit used an ability")
	foundation.constructed = true
	_check(sprint.is_ready(), "Constructed unit remained unavailable")
	foundation.hp = 0.0
	_check(not sprint.is_ready() and not sprint.trigger(), "Dead unit used an ability")
	foundation.queue_free()
	await _frames(2)
	_check(not sprint.is_ready(), "Retained ability refers to destroyed manager")


func _test_grenade():
	var infantry = _spawn("Infantry", _human, Vector3(40, 0, 8))
	var ally = _spawn("Tank", _human, Vector3(46, 0, 8))
	var near = _spawn("Tank", _enemy, Vector3(46, 0, 8))
	var edge = _spawn("Tank", _enemy, Vector3(49.4, 0, 8))
	var far = _spawn("Tank", _enemy, Vector3(50, 0, 8))
	var fixture = load("res://tests/headless/GrenadeFixture.gd")
	var building = fixture.building(_game, Vector3(46, 0, 10))
	var occupant = _spawn("Infantry", _enemy, Vector3(46, 0, 10))
	await _frames(5)
	var grenade = infantry.abilities.get_ability("frag_grenade")
	_check(not grenade.trigger(), "Grenade accepted a missing point")
	_check(not grenade.trigger(Vector3.INF), "Grenade accepted a nonfinite point")
	_check(not grenade.trigger(Vector3(51, 0, 8)), "Grenade exceeded 10 m range")
	_check(
		not grenade.trigger(building.global_position, building), "Grenade accepted empty building"
	)
	_check(not grenade.trigger(near.global_position, near), "Grenade accepted armor")
	_check(grenade.cooldown_left == 0, "Rejected cast consumed cooldown")
	_check(fixture.occupy(building, occupant), "Grenade fixture garrison rejected")
	var occupant_hp = occupant.hp
	var before = [ally.hp, near.hp, edge.hp, far.hp]
	_check(grenade.trigger(building.global_position, building), "Grenade did not trigger")
	_check(near.hp == before[1], "Grenade damaged enemies before arrival")
	_game.grenade_system._physics_process(0.59)
	_check(near.hp == before[1], "Grenade damaged enemies before fuse expired")
	_game.grenade_system._physics_process(0.01)
	_check(ally.hp == before[0] and far.hp == before[3], "Grenade hit ally or outside radius")
	_check(before[1] == near.hp and before[2] == edge.hp, "Grenade hit exterior armor")
	_check(occupant_hp - occupant.hp == 15, "Grenade garrison damage")
	_check(
		occupant.last_enemy_damage_time == _game.simulation_time,
		"Grenade bypassed damage bookkeeping"
	)
	grenade.cooldown_left = 12.0
	_check(not grenade.is_ready(), "Grenade bypassed cooldown")
	infantry.abilities._physics_process(12.5)
	_check(grenade.cooldown_left == 0 and grenade.is_ready(), "Grenade cooldown failed to clamp")
	building.get_parent().queue_free()


func _test_timed_effects():
	var assault = _spawn("AssaultInfantry", _human, Vector3(40, 0, 8))
	var manager = assault.abilities
	var sprint = manager.get_ability("combat_sprint")
	var base = assault.movement_speed
	_check(sprint.trigger(), "Sprint did not activate")
	_check(is_equal_approx(assault.movement_speed, base * 1.5), "Sprint speed factor")
	var state = manager.capture()
	manager._physics_process(4.1)
	_check(not sprint.is_active and assault.movement_speed == base, "Sprint failed to expire")
	manager.restore(state)
	_check(
		sprint.is_active and sprint.active_left == 4 and sprint.cooldown_left == 15,
		"Sprint state restore"
	)
	manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	paused = true
	var remaining = sprint.cooldown_left
	await _frames(6)
	_check(sprint.cooldown_left == remaining, "Ability timers advanced while paused")
	paused = false
	await _frames(6)
	_check(sprint.cooldown_left < remaining, "Physics did not advance ability timers")
	manager.process_mode = Node.PROCESS_MODE_INHERIT
	manager.restore({})
	_check(sprint.is_ready() and not sprint.is_active, "Empty state did not reset abilities")
	var tank = _spawn("Tank", _human, Vector3(40, 0, 14))
	var smoke = tank.abilities.get_ability("smoke_screen")
	paused = true
	_check(not smoke.trigger(), "Ability activated during pause")
	paused = false
	_check(smoke.trigger(), "Smoke did not deploy")
	var point = smoke.effect_position
	tank.global_position += Vector3(8, 0, 0)
	_check(
		smoke.radius == 6 and smoke.active_left == 7 and smoke.effect_position == point,
		"Smoke area moved with tank"
	)
	tank.abilities._physics_process(7.0)
	_check(not smoke.is_active and smoke.cooldown_left == 13, "Smoke duration or cooldown")


func _test_siege():
	var tank = _spawn("AdvancedTank", _human, Vector3(40, 0, 8))
	var target = _spawn("Tank", _enemy, Vector3(44, 0, 8))
	await _frames(5)
	var movement = tank.get_node("Movement")
	var anchor = tank.abilities.get_ability("siege_anchor")
	var rules = load("res://source/match/combat/CombatRules.gd")
	var base_range = rules.range_for(tank, target)
	var base_damage = rules.damage(tank, target)
	var speed = tank.movement_speed
	movement.move(Vector3(48, 0, 8))
	_check(anchor.trigger(), "Anchor did not activate")
	_check(
		not movement._has_destination and tank.movement_speed == 0, "Anchor did not stop movement"
	)
	movement.move(Vector3(48, 0, 8))
	var point = tank.global_position
	movement._physics_process(0.1)
	movement._on_velocity_computed(Vector3(10, 0, 0))
	_check(
		not movement._has_destination and tank.global_position == point,
		"Movement order or avoidance moved anchored tank"
	)
	_check(is_equal_approx(rules.range_for(tank, target), base_range * 1.35), "Anchor range bonus")
	_check(is_equal_approx(rules.damage(tank, target), base_damage * 1.3), "Anchor damage bonus")
	var shot = load("res://source/match/combat/Shot.gd").from(tank, point)
	var frozen = rules.damage_from(shot, target)
	_check(not anchor.trigger(), "Toggle bypassed 4 s cooldown")
	tank.abilities._physics_process(4.0)
	_check(anchor.is_active and anchor.trigger(), "Toggle failed to stay active or deactivate")
	_check(
		tank.movement_speed == speed and rules.range_for(tank, target) == base_range,
		"Anchor left modified stats behind"
	)
	_check(
		is_equal_approx(rules.damage_from(shot, target), frozen),
		"In-flight damage changed after unanchoring"
	)
	movement.move(Vector3(48, 0, 8))
	_check(movement._has_destination, "Unanchored tank cannot move")


func _test_salvo():
	var shooter = _spawn("RocketInfantry", _human, Vector3(40, 0, 8))
	var target = _spawn("Tank", _enemy, Vector3(48, 0, 8))
	var ally = _spawn("Tank", _human, Vector3(42, 0, 8))
	await _frames(5)
	var salvo = shooter.abilities.get_ability("guided_salvo")
	_check(not salvo.trigger(), "Salvo accepted missing target")
	_check(not salvo.trigger(Vector3.INF, ally), "Salvo targeted ally")
	_check(not salvo.trigger(Vector3(55, 0, 8)), "Salvo exceeded range")
	_check(not salvo.trigger(Vector3.ZERO, _game), "Salvo accepted a non-unit node")
	var before = target.hp
	_check(salvo.trigger(Vector3.INF, target), "Salvo rejected enemy unit")
	_check(target.hp == before, "Salvo damaged target before rocket flight")
	paused = true
	var builder = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = builder.capture(_game)
	_check(snapshot != null, "Salvo snapshot capture failed: " + builder.error)
	if snapshot != null:
		var loader = load("res://source/match/saves/MatchRestore.gd").new()
		var valid = loader.prepare(snapshot)
		_check(valid, "Save schema rejected the ability rocket: " + loader.error)
	var entities = {"owner": _human, "shooter": shooter, "target": target}
	var reference = func(object):
		for id in entities:
			if entities[id] == object:
				return id
		return ""
	var system = _game.projectile_system
	var flying = system.capture(reference)
	system.restore(flying, entities)
	_check(
		system.rounds_at(target).size() == 1 and system.rounds_at(target)[0].shot.raw_damage,
		"Salvo lost fixed damage on projectile restore"
	)
	paused = false
	shooter.queue_free()
	await _frames(90)
	_check(before - target.hp == 34, "Heavy rocket damage changed or died with shooter")
	var point_shooter = _spawn("RocketInfantry", _human, Vector3(40, 0, 14))
	var point_target = _spawn("Tank", _enemy, Vector3(48, 0, 14))
	await _frames(5)
	before = point_target.hp
	_check(
		point_shooter.abilities.trigger("guided_salvo", point_target.global_position),
		"Salvo rejected point target"
	)
	await _frames(90)
	_check(before - point_target.hp == 34, "Point salvo failed to hit enemy along flight path")

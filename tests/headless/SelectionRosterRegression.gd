extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _selection_roster(faction)
	for message in errors:
		push_error(message)
	print("Selection roster: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _selection_roster(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.hud._toggle_pause()
	var player = game._get_human_player()
	var soldiers = _units(player, "Infantry")
	while soldiers.size() < 2:
		soldiers.append(_spawn_member(player, "Infantry"))
	var infantry_roster = await _choose(soldiers.slice(0, 2))
	await _inspect_layout(player, infantry_roster, "infantry")
	for entry in infantry_roster._tiles:
		var portrait = entry.button.find_child("Portrait", true, false)
		_check(
			portrait.texture.get_width() < portrait.texture.get_height() * .8,
			"Square padding shrinks the soldier portrait"
		)
		_check(portrait.size.y >= 48, "Healthy soldier portrait does not fill its card")
		_check(not entry.label.visible, "Empty health label leaves the soldier miniature")
	# These temporary portrait fixtures do not change the full-army population fixture.
	for unit in soldiers.slice(2):
		unit.queue_free()
	var members = _units(player, "Tank") + _units(player, "Worker")
	members[0].hp = members[0].hp_max / 2.0
	var roster = await _choose(members)
	_check(roster != null, faction + ": mixed selection has no type counts or individual health")
	if roster != null:
		await _exercise(player, members, roster)
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _choose(members):
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in members:
		unit.get_node("Selection").select()
	await _frames(3)
	return game.find_child("SelectionRoster", true, false)


func _exercise(player, members, roster):
	var menus = game.find_child("UnitMenus")
	var clock = game.simulation_time
	_check(roster._members.size() == members.size(), "Roster omitted selected units")
	_check(roster._types.size() == 2, "Mixed armor/worker counts are missing")
	for entry in roster._types:
		var expected = members.filter(func(unit): return unit.type == entry.members[0].type)
		_check(entry.members == expected, "Type button has wrong units")
	_check(roster._damaged.text.ends_with("1"), "Damaged total is wrong")
	for entry in roster._tiles:
		var portrait = entry.button.find_child("Portrait", true, false)
		_check(portrait != null and portrait.size.y >= 32, "Selection portrait is miniature")
		_check(
			entry.label.visible == (entry.unit.hp < entry.unit.hp_max),
			"Empty health label steals portrait space"
		)
	var identities = roster._tiles.map(func(entry): return entry.button.get_instance_id())
	var units = roster._tiles.map(func(entry): return entry.unit)
	members[0].hp = members[0].hp_max * 0.25
	menus._refresh_buttons()
	_check(
		roster._tiles.map(func(entry): return entry.button.get_instance_id()) == identities,
		"Health refresh replaced focused controls"
	)
	_check(roster._tiles.map(func(entry): return entry.unit) == units, "Damage reordered units")
	var injured = roster._tiles.filter(func(entry): return entry.unit == members[0])
	_check(not injured.is_empty() and injured[0].label.text == "25%", "Individual health is stale")
	var tanks = members.filter(func(unit): return unit.type == "Tank")
	player.coordination_unlocked = true
	tanks[0].manual_orders.submit({"kind": "move", "point": Vector3(35, 0, 35)})
	tanks[0].manual_orders.submit({"kind": "move", "point": Vector3(40, 0, 35)}, true)
	var behavior = load("res://source/match/orders/UnitBehavior.gd")
	_check(behavior.guard(tanks[1], tanks[1].global_position_yless), "Guard fixture failed")
	var factory = _units(player, "VehicleFactory")[0]
	var job = factory.production_queue.produce(load("res://source/match/units/Tank.tscn"))
	_check(job != null, "Paid queue fixture failed")
	var funds = Vector2i(player.resource_a, player.resource_b)
	var queue = tanks[0].manual_orders.pending.duplicate(true)
	var guard_orders = tanks[1].manual_orders.pending.duplicate(true)
	var actions = members.map(func(unit): return unit.action)
	var camera = game.get_node("IsometricCamera3D").transform
	await _inspect_layout(player, roster, "mixed")
	await _activate_control(
		roster._types.filter(func(entry): return entry.members[0].type == "Tank")[0].button
	)
	_check(_own_selected() == tanks, "Type button did not isolate armor")
	roster = await _choose(members)
	await _activate_control(roster._damaged)
	_check(_own_selected() == [members[0]], "Damaged selection selected healthy units")
	roster = await _choose(members)
	await _activate_control(roster._tiles[0].button, true)
	_check(_own_selected().size() == 1, "Keyboard tile did not select one unit")
	roster = await _choose(members)
	var bindings = load("res://source/input/KeyBindings.gd")
	var original = root.get_node("Globals").options.capture()
	var profile = bindings.defaults()
	profile.keys.shift_selecting = KEY_J
	bindings.apply(profile)
	roster.refresh()
	_check(
		roster._types[0].button.tooltip_text.contains("Hold J"), "Remapped removal hint is stale"
	)
	await _held_key(KEY_J, true)
	await _activate_control(
		roster._types.filter(func(entry): return entry.members[0].type == "Worker")[0].button
	)
	await _held_key(KEY_J, false)
	root.get_node("Globals").options.restore(original)
	_check(_own_selected() == tanks, "Remapped modifier failed to remove workers")
	_check(tanks[0].manual_orders.pending == queue, "Filtering changed queued movement")
	_check(
		(
			tanks[1].stance == tanks[1].Stance.HOLD_POSITION
			and tanks[1].manual_orders.pending == guard_orders
		),
		"Filtering cancelled a guard order"
	)
	_check(
		members.map(func(unit): return unit.action) == actions, "Filtering changed active orders"
	)
	_check(factory.production_queue.get_elements() == [job], "Filtering changed paid production")
	_check(Vector2i(player.resource_a, player.resource_b) == funds, "Filtering spent resources")
	_check(paused and game.simulation_time == clock, "Filtering advanced tactical pause")
	_check(game.get_node("IsometricCamera3D").transform == camera, "Filtering moved the camera")
	var enemy = get_nodes_in_group("players").filter(func(side): return side != player)[0]
	roster = await _choose(members + [_units(enemy, "Tank")[0]])
	_check(roster._members.size() == members.size(), "Enemy entered the own-unit roster")
	menus._select_subset([_units(enemy, "Tank")[0]], false)
	_check(_own_selected().size() == members.size(), "Foreign request cleared own selection")
	root.get_node("MatchSignals").deselect_all_units.emit()
	roster = await _choose(members)
	for unit in members:
		unit.hp = unit.hp_max
	roster.refresh()
	_check(roster._damaged.disabled, "Healthy army can select an empty damaged subset")
	members[0].hp = members[0].hp_max * 0.5
	await _archive_selection(members, factory)
	await _large_roster(game._get_human_player())


func _archive_selection(members, factory):
	var snapshot = Snapshot.new().capture(game)
	_check(snapshot != null, "Selection snapshot failed")
	if snapshot == null:
		return
	var archive = "user://selection-roster-%d.json" % OS.get_process_id()
	var file = FileStore.new()
	_check(file.write_file(archive, snapshot), "Selection disk archive failed")
	var total = members.size()
	var pending = factory.production_queue.size()
	var time = game.simulation_time
	var result = await Restore.new().restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(result.ok, "Selection archive restore failed")
	if not result.ok:
		return
	game = result.game
	await _frames(5)
	var roster = game.find_child("SelectionRoster", true, false)
	_check(roster != null and roster._members.size() == total, "Archive lost mixed selection")
	_check(roster != null and roster._damaged.text.ends_with("1"), "Archive lost health counts")
	_check(
		_units(game._get_human_player(), "VehicleFactory")[0].production_queue.size() == pending,
		"Selection archive lost paid jobs"
	)
	_check(paused and game.simulation_time == time, "Selection archive advanced pause")


func _large_roster(player):
	var catalog = load("res://source/match/BastionCatalog.gd")
	for role in catalog.NAMES:
		if _units(player, role).is_empty():
			_spawn_member(player, role)
	while (
		(
			get_nodes_in_group("units")
			. filter(func(unit): return unit.player == player)
			. filter(func(unit): return unit.movement_speed > 0)
			. size()
		)
		< 100
	):
		_spawn_member(player, "Infantry")
	while (
		(
			get_nodes_in_group("units")
			. filter(func(unit): return unit.player == player)
			. filter(func(unit): return unit.movement_speed == 0)
			. size()
		)
		< 40
	):
		_spawn_member(player, "PowerPlant")
	var members = (
		get_nodes_in_group("units")
		. filter(func(unit): return unit.player == player)
		. filter(func(unit): return not unit.is_queued_for_deletion())
	)
	var roster = await _choose(members)
	_check(roster._members.size() == 140, "Full own-army roster size is wrong")
	_check(roster._types.size() == catalog.NAMES.size(), "Full roster omitted a role")
	_check(roster._tiles.size() == 8, "First page is not bounded to eight units")
	await _inspect_layout(player, roster, "full")
	_check(not roster._grid.visible, "Large mixed selection should show types only")
	var infantry = roster._types.filter(func(entry): return entry.members[0].type == "Infantry")[0]
	await _activate_control(infantry.button, true)
	roster = game.find_child("SelectionRoster", true, false)
	await _inspect_layout(player, roster, "individuals")
	members = roster._members.duplicate()
	var seen = []
	while true:
		seen.append_array(roster._tiles.map(func(entry): return entry.unit))
		if roster._next.disabled:
			break
		await _activate_control(roster._next, true)
	_check(seen == roster._members, "Paging duplicated or omitted selected units")
	_check(roster._tiles.size() == (members.size() - 1) % 8 + 1, "Last page has wrong remainder")
	await _inspect_layout(player, roster, "last-page")
	var victim = roster._tiles[-1].unit
	var old_count = members.size()
	await _destroy_target(roster, victim)
	roster = game.find_child("SelectionRoster", true, false)
	_check(roster._members.size() == old_count - 1, "Dead unit remains in the roster")
	_check(_own_selected().size() == old_count - 1, "Stale request cleared live selection")
	if player.faction != "bastion":
		return
	# Return below the mobile cap before the separate mission-role UI fixture.
	for unit in _units(player, "Infantry").slice(1) + _units(player, "PowerPlant").slice(1):
		unit.queue_free()
	await _frames(5)
	var truck = _spawn_member(player, "SupplyTruck")
	var tank = _spawn_member(player, "Tank")
	roster = await _choose([truck, tank])
	_check(
		roster._types.size() == 2 and roster._tiles.size() == 2, "Mission selection is incomplete"
	)
	await _inspect_layout(player, roster, "mission")
	await _activate_control(roster._tiles[1].button, true)
	_check(_own_selected() == [truck], "Mission tile selected the wrong unit")


func _destroy_target(roster, victim):
	victim.hp = 0
	roster._request([victim])
	await _frames(5)


func _spawn_member(player, role):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), Vector3(35, 0, 30)), player, false)
	return unit


func _own_selected():
	return get_nodes_in_group("selected_units").filter(
		func(unit): return unit.is_in_group("controlled_units")
	)


func _activate_control(button, _keyboard = false):
	button.pressed.emit()
	await _frames(3)


func _held_key(code, down):
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await _frames(2)


func _inspect_layout(_player, _roster, _label):
	pass

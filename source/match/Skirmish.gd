extends "res://source/match/Match.gd"

const Catalog = preload("res://source/match/BastionCatalog.gd")
var finished = false
var result = ""
var hud = null
var alerts = null
var units_produced = 0
var battle_record
var campaign_story = null
var campaign_hero = null
var _old_god_mode = false
var _defeat_timers = {}


func _enter_tree():
	_old_god_mode = FeatureFlags.god_mode
	FeatureFlags.god_mode = false
	super()


func _ready():
	super()
	get_node("Menu").queue_free()
	_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_camera.size_max = 45
	_camera.set_size_safely(28)
	_get_human_player().get_node("StructurePlacementHandler").process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)
	get_node("Handlers/UnitGroupSelectionHandler").process_mode = Node.PROCESS_MODE_ALWAYS
	find_child("Minimap").process_mode = Node.PROCESS_MODE_ALWAYS
	alerts = load("res://source/match/alerts/BattleAlerts.gd").new()
	add_child(alerts)
	hud = _create_hud()
	add_child(hud)
	for player in get_tree().get_nodes_in_group("players"):
		_defeat_timers[player] = 60.0
	MatchSignals.unit_production_finished.connect(func(_unit, _producer): units_produced += 1)
	battle_record = load("res://source/match/BattleRecord.gd").new()
	add_child(battle_record)
	if not settings.mission_id.is_empty():
		campaign_hero = load("res://source/match/campaign/CampaignHero.gd").new()
		campaign_hero.name = "CampaignHero"
		add_child(campaign_hero)
	_attach_campaign_story.call_deferred()


func _attach_campaign_story():
	if campaign_story != null:
		return
	var story = load("res://source/match/campaign/CampaignStory.gd")
	if story.supports(self):
		campaign_story = story.new()
		campaign_story.name = "CampaignStory"
		add_child(campaign_story)


func _spawn_player_units(player, spawn_transform):
	player.resource_a = 120 if settings.advanced_start else 60
	player.resource_b = 60 if settings.advanced_start else 12
	var roster = [
		["CommandCenter", Vector3.ZERO],
		["Worker", Vector3(-3, 0, 4)],
		["Worker", Vector3(-1, 0, 4)],
		["Worker", Vector3(1, 0, 4)],
		["Worker", Vector3(3, 0, 4)],
		["Infantry", Vector3(-1, 0, 6)],
		["Infantry", Vector3(1, 0, 6)]
	]
	if settings.advanced_start:
		roster += [
			["PowerPlant", Vector3(-6, 0, 0)],
			["Barracks", Vector3(0, 0, -6)],
			["VehicleFactory", Vector3(6, 0, 0)],
			["CommandLab", Vector3(6, 0, 6)],
			["RepairDepot", Vector3(-6, 0, 6)],
			["Tank", Vector3(-2, 0, 9)],
			["Tank", Vector3(2, 0, 9)],
			["RepairRobot", Vector3(0, 0, 9)]
		]
	var origin = spawn_transform.origin
	var direction = -1.0 if origin.z > map.size.y / 2.0 else 1.0
	# Shift advanced bases inward to fit buildings on the smaller legacy maps.
	origin.x = clamp(origin.x, 10.0, map.size.x - 10.0)
	origin.z = clamp(origin.z, 10.0, map.size.y - 10.0)
	for entry in roster:
		var point = origin + entry[1] * direction
		var unit = load(Catalog.scene_path(entry[0])).instantiate()
		if settings.advanced_start and entry[0] == "Tank":
			unit.set_meta("chip_installed", true)
		_setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)


func _physics_process(delta):
	super(delta)
	if finished or hud == null:
		return
	battle_record.observe()
	if campaign_hero != null:
		campaign_hero.step(delta)
		if finished:
			return
	_check_outcome(delta)


func _create_hud():
	return load("res://source/match/hud/SkirmishHUD.gd").new()


func _check_outcome(delta):
	var losers = []
	for player in _defeat_timers:
		var units = player.get_children().filter(
			func(unit): return "type" in unit and not unit.is_queued_for_deletion()
		)
		if player.has_completed_structure("CommandCenter"):
			_defeat_timers[player] = 60.0
		else:
			_defeat_timers[player] -= delta
		if units.is_empty() or _defeat_timers[player] <= 0:
			losers.append(player)
	if not losers.is_empty():
		finished = true
		result = (
			"Draw"
			if losers.size() > 1
			else ("Defeat" if _get_human_player() in losers else "Victory")
		)
		hud.show_result(result)


func result_summary():
	var seconds = int(simulation_time)
	return (
		(
			"Battle time %02d:%02d\nYour surviving units: %d / 100"
			% [seconds / 60, seconds % 60, _get_human_player().population()]
		)
		+ "\n\n"
		+ battle_record.summary()
	)


func objective_text():
	var human = _get_human_player()
	var players = _defeat_timers.keys()
	players.erase(human)
	players.push_front(human)
	var recovery = []
	for player in players:
		if not _defeat_timers.has(player) or player.has_completed_structure("CommandCenter"):
			continue
		var seconds = maxi(0, ceili(_defeat_timers[player]))
		recovery.append(
			(
				"Your HQ · complete a rebuild within %ds." % seconds
				if player == human
				else "Enemy HQ · prevent a rebuild for %ds." % seconds
			)
		)
	if not recovery.is_empty():
		return "\n".join(recovery)

	var text = "Destroy the enemy HQ. Prevent a rebuild for 60 seconds."
	if "relays" in map:
		var owned = (
			map.relays.filter(func(relay): return relay.captured_by == _get_human_player()).size()
		)
		text += "\nRelays %d/2 · Infantry hold 10s for local vision." % owned
	return text


func restart():
	get_tree().paused = false
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings.duplicate(true)
	loading.map_path = settings.map_path
	get_tree().root.add_child(loading)
	get_tree().current_scene = loading
	queue_free()


func _exit_tree():
	FeatureFlags.god_mode = _old_god_mode

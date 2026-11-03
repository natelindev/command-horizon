extends Node

const Session = preload("res://source/match/network/NetworkSession.gd")

var session: Node
var port: int = Session.PORT
var mode: String = "2v2"
var map_path: String = ""
var factions: Array = []
var ai_slots: Array = []
var auto_start: bool = true
var timeout_seconds: float = 0.0

var _elapsed_time: float = 0.0
var _started: bool = false
var _finished: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_arguments()
	_resolve_map()
	_start_hosting()


func _parse_arguments():
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=").to_lower()
		elif arg.begins_with("--map="):
			map_path = arg.trim_prefix("--map=")
		elif arg.begins_with("--timeout="):
			timeout_seconds = float(arg.trim_prefix("--timeout="))
		elif arg.begins_with("--auto-start="):
			auto_start = arg.trim_prefix("--auto-start=").to_lower() != "false"
		elif arg.begins_with("--factions="):
			factions = Array(arg.trim_prefix("--factions=").split(","))
		elif arg.begins_with("--ai-slots="):
			var raw = arg.trim_prefix("--ai-slots=").split(",")
			ai_slots = []
			for entry in raw:
				if entry.strip_edges().is_valid_int():
					ai_slots.append(int(entry.strip_edges()))


func _resolve_map():
	var is_2v2 = mode == "2v2"
	var default_keyword = "FourRiversMap" if is_2v2 else "DesertFrontier"
	var target_players = 4 if is_2v2 else 2

	if not map_path.is_empty():
		for path in Constants.Match.MAPS:
			if map_path in path:
				map_path = path
				return

	# Fallback to default map for player count
	for path in Constants.Match.MAPS:
		var info = Constants.Match.MAPS[path]
		if info.players == target_players and default_keyword in path:
			map_path = path
			return

	# Final fallback to first map with matching player count
	for path in Constants.Match.MAPS:
		if Constants.Match.MAPS[path].players == target_players and not "TerrainTestMap" in path:
			map_path = path
			return


func _start_hosting():
	session = Session.create(get_tree())
	session.changed.connect(_on_session_changed)

	var is_2v2 = mode == "2v2"
	var total_players = 4 if is_2v2 else 2
	var default_factions = ["bastion", "helix", "frontier", "bastion"]

	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.map_path = map_path
	settings.match_seed = int(Time.get_unix_time_from_system()) % 1000000000

	for index in total_players:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = 1 if index == 0 else 2
		side.color = Constants.Player.COLORS[index % Constants.Player.COLORS.size()]
		var faction_name = (
			factions[index] if index < factions.size() else default_factions[index % default_factions.size()]
		)
		side.faction = faction_name
		side.spawn_index = index
		if is_2v2:
			side.team = 0 if index < 2 else 1
		else:
			side.team = index
		if index in ai_slots:
			side.set_meta("ai_commander", true)
		settings.players.append(side)

	if not session.host(settings, port, true):
		push_error("[DEDICATED SERVER] Failed to host on port %d: %s" % [port, session.error])
		get_tree().quit(1)
		return

	print("[DEDICATED SERVER] Dedicated server listening on UDP port %d" % port)
	print("[DEDICATED SERVER] Mode: %s · Map: %s" % [mode, map_path])
	print("[DEDICATED SERVER] Slots: %d commanders (AI slots: %s)" % [total_players, str(ai_slots)])


func _on_session_changed():
	if not is_instance_valid(session):
		return
	print("[DEDICATED SERVER] %s" % session.status)
	if auto_start and not _started and session.is_ready_to_start():
		_launch_battle.call_deferred()


func _launch_battle():
	if _started:
		return
	_started = true
	print("[DEDICATED SERVER] All required commanders connected. Launching battle...")
	var success = await session.start_battle()
	if not success:
		push_error("[DEDICATED SERVER] Failed to start battle: %s" % session.error)
		get_tree().quit(1)
		return
	print("[DEDICATED SERVER] Battle running!")


func _process(delta):
	_elapsed_time += delta
	if not _started and timeout_seconds > 0.0 and _elapsed_time > timeout_seconds:
		print("[DEDICATED SERVER] Connection timeout reached (%ds). Exiting." % int(timeout_seconds))
		if is_instance_valid(session):
			session.shutdown()
			session.queue_free()
		get_tree().quit(0)
		return

	if _started and not _finished and is_instance_valid(session) and is_instance_valid(session.game):
		if session.game.finished:
			_finished = true
			print("[DEDICATED SERVER] Battle completed. Result: %s" % session.game.result)
			if not session.recording_path.is_empty():
				print("[DEDICATED SERVER] Replay stored: %s" % session.recording_path)
			_shutdown_after_drain.call_deferred()


func _shutdown_after_drain():
	for _frame in 60:
		await get_tree().process_frame
	if is_instance_valid(session):
		session.shutdown()
	print("[DEDICATED SERVER] Shutdown complete.")
	get_tree().quit(0)

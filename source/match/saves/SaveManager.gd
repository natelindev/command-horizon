# gdlint: disable=max-returns
extends Node

const Slots = preload("res://source/match/saves/SaveSlots.gd")
const Snapshot = preload("res://source/match/saves/MatchSnapshot.gd")
var slots = Slots.new()
var autosaves_enabled = false
var busy = false
var dialog = null
var _frozen = []
var _frozen_scene = null
var _was_paused = false
var _previous_focus = null
var _checkpoint = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


func active_game():
	var scene = get_tree().current_scene
	return (
		scene if is_instance_valid(scene) and "restoring" in scene and "finished" in scene else null
	)


func can_open():
	var game = active_game()
	if _network_save_blocked(game):
		return false
	return (
		not busy
		and not is_instance_valid(Globals.settings_dialog)
		and not is_instance_valid(dialog)
		and (
			game == null
			or not "campaign_story" in game
			or not is_instance_valid(game.campaign_story)
			or not game.campaign_story.cinematic
		)
	)


func open_dialog(mode = "load", selected = "manual-1"):
	if not can_open():
		return
	_freeze()
	dialog = load("res://source/match/saves/SaveDialog.gd").new()
	dialog.manager = self
	dialog.mode = mode if mode in ["save", "load"] else "load"
	dialog.selected = selected if selected in Slots.IDS else "manual-1"
	add_child(dialog)
	await dialog.refresh()


func close_dialog(loaded = false):
	if busy:
		return
	if is_instance_valid(dialog):
		dialog.queue_free()
	dialog = null
	if loaded:
		_frozen.clear()
		_frozen_scene = null
		var game = active_game()
		if game != null:
			game.hud._pause_button.grab_focus()
	else:
		_thaw()


func _input(event):
	var focus = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if is_instance_valid(Globals.settings_dialog):
		return
	if busy:
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(dialog):
		return
	var game = active_game()
	if game == null or game.finished:
		return
	if (
		"campaign_story" in game
		and is_instance_valid(game.campaign_story)
		and game.campaign_story.cinematic
	):
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action_pressed("quicksave_battle", false, true):
		get_viewport().set_input_as_handled()
		save_slot("quick")
	elif event.is_action_pressed("quickload_battle", false, true):
		get_viewport().set_input_as_handled()
		open_dialog("load", "quick")


func save_slot(id):
	if _network_save_blocked(active_game()):
		return false
	if busy:
		return false
	var game = active_game()
	if game == null or game.finished or not _ready_to_save(game):
		_notice("Battle is not ready to save. Wait for loading to finish and try again.")
		return false
	busy = true
	var modal = is_instance_valid(dialog)
	if not modal:
		_notice("Saving battle…")
		_freeze()
	else:
		dialog.set_busy("Saving battle…")
	await get_tree().process_frame
	# Settle presentation at this simulation boundary before capturing rendered history.
	game.fog_of_war._physics_process(0.0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var snapshotter = Snapshot.new()
	var data = snapshotter.capture(game)
	var ok = data != null and slots.write_slot(id, data)
	var message = (
		"Battle saved · " + Slots.title(id)
		if ok
		else (snapshotter.error if data == null else slots.error)
	)
	busy = false
	if not modal:
		_thaw()
	else:
		await dialog.refresh()
	_notice(message)
	return ok


func load_slot(id):
	if _network_save_blocked(active_game()):
		return false
	if busy or (not is_instance_valid(dialog) and not can_open()):
		return false
	busy = true
	if not is_instance_valid(dialog):
		busy = false
		await open_dialog("load", id)
		busy = true
	dialog.set_busy("Loading battle…")
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var data = slots.read_slot(id)
	if data == null:
		var read_error = slots.error
		busy = false
		await dialog.refresh()
		_notice(read_error)
		return false
	var restorer = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await restorer.restore(get_tree(), data)
	busy = false
	if result.get("cancelled", false) or not is_instance_valid(dialog):
		close_dialog()
		return false
	if not result.ok:
		if result.has("game"):
			# Replacement started: only a fresh load or menu exit is safe.
			_frozen.clear()
			_frozen_scene = null
			_freeze()
			dialog.recovery_only = true
		await dialog.refresh()
		_notice(result.error)
		return false
	_checkpoint.clear()
	autosaves_enabled = true
	close_dialog(true)
	return true


func request_checkpoint(game, reason):
	if autosaves_enabled and not game.restoring:
		_checkpoint = {"game": weakref(game), "reason": reason}


func _process(_delta):
	if _checkpoint.is_empty() or busy or is_instance_valid(dialog) or get_tree().paused:
		return
	var game = _checkpoint.game.get_ref()
	if not is_instance_valid(game) or game != active_game() or game.finished:
		_checkpoint.clear()
		return
	if not _ready_to_save(game):
		return
	var reason = _checkpoint.reason
	_checkpoint.clear()
	var id = slots.next_auto_slot()
	if id == "":
		_notice(slots.error)
	elif await save_slot(id):
		_notice("Checkpoint saved · " + reason)


func _ready_to_save(game):
	if game.restoring or not game.is_node_ready() or game.navigation.terrain._is_baking:
		return false
	if game.navigation.terrain._earliest_frame_to_perform_next_rebake != null:
		return false
	for unit in get_tree().get_nodes_in_group("units"):
		var movement = unit.get_node_or_null("Movement")
		if movement != null and not movement._synchronized:
			return false
	return true


func _freeze():
	_previous_focus = get_viewport().gui_get_focus_owner()
	_was_paused = get_tree().paused
	get_tree().paused = true
	_frozen_scene = get_tree().current_scene
	if not is_instance_valid(_frozen_scene):
		return
	_freeze_node(_frozen_scene)
	_frozen_scene.process_mode = Node.PROCESS_MODE_DISABLED


func _freeze_node(node):
	_frozen.append({"node": node, "mode": node.process_mode})
	node.process_mode = Node.PROCESS_MODE_INHERIT
	for child in node.get_children():
		_freeze_node(child)


func _thaw():
	for entry in _frozen:
		if is_instance_valid(entry.node):
			entry.node.process_mode = entry.mode
	_frozen.clear()
	if is_instance_valid(_frozen_scene) and _frozen_scene == get_tree().current_scene:
		get_tree().paused = _was_paused
	_frozen_scene = null
	if is_instance_valid(_previous_focus) and _previous_focus.is_inside_tree():
		_previous_focus.grab_focus()
	_previous_focus = null


func _notice(message):
	if is_instance_valid(dialog):
		dialog.show_notice(message)
	else:
		var game = active_game()
		if game != null:
			game.hud.show_notice(message)


func _network_save_blocked(game) -> bool:
	if is_instance_valid(game) and game.has_meta("network_session"):
		_notice("Network battles are recorded as replays. Leave the session before loading a local save.")
		return true
	return false

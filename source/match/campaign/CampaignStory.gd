# gdlint: disable=max-returns
extends Node

signal caption_changed(line)

const Narration = preload("res://source/match/campaign/CampaignNarration.gd")
const UiTheme = preload("res://source/match/hud/BattleTheme.gd")
const Catalog = preload("res://source/match/campaign/CampaignCatalog.gd")
var current = {}
var seen = []
var cinematic = false
var _game
var _audio: AudioStreamPlayer
var _voice
var _pending = []
var _active_cue = ""
var _line_index = 0
var _resume = {}
var _remaining = 0.0
var _started = false
var _scene_time = 0.0
var _scene_length = 0.0
var _was_paused = false
var _camera_state = {}
var _input_state = []
var _hud_state = []
var _focus_before
var _layer: CanvasLayer
var _modal: Control
var _briefing: PanelContainer
var _title: Label
var _subtitle
var _skip: Button
var _skip_release = false
var _interrupted = false


static func supports(game):
	return game.settings.mission_id in Narration.missions()


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game = get_parent()
	_voice = _game._get_human_player().get_node_or_null("BattleVoice")
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Voice"
	add_child(_audio)
	var captions = load("res://source/match/hud/BattleSubtitles.gd").new()
	captions.name = "CampaignSubtitles"
	captions.voice = self
	captions.always_show_captions = true
	_game.add_child(captions)
	_build_briefing()
	Globals.options.changed.connect(_refresh_language)


func snapshot():
	var active = _resume.duplicate()
	if not current.is_empty():
		active = {
			"cue": _active_cue,
			"line": current.id,
			"remaining": maxf(0, _remaining),
			"position": _audio.get_playback_position()
		}
	return {"seen": seen.duplicate(), "pending": _pending.duplicate(), "active": active}


func restore(data):
	if cinematic:
		_end_cinematic()
	_clear()
	seen = data.seen.duplicate()
	_pending = data.pending.duplicate()
	_resume = data.active.duplicate()
	_started = true


func cue(id):
	var key = id if id.contains(".") else "common." + id
	if key not in Narration.ids(_game.settings.mission_id) or key in seen:
		return false
	_mark_seen(key)
	_pending.append(key)
	return true


func start_briefing(force_cinematic = false):
	if cinematic or _game.restoring or _game.finished:
		return false
	_started = true
	var id = _game.settings.mission_id + ".intro"
	_mark_seen(id)
	# Headless replays have no camera presentation. Tests can explicitly exercise
	# the cinematic path; all narrated gameplay cues still use the same observer.
	if not force_cinematic and DisplayServer.get_name() == "headless":
		_pending.append(id)
		return true
	_pending.clear()
	_clear()
	_begin_cinematic()
	_play(id)
	_scene_length = 0.0
	for line in Narration.scene(id):
		var stream = load(line.stream) if ResourceLoader.exists(line.stream) else null
		_scene_length += _line_duration(line, stream)
	return true


func skip_briefing():
	if not cinematic:
		return
	_end_cinematic()
	_clear()


func _process(delta):
	if _game.restoring:
		return
	if not _started:
		start_briefing()
	# Battle dialogue follows tactical pause. Result dialogue and cinematic briefings
	# still run while their presentation owns the pause.
	if get_tree().paused and not cinematic and not _game.finished:
		_audio.stream_paused = true
		return
	if is_instance_valid(Globals.settings_dialog) or get_node("/root/SaveManager").busy:
		_audio.stream_paused = true
		return
	# A dangerous battlefield report takes precedence over story exposition.
	if not cinematic and _voice != null and _voice.current.get("priority", 0) >= 70:
		_audio.stream_paused = true
		if not _interrupted:
			_interrupted = true
			caption_changed.emit({})
		return
	_audio.stream_paused = false
	if not _resume.is_empty():
		var saved = _resume.duplicate()
		_resume.clear()
		var sequence = Narration.scene(saved.cue)
		var index = sequence.map(func(line): return line.id).find(saved.line)
		_play(saved.cue, index, saved.position, saved.remaining)
	if _interrupted:
		_interrupted = false
		caption_changed.emit(current.duplicate())
	var elapsed = delta / maxf(Engine.time_scale, 0.001)
	if cinematic:
		_scene_time += elapsed
		_animate_camera()
	else:
		_observe()
	if not current.is_empty():
		_remaining -= elapsed
		if _remaining <= 0:
			_advance_line()
	if current.is_empty() and not _pending.is_empty():
		_play(_pending.pop_front())


func _observe():
	if _game.finished:
		var id = (
			_game.settings.mission_id + ".victory"
			if _game.result == "Victory"
			else (
				_game.settings.mission_id + ".defeat"
				if Narration.lines().has(_game.settings.mission_id + ".defeat")
				else "common.defeat"
			)
		)
		if id not in seen:
			_pending.clear()
			_clear()
			cue(id)
		return
	for id in _milestones():
		cue(id)
	if _game.campaign_hero != null and _game.campaign_hero.alive():
		var hero = _game.campaign_hero.unit
		if hero.hp < hero.hp_max * .35:
			cue(_game.settings.mission_id + ".danger")
	if "opposition" in _game and is_instance_valid(_game.opposition):
		if _game.opposition.active:
			cue("enemy_base")
		# Air Corridor has a working base without a siege commander. Its helper
		# treats the absent boss as defeated for outcome checks, not storytelling.
		if _game.settings.mission_id == "command_horizon":
			if _game.opposition.boss_started:
				cue("boss_arrives")
			if _game.opposition.boss_defeated:
				cue("boss_defeated")


func _milestones():
	var result = []
	var mission = _game.settings.mission_id
	match mission:
		"supply_line":
			if _game.convoy.any(func(entry): return entry.leg > 0):
				result.append("supply_line.checkpoint")
		"first_orders":
			if _game.phase >= 1:
				result.append("first_orders.lab")
			if _game.defence_started:
				result.append("first_orders.relay")
		"split_signal":
			var human = _game._get_human_player()
			if _game.map.relays.filter(func(relay): return relay.captured_by == human).size() >= 2:
				result.append("split_signal.network")
		"broken_foundry":
			var disabled = _game.nodes.filter(func(entry): return entry.disabled).size()
			if disabled > 0:
				result.append("broken_foundry.node")
			if disabled == 2:
				result.append("broken_foundry.control")
		"command_horizon":
			if _game.deployed:
				result.append("command_horizon.deployment")
			if _game.command_destroyed:
				result.append("command_horizon.command")
	if Catalog.is_story(mission):
		if _game.stage > 0:
			result.append(mission + ".milestone")
		if _game.stage > 1:
			result.append(mission + ".stage_2")
	elif mission == "supply_line" and _game.convoy.any(func(entry): return entry.leg >= 2):
		result.append(mission + ".stage_2")
	elif mission == "split_signal" and _game.network_badge:
		result.append(mission + ".stage_2")
	return result


func _play(id, index = 0, position = 0.0, remaining = -1.0):
	var sequence = Narration.scene(id, Globals.options.language)
	if (index < 0 and not Narration.single_narrator(id)) or index >= sequence.size():
		return
	_active_cue = id
	_line_index = index
	current = (
		Narration._narrator_record(id, Globals.options.language)
		if index < 0
		else sequence[index].duplicate()
	)
	if _voice != null:
		_voice.begin_narration()
	_audio.stream = load(current.stream) if ResourceLoader.exists(current.stream) else null
	if _audio.stream != null:
		_audio.play(minf(position, _audio.stream.get_length()))
	_remaining = _line_duration(current, _audio.stream)
	if remaining >= 0:
		_remaining = remaining
	_present_line()


func _line_duration(line, stream):
	if stream != null:
		return maxf(stream.get_length() + .4, 2.2)
	# A missing asset must not trap the player in a briefing.
	return maxf(2.2, line.text.length() / 18.0)


func _present_line():
	if cinematic:
		_subtitle.set_line(current.speaker, current.text, Globals.options.subtitle_size)
		_subtitle.set_portrait(current.get("portrait", ""))
		_subtitle.set_caption_visible(true)
	else:
		caption_changed.emit(current.duplicate())


func _advance_line():
	if _line_index >= 0 and _line_index + 1 < Narration.scene(_active_cue).size():
		_play(_active_cue, _line_index + 1)
		return
	if cinematic:
		_end_cinematic()
	_clear()


func skip_dialogue():
	# Skip the active conversation as a whole; queued mission events remain intact.
	if cinematic:
		skip_briefing()
	else:
		_clear()


func _clear():
	_audio.stop()
	_interrupted = false
	current.clear()
	_resume.clear()
	_active_cue = ""
	_line_index = 0
	_remaining = 0.0
	caption_changed.emit({})
	if _voice != null:
		_voice.end_narration()


func _mark_seen(id):
	if id not in seen:
		seen.append(id)


func _begin_cinematic():
	cinematic = true
	_scene_time = 0.0
	_was_paused = get_tree().paused
	_focus_before = get_viewport().gui_get_focus_owner()
	# An opening can precede the first physics tick. Populate only the player's
	# existing sight circles before pausing, so the briefing has a visible world.
	_game.fog_of_war._physics_process(0)
	get_tree().paused = true
	var camera = _game.get_node("IsometricCamera3D")
	_camera_state = {
		"transform": camera.global_transform,
		"size": camera.size,
		"physics": camera.is_physics_processing(),
		"point": camera.get_ray_intersection(get_viewport().get_visible_rect().size / 2)
	}
	camera.set_physics_process(false)
	_suspend_input(_game)
	# Nested CanvasLayers (notably alerts) do not inherit their parent's visibility.
	for hud in _game.find_children("*", "CanvasLayer", true, false):
		if hud != _layer:
			_hud_state.append({"node": weakref(hud), "visible": hud.visible})
			hud.hide()
	_modal.show()
	_skip.grab_focus()
	_title.text = (
		"%s / %s"
		% [
			Catalog.operations()[_game.settings.mission_id].number,
			tr(Catalog.operations()[_game.settings.mission_id].title)
		]
	)
	_update_layout()


func _suspend_input(node):
	if node == self or node == _layer:
		return
	_input_state.append(
		{
			"node": weakref(node),
			"input": node.is_processing_input(),
			"unhandled": node.is_processing_unhandled_input(),
			"key": node.is_processing_unhandled_key_input()
		}
	)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	for child in node.get_children():
		_suspend_input(child)


func _end_cinematic():
	if _game.is_queued_for_deletion() or not _game.is_inside_tree():
		# The match is leaving: its canvases may still be attached while their
		# controls have already exited. Only release the cinematic pause.
		cinematic = false
		_input_state.clear()
		_hud_state.clear()
		get_tree().paused = _was_paused
		return
	var camera = _game.get_node("IsometricCamera3D")
	if camera.is_inside_tree():
		camera.set_size_safely(_camera_state.size)
		camera.global_transform = _camera_state.transform
		camera.set_physics_process(_camera_state.physics)
	for saved in _input_state:
		var node = saved.node.get_ref()
		if is_instance_valid(node):
			node.set_process_input(saved.input)
			node.set_process_unhandled_input(saved.unhandled)
			node.set_process_unhandled_key_input(saved.key)
	_input_state.clear()
	for saved in _hud_state:
		var hud = saved.node.get_ref()
		# Match teardown may already have removed the HUD. Toggling visibility
		# there invokes layout callbacks without a viewport.
		if is_instance_valid(hud) and hud.is_inside_tree():
			hud.visible = saved.visible
	_hud_state.clear()
	cinematic = false
	_modal.hide()
	get_tree().paused = _was_paused
	if is_instance_valid(_focus_before) and _focus_before.is_inside_tree():
		_focus_before.grab_focus()
	elif _skip.is_inside_tree():
		_skip.release_focus()


func _animate_camera():
	if Globals.options.reduced_flashes or not Globals.options.menu_motion:
		return
	var camera = _game.get_node("IsometricCamera3D")
	var origin = _camera_state.point
	if origin == null:
		return
	var amount = smoothstep(0.0, 1.0, clampf(_scene_time / maxf(_scene_length, 1), 0, 1))
	camera.set_position_safely(origin.lerp(_objective_point(), amount))
	camera.set_size_safely(lerpf(_camera_state.size, minf(36.0, camera.size_max), amount))


func _objective_point():
	if Catalog.is_story(_game.settings.mission_id):
		var point = _game.current_objective().point
		return Vector3(point[0], 0, point[1])
	match _game.settings.mission_id:
		"supply_line":
			return _game.map.POINTS[0]
		"first_orders":
			return _game.relay.global_position
		"split_signal":
			return _game.map.relays[1].global_position
		"broken_foundry":
			return _game.map.NODES[0]
		"command_horizon":
			return _game.map.DEPLOYMENT
	return Vector3.ZERO


func _input(event):
	if _skip_release and event is InputEventKey and not event.pressed:
		_skip_release = false
		get_viewport().set_input_as_handled()
		return
	if not cinematic or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
		_skip_release = true
		skip_briefing()


func _build_briefing():
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_modal)
	_briefing = PanelContainer.new()
	UiTheme.apply(_briefing, 22, 16)
	_modal.add_child(_briefing)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_briefing.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	column.add_child(_title)
	_subtitle = load("res://source/match/hud/SubtitleCard.gd").new()
	column.add_child(_subtitle)
	_skip = Button.new()
	_skip.text = "Continue / skip briefing"
	_skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	_skip.pressed.connect(skip_briefing)
	column.add_child(_skip)
	_modal.hide()
	get_viewport().size_changed.connect(_update_layout)


func _update_layout():
	if not is_instance_valid(_briefing):
		return
	var viewport = get_viewport().get_visible_rect().size
	_briefing.size.x = minf(760, maxf(1, viewport.x - 48))
	_briefing.size.y = _briefing.get_combined_minimum_size().y
	_briefing.position = Vector2((viewport.x - _briefing.size.x) / 2, 24)


func _refresh_language():
	if not current.is_empty():
		var localized = Narration.record(current.id, Globals.options.language)
		current.text = localized.text
		current.speaker = localized.speaker
		# Let an in-flight recording finish; a locale change never restarts a cue.
		_present_line()
	_update_layout()


func _exit_tree():
	if cinematic:
		_end_cinematic()
	if is_instance_valid(_audio):
		_audio.stop()
	if is_instance_valid(_voice):
		_voice.end_narration()

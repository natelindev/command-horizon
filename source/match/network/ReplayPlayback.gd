# gdlint: disable=max-returns
extends Node

signal changed
const Archive = preload("res://source/match/network/ReplayFile.gd")
const Frame = preload("res://source/match/network/AuthoritativeFrame.gd")
const Digest = preload("res://source/match/network/ReplicaDigest.gd")
const Values = preload("res://source/match/saves/SaveValue.gd")
var authority = false
var applying = false
var spectator = true
var local_slot = -1
var game
var replica
var registry = Frame.new()
var archive = Archive.new()
var tick = 0.0
var duration = 0
var speed = 1.0
var playing = true
var error = ""
var last_hash = ""
var _frame_index = -1
var _bar
var _slider: HSlider
var _clock: Label
var _play: Button


func open(path: String) -> bool:
	if not archive.open_read(path):
		return _fail(archive.error)
	if (
		archive.header.get("protocol") != 1
		or archive.header.get("tick_rate") != 60
		or archive.header.get("authority") != "server"
		or archive.header.get("shared_vision") != true
	):
		return _fail("Unsupported replay simulation contract.")
	var values = Values.new()
	var initial = values.decode(archive.header.get("initial"))
	if not values.error.is_empty() or not initial is Dictionary or not registry.validate(initial):
		return _fail("Replay initial state is invalid: " + registry.error)
	if (
		not archive.footer.get("tick") is int
		or archive.footer.tick < 0
		or not archive.footer.get("hash") is String
	):
		return _fail("Replay ending is invalid.")
	duration = archive.footer.tick
	process_mode = Node.PROCESS_MODE_ALWAYS
	applying = true
	replica = load("res://source/match/network/AuthoritativeReplica.gd").new()
	if not await replica.initialize(get_tree(), initial, -1, self):
		return _fail(replica.error)
	game = replica.game
	applying = false
	_build_controls()
	return seek(0)


func _process(delta):
	if not is_instance_valid(game) or not playing or error != "":
		return
	tick = minf(duration, tick + delta * 60.0 * speed)
	var selected = archive.frame_at(floori(tick))
	if selected != _frame_index:
		_apply_until(selected)
	if tick >= duration:
		playing = false
		if last_hash != archive.footer.hash:
			_fail("Replay end-state checksum mismatch.")
	_refresh()


func seek(at_tick: int) -> bool:
	if archive.frames.is_empty() or not is_instance_valid(game):
		return false
	tick = clampi(at_tick, 0, duration)
	var target = archive.frame_at(int(tick))
	if target < 0:
		return false
	var frame_position = archive.frames.find(target)
	while frame_position >= 0:
		var packet = archive.read_record(archive.frames[frame_position])
		if packet.get("full") == true:
			_frame_index = archive.frames[frame_position] - 1
			break
		frame_position -= 1
	if frame_position < 0:
		return _fail("Replay has no authoritative checkpoint.")
	return _apply_until(target)


func _apply_until(target: int) -> bool:
	var snapshot = replica.state
	for index in archive.frames:
		if index <= _frame_index or index > target:
			continue
		var packet = archive.read_record(index)
		if not _valid_frame(packet):
			return _fail("Replay frame is invalid.")
		var values = Values.new()
		var data = values.decode(packet.state)
		if not values.error.is_empty() or not data is Dictionary:
			return _fail("Replay frame encoding is invalid.")
		if not packet.full and not Frame.valid_delta(data):
			return _fail("Replay delta is invalid.")
		snapshot = data if packet.full else Frame.apply_delta(snapshot, data)
		if not registry.validate(snapshot) or Frame.hash_state(snapshot) != packet.hash:
			return _fail("Replay state checksum mismatch.")
		last_hash = packet.hash
		_frame_index = index
	applying = true
	var ok = replica.apply(snapshot)
	applying = false
	if not ok:
		return _fail(replica.error)
	if Digest.live(replica) != Digest.expected(snapshot):
		return _fail("Replay live replica differs from recorded state.")
	_refresh()
	return true


func _valid_frame(packet: Dictionary) -> bool:
	return (
		packet.get("type") == "frame"
		and packet.get("tick") is int
		and packet.tick >= 0
		and packet.tick <= duration
		and packet.get("full") is bool
		and packet.get("hash") is String
		and packet.hash.length() == 64
		and packet.has("state")
	)


func _build_controls():
	game.hud._pause_button.hide()
	var layer = CanvasLayer.new()
	layer.layer = 20
	game.add_child(layer)
	_bar = PanelContainer.new()
	_bar.name = "ReplayControls"
	_bar.theme = load("res://source/match/hud/BattleTheme.gd").create()
	_bar.theme_type_variation = "HudHousing"
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.offset_left = -310
	_bar.offset_right = 310
	_bar.offset_top = -68
	_bar.offset_bottom = -18
	layer.add_child(_bar)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_bar.add_child(row)
	_play = _button(row, "Pause replay", toggle)
	_clock = Label.new()
	_clock.custom_minimum_size.x = 100
	row.add_child(_clock)
	_slider = HSlider.new()
	_slider.custom_minimum_size.x = 180
	_slider.max_value = maxi(1, duration)
	_slider.accessibility_name = tr("Replay position")
	_slider.value_changed.connect(func(value): seek(int(value)))
	row.add_child(_slider)
	var choices = OptionButton.new()
	for rate in [.25, .5, 1.0, 2.0, 4.0]:
		choices.add_item(str(rate) + "×")
	choices.select(2)
	choices.item_selected.connect(func(index): speed = [.25, .5, 1.0, 2.0, 4.0][index])
	row.add_child(choices)
	_button(row, "Replays", close)


func _button(parent, caption, callback):
	var button = Button.new()
	button.text = tr(caption)
	button.custom_minimum_size.y = 34
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func toggle():
	playing = not playing
	_refresh()


func _refresh():
	if not is_instance_valid(_clock):
		return
	_clock.text = (
		"%02d:%02d / %02d:%02d"
		% [int(tick) / 3600, int(tick) / 60 % 60, duration / 3600, duration / 60 % 60]
	)
	_play.text = tr("Pause replay" if playing else "Play replay")
	_slider.set_value_no_signal(tick)
	changed.emit()


func submit(_intent: Dictionary) -> bool:
	notice("Replay playback is read-only.")
	return false


func submit_group_member(intent: Dictionary) -> bool:
	return submit(intent)


func id_for(node) -> String:
	for id in replica.entities:
		if replica.entities[id] == node:
			return id
	return ""


func notice(message: String):
	if is_instance_valid(game):
		game.hud.show_notice(message)


func shutdown():
	archive.close()
	playing = false
	get_tree().paused = false


func close():
	shutdown()
	get_tree().change_scene_to_file("res://source/main-menu/Replays.tscn")
	queue_free()


func _fail(message: String) -> bool:
	error = message
	playing = false
	notice(message)
	return false

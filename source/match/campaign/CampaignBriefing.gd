extends Control

## Layered painted motion comic. Simulation and voice ownership remain with
## CampaignStory; the same presentation can be inspected in the hub archive.
const Catalog = preload("res://source/match/campaign/CampaignCatalog.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const COMMANDERS = {"bastion": "aegis", "helix": "nyx", "frontier": "rook"}
const DURATION = 48.0
var mission_id = "supply_line"
var elapsed = 0.0
var duration = DURATION
var backdrop: TextureRect
var foreground: TextureRect
var dialogue_panel: PanelContainer
var title_label: Label
var caption
var skip_button: Button
var theater: Control
var objectives: Label
var progress: ProgressBar
var _map_points = PackedVector2Array()
var _faction = "bastion"
var _objective_lines = []


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop = _picture()
	foreground = _picture()
	var shade = ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, .2)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	theater = Control.new()
	theater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	theater.draw.connect(_draw_theater)
	add_child(theater)
	objectives = Label.new()
	objectives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objectives.add_theme_font_size_override("font_size", 17)
	objectives.add_theme_color_override("font_color", Color("f2e8cf"))
	objectives.add_theme_color_override("font_shadow_color", Color.BLACK)
	objectives.add_theme_constant_override("shadow_outline_size", 6)
	add_child(objectives)
	objectives.minimum_size_changed.connect(func(): _layout.call_deferred())
	dialogue_panel = PanelContainer.new()
	BattleTheme.apply(dialogue_panel, 18, 12)
	add_child(dialogue_panel)
	dialogue_panel.resized.connect(func(): _layout.call_deferred())
	dialogue_panel.minimum_size_changed.connect(func(): _layout.call_deferred())
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	dialogue_panel.add_child(column)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 20)
	column.add_child(title_label)
	caption = load("res://source/match/hud/SubtitleCard.gd").new()
	column.add_child(caption)
	var actions = HBoxContainer.new()
	column.add_child(actions)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.max_value = DURATION
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.custom_minimum_size.y = 4
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(progress)
	skip_button = Button.new()
	skip_button.text = tr("Continue / skip briefing")
	actions.add_child(skip_button)
	resized.connect(_layout)
	configure(mission_id)


func _picture() -> TextureRect:
	var picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	return picture


func configure(id: String):
	mission_id = id
	if not is_node_ready():
		return
	var operation = Catalog.operations()[id]
	_faction = operation.faction
	backdrop.texture = load("res://assets/ui/campaign/briefings/%s-environment.png" % _faction)
	foreground.texture = load("res://assets/ui/campaign/briefings/%s.png" % COMMANDERS[_faction])
	foreground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_label.text = "%s · %s" % [operation.number, tr(operation.title)]
	var points = operation.get("objectives", [])
	_map_points.clear()
	for objective in points:
		_map_points.append(Vector2(objective.point[0] / 168.0, objective.point[1] / 120.0))
	if _map_points.is_empty():
		_map_points = PackedVector2Array([Vector2(.1, .7), Vector2(.48, .32), Vector2(.85, .5)])
	_objective_lines.clear()
	for objective in points:
		_objective_lines.append(
			objective.zh_CN if Globals.options.language == "zh_CN" else objective.title
		)
	if points.is_empty():
		var summary = (
			operation.summary_zh if Globals.options.language == "zh_CN" else operation.summary
		)
		_objective_lines.append(
			summary.split("。" if Globals.options.language == "zh_CN" else ".")[0]
		)
	seek(0.0)
	_layout()


func seek(seconds: float):
	elapsed = clampf(seconds, 0.0, duration)
	if not is_node_ready():
		return
	progress.max_value = duration
	progress.value = elapsed
	var index = mini(
		_objective_lines.size() - 1, floori(elapsed / duration * _objective_lines.size())
	)
	if index >= 0:
		objectives.text = (
			tr("Deployment plan")
			+ " · %d/%d\n" % [index + 1, _objective_lines.size()]
			+ _objective_lines[index]
			+ "\n"
			+ tr("Secondary objective: return your hero with at least half hull intact.")
		)
	_layout()
	theater.queue_redraw()


func _layout():
	if not is_instance_valid(backdrop):
		return
	var motion = Globals.options.menu_motion and not Globals.options.reduced_flashes
	var pan = elapsed / duration if motion else .5
	backdrop.position = Vector2(-size.x * .05 + pan * size.x * .035, -size.y * .035)
	backdrop.size = size * 1.1
	foreground.position = Vector2(-size.x * .04 + pan * size.x * .02, size.y * .035)
	foreground.size = Vector2(size.x * .46, size.y * .9)
	var panel_width = minf(900, maxf(1, size.x - 48))
	var panel_style = dialogue_panel.get_theme_stylebox("panel")
	# Keep wrapped captions at their real container width when set_line resets
	# their size. A temporary nameplate-width reflow otherwise expands the
	# dialogue far beyond the viewport until a later narrative seek.
	caption.custom_minimum_size.x = maxf(
		1,
		(
			panel_width
			- panel_style.get_content_margin(SIDE_LEFT)
			- panel_style.get_content_margin(SIDE_RIGHT)
		)
	)
	# Lower the caption minimum before shrinking its parent; otherwise the
	# old minimum clamps the panel to its previous, wider viewport size.
	dialogue_panel.size.x = panel_width
	dialogue_panel.size.y = dialogue_panel.get_combined_minimum_size().y
	dialogue_panel.position = Vector2(
		(size.x - dialogue_panel.size.x) / 2, size.y - dialogue_panel.size.y - 20
	)
	theater.position = Vector2(size.x * .44, size.y * .12)
	theater.size = Vector2(size.x * .51, minf(size.y * .25, 200))
	var objective_font_size = 14 if size.y < 600 else 17
	objectives.add_theme_font_size_override("font_size", objective_font_size)
	if size.y < 600:
		# At 150% interface scale a 720p viewport has 480 logical pixels. Give the
		# objective text the full width above the dialogue, retaining a compact
		# map above it rather than letting the two text blocks overlap.
		objectives.size.x = maxf(1, size.x - 48)
		objectives.size.y = objectives.get_combined_minimum_size().y
		# Use the Label's actual height: its wrapping minimum can update after
		# the width changes, and is not identical to a separate Font estimate.
		objectives.position = Vector2(
			24, maxf(12, dialogue_panel.position.y - objectives.size.y - 16)
		)
		theater.position.y = 12
		theater.size.y = maxf(1, minf(size.y * .25, objectives.position.y - 20))
	else:
		objectives.position = theater.position + Vector2(10, theater.size.y + 14)
		objectives.size = Vector2(
			theater.size.x - 20, maxf(20, dialogue_panel.position.y - objectives.position.y - 16)
		)


func _draw_theater():
	var rect = Rect2(Vector2.ZERO, theater.size)
	theater.draw_style_box(BattleTheme.socket(12, 10), rect)
	var inset = Vector2(20, minf(20, theater.size.y * .2))
	var span = theater.size - inset * 2
	for index in 7:
		var x = inset.x + span.x * index / 6.0
		theater.draw_line(Vector2(x, inset.y), Vector2(x, inset.y + span.y), Color(.5, .7, .7, .14))
	for index in 5:
		var y = inset.y + span.y * index / 4.0
		theater.draw_line(Vector2(inset.x, y), Vector2(inset.x + span.x, y), Color(.5, .7, .7, .14))
	var amount = clampf(elapsed / (duration * .6), 0, 1) if Globals.options.menu_motion else 1.0
	for index in _map_points.size():
		var point = inset + _map_points[index] * span
		theater.draw_circle(point, 5, Color("e7c989"))
		if index == 0:
			continue
		var previous = inset + _map_points[index - 1] * span
		var segment = clampf(amount * (_map_points.size() - 1) - index + 1, 0, 1)
		var end = previous.lerp(point, segment)
		theater.draw_line(previous, end, Color("e7c989"), 3, true)
		if segment > .98:
			var direction = (previous - end).normalized()
			theater.draw_line(end, end + direction.rotated(.55) * 13, Color("e7c989"), 3, true)
			theater.draw_line(end, end + direction.rotated(-.55) * 13, Color("e7c989"), 3, true)
	# A small, deterministic atmosphere layer moves independently of both paints.
	if Globals.options.menu_motion and not Globals.options.reduced_flashes:
		for index in 28:
			var x = fposmod(index * 71.3 + elapsed * (5 + index % 3), theater.size.x)
			var y = fposmod(index * 29.9 - elapsed * 2, theater.size.y)
			theater.draw_circle(Vector2(x, y), 1 + index % 2, Color(.9, .8, .6, .15))

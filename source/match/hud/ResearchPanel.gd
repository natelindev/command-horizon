extends VBoxContainer

const Technologies = preload("res://source/match/research/TechnologyCatalog.gd")
const ResearchButton = preload("res://source/match/hud/ResearchButton.gd")
const Presentation = preload("res://source/match/hud/ResearchPresentation.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const ICONS = Presentation.ICONS
var lab
var player
var _active_row: HBoxContainer
var _active_icon: TextureRect
var _active_title: Label
var _project = {}
var _rate = 1.0
var _status: Label
var _progress
var _start
var _cancel
var _grid
var _branches = {}
var _queue_list
var _queue_title
var _queue_rows = []


func _ready():
	if player == null and is_instance_valid(lab):
		player = lab.player
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new()
	_grid.name = "ResearchChoices"
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)
	_start = _tile("coordination")
	_start.name = "ResearchCoordination"
	_start.pressed.connect(
		func():
			player.technology.enqueue("coordination", lab)
			refresh()
	)
	for branch in Technologies.BRANCHES:
		if not Technologies.available(branch, player.faction):
			continue
		var button = _tile(branch)
		button.pressed.connect(_research_branch.bind(branch))
		_branches[branch] = {"button": button}
	var footer = HBoxContainer.new()
	footer.name = "ResearchState"
	footer.add_theme_constant_override("separation", 8)
	add_child(footer)
	_active_row = HBoxContainer.new()
	_active_row.name = "ActiveResearch"
	_active_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_row.add_theme_constant_override("separation", 8)
	_active_row.mouse_filter = Control.MOUSE_FILTER_PASS
	footer.add_child(_active_row)
	_active_icon = TextureRect.new()
	_active_icon.name = "ActiveIcon"
	_active_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_active_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_active_icon.custom_minimum_size = Vector2(32, 32)
	_active_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_active_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_row.add_child(_active_icon)
	var details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 1)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_row.add_child(details)
	_active_title = Label.new()
	_active_title.name = "ActiveTitle"
	_active_title.add_theme_font_override("font", BattleTheme.display_font())
	_active_title.add_theme_font_size_override("font_size", 13)
	_active_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_active_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(_active_title)
	_status = Label.new()
	_status.name = "ActiveStatus"
	_status.add_theme_font_override("font", BattleTheme.numeral_font())
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", BattleTheme.MUTED)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(_status)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 4
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("fill", BattleTheme.bar_fill(BattleTheme.accent()))
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(_progress)
	_cancel = Button.new()
	_cancel.name = "CancelResearch"
	_cancel.icon = BattleTheme.icon("stop")
	_cancel.add_theme_constant_override("icon_max_width", 16)
	_cancel.custom_minimum_size = Vector2(36, 36)
	_cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cancel.accessibility_name = tr("Cancel & refund")
	_cancel.pressed.connect(_cancel_active)
	_active_row.add_child(_cancel)
	_queue_list = HBoxContainer.new()
	_queue_list.name = "ResearchQueue"
	_queue_list.add_theme_constant_override("separation", 4)
	footer.add_child(_queue_list)
	_queue_title = Label.new()
	_queue_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_title.add_theme_font_size_override("font_size", 13)
	_queue_title.hide()
	_queue_list.add_child(_queue_title)
	resized.connect(_fit_grid)
	_fit_grid()
	refresh()


func _tile(branch):
	var button = ResearchButton.new()
	button.name = "Research" + branch.capitalize()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(button)
	return button


func _fit_grid():
	# Research choices retain their visible names, prices and state.
	_grid.columns = clampi(floori((size.x + 6) / 156), 1, _grid.get_child_count())


func _cancel_active():
	if not is_instance_valid(player):
		return
	if player.technology.active != "":
		player.technology.cancel()
	else:
		player.cancel_coordination()
	refresh()


func _research_branch(branch):
	if not is_instance_valid(player):
		return
	var research = player.technology
	var id = Technologies.next_in_branch(branch, research.planned_technologies())
	if id != "":
		research.enqueue(id, lab)
	refresh()


func _cancel_queued(id):
	if not is_instance_valid(player):
		return
	for index in player.technology.queued.size():
		if player.technology.queued[index].id == id:
			player.technology.cancel_queued(index)
			break
	refresh()


func refresh():
	if not is_instance_valid(player) or _status == null:
		return
	if not is_instance_valid(lab) or lab.is_queued_for_deletion():
		var labs = player.get_children().filter(
			func(unit):
				return (
					"type" in unit
					and unit.type == "CommandLab"
					and unit.is_constructed()
					and not unit.is_queued_for_deletion()
				)
		)
		lab = labs[0] if not labs.is_empty() else null
	_project = Presentation.project(player, get_tree().paused)
	_rate = _project.rate if not _project.is_empty() else player.research_factor()
	_active_row.visible = not _project.is_empty()
	if not _project.is_empty():
		_active_title.text = _project.title
		_status.text = _project.status
		_progress.value = _project.progress
		_active_icon.texture = Presentation.icon_for(_project.id)
		_active_row.tooltip_text = _project.detail
		_cancel.tooltip_text = (
			_project.detail
			+ "\n"
			+ tr("Cancel and refund. Dependent queued upgrades are refunded too.")
		)
		_cancel.accessibility_description = _cancel.tooltip_text
	_refresh_coordination()
	for branch in _branches:
		_refresh_branch(branch)
	_refresh_queue()


func _refresh_coordination():
	var reason = tr(player.technology.queue_reason("coordination", lab))
	var description = (
		tr("Coordination unlocks long-range armor and %s. Queued projects run in order.")
		% tr(load("res://source/match/FactionCatalog.gd").signature_title(player.faction))
	)
	_update_tile(
		_start,
		"coordination",
		tr("Coordination"),
		player.COORDINATION_COST,
		description,
		player.COORDINATION_DURATION,
		reason,
		{
			"complete": player.coordination_unlocked,
			"active": player.coordination_left > 0,
			"left": player.coordination_left,
			"queued": player.technology.queued.any(func(entry): return entry.id == "coordination")
		}
	)


func _refresh_branch(branch):
	var research = player.technology
	var id = Technologies.next_in_branch(branch, research.planned_technologies())
	# A branch with no further purchase keeps its latest active/queued/completed
	# card visible. The ordered list below holds every already purchased project.
	if id == "":
		id = branch + "_3" if branch in ["weapons", "armor"] else branch
	var complete = id in research.completed
	var item = Technologies.ITEMS[id]
	_update_tile(
		_branches[branch].button,
		branch,
		tr(Technologies.title(id, player.faction)),
		{"resource_a": item.cost.x, "resource_b": item.cost.y},
		tr(Technologies.description(id, player.faction)),
		item.seconds,
		tr(research.queue_reason(id, lab)),
		{
			"complete": complete,
			"active": research.active == id,
			"left": research.left,
			"queued": research.queued.any(func(entry): return entry.id == id)
		}
	)


func _update_tile(button, branch, title, cost, description, seconds, reason, progress):
	button.show_role(_icon_for(branch), title, cost)
	button.disabled = progress.complete or reason != ""
	var research = player.technology
	var planned = research.planned_technologies()
	var excluded = Technologies.exclusion(branch, planned)
	var doctrine = Technologies.EXCLUSIVE_PAIRS.any(func(pair): return branch in pair)
	var state = "available"
	var marker = tr("Core") if branch == "coordination" else (tr("Choose one") if doctrine else "")
	if progress.complete:
		state = "completed"
		marker = "✓"
	elif progress.active:
		state = "active"
		marker = "Ⅱ" if _project.paused or _project.missing_lab else tr("%d s") % _project.seconds
	elif progress.queued:
		state = "queued"
		for index in research.queued.size():
			if research.queued[index].id == branch:
				marker = "Q%d" % (index + 1)
				break
	elif excluded != "":
		state = "excluded" if excluded in research.completed else "reserved"
		marker = tr("Excluded") if state == "excluded" else tr("Reserved")
		reason = (
			(
				tr("Permanently excluded by %s.")
				if state == "excluded"
				else tr("Reserved by %s. Cancel that project to choose this doctrine.")
			)
			% tr(Technologies.title(excluded, player.faction))
		)
	elif Technologies.requirements(branch).any(func(id): return id not in planned):
		state = "locked"
		marker = tr("Locked")
	elif reason != "":
		state = "unavailable"
	button.show_research(state, marker, _project.get("progress", 0.0))
	var timing = tr("%d s research at current power.") % ceili(seconds / _rate)
	if progress.active:
		timing = (tr("Researching · %d s remaining") % ceili(progress.left / _rate))
		timing += "\n" + _project.detail
		reason = ""
	elif progress.complete:
		timing = tr("Research complete.")
	elif progress.queued:
		timing = tr("Queued · paid in advance")
		reason = ""
	elif reason == "" and (player.technology.active != "" or player.coordination_left > 0):
		timing += "\n" + tr("Click to queue. Resources are reserved now.")
	# Match production tooltips: title, description, price, then timing/status.
	var price = tr("%d M / %d E") % [cost.resource_a, cost.resource_b]
	button.tooltip_text = title + "\n" + description + "\n" + price + "\n" + timing
	if reason != "":
		button.tooltip_text += "\n" + reason
	if doctrine:
		button.tooltip_text += (
			"\n" + tr("Choose one doctrine. Completing it permanently excludes the other.")
		)
	button.accessibility_name = title
	button.accessibility_description = button.tooltip_text


func _refresh_queue():
	var entries = player.technology.queued
	_queue_list.visible = not entries.is_empty()
	_queue_title.text = tr("Queued research · %d") % entries.size()
	# Reuse by project ID so focus follows the same project when earlier work leaves.
	var previous = {}
	var focus_index = -1
	for index in _queue_rows.size():
		var row = _queue_rows[index]
		previous[row.id] = row
		if row.cancel.has_focus():
			focus_index = index
	var rows = []
	for index in entries.size():
		var entry = entries[index]
		var row = previous.get(entry.id)
		if row == null:
			var button = ResearchButton.new()
			button.name = "QueuedResearch" + entry.id.capitalize().replace(" ", "")
			button.compact_layout(48)
			button.pressed.connect(_cancel_queued.bind(entry.id))
			_queue_list.add_child(button)
			row = {"id": entry.id, "row": button, "title": button._title, "cancel": button}
		else:
			previous.erase(entry.id)
		rows.append(row)
		if row.row.get_index() != index + 1:
			_queue_list.move_child(row.row, index + 1)
		var title = tr(Technologies.title(entry.id, player.faction))
		row.cancel.show_role(_icon_for(entry.id), title, entry.paid)
		row.cancel.show_research("queued", "Q%d" % (index + 1))
		row.cancel.accessibility_name = tr("Cancel queued %s") % title
		row.cancel.tooltip_text = (
			row.cancel.accessibility_name
			+ "\n"
			+ tr(Technologies.description(entry.id, player.faction))
			+ "\n"
			+ tr("%d M / %d E") % [entry.paid.resource_a, entry.paid.resource_b]
			+ "\n"
			+ (
				tr("Refund %d M / %d E. Dependent queued upgrades are refunded too.")
				% [entry.paid.resource_a, entry.paid.resource_b]
			)
		)
		row.cancel.accessibility_description = row.cancel.tooltip_text

	var focus_removed = false
	for removed in previous.values():
		focus_removed = focus_removed or removed.cancel.has_focus()
		# Hide now and free after all pressed listeners (including UI audio) run.
		removed.row.hide()
		removed.row.queue_free()
	_queue_rows = rows
	if focus_removed:
		if not rows.is_empty():
			rows[mini(focus_index, rows.size() - 1)].cancel.grab_focus()
		elif _cancel.is_visible_in_tree():
			_cancel.grab_focus()
		else:
			for tile in _grid.get_children():
				if not tile.disabled:
					tile.grab_focus()
					break


func _icon_for(id):
	return Presentation.icon_for(id)

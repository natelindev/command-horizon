extends CanvasLayer

const Bindings = preload("res://source/input/KeyBindings.gd")
const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")
var hud
var model
var toggle
var panel
var rows = {}
var _list
var _empty
var _clear
var _close
var _dirty = true
var _elapsed = 0.0
var _open_order = []
var _last_unread = 0


func _ready():
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	model = hud.get_parent().alerts
	model.changed.connect(func(): _dirty = true)
	Globals.options.changed.connect(func(): _dirty = true)
	toggle = Button.new()
	toggle.name = "AlertsBeacon"
	toggle.theme = BattleTheme.create()
	# A keycap docked in the system plate; it lights up amber while events need attention.
	toggle.custom_minimum_size = Vector2(164, 38)
	toggle.icon = BattleTheme.icon("alerts")
	toggle.expand_icon = true
	toggle.add_theme_constant_override("icon_max_width", 18)
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.clip_text = true
	toggle.tooltip_text = "Battle alerts · inspect events and affected units without changing orders."
	toggle.pressed.connect(_toggle)
	add_child(toggle)
	panel = PanelContainer.new()
	hud._style(panel)
	add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var heading = HBoxContainer.new()
	box.add_child(heading)
	var title = Label.new()
	title.text = "BATTLE ALERTS"
	title.theme_type_variation = "HudHeading"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_close = hud._button(heading, "Close", close)
	_close.theme_type_variation = "BattleQuietButton"
	_close.add_theme_font_size_override("font_size", 12)
	_clear = hud._button(box, "Clear history", model.clear_history)
	_clear.theme_type_variation = "BattleQuietButton"
	_clear.size_flags_horizontal = Control.SIZE_SHRINK_END
	_clear.add_theme_font_size_override("font_size", 12)
	_clear.tooltip_text = "Remove losses and resolved alerts. Active problems remain visible."
	var scroll = ScrollContainer.new()
	scroll.name = "History"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_empty = Label.new()
	_empty.text = "No alerts yet."
	_empty.custom_minimum_size.y = 60
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(_empty)
	panel.hide()
	_layout()
	_refresh()


func _process(delta):
	_layout()
	var available = _available()
	toggle.visible = available
	if not available:
		panel.hide()
	_elapsed += delta / maxf(Engine.time_scale, 0.001)
	if _dirty and _elapsed >= 0.2:
		_elapsed = 0
		_refresh()


func _available():
	return (
		not hud.get_parent().finished
		and hud._overlay == null
		and not is_instance_valid(Globals.settings_dialog)
		and not is_instance_valid(get_node("/root/SaveManager").dialog)
	)


func _layout():
	var viewport = get_viewport().get_visible_rect().size
	var slot = hud.get("alert_slot")
	if is_instance_valid(slot) and slot.is_visible_in_tree():
		toggle.position = slot.get_global_rect().position
		toggle.size = slot.size
	else:
		toggle.position = Vector2(viewport.x - toggle.size.x - 12, HudLayout.TOP_RAIL + 6)
	panel.position = Vector2(
		viewport.x - 404, maxf(HudLayout.TOP_PLATE, hud.system_plate.size.y) + 4
	)
	panel.size = Vector2(390, minf(480, viewport.y - 170))


func _toggle():
	if not _available():
		return
	if panel.visible:
		close()
	else:
		_open_order.clear()
		panel.show()
		_refresh()
		_list.get_parent().scroll_vertical = 0
		model.mark_read()
		_close.grab_focus()


func close():
	panel.hide()
	_open_order.clear()
	if toggle.visible:
		toggle.grab_focus()


func _refresh():
	_dirty = false
	_close.text = Bindings.hint("Close", "toggle_match_menu")
	var unread = model.unread_count()
	if unread > _last_unread:
		load("res://source/match/hud/HudMotion.gd").play(toggle, true)
	_last_unread = unread
	var active = model.entries.filter(func(entry): return entry.active).size()
	toggle.text = "Alerts · %d new" % unread if unread > 0 else "Alerts · %d active" % active
	if unread == 0 and active == 0:
		toggle.text = "Alerts"
	# Incoming fire should be visible without opening history. Reading an
	# event does not resolve it; the model's simulation-time expiry does.
	for entry in model.entries:
		if not entry.active:
			continue
		if entry.kind == "base_attack":
			toggle.text = "Base under attack"
			break
		if entry.kind == "attack":
			toggle.text = "Units under attack"
	toggle.tooltip_text = (
		"%d new · %d active alerts. Open history to inspect locations and units. Orders stay unchanged."
		% [unread, active]
	)
	_beacon(unread > 0 or toggle.text.ends_with("under attack"))
	toggle.accessibility_description = toggle.text + ". " + toggle.tooltip_text
	var ordered = model.entries.duplicate()
	ordered.sort_custom(_before)
	if panel.visible:
		_open_order = ordered.map(func(entry): return entry.id)
	var retained = []
	for index in ordered.size():
		var entry = ordered[index]
		retained.append(entry.id)
		if not rows.has(entry.id):
			rows[entry.id] = _row(entry.id)
		var row = rows[entry.id]
		_list.move_child(row.panel, index + 1)
		row.title.text = entry.title
		row.detail.text = entry.detail
		var stamp = int(entry.last)
		var state = "Active" if entry.active else ("Resolved" if entry.kind != "loss" else "Loss")
		var count = ""
		if entry.condition and entry.kind != "power":
			var noun = "engineer" if entry.count == 1 else "engineers"
			count = " · %d %s" % [entry.count, "queued" if entry.kind == "production" else noun]
		row.meta.text = "%02d:%02d · %s%s" % [stamp / 60, stamp % 60, state, count]
		row.action.text = "Go to field" if entry.kind.begins_with("field_") else "Show"
		row.action.tooltip_text = "Inspect the location and surviving units without changing orders."
		row.style.bg_color = Color.TRANSPARENT
		row.title.add_theme_color_override(
			"font_color", Color("e0c38d") if entry.active else Color("9aa8ad")
		)
	for id in rows.keys():
		if id not in retained:
			var focused = get_viewport().gui_get_focus_owner()
			if focused != null and rows[id].panel.is_ancestor_of(focused):
				_close.grab_focus()
			rows[id].panel.queue_free()
			rows.erase(id)
	_empty.visible = ordered.is_empty()
	_clear.disabled = model.entries.all(func(entry): return entry.active)
	if panel.visible and unread > 0:
		model.mark_read()


func _beacon(lit):
	# A steady filled key remains readable with motion and flashes disabled.
	toggle.theme_type_variation = "BattlePrimaryButton" if lit else ""


func _before(a, b):
	# Keep targets still under the pointer while the history is open.
	if panel.visible and not _open_order.is_empty():
		var a_index = _open_order.find(a.id)
		var b_index = _open_order.find(b.id)
		if a_index >= 0 or b_index >= 0:
			if a_index < 0:
				return false
			if b_index < 0:
				return true
			return a_index < b_index
	var a_resolved = not a.active and a.kind != "loss"
	var b_resolved = not b.active and b.kind != "loss"
	if a_resolved != b_resolved:
		return not a_resolved
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.last > b.last


func _label(parent, size):
	var label = Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 274
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _row(id):
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_width_bottom = 2
	style.border_color = Color("00000070")
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 8
	style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", style)
	_list.add_child(card)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var marker = Control.new()
	marker.custom_minimum_size.x = 16
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(marker)
	marker.draw.connect(
		func():
			marker.draw_line(Vector2(8, 25), Vector2(8, marker.size.y), Color("c4a56a30"), 1)
			marker.draw_colored_polygon(
				PackedVector2Array(
					[Vector2(8, 7), Vector2(13, 13), Vector2(8, 19), Vector2(3, 13)]
				),
				Color("d8bc80")
			)
	)
	marker.resized.connect(marker.queue_redraw)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	row.add_child(box)
	var title = _label(box, 17)
	var detail = _label(box, 12)
	detail.add_theme_color_override("font_color", Color("bcc7d3"))
	var footer = HBoxContainer.new()
	box.add_child(footer)
	var meta = Label.new()
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", Color("95a4aa"))
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(meta)
	var action = hud._button(footer, "Show", func(): navigate(id))
	action.theme_type_variation = "BattleQuietButton"
	return {
		"panel": card,
		"title": title,
		"detail": detail,
		"meta": meta,
		"action": action,
		"style": style
	}


func navigate(id):
	if not _available():
		return
	var entry = model.entry_by_id(id)
	if entry == null:
		return
	hud.cancel_map_assignment()
	hud._refresh_shortcuts()
	var human = hud.get_parent()._get_human_player()
	human.get_node("StructurePlacementHandler")._cancel_structure_placement()
	var units = model.live_units(entry)
	# Historical locations remain useful even after every unit has been lost.
	var point = entry.point
	if not units.is_empty():
		MatchSignals.deselect_all_units.emit()
		for unit in units:
			unit.get_node("Selection").select()
		if entry.kind != "loss" and not entry.kind.begins_with("field_"):
			point = units[0].global_position
	hud.get_parent().get_node("IsometricCamera3D").set_position_safely(point)
	close()

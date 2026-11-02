extends VBoxContainer

const Sites = preload("res://source/match/world/PointOfInterestCatalog.gd")
var hud
var focus_site = null
var _rows = []


func _ready():
	add_theme_constant_override("separation", 10)
	var help = Label.new()
	help.text = tr(
		(
			"Right-click facilities with infantry and channel for 12 seconds. "
			+ "Enemy infantry contest sites and suspend income."
		)
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 520
	help.add_theme_font_size_override("font_size", 13)
	add_child(help)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(
		520, maxf(120, get_viewport().get_visible_rect().size.y - 270)
	)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	for site in Sites.sites(hud.get_parent()):
		if focus_site != null and site != focus_site:
			continue
		var row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		list.add_child(row)
		var heading = HBoxContainer.new()
		row.add_child(heading)
		var title = Label.new()
		title.text = tr(site.label_title)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(title)
		var view = hud._button(heading, "View", _view.bind(site))
		view.accessibility_name = tr("View") + " " + title.text
		var status = Label.new()
		status.add_theme_font_size_override("font_size", 13)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(status)
		var entry = {"site": site, "status": status, "recruit": null}
		if site.kind == "mercenary":
			var recruit = hud._button(row, "Produce", _recruit.bind(site))
			entry.recruit = recruit
		_rows.append(entry)
	refresh()


func _process(_delta):
	refresh()


func refresh():
	var viewer = hud.get_parent()._get_human_player()
	for row in _rows:
		var site = row.site
		var owner = (
			tr("Neutral")
			if site.player == null
			else (tr("Yours") if site.player == viewer else tr("Enemy owned"))
		)
		var detail = ""
		if site.kind == "refinery":
			detail = (tr("Tech refinery · 3 M / 1 E every 4 s · +50 M / 25 E on capture"))
			if site.player != null:
				detail += "\n" + site.income_status()
		elif site.kind == "data_relay":
			detail = tr("Data relay · 2 E every 5 s · full-map radar sweep")
			if site.player != null:
				detail += "\n" + site.income_status()
		elif site.kind == "repair":
			detail = tr("Repair shop · two ground machines within 5 m")
		else:
			detail = (
				tr("Mercenary camp · paid infantry recruitment · %d / 3 queued") % site.jobs.size()
			)
			if not site.jobs.is_empty():
				detail += " · " + tr("Ready in %ds") % ceili(site.jobs[0].left)
		row.status.text = owner + " · " + tr(site.capture_status(viewer)) + "\n" + detail
		row.status.tooltip_text = site.capture_help(viewer)
		if row.recruit != null:
			row.recruit.disabled = site.player != viewer


func _view(site):
	hud.get_parent().get_node("IsometricCamera3D").set_position_safely(site.global_position)
	hud._close_menu()


func _recruit(site):
	hud._close_menu()
	hud.open_camp(site)

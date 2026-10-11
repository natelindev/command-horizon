extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")

var _buttons = []


func _ready():
	get_node("/root/SaveManager").autosaves_enabled = true
	theme = ArtTheme.create()
	add_child(load("res://source/main-menu/ArtBackdrop.gd").new())

	# --- TOP BAR ---
	var top_bar = MarginContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 44
	top_bar.offset_right = -44
	top_bar.offset_top = 16
	top_bar.offset_bottom = 50
	add_child(top_bar)

	var top_hbox = HBoxContainer.new()
	top_bar.add_child(top_hbox)

	var version = Label.new()
	version.text = "v 1.0.0"
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color("74858e"))
	top_hbox.add_child(version)

	var top_spacer = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(top_spacer)

	var top_right = HBoxContainer.new()
	top_right.add_theme_constant_override("separation", 20)
	top_hbox.add_child(top_right)

	for nav_text in ["NEWS", "COMMUNITY", "MODS"]:
		var nav_btn = Button.new()
		nav_btn.text = tr(nav_text)
		nav_btn.flat = true
		nav_btn.add_theme_font_size_override("font_size", 11)
		nav_btn.add_theme_color_override("font_color", Color("9eb0b8"))
		nav_btn.add_theme_color_override("font_hover_color", Color("ffffff"))
		top_right.add_child(nav_btn)

	var mail_lbl = Label.new()
	mail_lbl.text = "✉"
	mail_lbl.add_theme_font_size_override("font_size", 13)
	mail_lbl.add_theme_color_override("font_color", Color("8ea0a8"))
	top_right.add_child(mail_lbl)

	# Profile Badge
	var profile = HBoxContainer.new()
	profile.add_theme_constant_override("separation", 8)
	top_right.add_child(profile)

	var avatar = TextureRect.new()
	avatar.texture = preload("res://assets/ui/menu/avatar.png")
	avatar.custom_minimum_size = Vector2(26, 26)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile.add_child(avatar)

	var profile_info = VBoxContainer.new()
	profile_info.add_theme_constant_override("separation", -2)
	profile.add_child(profile_info)

	var name_lbl = Label.new()
	name_lbl.text = "Player001"
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color("f0f4f6"))
	profile_info.add_child(name_lbl)

	var rank_lbl = Label.new()
	rank_lbl.text = "LV. 28"
	rank_lbl.add_theme_font_size_override("font_size", 9)
	rank_lbl.add_theme_color_override("font_color", Color("7a8f98"))
	profile_info.add_child(rank_lbl)

	# --- LEFT NAVIGATION COLUMN ---
	var left_container = MarginContainer.new()
	left_container.anchor_left = 0.0
	left_container.anchor_right = 0.0
	left_container.anchor_top = 0.0
	left_container.anchor_bottom = 1.0
	left_container.offset_left = 48
	left_container.offset_right = 390
	left_container.offset_top = 58
	left_container.offset_bottom = -24
	add_child(left_container)

	var left_col = VBoxContainer.new()
	left_col.custom_minimum_size.x = 340
	left_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_col.add_theme_constant_override("separation", 10)
	left_container.add_child(left_col)

	# Title & Slogan
	var title_box = VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	left_col.add_child(title_box)

	var title_lbl = Label.new()
	title_lbl.text = "OPEN RTS"
	title_lbl.add_theme_font_size_override("font_size", 44)
	title_lbl.add_theme_color_override("font_color", Color("ffffff"))
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title_box.add_child(title_lbl)

	var slogan_lbl = Label.new()
	slogan_lbl.text = tr("TACTICS SHAPE A BRIGHTER TOMORROW")
	slogan_lbl.add_theme_font_size_override("font_size", 10)
	slogan_lbl.add_theme_color_override("font_color", Color("8a9da6"))
	title_box.add_child(slogan_lbl)

	var top_spacer2 = Control.new()
	top_spacer2.custom_minimum_size.y = 4
	left_col.add_child(top_spacer2)

	# Hero CONTINUE Card
	var continue_btn = _hero_card(
		left_col,
		"03    CONTINUE / LOAD",
		tr("CONTINUE"),
		tr("LAST CAMPAIGN"),
		preload("res://assets/ui/menu/thumb_continue.png"),
		func(): get_node("/root/SaveManager").open_dialog()
	)

	var mid_spacer = Control.new()
	mid_spacer.custom_minimum_size.y = 4
	left_col.add_child(mid_spacer)

	# MenuActions container
	var buttons = VBoxContainer.new()
	buttons.name = "MenuActions"
	buttons.custom_minimum_size.x = 340
	buttons.size_flags_horizontal = Control.SIZE_FILL
	buttons.add_theme_constant_override("separation", 6)
	left_col.add_child(buttons)

	var campaign_btn = _menu_action(
		buttons,
		"02    CAMPAIGN",
		tr("CAMPAIGN"),
		tr("STORY DRIVEN WAR"),
		preload("res://assets/ui/menu/ico_campaign.png"),
		func(): _open("res://source/main-menu/Campaign.tscn")
	)

	var skirmish_btn = _menu_action(
		buttons,
		"01    SKIRMISH     →",
		tr("SKIRMISH"),
		tr("CUSTOM BATTLE"),
		preload("res://assets/ui/menu/ico_skirmish.png"),
		_on_play_button_pressed
	)

	_menu_action(
		buttons,
		"05    WORLD & FACTIONS",
		tr("MULTIPLAYER"),
		tr("GLOBAL OPERATIONS"),
		preload("res://assets/ui/menu/ico_multiplayer.png"),
		func(): _open("res://source/main-menu/World.tscn")
	)

	_menu_action(
		buttons,
		"Model gallery",
		tr("MODS & SHOWCASE"),
		tr("EXPAND THE FRONTIER"),
		preload("res://assets/ui/menu/ico_mods.png"),
		func(): _open("res://source/showcase/HelixShowcase.tscn")
	)

	_menu_action(
		buttons,
		"04    SETTINGS",
		tr("SETTINGS"),
		tr("GAME / GRAPHICS / AUDIO"),
		preload("res://assets/ui/menu/ico_settings.png"),
		_on_options_button_pressed
	)

	_menu_action(
		buttons,
		"Quit",
		tr("EXIT"),
		tr("SEE YOU ON THE BATTLEFIELD"),
		preload("res://assets/ui/menu/ico_exit.png"),
		_on_quit_button_pressed
	)

	var bot_spacer = Control.new()
	bot_spacer.custom_minimum_size.y = 6
	left_col.add_child(bot_spacer)

	# Bottom Quote
	var quote_lbl = Label.new()
	quote_lbl.text = "“ " + tr("WAR IS NOT THE END.\nIT IS A TEST OF A BETTER TOMORROW.") + " ”"
	quote_lbl.add_theme_font_size_override("font_size", 10)
	quote_lbl.add_theme_color_override("font_color", Color(0.65, 0.74, 0.78, 0.6))
	left_col.add_child(quote_lbl)

	# --- MIDDLE-RIGHT DRAMATIC TEXT ---
	var right_callout = MarginContainer.new()
	right_callout.anchor_left = 1.0
	right_callout.anchor_right = 1.0
	right_callout.anchor_top = 0.5
	right_callout.anchor_bottom = 0.5
	right_callout.offset_left = -300
	right_callout.offset_right = -56
	right_callout.offset_top = 0
	right_callout.offset_bottom = 80
	add_child(right_callout)

	var callout_lbl = Label.new()
	callout_lbl.text = tr("REAL STRATEGY\nREAL BATTLEFIELD\nA LARGER TOMORROW")
	callout_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	callout_lbl.add_theme_font_size_override("font_size", 13)
	callout_lbl.add_theme_color_override("font_color", Color(0.72, 0.80, 0.84, 0.5))
	right_callout.add_child(callout_lbl)

	# --- BOTTOM-RIGHT 3 NEWS CARDS ---
	var cards_margin = MarginContainer.new()
	cards_margin.anchor_left = 1.0
	cards_margin.anchor_right = 1.0
	cards_margin.anchor_top = 1.0
	cards_margin.anchor_bottom = 1.0
	cards_margin.offset_left = -728
	cards_margin.offset_right = -40
	cards_margin.offset_top = -124
	cards_margin.offset_bottom = -24
	add_child(cards_margin)

	var cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 14)
	cards_margin.add_child(cards_hbox)

	_news_card(
		cards_hbox,
		"Bastion demo",
		preload("res://assets/ui/menu/card_tank.png"),
		tr("1.0 OFFICIAL LAUNCH"),
		tr("A NEW FRONTIER BEGINS →"),
		func(): _open("res://source/match/BastionDemo.tscn")
	)

	_news_card(
		cards_hbox,
		"Credits",
		preload("res://assets/ui/menu/card_mech.png"),
		tr("JOIN OUR COMMUNITY"),
		tr("STRATEGY LIVES TOGETHER →"),
		_on_credits_button_pressed
	)

	_news_card(
		cards_hbox,
		"Model gallery preview",
		preload("res://assets/ui/menu/card_ridge.png"),
		tr("NEW MAP: FROZEN RIDGE"),
		tr("NOW AVAILABLE →"),
		func(): _open("res://source/showcase/HelixShowcase.tscn")
	)

	ArtTheme.animate_buttons(self)
	skirmish_btn.grab_focus()

	if Globals.options.menu_motion:
		left_col.modulate.a = 0.0
		cards_hbox.modulate.a = 0.0
		right_callout.modulate.a = 0.0
		var fade = create_tween()
		fade.tween_property(left_col, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
		fade.parallel().tween_property(cards_hbox, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
		fade.parallel().tween_property(right_callout, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


func _hero_card(parent, action_name, title, subtitle, thumb_tex, callback):
	var btn = Button.new()
	btn.name = action_name.strip_edges().replace(" ", "_")
	btn.text = action_name
	btn.custom_minimum_size = Vector2(340, 58)
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))

	var normal_box = ArtTheme.panel(
		Color(0.10, 0.14, 0.17, 0.78), 6, 4, Color("c8973d"), 1
	)
	var hover_box = ArtTheme.panel(
		Color(0.18, 0.25, 0.30, 0.92), 6, 4, Color("e5b35c"), 1
	)
	btn.add_theme_stylebox_override("normal", normal_box)
	btn.add_theme_stylebox_override("hover", hover_box)
	btn.add_theme_stylebox_override("pressed", normal_box)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("margin_left", 6)
	hbox.add_theme_constant_override("margin_right", 12)
	hbox.add_theme_constant_override("separation", 10)
	btn.add_child(hbox)

	var pad_left = Control.new()
	pad_left.custom_minimum_size.x = 2
	hbox.add_child(pad_left)

	var thumb = TextureRect.new()
	thumb.texture = thumb_tex
	thumb.custom_minimum_size = Vector2(60, 42)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(thumb)

	var text_vbox = VBoxContainer.new()
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(text_vbox)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color("fff6e0"))
	text_vbox.add_child(title_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color("c8a870"))
	text_vbox.add_child(sub_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	var arrow = Label.new()
	arrow.text = ">"
	arrow.add_theme_font_size_override("font_size", 15)
	arrow.add_theme_color_override("font_color", Color("c8973d"))
	hbox.add_child(arrow)

	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _menu_action(parent, action_name, title, subtitle, icon_tex, callback):
	var btn = Button.new()
	btn.name = action_name.strip_edges().replace(" ", "_")
	btn.text = action_name
	btn.custom_minimum_size = Vector2(340, 44)
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))

	var normal_box = ArtTheme.panel(Color(0.06, 0.09, 0.12, 0.35), 6, 4)
	var hover_box = ArtTheme.panel(Color(0.18, 0.26, 0.32, 0.75), 6, 4)
	btn.add_theme_stylebox_override("normal", normal_box)
	btn.add_theme_stylebox_override("hover", hover_box)
	btn.add_theme_stylebox_override("pressed", normal_box)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	btn.add_child(hbox)

	var pad_left = Control.new()
	pad_left.custom_minimum_size.x = 4
	hbox.add_child(pad_left)

	var icon = TextureRect.new()
	icon.texture = icon_tex
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var text_vbox = VBoxContainer.new()
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_theme_constant_override("separation", 0)
	hbox.add_child(text_vbox)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color("f0f4f6"))
	text_vbox.add_child(title_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_size_override("font_size", 9)
	sub_lbl.add_theme_color_override("font_color", Color("7e9098"))
	text_vbox.add_child(sub_lbl)

	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _news_card(parent, action_name, img_tex, title, subtitle, callback):
	var btn = Button.new()
	btn.name = action_name.strip_edges().replace(" ", "_")
	btn.text = action_name
	btn.custom_minimum_size = Vector2(220, 96)
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))

	var normal_box = ArtTheme.panel(
		Color(0.08, 0.11, 0.14, 0.82), 4, 4, Color(0.25, 0.35, 0.40, 0.3), 1
	)
	var hover_box = ArtTheme.panel(
		Color(0.14, 0.20, 0.25, 0.95), 4, 4, Color(0.40, 0.55, 0.65, 0.6), 1
	)
	btn.add_theme_stylebox_override("normal", normal_box)
	btn.add_theme_stylebox_override("hover", hover_box)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
	btn.add_child(vbox)

	var img = TextureRect.new()
	img.texture = img_tex
	img.custom_minimum_size = Vector2(212, 50)
	img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(img)

	var pad_margin = MarginContainer.new()
	pad_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad_margin.add_theme_constant_override("margin_left", 8)
	pad_margin.add_theme_constant_override("margin_right", 8)
	vbox.add_child(pad_margin)

	var info_vbox = VBoxContainer.new()
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_theme_constant_override("separation", 0)
	pad_margin.add_child(info_vbox)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color("f0f4f6"))
	info_vbox.add_child(title_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_size_override("font_size", 9)
	sub_lbl.add_theme_color_override("font_color", Color("7a8f98"))
	info_vbox.add_child(sub_lbl)

	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _open(path):
	get_tree().change_scene_to_file(path)


func _on_play_button_pressed():
	_open("res://source/main-menu/Play.tscn")


func _on_options_button_pressed():
	Globals.open_settings()


func _on_credits_button_pressed():
	_open("res://source/main-menu/Credits.tscn")


func _on_quit_button_pressed():
	get_tree().quit()

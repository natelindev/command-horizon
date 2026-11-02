extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "language": "zh_CN"})
	_check(TranslationServer.get_locale() == "zh_CN", "Chinese locale not applied")
	_check(
		TranslationServer.translate("S", "map_repair") == "修",
		"Repair-site map marker is not localized"
	)
	await _loading_translations()
	for pair in [
		["25 Energy", "25 能量"],
		["Armed · Select target on map", "已准备 · 在地图上选择目标"],
		["Destroyed", "已摧毁"],
		["Rockets · %d/%d", "火箭弹 · %d/%d"],
		["Start %d · %s", "出生点 %d · %s"],
		["Settings", "设置"],
		["NORTH RELAY", "北侧中继站"],
		["SOUTH RELAY", "南侧中继站"],
		["North Refinery", "北侧炼油厂"],
		["West Mercenary Camp", "西侧佣兵营地"],
		["Garrison 2 / 8", "驻军 2 / 8"],
		["⚒ Idle: 3", "⚒ 空闲：3"],
		["Atk Move", "攻击移动"],
		["N ↑", "北 ↑"],
		[
			"Build Flux generator (15 M / 0 E). Low power slows production and service buildings.",
			"建造 通量发电机（15 材料 / 0 电子元件）。 供电不足会降低生产与维修速度。"
		],
		["Stop", "停止"],
		["Patrol [P]", "巡逻 [P]"],
		["Patrol: choose a destination.", "巡逻：请选择目的地。"],
		["High ground · vision and range bonus", "高地 · 视野和射程加成"],
		["Bronze · Reload 4% faster · Movement +3%", "铜级 · 装填时间缩短4% · 移动速度+3%"],
		["Return to results", "返回战果"],
		["R: refinery · M: mercenary camp · S: repair shop", "油：炼油厂 · 兵：佣兵营地 · 修：维修站"],
		["Free an aircraft stand to resume this queue.", "腾出一个停机位以继续此生产队列。"],
		[
			(
				"Cancel construction · 80 M / 20 E back. Refunds unused construction "
				+ "costs, rounded down to whole resources."
			),
			"取消建造 · 返还 80 材料 / 20 电子元件。 返还尚未投入施工的费用，资源数量向下取整。"
		],
		["Tech path: Field workshop.", "科技路线：野战维修站。"],
		["Helix Control", "螺旋控制中心"],
		["Needle skimmer online.", "针刺悬浮战车已就绪。"],
		["Needle skimmer linked.", "针刺悬浮战车已连接。"],
		["Bastion vs Helix", "堡垒 对阵 螺旋"],
		["Manual slot 3", "手动存档 3"],
		["Cargo: 4 M / 2 E", "货物：4 材料 / 2 电子元件"],
		["01    SKIRMISH     →", "01    遭遇战     →"],
		["Headquarters", "总部"],
		["Cancel construction · 45 M / 12 E back", "取消建造 · 返还 45 材料 / 12 电子元件"],
		["80 / 320 HP", "80 / 320 生命值"],
		["4 engineers", "4 名工程师"],
		["1 engineer", "1 名工程师"],
		["POWER   29 used / 65 supply", "电力   使用 29 / 供给 65"],
		["Pause [Space]", "暂停 [Space]"],
		["Bastion Directorate  vs  Helix Systems", "堡垒统辖局  对阵  螺旋系统"]
	]:
		var actual = str(TranslationServer.translate(pair[0]))
		_check(actual == pair[1], "Translation mismatch: %s => %s" % [pair[0], actual])
	var font = load("res://assets/fonts/NotoSansSC.ttf")
	for character in "简体中文堡垒螺旋边境设置":
		_check(font.has_char(character.unicode_at(0)), "Bundled font missing " + character)
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(10)
	var dialog = root.get_node("Globals").open_settings()
	_check(dialog.controls.language.selected == 1, "Language selector lost saved locale")
	var music_before = preferences.music_volume
	dialog._preview("music_volume", .17)
	dialog._preview("language", "en")
	_check(str(TranslationServer.translate("Settings")) == "Settings", "English switch failed")
	dialog._finish(false)
	await _frames(3)
	_check(TranslationServer.get_locale() == "zh_CN", "Cancel did not restore language")
	_check(preferences.music_volume == music_before, "Cancel did not restore music volume")
	var lore = load("res://source/lore/WorldLore.gd")
	for entry in lore.FACTIONS.values():
		for value in entry.values():
			_check(TranslationServer.translate(value) != value, "Missing faction story translation")
	menu.queue_free()
	await _frames(3)
	await _skirmish("bastion")
	root.get_node("MatchSignals").deselect_all_units.emit()
	_units(game._get_human_player(), "Tank")[0].get_node("Selection").select()
	await _frames(3)
	var panel = game.find_child("UnitMenus")._behavior_panel
	_check(panel._status.text == "行为 · 自动接敌", "Behavior status not translated")
	_check(
		TranslationServer.translate(panel._buttons.guard.text) == "警戒", "Guard key not translated"
	)
	TranslationServer.set_locale("en")
	await _frames(3)
	_check(
		panel._status.text == "Behavior · Auto-engage", "Behavior status did not switch to English"
	)

	preferences.apply()
	var archive = "user://locale-regression-%d.tres" % OS.get_process_id()
	_check(preferences.persist(archive) == OK, "Language save failed")
	var stored = ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(stored.language == "zh_CN", "Saved language lost")
	DirAccess.remove_absolute(archive)
	preferences.language = "unsupported"
	preferences.apply()
	_check(preferences.language == "en", "Unsupported language did not fall back")
	game.queue_free()
	await _frames(3)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Localization regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _loading_translations():
	var messages = {"en": "Loading battle…", "zh_CN": "正在加载战斗…"}
	var previous_locale = TranslationServer.get_locale()
	for locale in messages:
		TranslationServer.set_locale(locale)
		var loading = load("res://source/main-menu/Loading.tscn").instantiate()
		var settings = load("res://source/data-model/MatchSettings.gd").new()
		settings.skirmish = true
		settings.map_path = "res://source/match/maps/BastionDesert.tscn"
		for index in range(2):
			var side = load("res://source/data-model/PlayerSettings.gd").new()
			side.controller = index + 1
			side.faction = "helix" if index == 0 else "bastion"
			settings.players.append(side)
		loading.match_settings = settings
		loading.map_path = settings.map_path
		root.add_child(loading)
		# The loading screen keeps one translated status while its real pipeline
		# advances the progress bar and hands control to the configured match.
		var progress = -1.0
		var advances = 0
		for frame in 20:
			if not is_instance_valid(loading) or loading.is_queued_for_deletion():
				break
			_check(
				loading._label.text == messages[locale],
				"Loading translation mismatch (%s): %s" % [locale, loading._label.text]
			)
			var next_progress = loading._progress_bar.value
			_check(
				next_progress >= maxf(0.0, progress) and next_progress <= 1.0,
				"Loading progress reversed or exceeded its range (%s)" % locale
			)
			if next_progress > progress:
				advances += 1
			progress = next_progress
			await physics_frame
		await _frames(3)
		_check(not is_instance_valid(loading), "Loading screen did not finish (%s)" % locale)
		_check(advances >= 2 and progress >= 0.9, "Loading stages did not advance (%s)" % locale)
		var loaded_match = current_scene
		_check(
			is_instance_valid(loaded_match) and "settings" in loaded_match,
			"Loading did not hand control to a match (%s)" % locale
		)
		if is_instance_valid(loaded_match) and "settings" in loaded_match:
			_check(loaded_match.settings == settings, "Loading lost match settings (%s)" % locale)
			_check(
				loaded_match._get_human_player().faction == "helix",
				"Loading launched the wrong faction (%s)" % locale
			)
			loaded_match.queue_free()
		await _frames(3)
	TranslationServer.set_locale(previous_locale)

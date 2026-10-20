extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "language": "zh_CN"})
	_check(TranslationServer.get_locale() == "zh_CN", "Chinese locale not applied")
	await _loading_translations()
	for pair in [
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
	quit(0 if errors.is_empty() else 1)


func _loading_translations():
	var messages = {
		"en":
		[
			"Taking ammunition out of depot...",
			"Creating map...",
			"Preparing a ground for combat...",
			"Setting up a camera...",
			"Placing units in the field..."
		],
		"zh_CN": ["正在从仓库搬运弹药…", "正在创建地图…", "正在准备战场…", "正在设置镜头…", "正在部署单位…"]
	}
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
		for expected in messages[locale]:
			_check(
				loading._label.text == expected,
				"Loading translation mismatch (%s): %s" % [locale, loading._label.text]
			)
			await physics_frame
		await _frames(3)
		current_scene.queue_free()
		await _frames(3)
	TranslationServer.set_locale(previous_locale)

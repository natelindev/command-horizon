extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "language": "zh_CN"})
	_check(TranslationServer.get_locale() == "zh_CN", "Chinese locale not applied")
	for pair in [
		["Settings", "设置"],
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
	game.hud.open_visual_editor(
		[_units(game._get_human_player(), "Tank")[0]], "user://locale-regression-programs.json"
	)
	var editor = game.hud.program_editor
	await _frames(3)
	_check(editor._trace.text == "应用前请用样本输入检查草稿。", "Read-only trace not translated")
	TranslationServer.set_locale("en")
	await _frames(2)
	_check(editor._trace.text.begins_with("Check the draft"), "Trace did not switch to English")
	editor.close_editor()
	await _frames(3)
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

extends SceneTree
var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	var catalog = load("res://source/match/BastionCatalog.gd")
	var factions = load("res://source/match/FactionCatalog.gd")
	var original = TranslationServer.get_locale()
	var roles = catalog.NAMES.keys() + catalog.MISSION_NAMES.keys()
	var checked = 0
	for faction in factions.IDS:
		for role in roles:
			TranslationServer.set_locale("en")
			var title = factions.title(faction, role)
			var base = factions._description(faction, role)
			var english = factions.description(faction, role)
			TranslationServer.set_locale("zh_CN")
			_check(
				TranslationServer.translate(title) != title,
				"Untranslated dynamic title: " + faction + ":" + role + " " + title
			)
			if not base.is_empty():
				var translated = TranslationServer.translate(base)
				_check(
					translated != base,
					"Untranslated dynamic description: " + faction + ":" + role + " " + base
				)
				var composed = TranslationServer.translate(factions.description(faction, role))
				_check(
					composed != english and composed.contains(translated),
					"Composed description lost its translated base: " + faction + ":" + role
				)
				if faction == "bastion" and role in catalog.STRUCTURES:
					_check(
						(
							composed.contains("25%")
							and composed.contains("15%")
							and not composed.contains("Bastion bulkheads")
						),
						"Bastion innate fortification paragraph was not translated: " + role
					)
			checked += 1
	TranslationServer.set_locale(original)
	for message in errors:
		push_error(message)
	print(
		"Dynamic faction titles/descriptions including composed fortifications: ",
		checked,
		" role contexts, ",
		errors.size(),
		" failures"
	)
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _check(condition, message):
	if not condition:
		errors.append(message)

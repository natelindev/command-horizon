extends Node

var _formatted: Translation


func _ready():
	var catalog = load("res://assets/translations/ui.zh_CN.translation")
	_formatted = load("res://source/localization/FormattedTranslation.gd").new(catalog)
	TranslationServer.add_translation(_formatted)


func _exit_tree():
	TranslationServer.remove_translation(_formatted)
	_formatted = null

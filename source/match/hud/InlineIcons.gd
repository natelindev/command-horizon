extends RefCounted

const MATERIALS = "res://assets/ui/economy/materials.svg"
const ELECTRONICS = "res://assets/ui/economy/electronics.svg"
const WEAPONS = "res://assets/ui/research/weapons.svg"


static func icon(path):
	return "[img height=1em]%s[/img]" % path


static func escape(text_value):
	return text_value.replace("[", "[lb]")


static func price(materials, electronics):
	return "%s %d   %s %d" % [icon(MATERIALS), materials, icon(ELECTRONICS), electronics]


static func label(font_size = 14):
	var result = RichTextLabel.new()
	result.bbcode_enabled = true
	result.fit_content = true
	result.scroll_active = false
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("normal_font_size", font_size)
	result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return result

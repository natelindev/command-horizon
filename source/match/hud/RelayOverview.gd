extends VBoxContainer

var hud
var _rows = []


func _ready():
	add_theme_constant_override("separation", 12)
	var help = Label.new()
	help.text = (
		"Optional objectives · Command destruction still decides victory.\n"
		+ "Move infantry within 3 m and hold for 10 s to capture.\n"
		+ "Ground combatants from both sides in range pause capture.\n"
		+ "Owned relays keep providing local vision without a garrison."
	)
	help.add_theme_font_size_override("font_size", 14)
	add_child(help)
	for relay in hud.get_parent().map.relays:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		add_child(row)
		var status = Label.new()
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.add_theme_font_size_override("font_size", 14)
		row.add_child(status)
		var button = hud._button(row, "View " + relay.label_title.capitalize(), _view.bind(relay))
		button.name = "View" + str(relay.name)
		button.tooltip_text = "Center the camera here. Your selection and orders stay unchanged."
		_rows.append({"relay": relay, "status": status, "button": button})
	refresh()


func _process(_delta):
	refresh()


func refresh():
	var owner = hud.get_parent()._get_human_player()
	for row in _rows:
		var relay = row.relay
		var ownership = "Neutral"
		if relay.captured_by != null:
			ownership = "Yours" if relay.captured_by == owner else "Enemy owned"
		var state = relay.capture_status(owner)
		if state not in ["Unclaimed", "Secured", "Enemy owned"]:
			ownership += " · " + state
		row.status.text = relay.label_title.capitalize() + "\n" + ownership
		row.status.tooltip_text = relay.capture_help(owner)
		row.button.accessibility_description = row.status.text + ". " + row.button.tooltip_text


func _view(relay):
	if hud.get_parent().finished:
		return
	hud.get_parent().get_node("IsometricCamera3D").set_position_safely(relay.global_position)
	hud._close_menu()

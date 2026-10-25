extends HBoxContainer

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const DESCRIPTIONS = {
	"barrage": "Six shells after a 3.5 s warning. Enemies only; requires current vision.",
	"emp":
	"Strips shields, slows ground combat vehicles and disables turrets for 6 s. Enemies only.",
	"airdrop":
	(
		"Two Outriders and a repair crate. Reserves 2 population; "
		+ "the descending carrier can be intercepted."
	),
}
var game
var _power
var _status


func _ready():
	add_theme_constant_override("separation", 16)
	var player = game._get_human_player()
	var kind = game.commander_support.power_for(player)
	_power = load("res://source/match/hud/HudKey.gd").new()
	_power.glyph = BattleTheme.icon({"barrage": "attack", "emp": "tech", "airdrop": "cargo"}[kind])
	_power.badge = "Q"
	_power.custom_minimum_size = Vector2(82, 82)
	_power.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_power.tooltip_text = (
		tr(game.commander_support.TITLES[kind]) + " [Q]\n" + tr(DESCRIPTIONS[kind])
	)
	_power.accessibility_name = _power.tooltip_text
	_power.pressed.connect(func(): game.hud.direct_orders.arm_commander())
	add_child(_power)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title = Label.new()
	title.text = tr(game.commander_support.TITLES[kind])
	title.add_theme_font_size_override("font_size", 17)
	column.add_child(title)
	var price = Label.new()
	var cost = game.commander_support.cost_for(player)
	price.text = tr("%d M / %d E") % [cost.resource_a, cost.resource_b]
	column.add_child(price)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	column.add_child(_status)
	refresh()


func refresh():
	var player = game._get_human_player()
	var support = game.commander_support
	var reason = support.disabled_reason(player)
	_power.disabled = not reason.is_empty()
	_status.text = tr(reason) if not reason.is_empty() else tr("Ready · choose a target")

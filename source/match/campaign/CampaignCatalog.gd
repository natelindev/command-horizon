# gdlint: disable=class-variable-name
extends RefCounted

const LEGACY = {
	"command_horizon":
	{
		"summary":
		(
			"At the Meridian Spire, Aegis finally reaches Nyx. Bringing her to account means "
			+ "keeping the controls intact long enough to free the people below."
		),
		"summary_zh": "在子午尖塔，埃吉斯终于找到尼克斯。要让她承担责任，就必须保护控制系统，先释放被困在下方的人。",
		"title": "Command Horizon",
		"number": "06",
		"scene": "res://source/match/campaign/CommandHorizon.tscn",
		"map": "res://source/match/maps/CommandHorizonMap.tscn",
		"size": Vector2(184, 132)
	},
	"broken_foundry":
	{
		"summary":
		(
			"Nyx’s engineering marks lead Aegis into the foundry. Kerrigan keeps his promise "
			+ "to watch Aegis’s back as the gates close."
		),
		"summary_zh": "尼克斯留下的工程标记把埃吉斯引入铸造厂。闸门合拢时，凯里根仍坚守着保护他后背的承诺。",
		"title": "Broken Foundry",
		"number": "05",
		"scene": "res://source/match/campaign/BrokenFoundry.tscn",
		"map": "res://source/match/maps/BrokenFoundryMap.tscn",
		"size": Vector2(160, 116)
	},
	"air_corridor":
	{
		"title": "Air Corridor",
		"number": "04",
		"scene": "res://source/match/campaign/AirCorridor.tscn",
		"map": "res://source/match/maps/AirCorridorMap.tscn",
		"size": Vector2(144, 104)
	},
	"supply_line":
	{
		"summary":
		(
			"Aegis leads a relief convoy out of Meridian. An intercepted voice brings back "
			+ "the night his brother disappeared."
		),
		"summary_zh": "埃吉斯带领救援车队离开子午城。一段截获的声音，让他再次想起弟弟失踪的那一夜。",
		"title": "Supply Line",
		"number": "01",
		"scene": "res://source/match/campaign/SupplyLine.tscn",
		"map": "res://source/match/maps/SupplyLineMap.tscn",
		"size": Vector2(192, 128)
	},
	"first_orders":
	{
		"summary":
		(
			"Voss trains the new recruits while Aegis follows Nyx’s signal. The people beside "
			+ "him need a commander, not another name on a casualty list."
		),
		"summary_zh": "沃斯训练新兵，埃吉斯则追踪尼克斯的信号。他身边的人需要一位指挥官，而不是伤亡名单上的又一个名字。",
		"title": "First Orders",
		"number": "02",
		"scene": "res://source/match/campaign/FirstOrders.tscn",
		"map": "res://source/match/maps/FirstOrdersMap.tscn",
		"size": Vector2(80, 64)
	},
	"split_signal":
	{
		"summary":
		(
			"The mountain relays carry Elias’s last message. Aegis and Voss race to recover "
			+ "it before Helix erases the channel."
		),
		"summary_zh": "山地中继站保存着伊莱亚斯最后的留言。埃吉斯和沃斯必须赶在螺旋抹除频道前找回它。",
		"title": "Split Signal",
		"number": "03",
		"scene": "res://source/match/campaign/SplitSignal.tscn",
		"map": "res://source/match/maps/SplitSignalMap.tscn",
		"size": Vector2(108, 88)
	}
}

const ORDER = {
	"bastion":
	[
		"supply_line",
		"first_orders",
		"split_signal",
		"bastion_cinder_ford",
		"broken_foundry",
		"command_horizon"
	],
	"helix":
	[
		"helix_quiet_streets",
		"helix_the_gate",
		"helix_cinder_ford",
		"helix_pruning",
		"helix_severance"
	],
	"frontier":
	[
		"frontier_drainage",
		"frontier_cinder_ford",
		"frontier_salvage",
		"frontier_wren",
		"frontier_the_coalition"
	]
}
static var STORIES = JSON.parse_string(
	FileAccess.get_file_as_string("res://source/match/campaign/hero-operations.json")
)
static var OPERATIONS = _operations()


static func _operations():
	var result = LEGACY.duplicate(true)
	for id in result:
		result[id].faction = "bastion"
		result[id].enemy = "helix"
		result[id].act = int(result[id].number)
	for id in STORIES:
		var entry = STORIES[id].duplicate(true)
		entry.number = "%02d" % entry.act
		entry.scene = "res://source/match/campaign/HeroOperation.tscn"
		entry.map = "res://source/match/maps/HeroTheater.tscn"
		entry.size = Vector2(168, 120)
		result[id] = entry
	return result


static func is_story(id):
	return STORIES.has(id)


static func story_key(id):
	if id in LEGACY:
		return "bastion." + id
	return id.replace("bastion_", "bastion.").replace("helix_", "helix.").replace(
		"frontier_", "frontier."
	)

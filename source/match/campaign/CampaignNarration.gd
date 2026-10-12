extends RefCounted

const PATH = "res://assets/audio/campaign/narration.json"
const MISSIONS = [
	"supply_line",
	"first_orders",
	"split_signal",
	"air_corridor",
	"broken_foundry",
	"command_horizon"
]
static var _lines = {}


static func lines():
	if _lines.is_empty():
		_lines = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _lines


static func ids(mission):
	return lines().keys().filter(
		func(key): return key.begins_with(mission + ".") or key.begins_with("common.")
	)


static func record(id, language = "en"):
	if not lines().has(id):
		return {}
	var locale = "zh_CN" if language == "zh_CN" else "en"
	var path = (
		"res://assets/audio/campaign/%s_%s.wav"
		% [id.replace(".", "_"), "zh" if locale == "zh_CN" else "en"]
	)
	return {
		"id": id,
		"speaker": "堡垒指挥部" if locale == "zh_CN" else "Bastion Command",
		"text": lines()[id][locale],
		"stream": path
	}

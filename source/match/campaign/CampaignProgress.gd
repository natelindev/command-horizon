extends RefCounted

const Campaigns = preload("res://source/match/campaign/CampaignCatalog.gd")

const PATH = "user://campaign-progress.json"
var supply_complete = false
var complete = false
var doctrine_badge = false
var split_complete = false
var network_badge = false
var horizon_complete = false
var lean_complete = false
var reinforced_complete = false
var foundry_complete = false
var air_complete = false
var air_support = false
var error = ""
var operations = []


func read_progress(path = PATH):
	error = ""
	operations.clear()
	supply_complete = false
	complete = false
	doctrine_badge = false
	split_complete = false
	network_badge = false
	horizon_complete = false
	lean_complete = false
	reinforced_complete = false
	foundry_complete = false
	air_complete = false
	air_support = false
	if not FileAccess.file_exists(path):
		return true
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4096:
		error = "Campaign progress could not be read. Existing file retained."
		return false
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		error = "Campaign progress is invalid. Existing file retained."
		return false
	var data = parser.data
	if not _valid(data):
		error = "Campaign progress is invalid. Existing file retained."
		return false
	if data.schema >= 2:
		split_complete = data.split_signal
		network_badge = data.network_badge
	supply_complete = data.get("supply_line", false)
	horizon_complete = data.get("command_horizon", false)
	lean_complete = data.get("lean_complete", false)
	reinforced_complete = data.get("reinforced_complete", false)
	foundry_complete = data.get("broken_foundry", false)
	air_complete = data.get("air_corridor", false)
	air_support = data.get("air_support", false)
	operations = data.get("operations", []).duplicate()
	complete = data.first_orders
	doctrine_badge = data.doctrine_badge
	return true


func _valid(data):
	if (
		not data is Dictionary
		or not data.get("first_orders") is bool
		or not data.get("doctrine_badge") is bool
	):
		return false
	# JSON numbers decode as floats; Array membership would reject integer schema IDs.
	if data.get("schema") == 1:
		return data.size() == 3
	var version = data.get("schema")
	if (
		version != 2
		and version != 3
		and version != 4
		and version != 5
		and version != 6
		and version != 7
	):
		return false
	return (
		data.size() == {2: 5, 3: 6, 4: 8, 5: 9, 6: 12, 7: 13}[int(version)]
		and (
			version < 6
			or (
				data.get("command_horizon") is bool
				and data.get("lean_complete") is bool
				and data.get("reinforced_complete") is bool
			)
		)
		and (version < 5 or data.get("broken_foundry") is bool)
		and (version < 3 or data.get("supply_line") is bool)
		and (version < 4 or (data.get("air_corridor") is bool and data.get("air_support") is bool))
		and data.get("split_signal") is bool
		and data.get("network_badge") is bool
		and (version < 7 or _valid_operations(data.get("operations")))
	)


func record_victory(badge, path = PATH):
	return _record("first_orders", badge, path)


func record_split_victory(badge, path = PATH):
	return _record("split_signal", badge, path)


func _record(mission, badge, path, challenge = ""):
	if not read_progress(path):
		return false
	if Campaigns.is_story(mission) and mission not in operations:
		operations.append(mission)
	var data = {
		"schema": 7,
		"operations": operations.duplicate(),
		"command_horizon": horizon_complete or mission == "command_horizon",
		"lean_complete": lean_complete or (mission == "command_horizon" and challenge == "lean"),
		"reinforced_complete":
		reinforced_complete or (mission == "command_horizon" and challenge == "reinforced"),
		"broken_foundry": foundry_complete or mission == "broken_foundry",
		# Retired Air Corridor results stay in the file; they count toward Cinder Ford.
		"air_corridor": air_complete,
		"air_support": air_support,
		"supply_line": supply_complete or mission == "supply_line",
		"first_orders": complete or mission == "first_orders",
		"doctrine_badge": doctrine_badge or (mission == "first_orders" and badge),
		"split_signal": split_complete or mission == "split_signal",
		"network_badge": network_badge or (mission == "split_signal" and badge)
	}
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Campaign progress could not be saved."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		DirAccess.remove_absolute(path + ".tmp")
		error = "Campaign progress could not be replaced."
		return false
	supply_complete = data.get("supply_line", false)
	horizon_complete = data.get("command_horizon", false)
	lean_complete = data.get("lean_complete", false)
	reinforced_complete = data.get("reinforced_complete", false)
	foundry_complete = data.get("broken_foundry", false)
	air_complete = data.get("air_corridor", false)
	air_support = data.get("air_support", false)
	operations = data.get("operations", []).duplicate()
	complete = data.first_orders
	doctrine_badge = data.doctrine_badge
	split_complete = data.split_signal
	network_badge = data.network_badge
	return true


func record_supply_victory(path = PATH):
	return _record("supply_line", false, path)


func record_foundry_victory(path = PATH):
	return _record("broken_foundry", false, path)


func record_horizon_victory(challenge = "", path = PATH):
	if challenge not in ["", "lean", "reinforced"]:
		error = "Unsupported replay challenge."
		return false
	return _record("command_horizon", false, path, challenge)


func completed_count(faction = "bastion"):
	var count = 0
	for id in Campaigns.ORDER.get(faction, []):
		if completed(id):
			count += 1
	return count


func campaign_finished(faction = "bastion"):
	return (
		faction in Campaigns.ORDER and completed_count(faction) == Campaigns.ORDER[faction].size()
	)


func _valid_operations(value):
	if not value is Array or value.size() > 11:
		return false
	var seen = []
	for id in value:
		if not Campaigns.is_story(id) or id in seen:
			return false
		seen.append(id)
	return true


func record_operation(id, path = PATH):
	if not Campaigns.is_story(id):
		error = "Unknown campaign operation."
		return false
	return _record(id, false, path)


func completed(id):
	if id in operations:
		return true
	return (
		{
			"supply_line": supply_complete,
			"first_orders": complete,
			"split_signal": split_complete,
			"bastion_cinder_ford": air_complete,
			"broken_foundry": foundry_complete,
			"command_horizon": horizon_complete
		}
		. get(id, false)
	)


func foundry_support():
	return air_support or "bastion_cinder_ford" in operations

extends RefCounted

const FileStore = preload("res://source/match/saves/SaveFile.gd")
const Schema = preload("res://source/match/saves/SnapshotSchema.gd")
const Difficulty = preload("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")
const IDS = [
	"manual-1",
	"manual-2",
	"manual-3",
	"manual-4",
	"manual-5",
	"quick",
	"auto-1",
	"auto-2",
	"auto-3"
]
var directory = "user://saves"
var error = ""
var _auto_cursor = -1


func path_for(id):
	return directory.path_join(id + ".json") if id in IDS else ""


func read_slot(id):
	error = ""
	if id not in IDS:
		error = "Unknown save slot."
		return null
	var file = FileStore.new()
	var data = file.read_file(path_for(id))
	error = file.error
	return data


func write_slot(id, snapshot):
	error = ""
	if id not in IDS or not snapshot is Dictionary:
		error = "No valid battle or slot to save."
		return false
	var schema = Schema.new()
	if not schema.validate(snapshot):
		error = "Battle could not be saved: " + schema.error
		return false
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		error = "Save folder could not be created. Existing saves retained."
		return false
	# Storage-valid but gameplay-incompatible saves must also be retained.
	if FileAccess.file_exists(path_for(id)) and not describe(id).valid:
		error = "This slot is damaged or incompatible. Choose another slot; the original is retained."
		return false
	var file = FileStore.new()
	var ok = file.write_file(path_for(id), snapshot)
	error = file.error
	if ok and id.begins_with("auto-"):
		_auto_cursor = (int(id.trim_prefix("auto-")) % 3)
	return ok


func describe(id):
	var result = {
		"id": id,
		"exists": FileAccess.file_exists(path_for(id)),
		"valid": false,
		"summary": "Empty slot",
		"modified": 0
	}
	if not result.exists:
		return result
	result.modified = FileAccess.get_modified_time(path_for(id))
	var data = read_slot(id)
	var schema = Schema.new()
	if data == null or not schema.validate(data):
		result.summary = error if data == null else "Incompatible battle: " + schema.error
		return result
	result.valid = true
	result.summary = summary_for(data, result.modified)
	return result


static func summary_for(data, modified = 0):
	var settings = data.settings
	var title = (
		(
			load("res://source/match/campaign/CampaignCatalog.gd")
			. operations()[settings.mission_id]
			. title
		)
		if settings.mission_id != ""
		else Schema.Rules.MAPS[settings.map_path].name
	)
	var seconds = int(data.simulation_time)
	return (
		"%s · %s vs %s · %s · %02d:%02d\n%s"
		% [
			title,
			settings.players[0].faction.capitalize(),
			(
				"%d rivals" % (settings.players.size() - 1)
				if settings.players.size() > 2
				else settings.players[1].faction.capitalize()
			),
			Difficulty.TAGS[Difficulty.clamp_level(settings.players[1].difficulty)],
			seconds / 60,
			seconds % 60,
			Time.get_datetime_string_from_unix_time(modified).replace("T", " ") + " UTC"
		]
	)


func next_auto_slot():
	var candidates = []
	for index in range(3):
		candidates.append(describe("auto-%d" % (index + 1)))
	if _auto_cursor < 0:
		_auto_cursor = 0
		for index in range(3):
			if not candidates[index].exists:
				_auto_cursor = index
				break
			if candidates[index].modified < candidates[_auto_cursor].modified:
				_auto_cursor = index
	for offset in range(3):
		var candidate = candidates[(_auto_cursor + offset) % 3]
		if not candidate.exists or candidate.valid:
			return candidate.id
	error = "Checkpoint slots are damaged or incompatible. Originals retained; use a manual slot."
	return ""


static func title(id):
	if id == "quick":
		return "Quicksave"
	return id.replace("manual-", "Manual slot ").replace("auto-", "Campaign checkpoint ")

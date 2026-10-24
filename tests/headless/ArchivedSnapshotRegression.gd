extends SceneTree

## Current archived scenarios must remain loadable when the save contract changes.
var _errors = []
var _checked = 0
var _checksums_checked = 0
var _manifests = {}


func _initialize():
	call_deferred("_run")


func _run():
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	var file = load("res://source/match/saves/SaveFile.gd").new()
	for directory in ["res://docs/playtests", "res://tests/fixtures"]:
		for path in _json_files(directory):
			var envelope = JSON.parse_string(FileAccess.get_file_as_string(path))
			if (
				not envelope is Dictionary
				or not envelope.get("format") is String
				or envelope.format != "open-rts-match"
			):
				continue
			var snapshot = file.read_file(path)
			if snapshot == null:
				_errors.append(path + ": " + file.error)
				continue
			if not schema.validate(snapshot):
				_errors.append(path + ": " + schema.error)
			var recorded_hash = _recorded_hash(path)
			if not recorded_hash.is_empty():
				_checksums_checked += 1
				if FileAccess.get_sha256(path) != recorded_hash:
					_errors.append(path + ": SHA256SUMS does not match the current archive")
			_checked += 1
			if _checked % 50 == 0:
				await process_frame
	if _checked == 0:
		_errors.append("No current archived snapshots were checked")
	for message in _errors:
		push_error(message)
	print(
		(
			"Archived snapshots: %d checked, %d recorded checksums, %d failures"
			% [_checked, _checksums_checked, _errors.size()]
		)
	)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _recorded_hash(path):
	var directory = path.get_base_dir()
	if not _manifests.has(directory):
		var hashes = {}
		var manifest = directory.path_join("SHA256SUMS")
		if FileAccess.file_exists(manifest):
			for line in FileAccess.get_file_as_string(manifest).split("\n"):
				var parts = line.strip_edges().split(" ", false)
				if parts.size() == 2 and parts[0].length() == 64:
					hashes[parts[1].trim_prefix("*")] = parts[0]
		_manifests[directory] = hashes
	return _manifests[directory].get(path.get_file(), "")


func _json_files(path):
	var files = []
	var directory = DirAccess.open(path)
	if directory == null:
		_errors.append("Cannot read archive directory: " + path)
		return files
	for file in directory.get_files():
		if file.ends_with(".json"):
			files.append(path.path_join(file))
	for child in directory.get_directories():
		files.append_array(_json_files(path.path_join(child)))
	return files

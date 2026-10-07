extends Node

signal finished(report)

const Research = preload("res://source/match/programs/arena/ArenaResearch.gd")
const Record = preload("res://source/match/programs/ProgramRecord.gd")
var pid = -1
var directory = ""
var token = ""
var content_hash = ""
var research = Research.baseline()
var _elapsed = 0.0
var _started_at = 0


func launch(record, faction, battle_research = null):
	if pid > 0 or not Record.validate(record) or not Record.is_script(record):
		return {"ok": false, "error": "Save or correct the draft before opening the arena."}
	if battle_research == null:
		battle_research = Research.baseline()
	if not Research.valid(battle_research):
		return {"ok": false, "error": "The battle research setup is invalid."}
	research = battle_research.duplicate(true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	token = Crypto.new().generate_random_bytes(16).hex_encode()
	content_hash = record.content_hash
	directory = ProjectSettings.globalize_path("user://program-arena/" + token)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return {"ok": false, "error": "Could not create the arena workspace."}
	var request_path = directory.path_join("request.json")
	var file = FileAccess.open(request_path, FileAccess.WRITE)
	if file == null:
		cleanup()
		return {"ok": false, "error": "Could not write the arena draft."}
	file.store_string(
		JSON.stringify({"token": token, "record": record, "faction": faction, "research": research})
	)
	file.close()
	pid = OS.create_process(OS.get_executable_path(), _arguments(request_path))
	if pid <= 0:
		cleanup()
		return {"ok": false, "error": "Could not open the test window. Your draft is retained."}
	_started_at = Time.get_ticks_msec()
	return {"ok": true}


func _arguments(request_path):
	var args = PackedStringArray()
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(
		["--log-file", directory.path_join("arena.log"), "--", "--program-arena", request_path]
	)
	return args


func _process(delta):
	if pid <= 0:
		return
	_elapsed += delta
	if _elapsed < 0.25:
		return
	_elapsed = 0.0
	if OS.is_process_running(pid):
		if (
			Time.get_ticks_msec() - _started_at > 30000
			and not FileAccess.file_exists(directory.path_join("ready"))
		):
			cancel()
			finished.emit(
				{"ok": false, "error": "Arena startup timed out. Your draft is retained."}
			)
		return
	pid = -1
	var report = _read_report()
	cleanup()
	finished.emit(report)


func _read_report():
	var file = FileAccess.open(directory.path_join("report.json"), FileAccess.READ)
	if file == null or file.get_length() > 2 * 1024 * 1024:
		return {
			"ok": false,
			"error": "Arena closed without a result. Your draft and orders are unchanged."
		}
	var report = JSON.parse_string(file.get_as_text())
	if (
		not report is Dictionary
		or report.get("token") != token
		or report.get("content_hash") != content_hash
		or report.get("research", Research.baseline()) != research
	):
		return {"ok": false, "error": "Arena result did not match this draft."}
	if not report.get("results") is Array or report.results.size() > 32:
		return {"ok": false, "error": "Arena returned an invalid result."}
	for result in report.results:
		if not _valid_result(result):
			return {"ok": false, "error": "Arena returned an invalid result."}
	return {"ok": true, "results": report.results, "content_hash": content_hash}


func _valid_result(result):
	if not result is Dictionary or not result.get("passed") is bool:
		return false
	var setup = result.get("research", Research.baseline())
	if (
		not Research.valid(setup)
		or setup not in [research, Research.baseline()]
		or not result.get("error", "") is String
		or not result.get("checks") is Array
	):
		return false
	if result.checks.size() > 12:
		return false
	for check in result.checks:
		if not check is Dictionary or not check.get("passed") is bool:
			return false
		if not check.get("text") is String or check.text.length() > 300:
			return false
	return (
		not result.passed
		or (not result.checks.is_empty() and result.checks.all(func(check): return check.passed))
	)


func cancel():
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	pid = -1
	cleanup()


func cleanup():
	if directory.is_empty():
		return
	for filename in ["request.json", "report.json", "report.tmp", "arena.log", "ready"]:
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	directory = ""


func _exit_tree():
	cancel()

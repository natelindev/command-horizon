# gdlint: disable=max-returns
extends RefCounted

const Values = preload("res://source/match/saves/SaveValue.gd")
const FORMAT = "open-rts-match"
const SCHEMA = 1
const MAX_BYTES = 64 * 1024 * 1024
var error = ""


func read_file(path):
	error = ""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return _fail("Save cannot be read or exceeds 64 MiB. Source retained.")
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _fail("Save is not valid JSON. Source retained.")
	var envelope = parser.data
	if not envelope is Dictionary or envelope.size() != 4:
		return _fail("Save header is invalid. Source retained.")
	if envelope.get("format") != FORMAT or envelope.get("schema") != SCHEMA:
		return _fail("This save version is not supported. Source retained.")
	if not envelope.get("payload") is String or not envelope.get("sha256") is String:
		return _fail("Save payload is invalid. Source retained.")
	if envelope.payload.sha256_text() != envelope.sha256:
		return _fail("Save checksum does not match. Source retained.")
	if parser.parse(envelope.payload) != OK:
		return _fail("Save payload is not valid JSON. Source retained.")
	var values = Values.new()
	var result = values.decode(parser.data)
	if not values.error.is_empty() or not result is Dictionary:
		return _fail("Save values are invalid. Source retained.")
	# This is inert data. A scene restorer must validate gameplay schema before using it.
	return result


func write_file(path, snapshot):
	error = ""
	if not snapshot is Dictionary:
		_fail("No match snapshot to save.")
		return false
	var values = Values.new()
	var encoded = values.encode(snapshot)
	if not values.error.is_empty():
		_fail(values.error)
		return false
	var payload = JSON.stringify(encoded, "", false, true)
	var text = JSON.stringify(
		{"format": FORMAT, "schema": SCHEMA, "sha256": payload.sha256_text(), "payload": payload}
	)
	if text.to_utf8_buffer().size() > MAX_BYTES:
		_fail("Save exceeds 64 MiB; previous save retained.")
		return false
	# Never overwrite a corrupt/newer save while rotating or manually replacing a slot.
	if FileAccess.file_exists(path) and read_file(path) == null:
		return false
	var temporary = path + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_fail("Could not open the temporary save. Previous save retained.")
		return false
	file.store_string(text)
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK or read_file(temporary) == null:
		DirAccess.remove_absolute(temporary)
		_fail("Could not verify the temporary save. Previous save retained.")
		return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		_fail("Could not replace the save. Previous save retained.")
		return false
	return true


func _fail(message):
	error = message
	return null

# gdlint: disable=max-returns
extends RefCounted

## Versioned framed binary archive. Each compressed inert JSON record carries
## its uncompressed SHA-256. Readers scan lengths before allocating buffers.
const Protocol = preload("res://source/match/network/NetworkProtocol.gd")
const MAGIC = [82, 84, 83, 82, 80, 76, 89, 0]
const VERSION = 1
const HEADER = 1
const COMMAND = 2
const FRAME = 3
const FOOTER = 4
const MAX_FILE_BYTES = 512 * 1024 * 1024
const MAX_RECORDS = 100000
const RECORD_HEADER_BYTES = 81
var error = ""
var records = []
var frames = []
var header = {}
var footer = {}
var _file: FileAccess
var _codec = Protocol.new()
var _writing = false
var _written_records = 0
var _written_tick = 0


func begin(path: String, metadata: Dictionary) -> bool:
	close()
	error = ""
	if not path.ends_with(".rtsreplay") or FileAccess.file_exists(path):
		error = "Choose a new .rtsreplay file. Existing recordings are retained."
		return false
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		error = "Could not create the replay recording."
		return false
	_writing = true
	_written_records = 0
	_written_tick = 0
	_file.store_buffer(PackedByteArray(MAGIC))
	_file.store_32(VERSION)
	return append(HEADER, 0, metadata)


func append(kind: int, tick: int, data: Dictionary) -> bool:
	if _file == null or not _writing or kind not in [HEADER, COMMAND, FRAME, FOOTER] or tick < 0:
		error = "Replay recorder is not available."
		return false
	var plain = _codec.encode(data)
	if plain.is_empty():
		error = _codec.error
		return false
	var packed = plain.compress(FileAccess.COMPRESSION_DEFLATE)
	return append_prepared(kind, tick, prepare_record(plain, packed))


static func prepare_record(
	plain: PackedByteArray, packed: PackedByteArray = PackedByteArray()
) -> Dictionary:
	if packed.is_empty():
		packed = plain.compress(FileAccess.COMPRESSION_DEFLATE)
	return {
		"plain_size": plain.size(),
		"packed": packed,
		"checksum": Protocol.digest(plain).hex_decode(),
		"packed_checksum": Protocol.digest(packed).hex_decode()
	}


func append_prepared(kind: int, tick: int, prepared: Dictionary) -> bool:
	if _file == null or not _writing or kind not in [HEADER, COMMAND, FRAME, FOOTER] or tick < 0:
		error = "Replay recorder is not available."
		return false
	if tick < _written_tick or _written_records >= MAX_RECORDS - (0 if kind == FOOTER else 1):
		error = "Replay reached its record limit or received an out-of-order event."
		return false
	var packed: PackedByteArray = prepared.packed
	# Always leave enough room to close a playable recording at either limit.
	var footer_reserve = 0 if kind == FOOTER else 2048
	if _file.get_position() + packed.size() + RECORD_HEADER_BYTES + footer_reserve > MAX_FILE_BYTES:
		error = "Replay reached its 512 MiB recording limit."
		return false
	_file.store_8(kind)
	_file.store_64(tick)
	_file.store_32(prepared.plain_size)
	_file.store_32(packed.size())
	_file.store_buffer(prepared.checksum)
	_file.store_buffer(prepared.packed_checksum)
	_file.store_buffer(packed)
	_written_records += 1
	_written_tick = tick
	if kind in [HEADER, FOOTER] or tick % 300 == 0:
		_file.flush()
	if _file.get_error() != OK:
		error = "Replay recording could not be written."
		return false
	return true


func finish(tick: int, hash_value: String) -> bool:
	var success = append(FOOTER, tick, {"hash": hash_value, "tick": tick})
	close()
	return success


func open_read(path: String) -> bool:
	close()
	error = ""
	records.clear()
	frames.clear()
	header = {}
	footer = {}
	_file = FileAccess.open(path, FileAccess.READ)
	if _file == null or _file.get_length() < 12 or _file.get_length() > MAX_FILE_BYTES:
		return _fail("Replay is unavailable or exceeds its size limit.")
	if _file.get_buffer(8) != PackedByteArray(MAGIC) or _file.get_32() != VERSION:
		return _fail("Unsupported replay header or version.")
	var previous_tick = 0
	while _file.get_position() < _file.get_length():
		if (
			records.size() >= MAX_RECORDS
			or _file.get_length() - _file.get_position() < RECORD_HEADER_BYTES
		):
			return _fail("Replay record header is truncated or exceeds limits.")
		var offset = _file.get_position()
		var kind = _file.get_8()
		var tick = _file.get_64()
		var plain_size = _file.get_32()
		var packed_size = _file.get_32()
		var checksum = _file.get_buffer(32).hex_encode()
		var packed_checksum = _file.get_buffer(32).hex_encode()
		if (
			kind not in [HEADER, COMMAND, FRAME, FOOTER]
			or tick < previous_tick
			or plain_size == 0
			or plain_size > Protocol.MAX_BYTES
			or packed_size == 0
			or packed_size > Protocol.MAX_BYTES
			or packed_size > _file.get_length() - _file.get_position()
		):
			return _fail("Replay record length, type or tick is invalid.")
		var packed = _file.get_buffer(packed_size)
		if Protocol.digest(packed) != packed_checksum:
			return _fail("Replay compressed record checksum does not match.")
		var plain = packed.decompress(plain_size, FileAccess.COMPRESSION_DEFLATE)
		if plain.size() != plain_size or Protocol.digest(plain) != checksum:
			return _fail("Replay record checksum does not match.")
		var value = _codec.decode(plain)
		if not value is Dictionary:
			return _fail("Replay record contains invalid data.")
		var record = {"offset": offset, "kind": kind, "tick": tick}
		records.append(record)
		if kind == HEADER:
			if records.size() != 1 or tick != 0:
				return _fail("Replay contains an unexpected initial header.")
			header = value
		elif kind == FRAME:
			frames.append(records.size() - 1)
		elif kind == FOOTER:
			if _file.get_position() != _file.get_length():
				return _fail("Replay contains records after its footer.")
			footer = value
		previous_tick = tick
	if header.is_empty() or footer.is_empty() or frames.is_empty():
		return _fail("Replay is incomplete; the original file is retained.")
	return true


func read_record(index: int) -> Dictionary:
	if _file == null or _writing or index < 0 or index >= records.size():
		return {}
	_file.seek(records[index].offset + 9)
	var plain_size = _file.get_32()
	var packed_size = _file.get_32()
	var checksum = _file.get_buffer(32).hex_encode()
	var packed_checksum = _file.get_buffer(32).hex_encode()
	var packed = _file.get_buffer(packed_size)
	if Protocol.digest(packed) != packed_checksum:
		_fail("Replay changed while it was open.")
		return {}
	var plain = packed.decompress(plain_size, FileAccess.COMPRESSION_DEFLATE)
	if Protocol.digest(plain) != checksum:
		_fail("Replay changed while it was open.")
		return {}
	var result = _codec.decode(plain)
	return result if result is Dictionary else {}


func frame_at(tick: int) -> int:
	var low = 0
	var high = frames.size() - 1
	var selected = -1
	while low <= high:
		var middle = (low + high) / 2
		if records[frames[middle]].tick <= tick:
			selected = frames[middle]
			low = middle + 1
		else:
			high = middle - 1
	return selected


func close():
	if _file != null:
		_file.close()
	_file = null
	_writing = false


func _fail(message: String) -> bool:
	error = message
	close()
	return false

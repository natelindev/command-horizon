extends RefCounted

## Only typed intent ordering and canonical quantized state are deterministic.
## Physics/navigation remain authoritative on one server at fixed 60 Hz.
const TICKS_PER_SECOND = 60
const INPUT_DELAY = 2
const COMMANDS_PER_SECOND = 64
# A legal100-unit gesture is one packet but still costs100 operations. This
# separate bound admits group controls without multiplying work by128×64.
const OPERATIONS_PER_SECOND = 1024
const Protocol = preload("res://source/match/network/NetworkProtocol.gd")
var tick = 0
var pending = []
var last_sequences = {}
var error = ""
var _buckets = {}


func enqueue(slot: int, sequence: int, intent: Dictionary) -> bool:
	if slot < 0 or sequence <= last_sequences.get(slot, 0) or sequence > 1000000000:
		error = "Duplicate, stale or invalid command sequence."
		return false
	var bucket = _buckets.get(slot, {"second": -1, "count": 0, "work": 0})
	var second = tick / TICKS_PER_SECOND
	if bucket.second != second:
		bucket = {"second": second, "count": 0, "work": 0}
	var work = Protocol.work_cost(intent)
	if (
		bucket.count >= COMMANDS_PER_SECOND
		or bucket.work + work > OPERATIONS_PER_SECOND
		or pending.size() >= 512
	):
		error = "Command rate limit exceeded."
		return false
	bucket.count += 1
	bucket.work += work
	_buckets[slot] = bucket
	last_sequences[slot] = sequence
	pending.append(
		{
			"tick": tick + INPUT_DELAY,
			"slot": slot,
			"seq": sequence,
			"intent": intent.duplicate(true)
		}
	)
	error = ""
	return true


func advance(apply: Callable) -> Array:
	tick += 1
	pending.sort_custom(_before)
	var results = []
	while not pending.is_empty() and pending[0].tick <= tick:
		var command = pending.pop_front()
		command["result"] = apply.call(command.slot, command.intent)
		results.append(command)
	return results


func _before(a, b) -> bool:
	if a.tick != b.tick:
		return a.tick < b.tick
	if a.slot != b.slot:
		return a.slot < b.slot
	return a.seq < b.seq

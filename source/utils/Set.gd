extends RefCounted

const SCRIPT_PATH = "res://source/utils/Set.gd"

var _data = {}


static func from_array(array):
	# Runtime lookup avoids a strong self-script reference in factory bytecode.
	var a_set = load(SCRIPT_PATH).new()
	a_set.merge(array)
	return a_set


static func subtracted(minuend, subtrahend):
	var difference = load(SCRIPT_PATH).new()
	for item in minuend.iterate():
		if not subtrahend.has(item):
			difference.add(item)
	return difference


func add(item):
	_data[item] = true


func merge(data):
	if data is Array:
		for item in data:
			add(item)
	else:
		for item in data.iterate():
			add(item)


func erase(item):
	_data.erase(item)


func peek():
	for item in _data:
		return item


func peek_random(rng):
	return _data.keys()[rng.randi() % _data.keys().size()]


func pop():
	if empty():
		return null
	var item = _data.keys()[0]
	_data.erase(item)
	return item


func clear():
	_data = {}


func has(item):
	return _data.has(item)


func iterate():
	return _data


func empty():
	return _data.is_empty()


func is_empty():
	return _data.is_empty()


func size():
	return _data.size()


func to_str():
	return "Set({0})".format([str(_data.keys())])


func to_array():
	return _data.keys()

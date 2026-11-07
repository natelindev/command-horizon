extends RefCounted

## Keep the importer's index-only LODs when rigid surfaces enter a pose batch.
## Every index still addresses its original articulated vertex and material row.
const MAX_LEVELS = 3


static func read(mesh: ArrayMesh, surface: int) -> Dictionary:
	# ArrayMesh exposes LODs through its serialized surface data, unlike arrays.
	# Godot stores alternating edge lengths and 16/32-bit packed index buffers.
	var data: Array = mesh.get("_surfaces")
	var entry: Dictionary = data[surface]
	var packed: Array = entry.get("lods", [])
	var stride = 2 if entry.vertex_count <= 65536 else 4
	var result = {}
	for level in range(0, packed.size() - 1, 2):
		var bytes: PackedByteArray = packed[level + 1]
		var indices = PackedInt32Array()
		indices.resize(bytes.size() / stride)
		for index in indices.size():
			indices[index] = (
				bytes.decode_u16(index * stride)
				if stride == 2
				else bytes.decode_u32(index * stride)
			)
		result[float(packed[level])] = indices
	return result


static func combine(parts: Array) -> Dictionary:
	var thresholds = []
	for part in parts:
		for distance in part.levels:
			var scaled: float = distance * part.scale
			if scaled > 0.0 and scaled not in thresholds:
				thresholds.append(scaled)
	thresholds.sort()
	var result = {}
	var previous_count = 0
	for part in parts:
		previous_count += part.indices.size()
	var count = mini(MAX_LEVELS, thresholds.size())
	for step in count:
		var threshold: float = thresholds[ceili((step + 1.0) * thresholds.size() / count) - 1]
		var merged = PackedInt32Array()
		for part in parts:
			var chosen: PackedInt32Array = part.indices
			var chosen_distance = 0.0
			for distance in part.levels:
				if distance * part.scale <= threshold and distance >= chosen_distance:
					chosen = part.levels[distance]
					chosen_distance = distance
			for index in range(0, chosen.size(), 3):
				merged.append(chosen[index] + part.offset)
				merged.append(chosen[index + (2 if part.reflected else 1)] + part.offset)
				merged.append(chosen[index + (1 if part.reflected else 2)] + part.offset)
		if merged.size() < previous_count:
			result[threshold] = merged
			previous_count = merged.size()
	return result

extends RefCounted


static func allied(first, second):
	return (
		first == second
		or (
			is_instance_valid(first)
			and first.has_method("is_allied_with")
			and first.is_allied_with(second)
		)
	)

extends RefCounted

## One owner per match or sliced movement search. Calls never yield, and returned
## packed arrays remain independent when the result is reused by the next call.
var _parameters := NavigationPathQueryParameters3D.new()
var _result := NavigationPathQueryResult3D.new()


func _init():
	_parameters.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_NONE
	_parameters.path_postprocessing = (
		NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	)


func path(map: RID, start: Vector3, target: Vector3, layers: int = 1) -> PackedVector3Array:
	_parameters.map = map
	_parameters.start_position = start
	_parameters.target_position = target
	_parameters.navigation_layers = layers
	_result.reset()
	NavigationServer3D.query_path(_parameters, _result)
	return _result.get_path()

-- Hold your position. Direct orders always take priority.
return function(snapshot, state)
    return {intent = {kind = "hold", status = "Holding position"}, state = state}
end

-- Assign an area and a safe point before running.
-- Defend the six-metre area; regroup below 30% health until healed to 80%.
return function(snapshot, state)
    local health = snapshot.self.hp / snapshot.self.hp_max
    if health < 0.30 then state.retreating = true end
    if health >= 0.80 then state.retreating = false end
    if state.retreating then
        return {intent = {kind = "move", assignment = "safe"}, state = state}
    end
    -- The engine approaches observed enemies inside the assigned area,
    -- stops to fire at legal range, and returns when they leave.
    return {intent = {kind = "guard"}, state = state}
end

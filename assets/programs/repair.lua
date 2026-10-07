-- Repair robots only. Assign a service area before running.
return function(snapshot, state)
    for _, ally in ipairs(snapshot.allies) do
        if ally.can_repair and ally.hp < ally.hp_max then
            return {intent = {kind = "repair", target = ally.id}, state = state}
        end
    end
    return {intent = {kind = "hold", status = "Waiting for repairs"}, state = state}
end

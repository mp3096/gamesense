local ui_set, ui_get, ui_ref = ui.set, ui.get, ui.reference

local cache = { };

local function invoke_cache_callback(reference, index, condition, values)
    if (cache[index] == condition) then
        return
    end
  
    values = values or {true, false}
    condition = condition and 1 or 2

    ui_set(reference, values[condition])
    cache[index] = condition
end

client.set_event_callback("setup_command", function(cm) 
  local doubletap, hotkey = ui_ref("RAGE", "Other", "Double tap");
  local lby = ui_ref("AA", "Anti-aimbot angles", "Lower body yaw target");

  local should_call = ui_get(doubletap) and ui_get(hotkey)
  
  invoke_cache_callback(lby, "dt", should_call, {"Eye yaw", "Opposite"})
end)
--------------------------------------------------------------------------------
-- Caching common functions
--------------------------------------------------------------------------------
local client, cvar, entity, ui = client, cvar, entity, ui
local client_set_event_callback, client_userid_to_entindex
= client.set_event_callback, client.userid_to_entindex
local entity_get_local_player, entity_is_enemy
= entity.get_local_player, entity.is_enemy
local ui_get, ui_set, ui_reference, ui_set_callback, ui_set_visible, ui_new_checkbox, ui_new_slider, ui_new_combobox
= ui.get, ui.set, ui.reference, ui.set_callback, ui.set_visible, ui.new_checkbox, ui.new_slider, ui.new_combobox

--------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------
local function collect_keys(table)
    local keys = {}
    for k in pairs(table) do
        keys[#keys + 1] = k
    end
    return keys
end

local function play_sound(file, volume)
    if volume == 0 then
        return
    end
    for i=1, volume do
        cvar.playvol:invoke_callback(file, "1")
    end
end

--------------------------------------------------------------------------------
-- Constants and variables
--------------------------------------------------------------------------------
local sounds = {
    ["Wood stop"] = "doors/wood_stop1.wav",
    ["Wood strain"] = "physics/wood/wood_strain7.wav",
    ["Wood plank impact"] = "physics/wood/wood_plank_impact_hard4.wav",
    ["Warning"] = "resource/warning.wav",
}

--------------------------------------------------------------------------------
-- Menu and menu handling
--------------------------------------------------------------------------------
local menu = {
    hit_sound = ui_new_checkbox("VISUALS", "Player ESP", "Hit marker sound"),
    hit_sounds = ui_new_combobox("VISUALS", "Player ESP", "Sounds", collect_keys(sounds)),
    hit_volume = ui_new_slider("VISUALS", "Player ESP", "Volume", 1, 10, 5, true, "%", 10),
}

local function handle_menu()
    local state = ui_get(menu.hit_sound)
    ui_set_visible(menu.hit_sounds, state)
    ui_set_visible(menu.hit_volume, state)
end

handle_menu()
ui_set_callback(menu.hit_sound, handle_menu)

--------------------------------------------------------------------------------
-- Game event handling
--------------------------------------------------------------------------------
local function on_player_hurt(e)
    if not ui_get(menu.hit_sound) then
        return
    end
    if client_userid_to_entindex(e.attacker) ~= entity_get_local_player() then
        return
    end
    local current_sound = sounds[ui_get(menu.hit_sounds)]
    local current_volume = ui_get(menu.hit_volume)
    play_sound(current_sound, current_volume)
end

client_set_event_callback("player_hurt", on_player_hurt)
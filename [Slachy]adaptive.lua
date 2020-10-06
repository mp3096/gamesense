-- file:    adaptive.lua
-- version: 1.0
-- author:  peer <peer#0369>
-- updated: 07/05/2020 (dd/mm/yyyy)
-- desc:    allows you having settings for multiple weapon groups within one configuration

-- credits: Salvatore, NmChris, Sapphyrus, Aviarita and most likely some others

--/location on Gamesense menu
local menu =  { "LUA", "A" }

--#region vars & consts
local weapon_info = {}

local active_key = "Global"
local cached_key

local visible = false
local cached_target

local labels = {
    damage = { [0] = "Auto" },
    hit_chance = { [0] = "Off" },
    multipoint = { [24] = "Auto" }
}

local function generate_damage_labels()
    for i = 1, 26 do
        labels.damage[100 + i] = string.format("HP + %s", i)
    end
end
generate_damage_labels()

local weapon_indexes = {
    Global      = { }, --/all other weapons: non selected and knifes, zeus, grenades etc
    AWP         = { 9 },
    Auto        = { 11, 38 },
    Scout       = { 40 },
    Revolver    = { 64 },
    Deagle      = { 1 },
    Pistol      = { 2, 3, 4, 30, 32, 36, 61, 63 },
    Zeus        = { 31 },
    --Rifle     = { 7, 8, 10, 13, 16, 39, 60 },
    --SMG       = { 17, 19, 24, 26, 33, 34 },
    --Heavy     = { 14, 28},
    --Shotgun   = { 25, 27, 29, 35 },
}

--#endregion /vars & consts

--#region helpers
local function contains(tab, val)
    for i = 1, #tab do
        if tab[i] == val then
            return true
        end
    end
    
    return false
end

local function multi_exec(func, list)
    if func == nil then return end
    
    for ref, val in pairs(list) do
        func(ref, val)
    end
end

local function fix_multiselect(multiselect, value)
    local number = ui.get(multiselect)
    if #number == 0 then
        ui.set(multiselect, value)
    end
end

local function get_items(tbl)
    local items = {}
    local n = 0

    for k,v in pairs(tbl) do
        n = n + 1
        items[n]=k
    end
    table.sort(items)
    return items
end

local function get_key(val)
    for k, v in pairs(weapon_indexes) do
        if contains(v, val) then
            return k
        end
    end
    return "Global"
end

local function vec2_dist(f_x, f_y, t_x, t_y)
    local delta_x, delta_y = f_x - t_x, f_y - t_y
    return math.sqrt(delta_x * delta_x + delta_y * delta_y)
end

local function in_air()
    return (bit.band(entity.get_prop(entity.get_local_player(), "m_fFlags"), 1) == 0)
end

local function in_fd()
    if ui.get(ui.reference("RAGE", "Other", "Duck peek assist")) then
        return true
    end
    return false
end
--#endregion

--#region player checking
local function get_all_player_locations(w, h, enemy)
	local indexes = {}
	local positions = {}
	local players = entity.get_players(enemy)
	if #players == 0 or not #players then return end
	
	for i = 1, #players do
		local p = players[i]
		
		local px, py, pz = entity.get_prop(p, "m_vecOrigin")
		local vz = entity.get_prop(p,"m_vecViewOffset[2]")
		
		if pz ~= nil and vz ~= nil then
			pz = pz + (vz * 0.5)
			local sx, sy = renderer.world_to_screen(px, py, pz)
			if sx ~= nil and sy ~= nil then
				if sx >= 0 and sx < w and sy >= 0 and sy <= h then
                    indexes[#indexes+1] = p
                    positions[#positions+1] = {sx, sy}
                end
			end
		end
	end
	
	return indexes, positions
end

local function check_fov()
    local w, h = client.screen_size()
    local sx, sy = w * 0.5, h * 0.5
    local fov_limit = 250 --/number in pixels

    if get_all_player_locations(w, h, true) == nil then return end

    local enemy_indexes, enemy_coords = get_all_player_locations(w, h, true)
    if #enemy_indexes <= 0 then return true end
    if #enemy_coords == 0 then return true end

    local closest_fov = 133337
    local closest_entindex = 133337
    for i=1, #enemy_coords do
        local x = enemy_coords[i][1]
        local y = enemy_coords[i][2]

        local cur_fov = vec2_dist(x, y, sx, sy)
        if cur_fov < closest_fov then
            closest_fov = cur_fov
            closest_entindex = enemy_indexes[i]
        end
    end

    return closest_fov > fov_limit, closest_entindex
end

local can_see = function(ent)
    for i=0, 18 do
        if client.visible(entity.hitbox_position(ent, i)) then
            return true
        end
    end
    return false
end
--#endregion

--#region references
local   multipoint, 
        _, 
        mp_strenght     = ui.reference("RAGE", "Aimbot", "Multi-point")

local reference = {
    selection           = ui.reference("RAGE", "Aimbot", "Target selection"),
    hitbox              = ui.reference("RAGE", "Aimbot", "Target hitbox"),
    multipoint          = multipoint,
    multipoint_scale    = ui.reference("RAGE", "Aimbot", "Multi-point scale"),
    prefersafe          = ui.reference("RAGE", "Aimbot", "Prefer safe point"),
    forcesafe_limbs     = ui.reference("RAGE", "Aimbot", "Force safe point on limbs"),
    hit_chance          = ui.reference("RAGE", "Aimbot", "Minimum hit chance"),
    damage              = ui.reference("RAGE", "Aimbot", "Minimum damage"),
    boost               = ui.reference("RAGE", "Other", "Accuracy boost"),
    delay               = ui.reference("RAGE", "Other", "Delay shot"),
    stop                = ui.reference("RAGE", "Other", "Quick stop"),
    stop_options        = ui.reference("RAGE", "Other", "Quick stop options"),
    baim_peek           = ui.reference("RAGE", "Other", "Force body aim on peek"),
    baim                = ui.reference("RAGE", "Other", "Prefer body aim"),
    baim_disablers      = ui.reference("RAGE", "Other", "Prefer body aim disablers"),
    doubletap           = ui.reference("RAGE", "Other", "Double tap"),
    doubletap_stop      = ui.reference("RAGE", "Other", "Double tap quick stop")
}

--#endregion /references

--#region controls
local controls = {
    active          = "Global", --/default selected weapon group
    visible         = false,
    enabled         = ui.new_checkbox(menu[1], menu[2], "Enable adaptive weapons"),
    selected_weapon = ui.new_combobox(menu[1], menu[2], "Selected weapon", get_items(weapon_indexes)),
    indicators      = ui.new_checkbox(menu[1], menu[2], "Display override indicators"),
    key_damage      = ui.new_hotkey(menu[1], menu[2], "Hotkey: damage override", false),
    key_hitbox      = ui.new_hotkey(menu[1], menu[2], "Hotkey: hitbox override", false),
    key_head        = ui.new_hotkey(menu[1], menu[2], "Hotkey: force head", false)
}

local function generate_weapon_controls()
    for name in pairs(weapon_indexes) do 
        weapon_info[name] = {
            selection           = ui.new_combobox(menu[1], menu[2], string.format("[%s] Target selection", name), {"Cycle","Cycle (2x)", "Near crosshair", "Highest damage", "Lowest ping", "Best K/D ratio", "Best hit chance"}),
            hitbox              = ui.new_multiselect(menu[1], menu[2], string.format("[%s] Target hitbox", name), {"Head", "Chest", "Stomach", "Arms", "Legs", "Feet"}),
            hitbox_override     = ui.new_multiselect(menu[1], menu[2], string.format("[%s] Target hitbox override", name), {"Head", "Chest", "Stomach", "Arms", "Legs", "Feet"}),
            multipoint          = ui.new_multiselect(menu[1], menu[2], string.format("[%s] Multi-point", name), {"Head", "Chest", "Stomach", "Arms", "Legs", "Feet"}),
            multipoint_scale    = ui.new_slider(menu[1], menu[2], string.format("[%s] Multi-point scale", name), 24, 100, 50, true, "%", 1, labels.multipoint),
            dynamic             = ui.new_checkbox(menu[1], menu[2], string.format("[%s] Dynamic multi-point", name)),
            prefersafe          = ui.new_checkbox(menu[1], menu[2], string.format("[%s] Prefer safe point", name)),
            forcesafe_limbs     = ui.new_checkbox(menu[1], menu[2], string.format("[%s] Force safe point on limbs", name)),
            hit_chance          = ui.new_slider(menu[1], menu[2], string.format("[%s] Minimum hit chance", name), 0, 100, 55, true, "%", 1, labels.hit_chance),
            damage              = ui.new_slider(menu[1], menu[2], string.format("[%s] Minimum damage damage", name), 0, 124, 15, true, "\n", 1, labels.damage),
            visible             = ui.new_slider(menu[1], menu[2], string.format("[%s] Visible minimum damage", name), 0, 124, 15, true, "\n", 1, labels.damage),
            damage_override     = ui.new_slider(menu[1], menu[2], string.format("[%s] Override minimum damage", name), 0, 124, 15, true, "\n", 1, labels.damage),
            in_air              = ui.new_checkbox(menu[1], menu[2], string.format("[%s] Customize values in-air", name)),
            hit_chance_air      = ui.new_slider(menu[1], menu[2], string.format("[%s] In-air hit chance", name), 0, 100, 34, true, "%", 1, labels.hit_chance),
            damage_air          = ui.new_slider(menu[1], menu[2], string.format("[%s] In-air minimum damage", name), 0, 124, 20, true, "\n", 1, labels.damage),
            boost               = ui.new_combobox(menu[1], menu[2], string.format("[%s] Accuracy boost", name), { "Off", "Low", "Medium", "High", "Maximum" }),
            delay               = ui.new_checkbox(menu[1], menu[2], string.format("[%s] Delay shot", name)),
            stop                = ui.new_checkbox(menu[1], menu[2], string.format("[%s] Quick stop", name)),
            stop_options        = ui.new_multiselect(menu[1], menu[2], string.format("[%s] Quick stop options", name), { "Early", "Slow motion", "Duck", "Move between shots", "Ignore molotov" }),
            baim_peek           = ui.new_checkbox(menu[1], menu[2], string.format("[%s] Force body aim on peek", name)),
            baim                = ui.new_checkbox(menu[1], menu[2], string.format("[%s] Prefer body aim", name)),
            baim_disablers      = ui.new_multiselect(menu[1], menu[2], string.format("[%s] Prefer body aim disablers", name), { "Low inaccuracy","Target shot fired","Target resolved","Safe point headshot","Low damage" }),
            doubletap           = ui.new_checkbox(menu[1], menu[2], string.format("[%s] Double tap", name)),
            doubletap_stop      = ui.new_multiselect(menu[1], menu[2], string.format("[%s] Double tap quick stop", name), { "Slow motion", "Duck", "Move between shots" })
 		}
    end
end
generate_weapon_controls()

--#endregion controls

--#region control visibility handling
---/full credits to Salvatore
---/also thanks for the theme, it's pretty
local function bind_callback(list, callback, elem)
    for k in pairs(list) do
        if type(list[k]) == "table" and list[k][elem] ~= nil then
            ui.set_callback(list[k][elem], callback)
        end
    end
end

local function menu_callback(e, menu_call)
    local setup_controls = function(list, element, vis)
        for k, v in pairs(list) do
            local active = k == element
            local mode = list[k]

            if type(mode) == "table" then
                for j in pairs(mode) do
                    local set_element = true

                    local mp = ui.get(mode.multipoint)
                    local baim = ui.get(mode.baim)
                    local stop = ui.get(mode.stop)
                    local air = ui.get(mode.in_air)
                    local dt = ui.get(mode.doubletap)

                    if not next(mp) and (active and j == "dynamic" or j == "multipoint_scale") then set_element = false end
                    if not air and (active and j == "hit_chance_air" or j == "damage_air") then set_element = false end
                    if not stop and (active and j == "stop_options") then set_element = false end
                    if not baim and (active and j == "baim_disablers") then set_element = false end
                    if not dt and (active and j == "doubletap_stop") then set_element = false end

                    ui.set_visible(mode[j], active and vis and set_element)
                end
            end
        end
    end

    local state = not ui.get(controls.enabled)
    if e == nil then state = true end

    if menu_call == nil then
        setup_controls(weapon_info, ui.get(controls.selected_weapon), not state)
    end

    multi_exec(ui.set_visible, {
        [controls.selected_weapon] = not state,
        [controls.indicators] = not state,
        [controls.key_damage] = not state,
        [controls.key_hitbox] = not state,
        [controls.key_head] = not state
    })
end

menu_callback(controls.enabled)
bind_callback(weapon_info, menu_callback, "multipoint")
bind_callback(weapon_info, menu_callback, "in_air")
bind_callback(weapon_info, menu_callback, "stop")
bind_callback(weapon_info, menu_callback, "baim")
bind_callback(weapon_info, menu_callback, "doubletap")
ui.set_callback(controls.enabled, menu_callback)
ui.set_callback(controls.selected_weapon, menu_callback)
--#endregion /control visibility handling

--#region main functionality
local function update_settings(weapon)
    if not ui.get(controls.enabled) then return end
    local active = weapon_info[weapon]

    for name, ref in pairs(reference) do
        ui.set(ref, ui.get(active[name]))

	    if name == "hitbox" then
            if ui.get(controls.key_head) then
                ui.set(ref, "Head")
            elseif ui.get(controls.key_hitbox) then
                ui.set(ref, ui.get(active.hitbox_override))
            end
        end

        if name == "damage" then
            if in_fd() and not ui.get(controls.key_damage) then
                ui.set(ref, ui.get(active.damage))
            elseif in_air(entity.get_local_player()) and ui.get(active.in_air) and not ui.get(controls.key_damage) then
                ui.set(ref, ui.get(active.damage_air))
            elseif visible and not ui.get(controls.key_damage) then
                if ui.get(active.visible) ~= ui.get(active.damage) then
                    ui.set(ref, ui.get(active.visible))
                end
            elseif ui.get(controls.key_damage) then
                ui.set(ref, ui.get(active.damage_override))
            end
        end

        if name == "hit_chance" then
            if in_air(entity.get_local_player()) and ui.get(active.in_air) then
                ui.set(ref, ui.get(active.hit_chance_air))
            end
        end
    end
end

local function draw_indicators()
    if ui.get(controls.key_head) then
        renderer.indicator(255, 50, 50, 255, "HEAD")
    end
    if ui.get(controls.key_damage) then
        renderer.indicator(123, 193, 21, 255, "DMG")
    end
    if ui.get(controls.key_hitbox) then
        renderer.indicator(123, 193, 21, 255, "HB")
    end
end
--#endregion /main functionality

--#region events
client.set_event_callback("net_update_end", function()
    if not ui.get(controls.enabled) then return end
    if entity.get_prop(entity.get_local_player(), "m_lifeState") ~= 0 or not entity.get_local_player() then return end

    local player_weapon = entity.get_player_weapon(entity.get_local_player())
    local weapon_index = bit.band(65535, entity.get_prop(player_weapon, "m_iItemDefinitionIndex"))

    if (weapon_index > 40 and weapon_index < 50) or (weapon_index > 499 and weapon_index < 524) then
        return
    end

    active_key = get_key(weapon_index)
    local temp = weapon_info[active_key]

    fix_multiselect(temp.hitbox, "Head")
    fix_multiselect(temp.hitbox_override, "Head")

    update_settings(active_key)
    cached_key = active_key
end)

client.set_event_callback("paint", function()
    if not ui.get(controls.enabled) then return end
	if entity.get_prop(entity.get_local_player(), "m_lifeState") ~= 0 then	
		visible = false
		return
    end

    if ui.get(controls.indicators) then draw_indicators() end

    local temp = weapon_info[active_key]

    if temp ~= nil then
        local enemy_visible, enemy_entindex = check_fov()
        if enemy_entindex == nil then return end
        if enemy_visible and enemy_entindex ~= nil and cached_target ~= enemy_entindex then 
            cached_target = enemy_entindex
        end
        local _ = can_see(enemy_entindex)
        if _ then 
            visible = true
        else 
            visible = false
        end
        cached_target = enemy_entindex
    else return end
end)
--#endregion /events

-- file:    adaptive.lua
-- version: 1.0
-- author:  peer <peer#0369>
-- updated: 15/07/2020 (dd/mm/yyyy)
-- desc:    allows you having settings for multiple weapon groups within one configuration

-- credits: Salvatore, NmChris, Sapphyrus, Aviarita, Sigma/Kace and most likely some others

-- added: multi point mode / dmg override indicator

--#region cached functions
local ui_set, ui_get, ui_reference, ui_callback, ui_visible, ui_new_checkbox, ui_new_combobox, ui_new_hotkey, ui_new_slider, ui_new_multiselect = ui.set, ui.get, ui.reference, ui.set_callback, ui.set_visible, ui.new_checkbox, ui.new_combobox, ui.new_hotkey, ui.new_slider, ui.new_multiselect
local get_prop, local_player, get_players, entity_hitbox_position = entity.get_prop, entity.get_local_player, entity.get_players, entity.hitbox_position
local screen_size, client_visible, client_screen_size = client.screen_size, client.visible, client.screen_size
local band = bit.band
local sort = table.sort
local renderer_indicator, w2s, renderer_text = renderer.indicator, renderer.world_to_screen, renderer.text
local s_format = string.format
local sqrt = math.sqrt
local w, h = client_screen_size()
local center = { w / 2, h / 2 }

--#endregion /cached functions

--/location on Gamesense menu
local menu =  { "LUA", "A" }

--#region vars & consts
local weapon_info = { }

local active_key = "Global"
local cached_key

local visible = false
local cached_target

local labels = {
    damage = { [ 0 ] = "Auto" },
    hit_chance = { [ 0 ] = "Off" },
    multipoint = { [ 24 ] = "Auto" }
}

local function generate_damage_labels( )
    for i = 1, 26 do
        labels.damage[ 100 + i ] = s_format( "HP + %s", i )
    end
end
generate_damage_labels( )

local weapon_indexes = {
    Global      = { }, --/all other weapons: non selected and knifes, zeus, grenades etc
    AWP         = { 9 },
    Auto        = { 11, 38 },
    Scout       = { 40 },
    Revolver    = { 64 },
    Deagle      = { 1 },
    Pistol      = { 2, 3, 4, 30, 32, 36, 61, 63 },
    Zeus        = { 31 },
    -- Rifle       = { 7, 8, 10, 13, 16, 39, 60 },
    -- SMG         = { 17, 19, 24, 26, 33, 34 },
    -- Heavy       = { 14, 28},
    -- Shotgun     = { 25, 27, 29, 35 }
}

local weapon_groups = { }

--#endregion /vars & consts

--#region helpers
local function contains( tab, val )
    for i = 1, #tab do
        if tab[ i ] == val then
            return true
        end
    end
    
    return false
end

local function multi_exec( func, list )
    if func == nil then return end
    
    for ref, val in pairs( list ) do
        func( ref, val )
    end
end

local function fix_multiselect( multiselect, value )
    local number = ui_get( multiselect )
    if #number == 0 then
        ui_set( multiselect, value )
    end
end

local function get_items( tbl )
    local items = { }
    local n = 0

    for k,v in pairs( tbl ) do
        n = n + 1
        items[ n ] = k
    end
    sort( items )
    return items
end

local function get_key( val )
    for k, v in pairs( weapon_indexes ) do
        if contains( v, val ) then
            return k
        end
    end
    return "Global"
end

local function vec2_dist( f_x, f_y, t_x, t_y )
    local delta_x, delta_y = f_x - t_x, f_y - t_y
    return sqrt( delta_x * delta_x + delta_y * delta_y )
end

local function in_air( )
    return ( band( get_prop( local_player( ), "m_fFlags" ), 1 ) == 0 )
end

local function in_fd()
    if ui_get( ui_reference( "RAGE", "Other", "Duck peek assist" ) ) then
        return true
    end
    return false
end
--#endregion

--#region player checking
local function get_all_player_locations( w, h, enemy )
	local indexes = { }
	local positions = { }
	local players = get_players( enemy )
	if #players == 0 or not #players then return end
	
	for i = 1, #players do
		local p = players[ i ]
		
		local px, py, pz = get_prop( p, "m_vecOrigin" )
		local vz = get_prop( p,"m_vecViewOffset[2]" )
		
		if pz ~= nil and vz ~= nil then
			pz = pz + ( vz * 0.5 )
			local sx, sy = w2s( px, py, pz )
			if sx ~= nil and sy ~= nil then
				if sx >= 0 and sx < w and sy >= 0 and sy <= h then
                    indexes[ #indexes + 1 ] = p
                    positions[ #positions + 1 ] = { sx, sy }
                end
			end
		end
	end
	
	return indexes, positions
end

local function check_fov( )
    local w, h = screen_size( )
    local sx, sy = w * 0.5, h * 0.5
    local fov_limit = 250 --/number in pixels

    if get_all_player_locations( w, h, true ) == nil then return end

    local enemy_indexes, enemy_coords = get_all_player_locations( w, h, true )
    if #enemy_indexes <= 0 then return true end
    if #enemy_coords == 0 then return true end

    local closest_fov = 133337
    local closest_entindex = 133337
    for i=1, #enemy_coords do
        local x = enemy_coords[ i ][ 1 ]
        local y = enemy_coords[ i ][ 2 ]

        local cur_fov = vec2_dist( x, y, sx, sy )
        if cur_fov < closest_fov then
            closest_fov = cur_fov
            closest_entindex = enemy_indexes[ i ]
        end
    end

    return closest_fov > fov_limit, closest_entindex
end

local can_see = function( ent )
    for i = 0, 18 do
        if client_visible( entity_hitbox_position( ent, i ) ) then
            return true
        end
    end
    return false
end
--#endregion

--#region references
local ref_rage          = { ui_reference( "RAGE", "Aimbot", "Enabled" ) }
local ref_auto          = ui_reference( "RAGE", "Aimbot", "Automatic fire" )
local ref_awall         = ui_reference( "RAGE", "Aimbot", "Automatic penetration" )
local ref_silent        = ui_reference( "RAGE", "Aimbot", "Silent aim" )
local ref_scope         = ui_reference( "RAGE", "Aimbot", "Automatic scope" )
local ref_recoil        = ui_reference( "RAGE", "Other", "Remove recoil" )
local ref_resolver      = ui_reference( "RAGE", "Other", "Anti-aim correction" )
local ref_doubletap     = { ui_reference( "RAGE", "Other", "Double tap" ) }

local function init_rage_tab( )
    ui_set( ref_rage[ 1 ], true )
    ui_set( ref_rage[ 2 ], "Always on" )
    ui_set( ref_auto, true )
    ui_set( ref_awall, true )
    ui_set( ref_silent, true )
    ui_set( ref_scope, true )
    ui_set( ref_recoil, true )
    ui_set( ref_resolver, true )
end
init_rage_tab( )

local   multipoint, 
        _, 
        mp_strenght     = ui_reference( "RAGE", "Aimbot", "Multi-point" )

local reference = {
    selection           = ui_reference( "RAGE", "Aimbot", "Target selection" ),
    hitbox              = ui_reference( "RAGE", "Aimbot", "Target hitbox" ),
    multipoint          = multipoint,
    multipoint_mode     = mp_strenght,
    multipoint_scale    = ui_reference( "RAGE", "Aimbot", "Multi-point scale" ),
    prefersafe          = ui_reference( "RAGE", "Aimbot", "Prefer safe point" ),
    forcesafe           = ui_reference( "RAGE", "Aimbot", "Force safe point" ),
    forcesafe_limbs     = ui_reference( "RAGE", "Aimbot", "Force safe point on limbs" ),
    hit_chance          = ui_reference( "RAGE", "Aimbot", "Minimum hit chance" ),
    damage              = ui_reference( "RAGE", "Aimbot", "Minimum damage" ),
    boost               = ui_reference( "RAGE", "Other", "Accuracy boost" ),
    delay               = ui_reference( "RAGE", "Other", "Delay shot" ),
    stop                = ui_reference( "RAGE", "Other", "Quick stop" ),
    stop_options        = ui_reference( "RAGE", "Other", "Quick stop options" ),
    baim_peek           = ui_reference( "RAGE", "Other", "Force body aim on peek" ),
    baim                = ui_reference( "RAGE", "Other", "Prefer body aim" ),
    baim_disablers      = ui_reference( "RAGE", "Other", "Prefer body aim disablers" ),
    doubletap           = ui_reference( "RAGE", "Other", "Double tap" ),
    doubletap_hc        = ui_reference( "RAGE", "Other", "Double tap hit chance" ),
    doubletap_stop      = ui_reference( "RAGE", "Other", "Double tap quick stop" ),
    onshot              = ui_reference( "AA", "Other", "On shot anti-aim" )
}

--#endregion /references

--#region controls
local controls = {
    active          = "Global", --/default selected weapon group
    visible         = false,
    enabled         = ui_new_checkbox( menu[ 1 ], menu[ 2 ], "Enable adaptive weapons" ),
    selected_weapon = ui_new_combobox( menu[ 1 ], menu[ 2 ], "Selected weapon", get_items( weapon_indexes ) ),
    key_damage      = ui_new_hotkey( menu[ 1 ], menu[ 2 ], "Hotkey: damage override", false ),
    key_hitbox      = ui_new_hotkey( menu[ 1 ], menu[ 2 ], "Hotkey: hitbox override", false ),
    key_head        = ui_new_hotkey( menu[ 1 ], menu[ 2 ], "Hotkey: force head", false ),
    indicators      = ui_new_checkbox(menu[ 1 ], menu[ 2 ], "Display override indicators" )
}

local function generate_weapon_controls( )
    for name in pairs( weapon_indexes ) do 
        weapon_info[ name ] = {
            selection           = ui_new_combobox( menu[ 1 ], menu[ 2 ], s_format( "[%s] Target selection", name ), { "Cycle","Cycle (2x)", "Near crosshair", "Highest damage", "Lowest ping", "Best K/D ratio", "Best hit chance" } ),
            hitbox              = ui_new_multiselect( menu[ 1 ], menu[ 2 ], s_format( "[%s] Target hitbox", name ), { "Head", "Chest", "Stomach", "Arms", "Legs", "Feet" } ),
            multipoint          = ui_new_multiselect( menu[ 1 ], menu[ 2 ], s_format( "[%s] Multi-point", name ), { "Head", "Chest", "Stomach", "Arms", "Legs", "Feet" } ),
            multipoint_mode     = ui_new_combobox( menu[ 1 ], menu[ 2 ], s_format( "\n", name), { "Low", "Medium", "High" } ),
            multipoint_scale    = ui_new_slider( menu[ 1 ], menu[ 2 ], s_format( "[%s] Multi-point scale", name ), 24, 100, 50, true, "%", 1, labels.multipoint),
            prefersafe          = ui_new_checkbox( menu[ 1 ], menu[ 2 ], s_format( "[%s] Prefer safe point", name ) ),
            forcesafe_limbs     = ui_new_checkbox(menu[ 1 ], menu[ 2 ], s_format( "[%s] Force safe point on limbs", name ) ),
            forcesafe           = ui_new_combobox( menu[ 1 ], menu[ 2 ], s_format( "[%s] Force safe point", name ), { "On hotkey", "Toggle", "Always on", "Toggle" } ),
            hit_chance          = ui_new_slider( menu[ 1 ], menu[ 2 ], s_format( "[%s] Minimum hit chance", name ), 0, 100, 55, true, "%", 1, labels.hit_chance ),
            damage              = ui_new_slider( menu[ 1 ], menu[ 2 ], s_format( "[%s] Minimum damage", name ), 0, 124, 15, true, "\n", 1, labels.damage ),
            boost               = ui_new_combobox( menu[ 1 ], menu[ 2 ], s_format( "[%s] Accuracy boost", name ), { "Off", "Low", "Medium", "High", "Maximum" } ),
            delay               = ui_new_checkbox( menu[ 1 ], menu[ 2 ], s_format( "[%s] Delay shot", name ) ),
            stop                = ui_new_checkbox( menu[ 1 ], menu[ 2 ], s_format( "[%s] Quick stop", name ) ),
            stop_options        = ui_new_multiselect( menu[ 1 ], menu[ 2 ], s_format( "[%s] Quick stop options", name ), { "Early", "Slow motion", "Duck", "Fake duck", "Move between shots", "Ignore molotov" } ),
            baim_peek           = ui_new_checkbox( menu[ 1 ], menu[ 2 ], s_format( "[%s] Force body aim on peek", name ) ),
            baim                = ui_new_checkbox( menu[ 1 ], menu[ 2 ], s_format( "[%s] Prefer body aim", name ) ),
            baim_disablers      = ui_new_multiselect( menu[ 1 ], menu[ 2 ], s_format( "[%s] Prefer body aim disablers", name ), { "Low inaccuracy","Target shot fired","Target resolved","Safe point headshot","Low damage" } ),
            onshot              = ui_new_checkbox( menu[ 1 ], menu[ 2 ], s_format( "[%s] On shot anti-aim", name ) ),
            doubletap           = ui_new_checkbox( menu[ 1 ], menu[ 2 ], s_format( "[%s] Double tap", name ) ),
            doubletap_hc        = ui_new_slider( menu[ 1 ], menu[ 2 ], s_format( "[%s] Double tap hit chance", name ), 0, 100, 0, true, "%", 1),
            doubletap_stop      = ui_new_multiselect( menu[ 1 ], menu[ 2 ], s_format( "[%s] Double tap quick stop", name ), { "Slow motion", "Duck", "Move between shots" } ),
            overrides           = ui_new_multiselect( menu[ 1 ], menu[ 2 ], s_format( "[%s] Extra's", name ), { "Override hitbox", "Override damage", "Visible damage", "No-spread fix", "Double tap" } ),
            hitbox_override     = ui_new_multiselect( menu[ 1 ], menu[ 2 ], s_format( "[%s] Target hitbox override", name ), {"Head", "Chest", "Stomach", "Arms", "Legs", "Feet"} ),
            visible             = ui_new_slider( menu[ 1 ], menu[ 2 ], s_format( "[%s] Visible minimum damage", name ), 0, 124, 15, true, "\n", 1, labels.damage ),
            damage_override     = ui_new_slider( menu[ 1 ], menu[ 2 ], s_format( "[%s] Override minimum damage", name ), 0, 124, 15, true, "\n", 1, labels.damage ),
            hit_chance_air      = ui_new_slider( menu[ 1 ], menu[ 2 ], s_format( "[%s] No-spread fix hit chance", name ), 0, 100, 30, true, "%", 1, labels.hit_chance ),
            damage_air          = ui_new_slider( menu[ 1 ], menu[ 2 ], s_format( "[%s] No-spread fix minimum damage", name ), 0, 124, 20, true, "\n", 1, labels.damage ),
            doubletap_or_hb     = ui_new_multiselect( menu[ 1 ],  menu[ 2 ], s_format( "[%s] Double tap hitbox", name ), { "Head", "Chest", "Stomach", "Arms", "Legs", "Feet" } ),
            doubletap_or_hc     = ui_new_slider( menu[ 1 ], menu[ 2 ], s_format( "[%s] Double tap minimum hit chance", name ), 0, 100, 55, true, "%", 1, labels.hit_chance ),
            doubletap_or_dmg    = ui_new_slider( menu[ 1 ], menu[ 2 ], s_format( "[%s] Double tap minimum damage", name ), 0, 124, 15, true, "\n", 1, labels.damage )
 		}
    end
end
generate_weapon_controls( )

--#endregion controls

--#region control visibility handling
---/full credits to Salvatore
---/also thanks for the theme, it's pretty
local function bind_callback( list, callback, elem )
    for k in pairs( list ) do
        if type( list[k] ) == "table" and list[ k ][ elem ] ~= nil then
            ui_callback( list[ k ] [ elem ], callback )
        end
    end
end

local function menu_callback( e, menu_call )
    local setup_controls = function( list, element, vis )
        for k, v in pairs( list ) do
            local active = k == element
            local mode = list[ k ]

            if type( mode ) == "table" then
                for j in pairs( mode ) do
                    local set_element = true

                    local mp        = ui_get( mode.multipoint )
                    local baim      = ui_get( mode.baim )
                    local stop      = ui_get( mode.stop )
                    local dt        = ui_get( mode.doubletap )
                    local air       = contains( ui_get( mode.overrides ), "No-spread fix" )
                    local hb_or     = contains( ui_get( mode.overrides ), "Override hitbox" )
                    local visible   = contains( ui_get( mode.overrides ), "Visible damage" )
                    local dmg_or    = contains( ui_get( mode.overrides ), "Override damage" )
                    local dt_or     = contains( ui_get( mode.overrides ), "Double tap" )
                    local sp_limbs  = contains( ui_get( mode.hitbox ), "Legs" ) or contains( ui_get( mode.hitbox ), "Feet" ) or contains( ui_get( mode.hitbox ), "Arms" ) or false

                    if not next( mp ) and ( active and j == "multipoint_scale" ) then set_element = false end
                    if not hb_or      and ( active and j == "hitbox_override" ) then set_element = false end
                    if not sp_limbs   and ( active and j == "forcesafe_limbs" ) then set_element = false end
                    if not visible    and ( active and j == "visible" ) then set_element = false end
                    if not dmg_or     and ( active and j == "damage_override" ) then set_element = false end
                    if not air        and ( active and j == "hit_chance_air" or j == "damage_air" ) then set_element = false end
                    if not stop       and ( active and j == "stop_options" ) then set_element = false end
                    if not baim       and ( active and j == "baim_disablers" ) then set_element = false end
                    if not dt         and ( active and j == "doubletap_stop" or j == "doubletap_hc" or j == "doubletap_or_hb" or j == "doubletap_or_hc" or j == "doubletap_or_dmg" ) then set_element = false end
                    if not dt_or      and ( active and j == "doubletap_or_hb" or j == "doubletap_or_hc" or j == "doubletap_or_dmg" ) then set_element = false end
                    ui_visible( mode[ j ], active and vis and set_element )
                end
            end
        end
    end

    local state = not ui_get( controls.enabled )
    if e == nil then state = true end

    if menu_call == nil then
        setup_controls( weapon_info, ui_get( controls.selected_weapon ), not state )
    end

    multi_exec( ui_visible, {
        [ controls.selected_weapon ] = not state,
        [ controls.indicators ] = not state,
        [ controls.key_damage ] = not state,
        [ controls.key_hitbox ] = not state,
        [ controls.key_head ] = not state
    } )
end

menu_callback( controls.enabled )
bind_callback( weapon_info, menu_callback, "hitbox" )
bind_callback( weapon_info, menu_callback, "multipoint" )
bind_callback( weapon_info, menu_callback, "stop" )
bind_callback( weapon_info, menu_callback, "baim" )
bind_callback( weapon_info, menu_callback, "doubletap" )
bind_callback( weapon_info, menu_callback, "overrides" )
ui_callback( controls.enabled, menu_callback )
ui_callback( controls.selected_weapon, menu_callback )
--#endregion /control visibility handling

--#region main functionality
local function update_settings( weapon )
    if not ui_get( controls.enabled ) then return end
    local active = weapon_info[ weapon ]

    for name, ref in pairs( reference ) do
        ui_set( ref, ui_get( active[name] ) )

        if name == "hitbox" then
            if ui_get( controls.key_head ) then
                ui_set( ref, "Head" )
            elseif ui_get( controls.key_hitbox ) and contains( ui_get( active.overrides ), "Override hitbox" ) then
                ui_set( ref, ui_get( active.hitbox_override ) )
            elseif ui_get( active.doubletap ) and contains( ui_get( active.overrides ), "Double tap" ) and ui_get( ref_doubletap[ 1 ] ) and ui_get( ref_doubletap[ 2 ] ) then
                ui_set( ref, ui_get( active.doubletap_or_hb ) )
            end
        end

        if name == "damage" then
            if ui_get( controls.key_damage ) and contains( ui_get( active.overrides ), "Override damage" ) then
                ui_set( ref, ui_get( active.damage_override ) )
            elseif in_air( local_player( ) ) and contains( ui_get( active.overrides ), "No-spread fix" ) then
                ui_set( ref, ui_get( active.damage_air ) )
            elseif ui_get( active.doubletap ) and contains( ui_get( active.overrides ), "Double tap" ) and ui_get( ref_doubletap[ 1 ] ) and ui_get( ref_doubletap[ 2 ] ) then
                ui_set( ref, ui_get( active.doubletap_or_dmg ) )
            elseif visible and contains( ui_get( active.overrides ), "Visible damage" ) and ui_get( active.visible ) ~= ui_get( active.damage ) and not ui_get( controls.key_damage ) then
                ui_set( ref, ui_get( active.visible ) )
            end
        end

        if name == "hit_chance" then
            if in_air( local_player( ) ) and contains( ui_get( active.overrides ), "No-spread fix" ) then
                ui_set( ref, ui_get( active.hit_chance_air ) )
            elseif ui_get( active.doubletap ) and contains( ui_get( active.overrides ), "Double tap" ) and ui_get( ref_doubletap[ 1 ] ) and ui_get( ref_doubletap[ 2 ] ) then
                ui_set( ref, ui_get( active.doubletap_or_hc ) )
            end
        end
    end
end

local function draw_indicators( )
    local temp = weapon_info[ active_key ]

    if ui_get( controls.key_head ) then
        renderer_indicator( 255, 50, 50, 255, "HEAD" )
    end
    if ui_get( controls.key_damage ) and contains( ui_get( temp.overrides ), "Override damage" ) then
        renderer_text(center[1], (center[2] + 25), 255, 255, 255, 255, 'cb', 0, ui_get(reference.damage))
    end
    if ui_get( controls.key_hitbox ) and contains( ui_get( temp.overrides ), "Override hitbox" ) then
        renderer_indicator( 123, 193, 21, 255, "HB" )
    end
end
--#endregion /main functionality

--#region events
client.set_event_callback( "net_update_end", function( )
    if not ui_get( controls.enabled ) then return end
    if get_prop( local_player( ), "m_lifeState" ) ~= 0 or not local_player( ) then return end

    local player_weapon = entity.get_player_weapon( local_player( ) )
    if player_weapon == nil or not player_weapon then
        return
    end

    local weapon_index = band( 65535, get_prop( player_weapon, "m_iItemDefinitionIndex" ) )

    if ( weapon_index > 40 and weapon_index < 50 ) or ( weapon_index > 499 and weapon_index < 524 ) then
        return
    end

    active_key = get_key( weapon_index )
    local temp = weapon_info[ active_key ]

    fix_multiselect( temp.hitbox, "Head" )
    fix_multiselect( temp.hitbox_override, "Head" )
    fix_multiselect( temp.doubletap_or_hb, "Head" )

    update_settings( active_key )
    cached_key = active_key
end )

client.set_event_callback( "paint", function( )
    if not ui_get( controls.enabled ) then return end
	if get_prop( local_player( ), "m_lifeState" ) ~= 0 then	
		visible = false
		return
    end

    if ui_get( controls.indicators ) then draw_indicators( ) end

    local temp = weapon_info[ active_key ]

    if temp ~= nil then
        local enemy_visible, enemy_entindex = check_fov( )
        if enemy_entindex == nil then return end
        if enemy_visible and enemy_entindex ~= nil and cached_target ~= enemy_entindex then 
            cached_target = enemy_entindex
        end
        local _ = can_see( enemy_entindex )
        if _ then 
            visible = true
        else 
            visible = false
        end
        cached_target = enemy_entindex
    else return end
end )
--#endregion /events
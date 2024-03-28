local function is_local_player(entindex)
    return entindex == entity.get_local_player()
end


local function is_local_player_userid(userid)
    return is_local_player(client.userid_to_entindex(userid))
end

local autobuy_checkbox = ui.new_checkbox("MISC", "Miscellaneous", "Autobuy")
local autobuy_dropbox = ui.new_combobox("MISC", "Miscellaneous", "Autobuy value", "None", "AWP", "Autosniper", "Scout")

function autobuy(e)

	local autobuy_value = ui.get(autobuy_dropbox)

	local checkbox, userid = ui.get(autobuy_checkbox), e.userid
	
	if userid == nil then return end
	
	local local_player = entity.get_local_player()
	
	if not is_local_player_userid(userid) then return end
	
	local primary = ''

				--client.log('Debug: ',autobuy_value)
				
	if checkbox and autobuy_value ~= "None" then
	
			if autobuy_value == "Autosniper" then
			
				primary = 'buy scar20; buy g3sg1; '
				
			elseif autobuy_value == "Scout" then
			
				primary = 'buy ssg08; '
				
			elseif autobuy_value == "AWP" then
			
				primary = 'buy awp; '
				
			end
				client.exec(primary, 'buy deagle; buy taser; buy defuser; buy vesthelm; buy molotov; buy incgrenade; buy hegrenade; buy smokegrenade')
				client.log('[autobuy] Bought ',autobuy_value,' setup!')
				
	elseif checkbox and autobuy_value == "None" then
	
			client.log('[autobuy] Autobuy value set to None.')
	end
end

local result = client.set_event_callback('player_spawn', autobuy) 

if result then
	client.log('set_event_callback failed: ', result)
end
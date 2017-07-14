--[[
                                     .__        __
__  _  _______  ___.__.______   ____ |__| _____/  |_  ______
\ \/ \/ /\__  \<   |  |\____ \ /  _ \|  |/    \   __\/  ___/
 \     /  / __ \\___  ||  |_> >  <_> )  |   |  \  |  \___ \
  \/\_/  (____  / ____||   __/ \____/|__|___|  /__| /____  >
              \/\/     |__|                  \/          \/
--]]

local load_time_start = os.clock()
local modname = minetest.get_current_modname()


local modstorage = core.get_mod_storage()

local world_name
local waypoints
worldname.register_on_get(function()
	world_name = worldname.get()
	waypoints = minetest.deserialize(modstorage:get_string(world_name)) or
			{{name = "zeropoint", pos = {x=0, y=0, z=0}}}
end)
local searched
local selected

local last_command_side = "1"
local last_commands = {}

local default_view = modstorage:get_int("/settings: default_view") == 1

local localplayer
minetest.register_on_connect(function()
	localplayer = minetest.localplayer
end)

local function check_color(s)
	if type(s) ~= "string" or #s ~= 7 or s:sub(1, 1) ~= "#" then
		return false
	end
	local chars = {
		"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a",
		"b", "c", "d", "e", "f", "A", "B", "C", "D", "E", "F",
	}
	for i = 2, #s do
		local ok = false
		for k = 1, #chars do
			if chars[k] == s:sub(i, i) then
				ok = true
				break
			end
		end
		if not ok then
			return false
		end
	end
	return true
end

local function save()
	modstorage:set_string(world_name, minetest.serialize(waypoints))
end

local function show_formspec(page, data)
	local f = ""
	if page == "main" then
		f = f..
			"size[12,10]"..
			"textlist[0,0;8,10;list;"
		for i = 1, #waypoints do
			f = f..(waypoints[i].color or "")..minetest.formspec_escape(waypoints[i].name..
				" "..minetest.pos_to_string(waypoints[i].pos))..","
		end
		f = f:sub(1, -2).. -- Cut away the last ",".
			";"..selected..";false]"..
			"container[9,0]"..
			"button[0,1;2,1;add;Add]"..
			"button[0,2;2,1;edit;Edit]"..
			"button[0,3;2,1;delete;Delete]"..
			"button_exit[0,4;2,1;teleport;Teleport to]"..
			"button[0,5;2,1;chatcommand;Run Command]"..
			"button_exit[0,7;2,1;search;Search]"..
			"button[0,8;2,1;settings;Settings]"..
			"button_exit[0,9;2,1;exit;Exit]"..
			"container_end[]"
	elseif page == "add" then
		f = f..
			"size[8,6]"..
			"field[0.5,0.5;3,1;name;Name;"..
				((data and
					--[[((check_color(data.color) and
						minetest.colorize(data.color, data.name))
					or]] data.name)--)
				or "")..
			"]"..
			"field[0.5,1.5;1.5,1;color;Color;"..((data and data.color) or "").."]"..
			"field[7,1;1.5,1;x;X;"..((data and tostring(data.x)) or "").."]"..
			"field[7,2;1.5,1;y;Y;"..((data and tostring(data.y)) or "").."]"..
			"field[7,3;1.5,1;z;Z;"..((data and tostring(data.z)) or "").."]"..
			"field_close_on_enter[name;false]"..
			"field_close_on_enter[color;false]"..
			"field_close_on_enter[x;false]"..
			"field_close_on_enter[y;false]"..
			"field_close_on_enter[z;false]"..
			"box[0.8,1;0.7,0.2;"..((data and check_color(data.color) and data.color)
				or "#FFFFFF").."]"..
			"button[5,4;3,1;current_pos;take current pos]"..
			"button[4,5.5;2,1;cancel;Cancel]"..
			"button[6,5.5;2,1;add;Add]"
	elseif page == "edit" then
		f = f..
			"size[8,6]"..
			"field[0.5,0.5;3,1;name;Name;"..
				((data and
					--[[((check_color(data.color) and
						minetest.colorize(data.color, data.name))
					or]] data.name)--)
				or "")..
			"]"..
			"field[0.5,1.5;1.5,1;color;Color;"..((data and data.color) or "").."]"..
			"field[7,1;1.5,1;x;X;"..((data and tostring(data.x)) or "").."]"..
			"field[7,2;1.5,1;y;Y;"..((data and tostring(data.y)) or "").."]"..
			"field[7,3;1.5,1;z;Z;"..((data and tostring(data.z)) or "").."]"..
			"field_close_on_enter[name;false]"..
			"field_close_on_enter[color;false]"..
			"field_close_on_enter[x;false]"..
			"field_close_on_enter[y;false]"..
			"field_close_on_enter[z;false]"..
			"box[0.8,1;0.7,0.2;"..((data and check_color(data.color) and data.color)
				or "#FFFFFF").."]"..
			"button[5,4;3,1;current_pos;take current pos]"..
			"button[4,5.5;2,1;cancel;Cancel]"..
			"button[6,5.5;2,1;submit;Submit]"
	elseif page == "delete" then
		f = f..
			"size[4,2]"..
			"label[0,0;Do you really want to delete "..
				minetest.formspec_escape(waypoints[selected].name).."?]"..
			"button[2.5,1.5;1,1;y;YES]"..
			"button[0.5,1.5;1,1;n;NO]"
	elseif page == "chatcommand" then
		f = f..
			"size[8,6]"..
			"label[0.5,0.5;%s will be changed to the selected waypoint's position]"..
			"dropdown[1,3;0.5;side;/,.;"..last_command_side.."]"..
			"field[1.7,3.2;3.8,1;command;;"..(data or "").."]"..
			"field_close_on_enter[command;false]"..
			"dropdown[5,3;3;old;"
		if #last_commands > 0 then
			for i = #last_commands, #last_commands-8, -1 do
				if i <= 0 then
					break
				end
				f = f..last_commands[i]..","
			end
		else
			f = f..","
		end
		f = f:sub(1, -2).. -- Cut away the last ",".
			";0]"..
			"button[4,5.5;2,1;cancel;Cancel]"..
			"button_exit[6,5.5;2,1;run;Run]"
	elseif page == "settings" then
		f = f..
			"size[8,6]"..
			"checkbox[0.8,0.5;default_view;Default View;"..tostring(default_view).."]"..
			"button[4,5.5;2,1;cancel;Cancel]"..
			"button[6,5.5;2,1;save;Save]"
	end
	if default_view then
		f = f..
			"bgcolor[#080808BB;true]"..
			"background[5,5;1,1;gui_formbg.png;true]"..
			"listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]"
	end
	minetest.show_formspec("waypoints_"..page, f)
end

minetest.register_chatcommand("waypoints", {
	params = "",
	description = "Opens a formspec.",
	func = function(param)
		if not world_name then
			return false, "No worldname."
		end
		selected = searched or 1
		show_formspec("main")
		return true, "Opening formspec."
	end,
})

minetest.register_on_formspec_input(function(formname, fields)
	if formname:sub(1, 9) ~= "waypoints" then
		return
	end
	local page = formname:sub(11)
	print(dump(fields))
	if page == "main" then
		if fields.add then
			show_formspec("add")
		elseif fields.edit then
			local data = table.copy(waypoints[selected])
			data.x = data.pos.x
			data.y = data.pos.y
			data.z = data.pos.z
			show_formspec("edit", data)
		elseif fields.delete then
			show_formspec("delete")
		elseif fields.teleport then
			minetest.run_server_chatcommand("teleport",
					minetest.pos_to_string(waypoints[selected].pos):sub(2, -2))
		elseif fields.chatcommand then
			show_formspec("chatcommand")
		elseif fields.settings then
			show_formspec("settings")
		elseif fields.list then
			if fields.list:sub(1, 4) == "CHG:" then
				selected = tonumber(fields.list:sub(5))
			end
		elseif fields.search then
			searched = selected
			-- Todo: add hud when possible
		end
	elseif page == "add" then
		if fields.add or (fields.key_enter == "true" and fields.key_enter_field == "name") then
			waypoints[#waypoints+1] = {
				name = fields.name,
				color = fields.color,
				pos = vector.new(tonumber(fields.x), tonumber(fields.y),
						tonumber(fields.z))
			}
			save()
			selected = #waypoints
			show_formspec("main")
		elseif fields.cancel then
			show_formspec("main")
		elseif fields.quit then
			minetest.after(0.061, show_formspec, "main")
		elseif fields.key_enter == "true" and fields.key_enter_field == "color" then
			show_formspec("add", fields)
		elseif fields.current_pos then
			local pos = vector.round(localplayer:get_pos())
			fields.x, fields.y, fields.z = pos.x, pos.y, pos.z
			show_formspec("add", fields)
		end
	elseif page == "edit" then
		if fields.submit or (fields.key_enter == "true" and fields.key_enter_field == "name") then
			waypoints[selected] = {
				name = fields.name,
				color = fields.color,
				pos = vector.new(tonumber(fields.x), tonumber(fields.y),
						tonumber(fields.z))
			}
			save()
			show_formspec("main")
		elseif fields.cancel then
			show_formspec("main")
		elseif fields.quit then
			minetest.after(0.061, show_formspec, "main")
		elseif fields.key_enter == "true" and fields.key_enter_field == "color" then
			show_formspec("edit", fields)
		elseif fields.current_pos then
			local pos = vector.round(localplayer:get_pos())
			fields.x, fields.y, fields.z = pos.x, pos.y, pos.z
			show_formspec("edit", fields)
		end
	elseif page == "delete" then
		if fields.y then
			table.remove(waypoints, selected)
			save()
		end
		if fields.quit then
			minetest.after(0.061, show_formspec, "main")
		else
			show_formspec("main")
		end
	elseif page == "chatcommand" then
		if fields.run then
			last_command_side = fields.side == "/" and "1" or "2"
			for i = 1, #last_commands do
				if last_commands[i] == fields.side..fields.command then
					table.remove(last_commands, i)
				end
			end
			last_commands[#last_commands+1] = fields.side..fields.command
			local f = fields.command:find(" ")
			local cmd, param
			if not f then
				cmd = fields.command
				param = ""
			else
				cmd = fields.command:sub(1, f-1)
				param = fields.command:sub(f+1)
				local pos = minetest.pos_to_string(waypoints[selected].pos):sub(2,-2)
				param = param:format(pos)
			end
			if fields.side == "/" then
				minetest.run_server_chatcommand(cmd, param)
			elseif fields.side == "." then
				local _, msg = minetest.registered_chatcommands[cmd].func(param)
				minetest.display_chat_message(msg)
			end
		elseif fields.cancel then
			show_formspec("main")
		elseif fields.quit then
			minetest.after(0.061, show_formspec, "main")
		elseif fields.old then
			last_command_side = fields.old:sub(1, 1) == "/" and "1" or "2"
			show_formspec("chatcommand", fields.old:sub(2))
		end
	elseif page == "settings" then
		if fields.default_view then
			default_view = fields.default_view == "true"
			show_formspec("settings")
		elseif fields.cancel then
			default_view = modstorage:get_int("/settings: default_view") == 1
			show_formspec("main")
		elseif fields.quit then
			default_view = modstorage:get_int("/settings: default_view") == 1
			minetest.after(0.061, show_formspec, "main")
		elseif fields.save then
			modstorage:set_int("/settings: default_view", (default_view and 1) or 0)
			show_formspec("main")
		end
	end
	return true
end)


local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "["..modname.."] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end

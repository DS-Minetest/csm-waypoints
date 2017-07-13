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

local default_view = true -- Set this to true if you want the default mod look.

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

local localplayer
minetest.register_on_connect(function()
	localplayer = minetest.localplayer
end)

local function check_color(s)
	if type(s) ~= "string" or #s ~= 7 or s:sub(1) ~= "#" then
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
			"button_exit[0,8;2,1;search;Search]"..
			"button_exit[0,9;2,1;exit;Exit]"..
			"container_end[]"
	elseif page == "add" then
		f = f..
			"size[8,6]"..
			"field[0.5,3.5;3,1;name;Name;]"..
			"field_close_on_enter[name;false]"..
			"field[4,3.5;1.5,1;color;Color;"..((data and data.color) or "").."]"..
			"field_close_on_enter[color;false]"..
			((data and data.color and "box[5.5,3.5;1,1;"..data.color.."]") or "")..
			"button[4,1;2,1;current_pos;take current pos]"..
			"button[4,5.5;2,1;cancel;Cancel]"..
			"button[6,5.5;2,1;add;Add]"
	elseif page == "delete" then
		f = f..
			"size[4,2]"..
			"label[0,0;Do you really want to delete "..
				minetest.formspec_escape(waypoints[selected].name).."?]"..
			"button[2.5,1.5;1,1;y;YES]"..
			"button[0.5,1.5;1,1;n;NO]"
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
		elseif fields.delete then
			show_formspec("delete")
		elseif fields.teleport then
			minetest.run_server_chatcommand("teleport",
					minetest.pos_to_string(waypoints[selected].pos):sub(2, -2))
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
			waypoints[#waypoints+1] = {name = fields.name, color = fields.color, pos = {x=10,y=9,z=-20}}
			selected = #waypoints
			show_formspec("main")
		elseif fields.cancel then
			show_formspec("main")
		elseif fields.quit then
			minetest.after(0.061, show_formspec, "main")
		elseif fields.key_enter == "true" and fields.key_enter_field == "color" then
			if not check_color(fields.color) then
				fields.color = false
			end
			print("bla")
			show_formspec("add", {color = fields.color})
		end
	elseif page == "delete" then
		if fields.y then
			table.remove(waypoints, selected)
		end
		-- Bring back to main page.
		if fields.quit then
			minetest.after(0.061, show_formspec, "main")
		else
			show_formspec("main")
		end
	end
	return true
end)

minetest.register_on_shutdown(function()
	modstorage:set_string(world_name, minetest.serialize(waypoints))
end)


local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "["..modname.."] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end

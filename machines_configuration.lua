local F, S = basic_machines.F, basic_machines.S
local machines_TTL = basic_machines.properties.machines_TTL
local max_range = basic_machines.properties.max_range
local mover_upgrade_max = basic_machines.properties.mover_upgrade_max
local punchset = {}

minetest.register_on_joinplayer(function(player)
	punchset[player:get_player_name()] = {state = 0, node = ""}
end)

minetest.register_on_leaveplayer(function(player)
	punchset[player:get_player_name()] = nil
end)

-- SETUP BY PUNCHING
local punchable_nodes = {
	["basic_machines:detector"] = "DETECTOR",
	["basic_machines:keypad"] = "KEYPAD",
	["basic_machines:mover"] = "MOVER"
}

local function check_keypad(pos, name) -- called only when manually activated via punch
	local meta = minetest.get_meta(pos)
	if meta:get_string("pass") == "" then
		local count = meta:get_int("count")
		local iter = meta:get_int("iter")
		-- so that keypad can work again, at least one operation must have occured though
		if count < iter - 1 or iter < 2 then meta:set_int("active_repeats", 0) end
		meta:set_int("count", iter); basic_machines.use_keypad(pos, machines_TTL, 0) -- time to live set when punched
		return
	end

	if name == "" then return end

	if meta:get_string("text") == "@" then -- keypad works as a keyboard
		minetest.show_formspec(name, "basic_machines:check_keypad_" .. minetest.pos_to_string(pos),
			"size[3,1.25]field[0.25,0.25;3,1;pass;" .. F(S("Enter text:")) ..
			";]button_exit[0,0.75;1,1;OK;" .. F(S("OK")) .. "]")
	else
		minetest.show_formspec(name, "basic_machines:check_keypad_" .. minetest.pos_to_string(pos),
			"size[3,1.25]no_prepend[]bgcolor[#FF8888BB;false]field[0.25,0.25;3,1;pass;" .. F(S("Enter password:")) ..
			";]button_exit[0,0.75;1,1;OK;" .. F(S("OK")) .. "]")
	end
end

local abs = math.abs

minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
	local name = puncher:get_player_name()
	local punch_state = punchset[name].state
	local punchset_desc = punchable_nodes[node.name]
	if punch_state == 0 and punchset_desc == nil then return end
	local punch_node = punchset[name].node
	punchset_desc = punch_node == "basic_machines:distributor" and "DISTRIBUTOR" or
		(punchable_nodes[punch_node] or punchset_desc)

	if punchset_desc ~= "KEYPAD" and minetest.is_protected(pos, name) then
		if punch_state > 0 then
			minetest.chat_send_player(name, S(punchset_desc .. ": Punched position is protected. Aborting."))
			punchset[name] = {state = 0, node = ""}
		end
		return
	end

	if punch_state == 0 then
		if punchset_desc == "KEYPAD" then
			local meta = minetest.get_meta(pos)
			if meta:get_int("x0") ~= 0 or meta:get_int("y0") ~= 0 or meta:get_int("z0") ~= 0 then -- already configured
				check_keypad(pos, name); return -- not setup, just standard operation
			elseif minetest.is_protected(pos, name) then
				minetest.chat_send_player(name, S("KEYPAD: You must be able to build to set up keypad.")); return
			end
		end
		punchset[name] = {
			pos = pos,
			node = node.name,
			state = 1
		}
		local msg = ""
		if punchset_desc == "MOVER" then
			msg = "MOVER: Now punch source1, source2, end position to set up mover."
		elseif punchset_desc == "KEYPAD" then
			msg = "KEYPAD: Now punch the target block."
		elseif punchset_desc == "DETECTOR" then
			msg = "DETECTOR: Now punch the source block."
		end
		if msg ~= "" then
			minetest.chat_send_player(name, S(msg))
		end
		return
	end

	local self_pos = punchset[name].pos

	if minetest.get_node(self_pos).name ~= punch_node then
		punchset[name] = {state = 0, node = ""}; return
	end


	-- MOVER
	if punchset_desc == "MOVER" then
		local meta = minetest.get_meta(self_pos)
		local privs = minetest.check_player_privs(name, "privs")
		local range

		if meta:get_inventory():get_stack("upgrade", 1):get_name() == "default:mese" then
			range = meta:get_int("upgrade") * max_range
		else
			range = max_range
		end

		if punch_state == 1 then
			if not privs and
				(abs(pos.x - self_pos.x) > range or abs(pos.y - self_pos.y) > range or abs(pos.z - self_pos.z) > range)
			then
				minetest.chat_send_player(name, S("MOVER: Punch closer to mover. Resetting."))
				punchset[name] = {state = 0, node = ""}; return
			end

			if vector.equals(pos, self_pos) then
				minetest.chat_send_player(name, S("MOVER: Punch something else. Aborting."))
				punchset[name] = {state = 0, node = ""}; return
			end

			punchset[name].pos1 = pos -- source1
			punchset[name].state = 2
			machines.mark_pos1(name, pos) -- mark pos1
			minetest.chat_send_player(name, S("MOVER: Source1 position for mover set. Punch again to set source2 position."))
		elseif punch_state == 2 then
			if not privs and
				(abs(pos.x - self_pos.x) > range or abs(pos.y - self_pos.y) > range or abs(pos.z - self_pos.z) > range)
			then
				minetest.chat_send_player(name, S("MOVER: Punch closer to mover. Resetting."))
				punchset[name] = {state = 0, node = ""}; return
			end

			if vector.equals(pos, self_pos) then
				minetest.chat_send_player(name, S("MOVER: Punch something else. Aborting."))
				punchset[name] = {state = 0, node = ""}; return
			end

			punchset[name].pos11 = pos -- source2
			punchset[name].state = 3
			machines.mark_pos11(name, pos) -- mark pos11
			minetest.chat_send_player(name, S("MOVER: Source2 position for mover set. Punch again to set target position."))
		elseif punch_state == 3 then
			local mode = meta:get_string("mode")
			local pos1 = punchset[name].pos1

			if mode == "object" then -- check if elevator mode, only if object mode
				if meta:get_int("elevator") == 1 then meta:set_int("elevator", 0) end

				if (pos1.x == self_pos.x and pos1.z == self_pos.z and pos.x == self_pos.x and pos.z == self_pos.z) or
					(pos1.x == self_pos.x and pos1.y == self_pos.y and pos.x == self_pos.x and pos.y == self_pos.y) or
					(pos1.y == self_pos.y and pos1.z == self_pos.z and pos.y == self_pos.y and pos.z == self_pos.z)
				then
					local ecost = abs(pos.x - self_pos.x) + abs(pos.y - self_pos.y) + abs(pos.z - self_pos.z)
					if ecost > 3 then -- trying to make an elevator ?
						-- count number of diamond blocks to determine if elevator can be set up with this height distance
						local upgrade = meta:get_int("upgrade")

						local requirement = math.floor(ecost / 100) + 1
						if upgrade - 1 < requirement and
							meta:get_inventory():get_stack("upgrade", 1):get_name() ~= "default:diamondblock" and upgrade ~= -1
						then
							minetest.chat_send_player(name, S("MOVER: Error while trying to make an elevator. Need at least @1 diamond block(s) in upgrade (1 for every 100 distance).", requirement))
							punchset[name] = {state = 0, node = ""}; return
						else
							meta:set_int("elevator", 1)
							meta:set_string("infotext", S("ELEVATOR: Activate to use."))
							minetest.chat_send_player(name, S("MOVER: Elevator setup completed, upgrade level @1.", upgrade - 1))
						end
					end
				end
			elseif not privs and
				(abs(pos.x - self_pos.x) > range or abs(pos.y - self_pos.y) > range or abs(pos.z - self_pos.z) > range)
			then
				minetest.chat_send_player(name, S("MOVER: Punch closer to mover. Aborting."))
				punchset[name] = {state = 0, node = ""}; return
			end

			machines.mark_pos2(name, pos) -- mark pos2

			local x0 = pos1.x - self_pos.x					-- source1
			local y0 = pos1.y - self_pos.y
			local z0 = pos1.z - self_pos.z

			local x1 = punchset[name].pos11.x - self_pos.x	-- source2
			local y1 = punchset[name].pos11.y - self_pos.y
			local z1 = punchset[name].pos11.z - self_pos.z

			local x2 = pos.x - self_pos.x					-- target
			local y2 = pos.y - self_pos.y
			local z2 = pos.z - self_pos.z

			if mode == "object" then
				meta:set_int("dim", 1)
			else
				if x0 > x1 then x0, x1 = x1, x0 end -- this ensures that x0 <= x1
				if y0 > y1 then y0, y1 = y1, y0 end
				if z0 > z1 then z0, z1 = z1, z0 end
				meta:set_int("dim", (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1))
			end

			meta:set_int("x0", x0); meta:set_int("y0", y0); meta:set_int("z0", z0)
			meta:set_int("x1", x1); meta:set_int("y1", y1); meta:set_int("z1", z1)
			meta:set_int("x2", x2); meta:set_int("y2", y2); meta:set_int("z2", z2)
			meta:set_int("pc", 0)
			punchset[name] = {state = 0, node = ""}
			minetest.chat_send_player(name, S("MOVER: End position for mover set."))
		end


	-- DISTRIBUTOR
	elseif punchset_desc == "DISTRIBUTOR" then
		local x = pos.x - self_pos.x
		local y = pos.y - self_pos.y
		local z = pos.z - self_pos.z

		if abs(x) > 2 * max_range or abs(y) > 2 * max_range or abs(z) > 2 * max_range then
			minetest.chat_send_player(name, S("DISTRIBUTOR: Punch closer to distributor. Aborting."))
			punchset[name] = {state = 0, node = ""}; return
		end

		machines.mark_pos1(name, pos) -- mark pos1

		local meta = minetest.get_meta(self_pos)
		meta:set_int("x" .. punch_state, x); meta:set_int("y" .. punch_state, y); meta:set_int("z" .. punch_state, z)
		if x == 0 and y == 0 and z == 0 then meta:set_int("active" .. punch_state, 0) end

		punchset[name] = {state = 0, node = ""}
		minetest.chat_send_player(name, S("DISTRIBUTOR: Target set."))


	-- KEYPAD
	elseif punchset_desc == "KEYPAD" then -- keypad setup code
		if minetest.is_protected(pos, name) then
			minetest.chat_send_player(name, S("KEYPAD: Punched position is protected. Aborting."))
			punchset[name] = {state = 0, node = ""}; return
		end

		local x = pos.x - self_pos.x
		local y = pos.y - self_pos.y
		local z = pos.z - self_pos.z

		if abs(x) > max_range or abs(y) > max_range or abs(z) > max_range then
			minetest.chat_send_player(name, S("KEYPAD: Punch closer to keypad. Resetting."))
			punchset[name] = {state = 0, node = ""}; return
		end

		machines.mark_pos1(name, pos) -- mark pos1

		local meta = minetest.get_meta(self_pos)
		meta:set_int("x0", x); meta:set_int("y0", y); meta:set_int("z0", z)
		meta:set_string("infotext", S("Punch keypad to use it."))
		punchset[name] = {state = 0, node = ""}
		minetest.chat_send_player(name, S("KEYPAD: Target set with coordinates @1,@2,@3.", x, y, z))


	-- DETECTOR
	elseif punchset_desc == "DETECTOR" then
		if abs(pos.x - self_pos.x) > max_range or
			abs(pos.y - self_pos.y) > max_range or
			abs(pos.z - self_pos.z) > max_range
		then
			minetest.chat_send_player(name, S("DETECTOR: Punch closer to detector. Aborting."))
			punchset[name] = {state = 0, node = ""}; return
		end

		if punch_state == 1 then
			punchset[name].pos1 = pos
			punchset[name].state = 2
			machines.mark_pos1(name, pos) -- mark pos1
			minetest.chat_send_player(name, S("DETECTOR: Now punch the target machine."))
		elseif punch_state == 2 then
			if vector.equals(pos, self_pos) then
				minetest.chat_send_player(name, S("DETECTOR: Punch something else. Aborting."))
				punchset[name] = {state = 0, node = ""}; return
			end

			machines.mark_pos2(name, pos) -- mark pos2

			local x = punchset[name].pos1.x - self_pos.x
			local y = punchset[name].pos1.y - self_pos.y
			local z = punchset[name].pos1.z - self_pos.z

			local meta = minetest.get_meta(self_pos)
			meta:set_int("x0", x); meta:set_int("y0", y); meta:set_int("z0", z)
			x = pos.x - self_pos.x; y = pos.y - self_pos.y; z = pos.z - self_pos.z
			meta:set_int("x2", x); meta:set_int("y2", y); meta:set_int("z2", z)
			punchset[name] = {state = 0, node = ""}
			minetest.chat_send_player(name, S("DETECTOR: Setup complete."))
		end
	end
end)

-- FORM PROCESSING for all machines: mover, distributor, keypad, detector
local fnames = {
	"basic_machines:mover_",
	"basic_machines:distributor_",
	"basic_machines:keypad_",
	"basic_machines:check_keypad_",
	"basic_machines:detector_"
}

local function check_fname(formname)
	for i = 1, #fnames do
		local fname = fnames[i]; local fname_len = fname:len()
		if formname:sub(1, fname_len) == fname then
			return fname:sub(("basic_machines:"):len() + 1, fname_len - 1), formname:sub(fname_len + 1)
		end
	end
end

local function strip_translator_sequence(msg) return msg:match("%)([%w_-]+)") end

-- list of machines that distributor can connect to, used for distributor scan feature
local connectables = {
	["basic_machines:ball_spawner"] = true,
	["basic_machines:battery_0"] = true,
	["basic_machines:battery_1"] = true,
	["basic_machines:battery_2"] = true,
	["basic_machines:clockgen"] = true,
	["basic_machines:detector"] = true,
	["basic_machines:distributor"] = true,
	["basic_machines:generator"] = true,
	["basic_machines:keypad"] = true,
	["basic_machines:light_off"] = true,
	["basic_machines:light_on"] = true,
	["basic_machines:mover"] = true
}

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local formname_sub, pos = check_fname(formname); if not formname_sub or pos == "" then return end
	local name = player:get_player_name(); if name == "" then return end
	pos = minetest.string_to_pos(pos)
	local meta = minetest.get_meta(pos)


	-- MOVER
	if formname_sub == "mover" then
		if fields.OK and not minetest.is_protected(pos, name) then
			if meta:get_int("seltab") == 2 then -- POSITIONS
				local x0, y0, z0 = tonumber(fields.x0) or 0, tonumber(fields.y0) or -1, tonumber(fields.z0) or 0
				local x1, y1, z1 = tonumber(fields.x1) or 0, tonumber(fields.y1) or -1, tonumber(fields.z1) or 0
				local x2, y2, z2 = tonumber(fields.x2) or 0, tonumber(fields.y2) or 1, tonumber(fields.z2) or 0

				if minetest.is_protected(vector.add(pos, {x = x0, y = y0, z = z0}), name) or
					minetest.is_protected(vector.add(pos, {x = x1, y = y1, z = z1}), name) or
					minetest.is_protected(vector.add(pos, {x = x2, y = y2, z = z2}), name)
				then
					minetest.chat_send_player(name, S("MOVER: Position is protected. Aborting.")); return
				end

				-- did the numbers change from last time ?
				if meta:get_int("x0") ~= x0 or meta:get_int("y0") ~= y0 or meta:get_int("z0") ~= z0 or
					meta:get_int("x1") ~= x1 or meta:get_int("y1") ~= y1 or meta:get_int("z1") ~= z1 or
					meta:get_int("x2") ~= x2 or meta:get_int("y2") ~= y2 or meta:get_int("z2") ~= z2
				then
					-- are new numbers inside bounds ?
					if not minetest.check_player_privs(name, "privs") and
						(abs(x0) > max_range or abs(y0) > max_range or abs(z0) > max_range or
						abs(x1) > max_range or abs(y1) > max_range or abs(z1) > max_range or
						abs(x2) > max_range or abs(y2) > max_range or abs(z2) > max_range)
					then
						minetest.chat_send_player(name, S("MOVER: All coordinates must be between @1 and @2. For increased range set up positions by punching.",
							-max_range, max_range)); return
					end
				end

				if meta:get_string("mode") == "object" then
					meta:set_int("dim", 1)
				else
					local x = x0; x0 = math.min(x, x1); x1 = math.max(x, x1)
					local y = y0; y0 = math.min(y, y1); y1 = math.max(y, y1)
					local z = z0; z0 = math.min(z, z1); z1 = math.max(z, z1)
					meta:set_int("dim", (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1))
				end

				meta:set_int("x0", x0); meta:set_int("y0", y0); meta:set_int("z0", z0)
				meta:set_int("x1", x1); meta:set_int("y1", y1); meta:set_int("z1", z1)
				meta:set_int("x2", x2); meta:set_int("y2", y2); meta:set_int("z2", z2)

				meta:set_string("inv1", fields.inv1 and (strip_translator_sequence(fields.inv1) or fields.inv1) or "")
				meta:set_string("inv2", fields.inv2 and (strip_translator_sequence(fields.inv2) or fields.inv2) or "")
				meta:set_int("reverse", tonumber(fields.reverse) or 0)

				-- notification
				meta:set_string("infotext", S("Mover block." ..
					" Set up with source coordinates @1,@2,@3 -> @4,@5,@6 and target coordinates @7,@8,@9." ..
					" Put charged battery next to it and start it with keypad/mese signal.", x0, y0, z0, x1, y1, z1, x2, y2, z2))
			else -- MODE
				local mode = strip_translator_sequence(fields.mode) or fields.mode
				local prefer = fields.prefer or ""
				local mreverse = meta:get_int("reverse")

				-- mode
				if mode ~= meta:get_string("mode") then
					-- input validation
					if basic_machines.check_mover_filter(mode, prefer, mreverse) or
						basic_machines.check_target_chest(mode, pos, meta)
					then
						meta:set_string("mode", mode)
					else
						minetest.chat_send_player(name, S("MOVER: Wrong filter - must be name of existing minetest block"))
					end
				end

				-- filter
				if prefer ~= meta:get_string("prefer") then
					-- input validation
					if basic_machines.check_mover_filter(mode, prefer, mreverse) or
						basic_machines.check_target_chest(mode, pos, meta)
					then
						meta:set_string("prefer", prefer)
						meta:get_inventory():set_list("filter", {})
					else
						minetest.chat_send_player(name, S("MOVER: Wrong filter - must be name of existing minetest block"))
					end
				end

				if meta:get_float("fuel") < 0 then meta:set_float("fuel", 0) end -- reset block

				-- display battery
				local fpos = basic_machines.find_and_connect_battery(pos)

				if not fpos then
					if meta:get_int("upgrade") > -1 then
						minetest.chat_send_player(name, S("MOVER: Please put battery nearby"))
					end
				else
					minetest.chat_send_player(name, S("MOVER: Battery found - displaying mark 1"))
					machines.mark_pos1(name, fpos)
				end
			end

		elseif fields.tabs then
			meta:set_int("seltab", tonumber(fields.tabs) or 1)

			minetest.show_formspec(name, "basic_machines:mover_" .. minetest.pos_to_string(pos),
				basic_machines.get_mover_form(pos, name))

		elseif fields.help then
			minetest.show_formspec(name, "basic_machines:help_mover", "size[6,7]textarea[0,0;6.5,8.5;help;" ..
				F(S("MOVER HELP")) .. ";" .. F(S("version @1\nSETUP: For interactive setup punch the mover and then punch source1, source2, target node (follow instructions)." ..
				" Put the mover directly next to a battery. For advanced setup right click mover." ..
				" Positions are defined by x y z coordinates (see top of mover for orientation)." ..
				" Mover itself is at coordinates 0, 0, 0.", basic_machines.version)) ..
				F(S("\n\nMODES of operation: normal (just teleport block), dig (digs and gives you resulted node - good for harvesting farms);" ..
				" by setting 'filter' only selected node is moved, drop (drops node on ground), object (teleportation of players and objects)" ..
				" - distance between source1/2 defines teleport radius; by setting 'filter' you can specify move time - [0.2, 20] - for non players." ..
				"\nAfter changing from/to object mode, you need to reconfigure sources position." ..
				"\nInventory mode can exchange items between node inventories." ..
				" You need to select inventory name for source/target from the dropdown list on the right.\n" ..
				"\nADVANCED:\nYou can reverse start/end position by setting reverse nonzero." ..
				" This is useful for placing stuff at many locations-planting." ..
				" If you put reverse = 2/3 in transport mode it will disable parallel transport but will still do reverse effect with 3." ..
				" If you activate mover with OFF signal it will toggle reverse.")) ..
				F(S("\n\nFUEL CONSUMPTION depends on blocks to be moved and distance." ..
				" For example, stone or tree is harder to move than dirt, harvesting wheat is very cheap and and moving lava is very hard." ..
				"\n\nUPGRADE mover by moving mese blocks in upgrade inventory." ..
				" Each mese block increases mover range by @1, fuel consumption is divided by (number of mese blocks)+1 in upgrade." ..
				" Max @2 blocks are used for upgrade." ..
				"\n\nActivate mover by keypad/detector signal or mese signal through mesecon adapter (if mesecons mod).",
				max_range, mover_upgrade_max)) .. "]")

		elseif fields.mode and not minetest.is_protected(pos, name) then
			local mode = strip_translator_sequence(fields.mode) or fields.mode
			-- input validation
			if not basic_machines.check_mover_filter(mode, meta:get_string("prefer"), meta:get_int("reverse")) and
				not basic_machines.check_target_chest(mode, pos, meta)
			then
				minetest.chat_send_player(name, S("MOVER: Wrong filter - must be name of existing minetest block")); return
			end

			meta:set_string("mode", mode)

			minetest.show_formspec(name, "basic_machines:mover_" .. minetest.pos_to_string(pos),
				basic_machines.get_mover_form(pos, name))
		end


	-- DISTRIBUTOR
	elseif formname_sub == "distributor" then
		if fields.OK then
			if minetest.is_protected(pos, name) then return end

			local view = meta:get_int("view") == 0
			for i = 1, meta:get_int("n") do
				local xi, yi, zi = meta:get_int("x" .. i), meta:get_int("y" .. i), meta:get_int("z" .. i)
				local posfi = {
					x = tonumber(fields["x" .. i]) or xi,
					y = tonumber(fields["y" .. i]) or yi,
					z = tonumber(fields["z" .. i]) or zi
				}

				if minetest.is_protected(vector.add(pos, posfi), name) then
					minetest.chat_send_player(name, S("DISTRIBUTOR: Position @1 is protected. Aborting.",
						minetest.pos_to_string(posfi))); return
				end

				if view and (xi ~= posfi.x or yi ~= posfi.y or zi ~= posfi.z) then
					if not minetest.check_player_privs(name, "privs") and
						(abs(posfi.x) > 2 * max_range or abs(posfi.y) > max_range or abs(posfi.z) > 2 * max_range)
					then
						minetest.chat_send_player(name, S("DISTRIBUTOR: All coordinates must be between @1 and @2.",
							-2 * max_range, 2 * max_range)); return
					end

					meta:set_int("x" .. i, posfi.x); meta:set_int("y" .. i, posfi.y); meta:set_int("z" .. i, posfi.z)
				end

				local activefi = tonumber(fields["active" .. i]) or 0
				if meta:get_int("active" .. i) ~= activefi then
					if vector.equals(posfi, {x = 0, y = 0, z = 0}) then
						meta:set_int("active" .. i, 0) -- no point in activating itself
					else
						meta:set_int("active" .. i, activefi)
					end
				end
			end

			meta:set_float("delay", tonumber(fields.delay) or 0)

		elseif fields.ADD then
			if minetest.is_protected(pos, name) then return end

			local n = meta:get_int("n")
			if n < 16 then meta:set_int("n", n + 1) end -- max 16 outputs

			minetest.show_formspec(name, "basic_machines:distributor_" .. minetest.pos_to_string(pos),
				basic_machines.get_distributor_form(pos))

		elseif fields.view then -- change view mode
			meta:set_int("view", 1 - meta:get_int("view"))

			minetest.show_formspec(name, "basic_machines:distributor_" .. minetest.pos_to_string(pos),
				basic_machines.get_distributor_form(pos))

		elseif fields.scan then -- scan for connectable nodes
			if minetest.is_protected(pos, name) then return end

			local x1, y1, z1 = meta:get_int("x1"), meta:get_int("y1"), meta:get_int("z1")
			local x2, y2, z2 = meta:get_int("x2"), meta:get_int("y2"), meta:get_int("z2")

			if x1 > x2 then x1, x2 = x2, x1 end
			if y1 > y2 then y1, y2 = y2, y1 end
			if z1 > z2 then z1, z2 = z2, z1 end

			local count = 0

			for x = x1, x2 do
				for y = y1, y2 do
					for z = z1, z2 do
						if count >= 16 then break end
						local poss = vector.add(pos, {x = x, y = y, z = z})
						if not minetest.is_protected(poss, name) and
							connectables[minetest.get_node(poss).name]
						then
							count = count + 1
							meta:set_int("x" .. count, x); meta:set_int("y" .. count, y); meta:set_int("z" .. count, z)
							meta:set_int("active" .. count, 1) -- turns the connection on
						end
					end
				end
			end

			meta:set_int("n", count)
			minetest.chat_send_player(name, S("DISTRIBUTOR: Connected @1 targets.", count))

		elseif fields.help then
			minetest.show_formspec(name, "basic_machines:help_distributor", "size[5.5,5.5]textarea[0,0;6,7;help;" ..
				F(S("DISTRIBUTOR HELP")) .. ";" .. F(S("SETUP: To select target nodes for activation click SET then click target node.\n" ..
				"You can add more targets with ADD. To see where target node is click SHOW button next to it.\n" ..
				"\n4 numbers in each row represent (from left to right): first 3 numbers are target coordinates x y z, last number (MODE) controls how signal is passed to target.\n" ..
				"For example, to only pass OFF signal use -2, to only pass ON use 2, -1 negates the signal, 1 passes original signal, 0 blocks signal.\n" ..
				"delay option adds delay to activations, in seconds. A negative delay activation is randomized with probability -delay/1000.\n" ..
				"view button toggles view of target names, in names view there is button scan which automatically scans for valid targets in a box defined by first and second target.\n"..
				"\nADVANCED:\nYou can use the distributor as an event handler - it listens to events like interact attempts and chat around the distributor.\n" ..
				"You need to place the distributor at a position (x, y, z), with coordinates of the form (20*i, 20*j+1, 20*k) for some integers i, j, k.\n" ..
				"Left click while holding sneak key with a distributor in the hand to show a suitable position.\n" ..
				"Then you need to configure first row of numbers in the distributor:\n" ..
				"by putting 0 as MODE it will start to listen." ..
				" First number x = 0/1 controls if node listens to failed interact attempts around it, second number y = -1/0/1 controls listening to chat (-1 additionally mutes chat)")) .. "]")

		else
			local n, j = meta:get_int("n"), -1

			-- SHOWING TARGET
			for i = 1, n do if fields["SHOW" .. i] then j = i; break end end
			-- show j - th point
			if j > 0 then
				machines.mark_pos1(name, vector.add(pos, {
					x = meta:get_int("x" .. j),
					y = meta:get_int("y" .. j),
					z = meta:get_int("z" .. j)
				}))
				return
			end

			if minetest.is_protected(pos, name) then return end

			-- SETUP TARGET
			for i = 1, n do if fields["SET" .. i] then j = i; break end end
			-- set up j - th point
			if j > 0 then
				punchset[name] = {
					pos = pos,
					node = "basic_machines:distributor",
					state = j
				}
				minetest.chat_send_player(name, S("DISTRIBUTOR: Punch the position to set target @1.", j)); return
			end

			-- REMOVE TARGET
			if n > 0 then
				for i = 1, n do if fields["X" .. i] then j = i; break end end
				-- remove j - th point
				if j > 0 then
					for i = j, n - 1 do
						meta:set_int("x" .. i, meta:get_int("x" .. (i + 1)))
						meta:set_int("y" .. i, meta:get_int("y" .. (i + 1)))
						meta:set_int("z" .. i, meta:get_int("z" .. (i + 1)))
						meta:set_int("active" .. i, meta:get_int("active" .. (i + 1)))
					end

					meta:set_int("n", n - 1)

					minetest.show_formspec(name, "basic_machines:distributor_" .. minetest.pos_to_string(pos),
						basic_machines.get_distributor_form(pos))
				end
			end
		end


	-- KEYPAD
	elseif formname_sub == "keypad" then
		if fields.OK and not minetest.is_protected(pos, name) then
			local x0, y0, z0 = tonumber(fields.x0) or 0, tonumber(fields.y0) or 1, tonumber(fields.z0) or 0

			if minetest.is_protected(vector.add(pos, {x = x0, y = y0, z = z0}), name) then
				minetest.chat_send_player(name, S("KEYPAD: Position is protected. Aborting.")); return
			end

			if not minetest.check_player_privs(name, "privs") and
				(abs(x0) > max_range or abs(y0) > max_range or abs(z0) > max_range)
			then
				minetest.chat_send_player(name, S("KEYPAD: All coordinates must be between @1 and @2.",
					-max_range, max_range)); return
			end

			meta:set_int("mode", tonumber(fields.mode) or 2)
			meta:set_int("iter", math.min(tonumber(fields.iter) or 1, 500))

			local pass = fields.pass or ""

			if pass ~= "" and pass:len() <= 16 then -- don't replace password with hash which is longer - 27 chars
				pass = minetest.get_password_hash(pos.x, pass .. pos.y); pass = minetest.get_password_hash(pos.y, pass .. pos.z)
				meta:set_string("pass", pass)
			end

			meta:set_string("text", fields.text)
			if fields.text:sub(1,1) == "!" then
				minetest.log("action", ("%s set up keypad for message display at %s,%s,%s"):format(name, pos.x, pos.y, pos.z))
			end
			meta:set_int("x0", x0); meta:set_int("y0", y0); meta:set_int("z0", z0)

			if pass == "" then
				meta:set_string("infotext", S("Punch keypad to use it."))
			else
				if fields.text == "@" then
					meta:set_string("infotext", S("Punch keyboard to use it."))
				else
					meta:set_string("infotext", S("Punch keypad to use it. Password protected."))
				end
			end

		elseif fields.help then
			minetest.show_formspec(name, "basic_machines:help_keypad", "size[6,7]textarea[0,0;6.5,8.5;help;" ..
				F(S("KEYPAD HELP")) .. ";" .. F(S("Mode: 1=OFF, 2=ON, 3=TOGGLE control the way how target node is activated." ..
				"\n\nRepeat: Number to control how many times activation is repeated after initial punch." ..
				"\n\nPassword: Enter password and press OK. Password will be encrypted." ..
				" Next time you use keypad you will need to enter correct password to gain access." ..
				"\n\nText: If set then text on target node will be changed." ..
				" In case target is detector/mover, filter settings will be changed. Can be used for special operations." ..
				"\n\nTarget: Represents coordinates (x, y, z) relative to keypad." ..
				" (0, 0, 0) is keypad itself, (0, 1, 0) is one node above, (0, -1, 0) one node below." ..
				" X coordinate axes goes from east to west, Y from down to up, Z from south to north." ..
				"\n\n****************\nUsage\n****************\n")) ..
				F(S("\nJust punch (left click) keypad, then the target block will be activated." ..
				"\nTo set text on other nodes (text shows when you look at node) just target the node and set nonempty text." ..
				" Upon activation text will be set. When target node is another keypad, its \"text\" field will be set." ..
				" When targets is mover/detector, its \"filter\" field will be set. To clear \"filter\" set text to \"@@\"." ..
				" When target is distributor, you can change i-th target of distributor to mode mode with \"i mode\"." ..
				"\n\nKeyboard: To use keypad as keyboard for text input write \"@@\" in \"text\" field and set any password." ..
				" Next time keypad is used it will work as text input device." ..
				"\n\nDisplaying messages to nearby players (up to 5 blocks around keypad's target): Set text to \"!text\"." ..
				" Upon activation player will see \"text\" in their chat." ..
				"\n\nPlaying sound to nearby players: set text to \"$sound_name\", optionally followed by a space and pitch value: 0.01 to 10.")) ..
				F(S("\n\nADVANCED:\nText replacement: Suppose keypad A is set with text \"@@some @@. text @@!\" and there are blocks on top of keypad A with infotext '1' and '2'." ..
				" Suppose we target B with A and activate A. Then text of keypad B will be set to \"some 1. text 2!\"." ..
				"\nWord extraction: Suppose similar setup but now keypad A is set with text \"%1\"." ..
				" Then upon activation text of keypad B will be set to 1.st word of infotext.")) .. "]")
		end

	elseif formname_sub == "check_keypad" then
		if fields.OK then
			local pass = fields.pass or ""

			if meta:get_string("text") == "@" then -- keyboard mode
				meta:set_string("input", pass)
				meta:set_int("count", 1)
				basic_machines.use_keypad(pos, machines_TTL, 0)
				return
			end

			pass = minetest.get_password_hash(pos.x, pass .. pos.y); pass = minetest.get_password_hash(pos.y, pass .. pos.z)

			if pass ~= meta:get_string("pass") then
				minetest.chat_send_player(name, S("ACCESS DENIED. WRONG PASSWORD.")); return
			end

			minetest.chat_send_player(name, S("ACCESS GRANTED"))

			if meta:get_int("count") <= 0 then -- only accept new operation requests if idle
				meta:set_int("count", meta:get_int("iter"))
				meta:set_int("active_repeats", 0)
				basic_machines.use_keypad(pos, machines_TTL, 0)
			else
				meta:set_int("count", 0)
				meta:set_string("infotext", S("Operation aborted by user. Punch to activate.")) -- reset
			end
		end


	-- DETECTOR
	elseif formname_sub == "detector" then
		if fields.OK and not minetest.is_protected(pos, name) then
			local x0, y0, z0 = tonumber(fields.x0) or 0, tonumber(fields.y0) or 0, tonumber(fields.z0) or 0
			local x1, y1, z1 = tonumber(fields.x1) or 0, tonumber(fields.y1) or 0, tonumber(fields.z1) or 0
			local x2, y2, z2 = tonumber(fields.x2) or 0, tonumber(fields.y2) or 0, tonumber(fields.z2) or 0

			if minetest.is_protected(vector.add(pos, {x = x0, y = y0, z = z0}), name) or
				minetest.is_protected(vector.add(pos, {x = x1, y = y1, z = z1}), name) or
				minetest.is_protected(vector.add(pos, {x = x2, y = y2, z = z2}), name)
			then
				minetest.chat_send_player(name, S("DETECTOR: Position is protected. Aborting.")); return
			end

			if not minetest.check_player_privs(name, "privs") and
				(abs(x0) > max_range or abs(y0) > max_range or abs(z0) > max_range or
				abs(x1) > max_range or abs(y1) > max_range or abs(z1) > max_range or
				abs(x2) > max_range or abs(y2) > max_range or abs(z2) > max_range)
			then
				minetest.chat_send_player(name, S("DETECTOR: All coordinates must be between @1 and @2.",
					-max_range, max_range)); return
			end

			meta:set_int("x0", x0); meta:set_int("y0", y0); meta:set_int("z0", z0)
			meta:set_int("x1", x1); meta:set_int("y1", y1); meta:set_int("z1", z1)
			meta:set_int("x2", x2); meta:set_int("y2", y2); meta:set_int("z2", z2)

			meta:set_string("op", strip_translator_sequence(fields.op) or fields.op)
			meta:set_int("r", math.min((tonumber(fields.r) or 1), max_range))
			meta:set_string("node", fields.node or "")
			meta:set_int("NOT", tonumber(fields.NOT) or 0)
			meta:set_string("mode", strip_translator_sequence(fields.mode) or fields.mode)
			meta:set_string("inv1", strip_translator_sequence(fields.inv1) or fields.inv1)

		elseif fields.help then
			minetest.show_formspec(name, "basic_machines:help_detector", "size[5.5,5.5]textarea[0,0;6,7;help;" ..
				F(S("DETECTOR HELP")) .. ";" .. F(S("SETUP: Right click or punch and follow chat instructions." ..
				" With a detector you can detect nodes, objects, players, items inside inventories, nodes information and light levels. " ..
				"If detector activates it will trigger machine at target position." ..
				"\n\nThere are 6 modes of operation - node/player/object/inventory/infotext/light detection." ..
				" Inside detection filter write node/player/object name or infotext/light level." ..
				" If you detect node/player/object you can specify a range of detection." ..
				" If you want detector to activate target precisely when its not triggered set output signal to 1.\n" ..
				"\nFor example, to detect empty space write air, to detect tree write default:tree, to detect ripe wheat write farming:wheat_8, for flowing water write default:water_flowing... " ..
				"If mode is inventory it will check for items in specified inventory of source node like a chest.\n" ..
				"\nADVANCED:\nIn inventory (must set a filter)/node detection mode, you can specify a second source and then select AND/OR from the right top dropdown list to do logical operations." ..
				"\nYou can also filter output signal in any modes:\n" ..
				"-2=only OFF, -1=NOT, 0/1=normal, 2=only ON, 3=only if changed, 4=if target is keypad set its text to detected object name.")) .. "]")
		end
	end
end)
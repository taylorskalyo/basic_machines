local F, S = basic_machines.F, basic_machines.S
local machines_minstep = basic_machines.properties.machines_minstep
local detector_oplist = {["-"] = 1, ["AND"] = 2, ["OR"] = 3}
local detector_modelist = {["node"] = 1, ["player"] = 2, ["object"] = 3, ["inventory"] = 4,
	["infotext"] = 5, ["light"] = 6}
local detector_modelist_translated = {}

for k, v in pairs(detector_modelist) do
	detector_modelist_translated[v] = F(S(k))
end
detector_modelist_translated = table.concat(detector_modelist_translated, ",")

minetest.register_node("basic_machines:detector", {
	description = S("Detector - can detect blocks/players/objects and activate machines"),
	groups = {cracky = 3},
	tiles = {"basic_machines_detector.png"},
	sounds = default.node_sound_wood_defaults(),

	after_place_node = function(pos, placer)
		if not placer then return end

		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", S("Detector. Right click/punch to set it up."))
		meta:set_string("owner", placer:get_player_name())

		meta:set_int("x0", 0); meta:set_int("y0", 0); meta:set_int("z0", 0) -- source1: read
		meta:set_string("op", "-")
		meta:set_int("x1", 0); meta:set_int("y1", 0); meta:set_int("z1", 0) -- source2: read
		meta:set_int("x2", 0); meta:set_int("y2", 1); meta:set_int("z2", 0) -- target: activate
		meta:set_int("r", 0)
		meta:set_string("node", ""); meta:set_int("NOT", 2)
		meta:set_string("mode", "node")
		meta:set_int("state", 0)
	end,

	can_dig = function(pos, player)
		return minetest.get_meta(pos):get_string("owner") == player:get_player_name()
	end,

	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta, name = minetest.get_meta(pos), player:get_player_name()

		local pos1 = {x = meta:get_int("x0"), y = meta:get_int("y0"), z = meta:get_int("z0")}
		local pos11 = {x = meta:get_int("x1"), y = meta:get_int("y1"), z = meta:get_int("z1")}
		local pos2 = {x = meta:get_int("x2"), y = meta:get_int("y2"), z = meta:get_int("z2")}

		local pos1_abs = vector.add(pos, pos1)

		machines.mark_pos1(name, pos1_abs) -- mark pos1
		machines.mark_pos2(name, vector.add(pos, pos2)) -- mark pos2

		local op = detector_oplist[meta:get_string("op")] or 1
		local mode_string = meta:get_string("mode")
		local node_filter = meta:get_string("node")

		-- pos11 and logical operations are only available with node/inventory mode
		if mode_string == "node" or mode_string == "inventory" and node_filter ~= "" then
			machines.mark_pos11(name, vector.add(pos, pos11)) -- mark pos11
		end

		local inventory_list

		if mode_string == "inventory" then
			local meta1 = minetest.get_meta(pos1_abs)
			local inv1m = meta:get_string("inv1")
			local inv1 = 1

			local list1, inv_list1 = meta1:get_inventory():get_lists(), ""
			-- stupid dropdown requires item index but returns string on receive so we have to find index.. grrr
			-- one other solution: invert the table: key <-> value
			local j = 1
			for k, _ in pairs(list1) do
				inv_list1 = inv_list1 .. F(S(k)) .. ","
				if k == inv1m then inv1 = j end; j = j + 1
			end
			inventory_list = "label[0,5.1;" .. F(S("Inventory selection")) ..
				"]dropdown[0,5.5;3,1;inv1;" .. inv_list1:gsub(",$", "") .. ";" .. inv1 .. "]"
		else
			inventory_list = "label[0,5.1;" .. F(S("Inventory selection")) .. "]dropdown[0,5.5;3,1;inv1;;]"
		end

		minetest.show_formspec(name, "basic_machines:detector_" .. minetest.pos_to_string(pos), "size[4,6.25]" ..
			"field[0.25,0.5;1,1;x0;" .. F(S("Source1")) .. ";" .. pos1.x ..
			"]field[1.25,0.5;1,1;y0;;" .. pos1.y .. "]field[2.25,0.5;1,1;z0;;" .. pos1.z ..
			"]dropdown[3,0.25;1,1;op;" .. F(S("-")) .. "," .. F(S("AND")) .. "," .. F(S("OR")) .. ";" .. op ..
			"]field[0.25,1.5;1,1;x1;" .. F(S("Source2")) .. ";" .. pos11.x ..
			"]field[1.25,1.5;1,1;y1;;" .. pos11.y .. "]field[2.25,1.5;1,1;z1;;" .. pos11.z ..
			"]field[0.25,2.5;1,1;x2;" .. F(S("Target")) .. ";" .. pos2.x ..
			"]field[1.25,2.5;1,1;y2;;" .. pos2.y .. "]field[2.25,2.5;1,1;z2;;" .. pos2.z ..
			"]field[3.25,2.5;1,1;r;" .. F(S("Radius")) .. ";" .. meta:get_int("r") ..
			"]field[0.25,3.5;2,1;node;" .. F(S("Detection filter")) .. ";" .. F(node_filter) ..
			"]field[2.25,3.5;2,1;NOT;" .. F(S("Filter out -2/-1/0/1/2/3/4")) .. ";" .. meta:get_int("NOT") ..
			"]label[0,4.1;" .. minetest.colorize("lawngreen", F(S("MODE selection"))) .. "]" ..
			"]dropdown[0,4.5;3,1;mode;" .. detector_modelist_translated .. ";" .. (detector_modelist[mode_string] or 1) ..
			"]button[3,4.4;1,1;help;" .. F(S("help")) .. "]" ..
			inventory_list .. "button_exit[3,5.4;1,1;OK;" .. F(S("OK")) .. "]")
	end,

	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
	--[[
		local mode = "node"
		local meta = minetest.get_meta(pos)
		if to_index == 2 then
			mode = "player"
			meta:set_int("r", math.max(meta:get_int("r"), 1))
		end
		if to_index == 3 then
			mode = "object"
			meta:set_int("r", math.max(meta:get_int("r"), 1))
		end
		meta:set_string("mode", mode)
		minetest.chat_send_player(player:get_player_name(), S("DETECTOR: Mode of operation set to: @1", S(mode)))
		return count
	--]]
		return 0
	end,

	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		return 0
	end,

	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		return 0
	end,

	effector = {
		action_on = function(pos, ttl)
			if type(ttl) ~= "number" then ttl = 1 end
			if ttl < 1 then return end -- machines_TTL prevents infinite recursion

			local meta = minetest.get_meta(pos)

			local t0, t1 = meta:get_int("t"), minetest.get_gametime()
			local T = meta:get_int("T") -- temperature

			if t0 > t1 - machines_minstep then -- activated before natural time
				T = T + 1
			else
				if T > 0 then T = T - 1 end
			end
			meta:set_int("T", T)
			meta:set_int("t", t1) -- update last activation time

			if T > 2 then -- overheat
				minetest.sound_play("default_cool_lava", {pos = pos, max_hear_distance = 16, gain = 0.25}, true)
				meta:set_string("infotext", S("Overheat: temperature @1", T))
				return
			end

			local pos1 = vector.add(pos, {x = meta:get_int("x0"), y = meta:get_int("y0"), z = meta:get_int("z0")})

			local mode = meta:get_string("mode")
			local node = meta:get_string("node") -- detection filter
			local NOT = meta:get_int("NOT")

			local detected_obj = ""
			local trigger = false

			if mode == "node" then
				local tnode = minetest.get_node(pos1).name -- read node at source position
				local r = meta:get_int("r")
				detected_obj = tnode

				if (node == "" and tnode ~= "air") or node == tnode then
					trigger = true
				elseif r > 0 and node ~= "" then
					if minetest.find_node_near(pos1, r, {node}) then trigger = true end
				end

				local op = meta:get_string("op")

				-- operation: AND, OR... look at other source position too
				if op ~= "-" then
					local pos11 = vector.add(pos, {x = meta:get_int("x1"), y = meta:get_int("y1"), z = meta:get_int("z1")})
					tnode = minetest.get_node(pos11).name -- read node at source position
					local trigger1 = false

					if (node == "" and tnode ~= "air") or node == tnode then
						trigger1 = true
					elseif r > 0 and node ~= "" then
						if minetest.find_node_near(pos1, r, {node}) then trigger1 = true end
					end

					if op == "AND" then
						trigger = trigger and trigger1
					elseif op == "OR" then
						trigger = trigger or trigger1
					end
				end

			elseif mode == "inventory" then
				local inv = minetest.get_meta(pos1):get_inventory()
				local inv1m = meta:get_string("inv1")

				if node == "" then -- if there is item report name and trigger
					if inv:is_empty(inv1m) then
						trigger = false
					else -- nonempty
						trigger = true
						for i = 1, inv:get_size(inv1m) do -- find item to move in inventory
							local stack = inv:get_stack(inv1m, i)
							if not stack:is_empty() then detected_obj = stack:to_string(); break end
						end
					end
				else -- node name was set
					if inv:contains_item(inv1m, ItemStack(node)) then
						trigger = true;	detected_obj = node
					end

					local op = meta:get_string("op")

					-- operation: AND, OR... look at other source position too
					if op ~= "-" then
						local pos11 = vector.add(pos, {x = meta:get_int("x1"), y = meta:get_int("y1"), z = meta:get_int("z1")})
						local trigger1 = minetest.get_meta(pos11):get_inventory():contains_item(inv1m, ItemStack(node))

						if op == "AND" then
							trigger = trigger and trigger1
						elseif op == "OR" then
							trigger = trigger or trigger1
						end
					end
				end

			elseif mode == "infotext" then
				detected_obj = minetest.get_meta(pos1):get_string("infotext")
				-- if detected_obj == node or node == "" then trigger = true end
				if detected_obj:find(node) or node == "" then trigger = true end

			elseif mode == "light" then
				detected_obj = minetest.get_node_light(pos1) or 0
				if detected_obj >= (tonumber(node) or 0) or node == "" then trigger = true end

			else -- players/objects
				local player_near = false
				for _, obj in ipairs(minetest.get_objects_inside_radius(pos1, meta:get_int("r"))) do
					if mode == "player" then
						if obj:is_player() then
							player_near = true
							detected_obj = obj:get_player_name()
							if node == "" or detected_obj == node then
								trigger = true; break
							end
						end
					elseif mode == "object" and not obj:is_player() then
						local lua_entity = obj:get_luaentity()
						if lua_entity then
							detected_obj = lua_entity.itemstring or lua_entity.name or ""
							if detected_obj == node then trigger = true; break end
						end
						if node == "" then trigger = true; break end
					end
				end

				if node ~= "" and mode == "player" and NOT == -1 and not trigger and not player_near then
					trigger = true
				end -- name specified, but no one around and negation -> 0
			end

			-- negation and output filtering
			local state = meta:get_int("state")

			-- -2: only false, -1: NOT, 0: no signal, 1: normal signal: 2: only true, 3: only if change
			if NOT ~= 1 then -- else, just go on normally
				if NOT == -1 then trigger = not trigger -- NEGATION
				elseif NOT == -2 and trigger then meta:set_string("infotext", ""); return -- ONLY FALSE
				elseif NOT == 0 then meta:set_string("infotext", ""); return -- do nothing
				elseif NOT == 2 and not trigger then meta:set_string("infotext", ""); return -- ONLY TRUE
				elseif NOT == 3 and ((trigger and state == 1) or (not trigger and state == 0)) then
					meta:set_string("infotext", ""); return -- no change of state
				end
			end

			local nstate = trigger and 1 or 0 -- next detector output state
			if nstate ~= state then meta:set_int("state", nstate) end -- update state if changed

			local pos2 = vector.add(pos, {x = meta:get_int("x2"), y = meta:get_int("y2"), z = meta:get_int("z2")})

			node = minetest.get_node_or_nil(pos2); if not node then return end -- error
			local def = minetest.registered_nodes[node.name]
			if def and (def.effector or def.mesecons and def.mesecons.effector) then -- activate target
				local effector = def.effector or def.mesecons.effector
				local param = def.effector and (ttl - 1) or node

				if trigger then -- activate target node if successful
					if effector.action_on then
						meta:set_string("infotext", S("Detector: on"))
						if NOT == 4 then -- set detected object name as target text (target must be keypad, if not changes infotext)
							if node.name == "basic_machines:keypad" then
								minetest.get_meta(pos2):set_string("text", detected_obj)
							end
						end
						effector.action_on(pos2, param) -- run
					end
				else
					if effector.action_off then
						meta:set_string("infotext", S("Detector: off"))
						effector.action_off(pos2, param) -- run
					end
				end
			end
		end
	}
})

if basic_machines.settings.register_crafts then
	minetest.register_craft({
		output = "basic_machines:detector",
		recipe = {
			{"default:mese_crystal", "default:mese_crystal"},
			{"default:mese_crystal", "default:mese_crystal"},
			{"basic_machines:keypad", ""}
		}
	})
end
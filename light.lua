local F, S = basic_machines.F, basic_machines.S

minetest.register_node("basic_machines:light_off", {
	description = S("Light Off"),
	groups = {cracky = 3, not_in_creative_inventory = 1},
	tiles = {"basic_machines_light_off.png"},

	effector = {
		action_on = function(pos, _)
			minetest.swap_node(pos, {name = "basic_machines:light_on"})
			local meta = minetest.get_meta(pos)
			local deactivate = meta:get_int("deactivate")

			if deactivate > 0 then
				-- meta:set_int("active", 0)
				minetest.after(deactivate, function()
					-- if meta:get_int("active") ~= 1 then -- was not activated again, so turn it off
						minetest.swap_node(pos, {name = "basic_machines:light_off"}) -- turn off again
						-- meta:set_int("active", 0)
					-- end
				end)
			end
		end
	}
})

minetest.register_node("basic_machines:light_on", {
	description = S("Light On"),
	groups = {cracky = 3},
	light_source = default.LIGHT_MAX,
	tiles = {"basic_machines_light.png"},

	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec",
			"size[2,1.75]field[0.25,0.5;2,1;deactivate;" .. F(S("deactivate after")) .. ";" .. meta:get_int("deactivate") ..
			"]button_exit[0,1;1,1;OK;" .. F(S("OK")) .. "]")
	end,

	on_receive_fields = function(pos, formname, fields, sender)
		if fields.OK and not minetest.is_protected(pos, sender:get_player_name()) then
			local meta = minetest.get_meta(pos)
			local deactivate = tonumber(fields.deactivate) or 0
			if deactivate < 0 or deactivate > 600 then deactivate = 0 end
			meta:set_int("deactivate", deactivate)
			meta:set_string("formspec",
				"size[2,1.75]field[0.25,0.5;2,1;deactivate;" .. F(S("deactivate after")) .. ";" .. deactivate ..
				"]button_exit[0,1;1,1;OK;" .. F(S("OK")) .. "]")
		end
	end,

	effector = {
		action_on = function(pos, _)
			local meta = minetest.get_meta(pos)
			local count = tonumber(meta:get_string("infotext")) or 0
			meta:set_string("infotext", count + 1) -- increase activate count
		end,

		action_off = function(pos, _)
			minetest.swap_node(pos, {name = "basic_machines:light_off"})
		end
	}
})

if basic_machines.settings.register_crafts then
	minetest.register_craft({
		output = "basic_machines:light_on",
		recipe = {
			{"default:torch", "default:torch"},
			{"default:torch", "default:torch"}
		}
	})
end
-- Make other light blocks work with signals - can toggle on/off
-- (c) 2015-2016 rnd
-- Copyright (C) 2022-2025 мтест
-- See README.md for license details

local function enable_toggle_light(name)
	local def = minetest.registered_nodes[name]
	if not def or def.effector or def.mesecons then return end -- we don't want to overwrite existing stuff!

	local offname = "basic_machines:" .. name:gsub(":", "_") .. "_OFF"

	-- redefine item
	minetest.override_item(name, {
		effector = { -- action to toggle light off
			action_off = function(pos, _)
				minetest.swap_node(pos, {name = offname})
			end
		}
	})

	local def_off = table.copy(def)

	def_off.groups.not_in_creative_inventory = 1
	def_off.light_source = 0 -- off block has light off
	def_off.effector = {
		action_on = function(pos, _)
			minetest.swap_node(pos, {name = name})
		end
	}

	-- REGISTER OFF BLOCK
	minetest.register_node(":" .. offname, def_off)
end

-- lights
local lights = {}

if minetest.get_modpath("darkage") then
	lights[#lights + 1] = "darkage:lamp"
end

if basic_machines.use_default then
	local i = #lights
	lights[i + 1] = "default:mese_post_light"
	lights[i + 2] = "default:mese_post_light_acacia_wood"
	lights[i + 3] = "default:mese_post_light_aspen_wood"
	lights[i + 4] = "default:mese_post_light_junglewood"
	lights[i + 5] = "default:mese_post_light_pine_wood"
	lights[i + 6] = "default:meselamp"
end

if minetest.global_exists("moreblocks") then
	local i = #lights
	lights[i + 1] = "moreblocks:slab_meselamp_1"
	lights[i + 2] = "moreblocks:slab_super_glow_glass"
end

if minetest.global_exists("xdecor") then
	local i = #lights
	lights[i + 1] = "xdecor:iron_lightbox"
	lights[i + 2] = "xdecor:wooden2_lightbox"
	lights[i + 3] = "xdecor:wooden_lightbox"
end

for _, light in ipairs(lights) do
	enable_toggle_light(light)
end
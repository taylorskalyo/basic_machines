-- Block that can be activated by/activate mesecon blocks

local machines_TTL = basic_machines.properties.machines_TTL

local adapter_effector = {
	action_on = function(pos, ttl)
		if type(ttl) ~= "number" then ttl = machines_TTL end
		if ttl < 1 then return end -- machines_TTL prevents infinite recursion

		pos.y = pos.y + 1; local node = minetest.get_node_or_nil(pos)
		if not node then return end -- error

		local def = minetest.registered_nodes[node.name]; if not def then return end

		local effector = def.effector
		if effector and effector.action_on then -- activate basic_machines
			effector.action_on(pos, math.min(machines_TTL, ttl))
		else -- def.mesecons and def.mesecons.effector then -- activate mesecons
			pos.y = pos.y - 1
			mesecon.receptor_on(pos, mesecon.rules.buttonlike_get(node))
			-- effector = def.mesecons.effector
			-- effector.action_on(pos)
		end
	end,

	action_off = function(pos, ttl)
		if type(ttl) ~= "number" then ttl = machines_TTL end
		if ttl < 1 then return end -- machines_TTL prevents infinite recursion

		pos.y = pos.y + 1; local node = minetest.get_node_or_nil(pos)
		if not node then return end -- error

		local def = minetest.registered_nodes[node.name]; if not def then return end

		local effector = def.effector
		if effector and effector.action_off then -- activate basic_machines
			effector.action_off(pos, math.min(machines_TTL, ttl))
		else -- def.mesecons and def.mesecons.effector then -- activate mesecons
			pos.y = pos.y - 1
			mesecon.receptor_off(pos, mesecon.rules.buttonlike_get(node))
			-- effector = def.mesecons.effector
			-- effector.action_off(pos, node)
		end
	end
}

minetest.register_node("basic_machines:mesecon_adapter", {
	description = basic_machines.S("Interface between machines and mesecons - place block to be activated on top of it"),
	groups = {cracky = 3, mesecon_effector_on = 1, mesecon_effector_off = 1, mesecon_needs_receiver = 1},
	tiles = {"basic_machines_clock_generator.png", "basic_machines_clock_generator.png",
		"jeija_luacontroller_top.png", "jeija_luacontroller_top.png",
		"jeija_luacontroller_top.png", "jeija_luacontroller_top.png"},
	sounds = default.node_sound_wood_defaults(),

	effector = adapter_effector,

	mesecons = {
		effector = adapter_effector,
		receptor = {
			rules = mesecon.rules.buttonlike_get,
			state = mesecon.state.off
		}
	}
})

if basic_machines.settings.register_crafts then
	minetest.register_craft({
		output = "basic_machines:mesecon_adapter",
		recipe = {{"default:mese_crystal_fragment"}}
	})
end
-- rnd 2016:

-- CONSTRUCTOR machine: used to make all other basic_machines

local F, S = basic_machines.F, basic_machines.S
local craft_recipes = {}
local recipes_order = {}
local recipes_order_translated = {}

local function constructor_update_form(pos, meta)
	local constructor = minetest.get_node(pos).name

	local description = craft_recipes[constructor][meta:get_string("craft")]
	local item = ""

	if description then
		item = description.item
		local i = 0
		local inv = meta:get_inventory() -- set up craft list

		for _, v in ipairs(description.craft) do
			i = i + 1; inv:set_stack("recipe", i, ItemStack(v))
		end

		for j = i + 1, 6 do
			inv:set_stack("recipe", j, ItemStack(""))
		end

		description = description.description
	end

	meta:set_string("formspec", ([[
		size[8,10.25]
		textlist[0,0;3,1.5;craft;%s;%i]
		item_image[3.65,0;1,1;%s]
		list[context;recipe;5,0;3,2;]
		button[3.5,1;1.25,0.75;CRAFT;%s]
		label[0,1.85;%s]
		list[context;main;0,2.5;8,3;]
		list[current_player;main;0,6;8,1;]
		list[current_player;main;0,7.25;8,3;8]
		listring[context;main]
		listring[current_player;main]
		%s
	]]):format(recipes_order_translated[constructor], meta:get_int("selected"),
		item, F(S("CRAFT")), F(S(description or "")), default.get_hotbar_bg(0, 6)))
end

local function constructor_process(pos, name)
	local meta = minetest.get_meta(pos)

	local craft = craft_recipes[minetest.get_node(pos).name][meta:get_string("craft")]
	if not craft then return end

	local inv, item = meta:get_inventory(), craft.item
	local stack = ItemStack(item)
	if inv:room_for_item("main", stack) then
		if not basic_machines.creative(name or "") then
			local recipe = craft.craft

			for _, v in ipairs(recipe) do
				if not inv:contains_item("main", ItemStack(v)) then
					meta:set_string("infotext", S("#CRAFTING: you need '@1' to craft '@2'", v, item)); return
				end
			end

			for _, v in ipairs(recipe) do
				inv:remove_item("main", ItemStack(v))
			end
		end
		inv:add_item("main", stack)
		if name or meta:get_string("infotext") == "" then
			local def = minetest.registered_items[item:split(" ")[1]]
			meta:set_string("infotext", S("#CRAFTING: '@1' (@2)",
				def and def.description or S("Unknown item"), item))
		end
	end
end

local function add_constructor(name, def)
	craft_recipes[name] = def.craft_recipes
	recipes_order[name] = def.recipes_order
	recipes_order_translated[name] = {}

	for i, v in ipairs(recipes_order[name]) do
		recipes_order_translated[name][i] = F(S(v))
	end
	recipes_order_translated[name] = table.concat(recipes_order_translated[name], ",")

	minetest.register_node(name, {
		description = S(def.description),
		groups = {cracky = 3, constructor = 1},
		tiles = {name:gsub(":", "_") .. ".png"},
		sounds = default.node_sound_wood_defaults(),

		after_place_node = function(pos, placer)
			if not placer then return end

			local meta = minetest.get_meta(pos)
			meta:set_string("infotext",
				S("Constructor: to operate it insert materials, select item to make and click craft button"))
			meta:set_string("owner", placer:get_player_name())

			meta:set_string("craft", def.recipes_order[1])
			meta:set_int("selected", 1)

			local inv = meta:get_inventory()
			inv:set_size("main", 24)
			inv:set_size("recipe", 6)

			constructor_update_form(pos, meta)
		end,

		can_dig = function(pos, player) -- main inv must be empty to be dug
			local meta = minetest.get_meta(pos)
			return meta:get_inventory():is_empty("main") and meta:get_string("owner") == player:get_player_name()
		end,

		on_receive_fields = function(pos, formname, fields, sender)
			local player_name = sender:get_player_name()
			if fields.quit or minetest.is_protected(pos, player_name) then return end

			if fields.CRAFT then
				constructor_process(pos, player_name)
			elseif fields.craft then
				if fields.craft:sub(1, 3) == "CHG" then
					local sel = tonumber(fields.craft:sub(5)) or 1
					local meta = minetest.get_meta(pos)

					meta:set_string("infotext", "")
					for i, v in ipairs(recipes_order[minetest.get_node(pos).name]) do
						if i == sel then meta:set_string("craft", v); break end
					end
					meta:set_int("selected", sel)

					constructor_update_form(pos, meta)
				end
			end
		end,

		allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
			return 0
		end,

		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if listname == "recipe" or minetest.is_protected(pos, player:get_player_name()) then
				return 0
			end
			return stack:get_count()
		end,

		allow_metadata_inventory_take = function(pos, listname, index, stack, player)
			if listname == "recipe" or minetest.is_protected(pos, player:get_player_name()) then
				return 0
			end
			return stack:get_count()
		end,

		effector = {
			action_on = function(pos, _)
				constructor_process(pos, nil)
			end
		}
	})

	minetest.register_craft({
		output = name,
		recipe = def.recipe
	})
end


-- CONSTRUCTOR
local def = {
	description = "Constructor: used to make machines",
	recipe = {
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
		{"default:steel_ingot", "default:copperblock", "default:steel_ingot"},
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"}
	},
	craft_recipes = {
		["Autocrafter"] = {
			item = "basic_machines:autocrafter",
			description = "Automate crafting",
			craft = {"default:steel_ingot 5", "default:mese_crystal 2", "default:diamondblock 2"}
		},

		["Ball Spawner"] = {
			item = "basic_machines:ball_spawner",
			description = "Spawn moving energy balls",
			craft = {"basic_machines:power_cell", "basic_machines:keypad"}
		},

		["Battery"] = {
			item = "basic_machines:battery_0",
			description = "Power for machines",
			craft = {"default:bronzeblock 2", "default:mese", "default:diamond"}
		},

		["Clock Generator"] = {
			item = "basic_machines:clockgen",
			description = "For making circuits that run non stop",
			craft = {"default:diamondblock", "basic_machines:keypad"}
		},

		["Coal Lump"] = {
			item = "default:coal_lump",
			description = "Coal lump, contains 1 energy unit",
			craft = {"basic_machines:power_cell 2"}
		},

		["Detector"] = {
			item = "basic_machines:detector",
			description = "Detect and measure players, objects, blocks, light level",
			craft = {"default:mese_crystal 4", "basic_machines:keypad"}
		},

		["Distributor"] = {
			item = "basic_machines:distributor",
			description = "Organize your circuits better",
			craft = {"default:steel_ingot", "default:mese_crystal", "basic_machines:keypad"}
		},

		["Environment"] = {
			item = "basic_machines:enviro",
			description = "Change gravity and more",
			craft = {"basic_machines:generator 8", "basic_machines:clockgen"}
		},

		["Generator"] = {
			item = "basic_machines:generator",
			description = "Generate power crystals",
			craft = {"default:diamondblock 5", "basic_machines:battery_0 5", "default:goldblock 5"}
		},

		["Grinder"] = {
			item = "basic_machines:grinder",
			description = "Makes dusts and grinds materials",
			craft = {"default:diamond 13", "default:mese 4"}
		},

		["Keypad"] = {
			item = "basic_machines:keypad",
			description = "Turns on/off lights and activates machines or opens doors",
			craft = {"default:wood", "default:stick"}
		},

		["Light"] = {
			item = "basic_machines:light_on",
			description = "Light in darkness",
			craft = {"default:torch 4"}
		},

		["Mover"] = {
			item = "basic_machines:mover",
			description = "Can dig, harvest, plant, teleport or move items from/in inventories",
			craft = {"default:mese_crystal 6", "default:stone 2", "basic_machines:keypad"}
		},

		["Power Block"] = {
			item = "basic_machines:power_block 5",
			description = "Energy cell, contains 11 energy units",
			craft = {"basic_machines:power_rod"}
		},

		["Power Cell"] = {
			item = "basic_machines:power_cell 5",
			description = "Energy cell, contains 1 energy unit",
			craft = {"basic_machines:power_block"}
		},

		["Recycler"] = {
			item = "basic_machines:recycler",
			description = "Recycle old tools",
			craft = {"default:mese_crystal 8", "default:diamondblock"}
		}
	},
	recipes_order = { -- order in which nodes appear
		"Keypad",
		"Light",
		"Grinder",
		"Mover",
		"Battery",
		"Generator",
		"Detector",
		"Distributor",
		"Clock Generator",
		"Recycler",
		"Autocrafter",
		"Ball Spawner",
		"Environment",
		"Power Block",
		"Power Cell",
		"Coal Lump"
	}
}

if minetest.global_exists("mesecon") then -- add mesecon adapter
	def.craft_recipes["Mesecon Adapter"] = {
		item = "basic_machines:mesecon_adapter",
		description = "Interface between machines and mesecons",
		craft = {"default:mese_crystal_fragment"}
	}
	def.recipes_order[#def.recipes_order + 1] = "Mesecon Adapter"
end

add_constructor("basic_machines:constructor", def)
-- ENVIRO block: change physics and skybox for players
-- Note: nonadmin players are limited in changes

-- rnd 2016:

local F, S = basic_machines.F, basic_machines.S
local max_range = basic_machines.properties.max_range
local use_player_monoids = minetest.global_exists("player_monoids")
local enviro_sky = {}

minetest.register_on_leaveplayer(function(player)
	enviro_sky[player:get_player_name()] = nil
end)

if use_player_monoids then
	-- Sneak monoid. Effect values are sneak booleans.
	basic_machines.player_sneak = player_monoids.make_monoid({
		combine = function(p, q) return p or q end,
		fold = function(elems)
			for _, v in pairs(elems) do
				if v then return true end
			end

			return false
		end,
		identity = false,
		apply = function(can_sneak, player)
			local ov = player:get_physics_override()
			ov.sneak = can_sneak
			player:set_physics_override(ov)
		end
	})
end

local skyboxes = {
	["-"] = {id = 1, type = "", tex = {}},
	["surface"] = {id = 2, type = "regular", tex = {}},
	["cave"] = {id = 3, type = "skybox", tex = {
		"basic_machines_black.png", "basic_machines_black.png", "basic_machines_black.png",
		"basic_machines_black.png", "basic_machines_black.png", "basic_machines_black.png"
	}},
	["space"] = {id = 4, type = "skybox", tex = {
		"basic_machines_stars.png", "basic_machines_stars.png", "basic_machines_stars.png",
		"basic_machines_stars.png", "basic_machines_stars.png", "basic_machines_stars.png"
	}}
}
local enviro_skylist_translated = {}

for k, v in pairs(skyboxes) do
	enviro_skylist_translated[v.id] = F(S(k))
end
enviro_skylist_translated = table.concat(enviro_skylist_translated, ",")

local function enviro_update_form(pos, meta)
	local skybox = meta:get_string("skybox")
	local list_name = "nodemeta:" .. pos.x .. ',' .. pos.y .. ',' .. pos.z

	meta:set_string("formspec", ([[
		size[8,8]
		field[0.25,0.5;1,1;x0;%s;%i]
		field[1.25,0.5;1,1;y0;;%i]
		field[2.25,0.5;1,1;z0;;%i]
		field[3.25,0.5;1,1;radius;%s;%i]
		field[0.25,1.5;1,1;speed;%s;%.2f]
		field[1.25,1.5;1,1;jump;%s;%.2f]
		field[2.25,1.5;1,1;gravity;%s;%.2f]
		field[3.25,1.5;1,1;sneak;%s;%i]
		label[-0.02,1.9;%s]dropdown[-0.02,2.3;1.5,1;skybox;%s;%i]
		label[5,0;%s]list[%s;fuel;5,0.5;1,1;]
		button_exit[6.5,0;1,1;OK;%s]
		button[6.5,1;1,1;help;%s]
		list[current_player;main;0,3.75;8,1;]
		list[current_player;main;0,5;8,3;8]
		listring[%s;fuel]
		listring[current_player;main]
		%s
	]]):format(F(S("Target")), meta:get_int("x0"), meta:get_int("y0"), meta:get_int("z0"),
		F(S("Radius")), meta:get_int("radius"), F(S("Speed")), meta:get_float("speed"),
		F(S("Jump")), meta:get_float("jump"), F(S("Gravity")), meta:get_float("gravity"),
		F(S("Sneak")), meta:get_int("sneak"), F(S("Sky")),
		enviro_skylist_translated, skyboxes[skybox] and skyboxes[skybox].id or 1, F(S("FUEL")),
		list_name, F(S("OK")), F(S("help")), list_name, default.get_hotbar_bg(0, 3.75)
	))
end

local function format_num(num, specifier) return (specifier):format(num) end

local function toggle_visibility(player, b)
	player:set_sun({visible = b, sunrise_visible = b})
	player:set_moon({visible = b})
	player:set_stars({visible = b})
end

-- environment changer
minetest.register_node("basic_machines:enviro", {
	description = S("Changes environment for players around target location"),
	groups = {cracky = 3},
	tiles = {"basic_machines_enviro.png"},
	drawtype = "allfaces",
	paramtype = "light",
	param1 = 1,
	sounds = default.node_sound_wood_defaults(),

	after_place_node = function(pos, placer)
		if not placer then return end

		local meta, name = minetest.get_meta(pos), placer:get_player_name()
		meta:set_string("infotext", S("Right click to set it. Activate by signal."))
		meta:set_string("owner", name)

		if minetest.check_player_privs(name, "privs") then meta:set_int("admin", 1) end

		meta:set_int("x0", 0); meta:set_int("y0", 0); meta:set_int("z0", 0) -- target
		meta:set_int("radius", 5)
		meta:set_float("speed", 1)
		meta:set_float("jump", 1)
		meta:set_float("gravity", 1)
		meta:set_int("sneak", 1)
		meta:set_string("skybox", "-")

		meta:get_inventory():set_size("fuel", 1)

		enviro_update_form(pos, meta)
	end,

	can_dig = function(pos, player) -- don't dig if fuel is inside, cause it will be destroyed
		local meta = minetest.get_meta(pos)
		return meta:get_inventory():is_empty("fuel") and meta:get_string("owner") == player:get_player_name()
	end,

	on_receive_fields = function(pos, formname, fields, sender)
		local name = sender:get_player_name()
		if fields.OK and not minetest.is_protected(pos, name) then
			local meta = minetest.get_meta(pos)
			meta:set_string("infotext", S("Right click to set it. Activate by signal."))
			local privs = minetest.check_player_privs(name, "privs")

			-- target
			local x0 = tonumber(fields.x0) or 0
			local y0 = tonumber(fields.y0) or 0
			local z0 = tonumber(fields.z0) or 0
			if not privs and (math.abs(x0) > max_range or math.abs(y0) > max_range or math.abs(z0) > max_range) then return end
			meta:set_int("x0", x0); meta:set_int("y0", y0); meta:set_int("z0", z0)

			-- radius
			local radius = tonumber(fields.radius) or 5
			if (radius < 0 or radius > max_range) and not privs then return end
			meta:set_int("radius", radius)

			-- speed
			local speed = tonumber(fields.speed) or 1
			if (speed < 0 or speed > 1.2) and not privs then return end
			meta:set_float("speed", ("%.2f"):format(speed))

			-- jump
			local jump = tonumber(fields.jump) or 1
			if (jump < 0 or jump > 2) and not privs then return end
			meta:set_float("jump", ("%.2f"):format(jump))

			-- gravity
			local gravity = tonumber(fields.gravity) or 1
			if (gravity < 0.1 or gravity > 40) and not privs then return end
			meta:set_float("gravity", ("%.2f"):format(gravity))

			-- sneak
			local sneak = tonumber(fields.sneak) or 1
			if sneak < 0 or sneak > 1 then return end
			meta:set_int("sneak", tonumber(fields.sneak))

			-- skybox
			fields.skybox = fields.skybox or "-"
			meta:set_string("skybox", fields.skybox:match("%)([%w_-]+)") or "-")

			enviro_update_form(pos, meta)

		elseif fields.help then
			minetest.show_formspec(name, "basic_machines:help_enviro",
				"size[6,7]textarea[0,0;6.5,8.5;help;" .. F(S("ENVIRONMENT MODIFICATIONS")) .. ";" .. F(S([[
VALUES

Target:		Center position of the area to apply environment effects
			x: [-@1, @2], y: [-@3, @4], z: [-@5, @6]
Radius:		[0,   @7]@
Speed:		[0,   1.2]
Jump:		[0,   2]
Gravity:	[0.1, 40]
Sneak:		[0,   1]
Sky:		-, surface, cave or space
]], max_range, max_range, max_range, max_range, max_range, max_range, max_range)) .. "]")
		end
	end,

	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if minetest.is_protected(pos, player:get_player_name()) then return 0 end
		return stack:get_count()
	end,

	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		if minetest.is_protected(pos, player:get_player_name()) then return 0 end
		return stack:get_count()
	end,

	effector = {
		action_on = function(pos, _)
			local meta = minetest.get_meta(pos)

			local radius, gravity, skybox = meta:get_int("radius"), meta:get_float("gravity"), meta:get_string("skybox")
			if meta:contains("r") then -- for compatibility
				local meta_new = meta:to_table(); meta:from_table(nil); local fields = meta_new.fields
				fields.infotext = S("Right click to set it. Activate by signal.")
				if minetest.check_player_privs(fields.owner, "privs") then fields.admin = 1 end
				radius = tonumber(fields.r); fields.r, fields.radius = nil, radius
				gravity = tonumber(fields.g); fields.g, fields.gravity = nil, gravity
				skybox = "-"; fields.skybox = "-"; fields.public = nil
				if minetest.get_meta(pos):from_table(meta_new) then meta = minetest.get_meta(pos) else return end
				enviro_update_form(pos, meta)
			end

			if radius <= 0 then return end
			local inv, stack = meta:get_inventory(), ItemStack("default:diamond")
			local admin = meta:get_int("admin")
			local physics = {
				speed = meta:get_float("speed"),
				jump = meta:get_float("jump"),
				gravity = gravity,
				sneak = meta:get_int("sneak")
			}

			if inv:contains_item("fuel", stack) and admin ~= 1 then
				meta:set_string("infotext", S("#SETTINGS Speed=@1 Jump=@2 Gravity=@3 Sneak=@4 Sky=@5",
					format_num(physics.speed, "%.2f"), format_num(physics.jump, "%.2f"),
					format_num(physics.gravity, "%.2f"), physics.sneak, S(skybox)))
				inv:remove_item("fuel", stack)
			elseif admin == 1 then
				meta:set_string("infotext", S("ADMIN #SETTINGS Speed=@1 Jump=@2 Gravity=@3 Sneak=@4 Sky=@5",
					format_num(physics.speed, "%.2f"), format_num(physics.jump, "%.2f"),
					format_num(physics.gravity, "%.2f"), physics.sneak, S(skybox)))
			else
				meta:set_string("infotext", S("Error. Insert diamond in fuel inventory.")); return
			end

			local pos0 = vector.add(pos,
				{x = meta:get_int("x0"), y = meta:get_int("y0"), z = meta:get_int("z0")})
			for _, player in ipairs(minetest.get_connected_players()) do
				local pos1 = player:get_pos()
				if math.sqrt((pos1.x - pos0.x)^2 + (pos1.y - pos0.y)^2 + (pos1.z - pos0.z)^2) <= radius then
					physics.sneak = physics.sneak == 1
					if use_player_monoids then
						player_monoids.speed:add_change(player, physics.speed,
							"basic_machines:physics")
						player_monoids.jump:add_change(player, physics.jump,
							"basic_machines:physics")
						player_monoids.gravity:add_change(player, physics.gravity,
							"basic_machines:physics")
						basic_machines.player_sneak:add_change(player, physics.sneak,
							"basic_machines:physics")
					else
						player:set_physics_override(physics)
					end

					if skybox ~= "-" then
						local sky = skyboxes[skybox]
						local b = skybox == "surface"
						player:set_sky({base_color = 0x000000, type = sky["type"], textures = sky["tex"], clouds = b})
						toggle_visibility(player, b)
						enviro_sky[player:get_player_name()] = skybox
					end
				end
			end

			-- attempt to set acceleration to balls, if any around
			for _, obj in ipairs(minetest.get_objects_inside_radius(pos0, radius)) do
				local luaent = obj:get_luaentity()
				if luaent and luaent.name == "basic_machines:ball" then
					obj:set_acceleration({x = 0, y = -physics.gravity, z = 0})
				end
			end
		end
	}
})

-- DEFAULT (SPAWN) PHYSICS VALUE/SKYBOX
local function reset_player_physics(player)
	if player and player:is_player() then
		if use_player_monoids then
			player_monoids.speed:del_change(player, "basic_machines:physics")
			player_monoids.jump:del_change(player, "basic_machines:physics")
			player_monoids.gravity:del_change(player, "basic_machines:physics")
			basic_machines.player_sneak:del_change(player, "basic_machines:physics")
		else
			player:set_physics_override({speed = 1, jump = 1, gravity = 1, sneak = true})
		end

		local name = player:get_player_name()

		if enviro_sky[name] and enviro_sky[name] ~= "surface" then -- default skybox is "surface"
			local sky = skyboxes["surface"]
			player:set_sky({type = sky["type"], textures = sky["tex"], clouds = true})
			toggle_visibility(player, true)
			enviro_sky[name] = nil
		end
	end
end

-- restore default physics values on respawn of player
minetest.register_on_respawnplayer(reset_player_physics)

if basic_machines.settings.register_crafts then
	-- RECIPE: extremely expensive
	minetest.register_craft({
		output = "basic_machines:enviro",
		recipe = {
			{"basic_machines:generator", "basic_machines:clockgen", "basic_machines:generator"},
			{"basic_machines:generator", "basic_machines:generator", "basic_machines:generator"},
			{"basic_machines:generator", "basic_machines:generator", "basic_machines:generator"}
		}
	})
end
local modpath = minetest.get_modpath(minetest.get_current_modname())
dofile(modpath .. "/volcano_lava.lua")
core.register_mapgen_script(modpath .. "/volcanoesmg.lua")

local S = magma_conduits.S

local depth_root = magma_conduits.config.volcano_min_depth
local depth_base = -50 -- point where the mountain root starts expanding
local depth_maxwidth = -30 -- point of maximum width

local radius_vent = 3 -- approximate minimum radius of vent - noise adds a lot to this
local radius_lining = 5 -- the difference between this and the vent radius is about how thick the layer of lining nodes is, though noise will affect it
local caldera_min = 5 -- minimum radius of caldera
local caldera_max = 20 -- maximum radius of caldera

local snow_line = 120 -- above this elevation snow is added to the dirt type
local snow_border = 15 -- transitional zone where there's dirt with snow on it

local depth_maxpeak = magma_conduits.config.volcano_max_height
local depth_minpeak = magma_conduits.config.volcano_min_height
local slope_min = magma_conduits.config.volcano_min_slope
local slope_max = magma_conduits.config.volcano_max_slope

local region_mapblocks = magma_conduits.config.volcano_region_mapblocks
local mapgen_chunksize = tonumber(minetest.get_mapgen_setting("chunksize"))
local volcano_region_size = region_mapblocks * mapgen_chunksize * 16

local magma_chambers_enabled = magma_conduits.config.volcano_magma_chambers
local chamber_radius_multiplier = magma_conduits.config.volcano_magma_chamber_radius_multiplier

local p_active = magma_conduits.config.volcano_probability_active
local p_dormant = magma_conduits.config.volcano_probability_dormant
local p_extinct = magma_conduits.config.volcano_probability_extinct

if p_active + p_dormant + p_extinct > 1.0 then
	minetest.log("error", "[magma_conduits] probabilities of various volcano types adds up to more than 1")
end

local state_dormant = 1 - p_active
local state_extinct = 1 - p_active - p_dormant
local state_none = 1 - p_active - p_dormant - p_extinct

local c_air = minetest.get_content_id("air")
local c_lava = minetest.get_content_id("default:lava_source")
local c_water = minetest.get_content_id("default:water_source")

local c_lining = minetest.get_content_id("default:obsidian")
local c_hot_lining = minetest.get_content_id("default:obsidian")

local c_cone = minetest.get_content_id("default:stone")


local c_ash = minetest.get_content_id("default:gravel")
local c_soil = minetest.get_content_id("default:dirt")
local c_soil_snow = minetest.get_content_id("default:dirt_with_snow")
local c_snow = minetest.get_content_id("default:snow")
local c_snow_block = minetest.get_content_id("default:snowblock")

local c_sand = minetest.get_content_id("default:sand")
local c_underwater_soil = c_sand
local c_plug = minetest.get_content_id("default:obsidian")

if magma_conduits.config.glowing_rock then
	c_hot_lining = minetest.get_content_id("magma_conduits:glow_obsidian")
end

local water_level = tonumber(minetest.get_mapgen_setting("water_level"))
local mapgen_seed = tonumber(minetest.get_mapgen_setting("seed"))

-- derived values

local radius_cone_max =  (depth_maxpeak - depth_maxwidth) * slope_max + radius_lining + 20
local depth_maxwidth_dist = depth_maxwidth-depth_base
local depth_maxpeak_dist = depth_maxpeak-depth_maxwidth

local scatter_2d = function(min_xz, gridscale, border_width)
	local bordered_scale = gridscale - 2 * border_width
	local point = {}
	point.x = math.random() * bordered_scale + min_xz.x + border_width
	point.y = 0
	point.z = math.random() * bordered_scale + min_xz.z + border_width
	return point
end

-- For some reason, map chunks generate with -32, -32, -32 as the "origin" minp. To make the large-scale grid align with map chunks it needs to be offset like this.
local get_corner = function(pos)
	return {x = math.floor((pos.x+32) / volcano_region_size) * volcano_region_size - 32, z = math.floor((pos.z+32) / volcano_region_size) * volcano_region_size - 32}
end

local get_volcano = function(pos)
	local corner_xz = get_corner(pos)
	local next_seed = math.random(1, 1000000000)
	math.randomseed(corner_xz.x + corner_xz.z * 2 ^ 8 + mapgen_seed)

	local state = math.random()
	if state < state_none then
		math.randomseed(next_seed)
		return nil
	end

	local name
	local color
	local location = scatter_2d(corner_xz, volcano_region_size, radius_cone_max)
	local depth_peak = math.random(depth_minpeak, depth_maxpeak)
	local depth_lava
	if state < state_extinct then
		depth_lava = - math.random(1, math.abs(depth_root)) -- extinct, put the lava somewhere deep.
	elseif state < state_dormant then
		depth_lava = depth_peak - math.random(5, 50) -- dormant
	else
		depth_lava = depth_peak - math.random(1, 25) -- active, put the lava near the top
		color = 0xFF7F00 -- orange
	end
	local slope = math.random() * (slope_max - slope_min) + slope_min
	local caldera = math.random() * (caldera_max - caldera_min) + caldera_min
	
	math.randomseed(next_seed)
	return {location = location, depth_peak = depth_peak, depth_lava = depth_lava, slope = slope, state = state, caldera = caldera}
end
----------------------------------------------------------------------------------------------
-- Debugging and sightseeing commands

minetest.register_privilege("findvolcano", { description = S("Allows players to use a console command to find volcanoes"), give_to_singleplayer = false})

function round(val, decimal)
  if (decimal) then
    return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
  else
    return math.floor(val+0.5)
  end
end

local send_volcano_state = function(pos, name)
	local corner_xz = get_corner(pos)
	local volcano = get_volcano(pos)
	if volcano == nil then
		return false
	end
	local location = {x=math.floor(volcano.location.x), y=volcano.depth_peak, z=math.floor(volcano.location.z)}
	local text = "Peak at " .. minetest.pos_to_string(location)
		.. ", Slope: " .. tostring(round(volcano.slope, 2))
		.. ", State: "
	if volcano.state < state_extinct then
		text = text .. "Extinct"
	elseif volcano.state < state_dormant then
		text = text .. "Dormant"
	else
		text = text .. "Active"
	end
	
	minetest.chat_send_player(name, text)
	return true
end

local send_nearby_states = function(pos, name)
	local retval = false
	retval = send_volcano_state({x=pos.x-volcano_region_size, y=0, z=pos.z+volcano_region_size}, name) or retval
	retval = send_volcano_state({x=pos.x, y=0, z=pos.z+volcano_region_size}, name) or retval
	retval = send_volcano_state({x=pos.x+volcano_region_size, y=0, z=pos.z+volcano_region_size}, name) or retval
	retval = send_volcano_state({x=pos.x-volcano_region_size, y=0, z=pos.z}, name) or retval
	retval = send_volcano_state(pos, name) or retval
	retval = send_volcano_state({x=pos.x+volcano_region_size, y=0, z=pos.z}, name) or retval
	retval = send_volcano_state({x=pos.x-volcano_region_size, y=0, z=pos.z-volcano_region_size}, name) or retval
	retval = send_volcano_state({x=pos.x, y=0, z=pos.z-volcano_region_size}, name) or retval
	retval = send_volcano_state({x=pos.x+volcano_region_size, y=0, z=pos.z-volcano_region_size}, name) or retval
	return retval
end

minetest.register_chatcommand("findvolcano", {
    params = "pos", -- Short parameter description
    description = S("find the volcanoes near the player's map region, or in the map region containing pos if provided"),
    func = function(name, param)
		if minetest.check_player_privs(name, {findvolcano = true}) then
			local pos = {}
			pos.x, pos.y, pos.z = string.match(param, "^([%d.-]+)[, ] *([%d.-]+)[, ] *([%d.-]+)$")
			pos.x = tonumber(pos.x)
			pos.y = tonumber(pos.y)
			pos.z = tonumber(pos.z)
			if pos.x and pos.y and pos.z then
				if not send_nearby_states(pos, name) then
					minetest.chat_send_player(name, S("No volcanoes near @1", minetest.pos_to_string(pos)))
				end
				return true
			else
				local playerobj = minetest.get_player_by_name(name)
				pos = playerobj:get_pos()
				if not send_nearby_states(pos, name) then
					pos.x = math.floor(pos.x)
					pos.y = math.floor(pos.y)
					pos.z = math.floor(pos.z)
					minetest.chat_send_player(name, S("No volcanoes near @1", minetest.pos_to_string(pos)))
				end
				return true
			end
		else
			return false, S("You need the findvolcano privilege to use this command.")
		end
	end,
})


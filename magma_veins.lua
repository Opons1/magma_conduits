-- Hard-coding on account of issue https://github.com/minetest/minetest/issues/7364
local height_min = magma_conduits.config.lower_limit
local height_max = magma_conduits.config.upper_limit

minetest.register_ore({
	ore_type = "vein",
	ore = "default:lava_source",
	wherein = {
		"default:stone",
		"default:desert_stone",
		"default:sandstone",
		"default:stone_with_coal",
		"default:stone_with_iron",
		"default:stone_with_copper",
		"default:stone_with_tin",
		"default:stone_with_gold",
		"default:stone_with_diamond",
		"default:dirt",
		"default:dirt_with_grass",
		"default:dirt_with_dry_grass",
		"default:dirt_with_snow",
		"default:dirt_with_rainforest_litter",
		"default:dirt_with_coniferous_litter",
		"default:sand",
		"default:desert_sand",
		"default:silver_sand",
		"default:gravel",
	},
	column_height_min = 2,
	column_height_max = 6,
	y_min = height_min,
	y_max = height_max,
	noise_threshold = 0.9,
	noise_params = {
		offset = 0,
		scale = 3,
		spread = {x=magma_conduits.config.spread, y=magma_conduits.config.spread*2, z=magma_conduits.config.spread},
		seed = 25391,
		octaves = 4,
		persist = 0.5,
		flags = "eased",
	},
	random_factor = 0,
})

-------------------------------------------------------------------------------------------------

local modname = minetest.get_current_modname()
local modpath = core.get_modpath(modname)
core.register_mapgen_script(modpath .. "/magma_veinsmg.lua")

-- Dimensions API.
-- Specifies y top and bottom values, and a function to run on a generation step for the area

worldgen.registered_dimensions = {}
worldgen.named_dimensions = {} -- TODO: Better name, as this just stores a dimension name -> dimension def table

-- Commonly used content ids
local c_air = minetest.get_content_id("air")
local c_grass = minetest.get_content_id("bobcraft_blocks:grass_block")
local c_dirt = minetest.get_content_id("bobcraft_blocks:dirt")
local c_stone = minetest.get_content_id("bobcraft_blocks:stone")
local c_water = minetest.get_content_id("bobcraft_blocks:water_source")
local c_lava = minetest.get_content_id("bobcraft_blocks:lava_source")
local c_bedrock = minetest.get_content_id("bobcraft_blocks:bedrock")

local c_hellstone = minetest.get_content_id("bobcraft_blocks:hellstone")

function worldgen.register_dimension(def)
	-- y_min is where the dimension starts generating in y levels,
	-- y_max is where the dimension stops generating in y levels
	def.y_min = def.y_min or 0
	def.y_max = def.y_max or 256

	-- The function we run when we're told to generate for a given minp/maxp
	def.gen_func = def.gen_func or function(this, minp, maxp, blockseed, vm, area, data) return data end

	-- The sealing
	-- Done AFTER the gen_func is called
	if def.seal_bottom == nil then
		def.seal_bottom = true
	end
	if def.seal_top == nil then
		def.seal_top = true
	end
	def.seal_node = def.seal_node or "bobcraft_blocks:bedrock"
	def.seal_thickness = def.seal_thickness or 1 -- How many blocks the sealer will 'jitter'

	-- The biomes we are allowed to generate in this dimension
	-- Basically the table passed into worldgen.get_biome_nearest
	def.biome_list = def.biome_list

	-- The compression factor to apply when transporting in or out of the dimension
	-- ex. when entering, the coords are divided by the compression_factor
	-- and when leaving, the coords are multiplied by the compression_factor
	-- so at 8, when entering at {8,8,8} you end up at {1,1,1}
	-- and when leaving at {8,8,8} you end up at {64,64,64}
	def.compression_factor = def.compression_factor or 1

	-- Fix-up node ids
	def.seal_node = minetest.get_content_id(def.seal_node)

	table.insert(worldgen.registered_dimensions, def)
	worldgen.named_dimensions[def.name] = def
end

-- Overworld
worldgen.register_dimension({
	name = "worldgen:dimension_overworld",
	y_min = worldgen.overworld_bottom,
	y_max = worldgen.overworld_top,
	seal_top = false,

	seal_thickness = 2,

	biome_list = {
		worldgen.biome("worldgen:biome_plains"),
		worldgen.biome("worldgen:biome_desert"),
		worldgen.biome("worldgen:biome_tundra"),
	},

	compression_factor = 1,

	gen_func = function(this, minp, maxp, blockseed, vm, area, data)
		local sidelen = maxp.x - minp.x + 1
		local noise_base = worldgen.get_perlin_map(worldgen.np_base, {x=sidelen, y=sidelen, z=sidelen}, minp)
		local noise_overlay = worldgen.get_perlin_map(worldgen.np_overlay, {x=sidelen, y=sidelen, z=sidelen}, minp)
		local noise_overlay2 = worldgen.get_perlin_map(worldgen.np_overlay2, {x=sidelen, y=sidelen, z=sidelen}, minp)
	
		local noise_top_layer = worldgen.get_perlin_map(worldgen.np_second_layer, {x=sidelen, y=sidelen, z=sidelen}, minp)
		local noise_second_layer = worldgen.get_perlin_map(worldgen.np_second_layer, {x=sidelen, y=sidelen, z=sidelen}, minp)
	
		local noise_temperature = worldgen.get_perlin_map(worldgen.np_temperature, {x=sidelen, y=sidelen, z=sidelen}, minp)
		local noise_rainfall = worldgen.get_perlin_map(worldgen.np_rainfall, {x=sidelen, y=sidelen, z=sidelen}, minp)

		local ni = 1
		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				if maxp.y >= worldgen.overworld_bottom then 
					local top_node, mid_node, bottom_node, above_node
					local temperature = noise_temperature[ni]
					local rainfall = noise_rainfall[ni]
					local biome, h = worldgen.get_biome_nearest(temperature, rainfall, this.biome_list)
					local listwithoutbiome = table.copy(this.biome_list)
					table.remove(listwithoutbiome, h)

					local tempdiff = worldgen.tempdiff(temperature, biome, listwithoutbiome)

					if tempdiff < 0 then
						tempdiff = 0
					elseif tempdiff > 1 then
						tempdiff = 1
					end

					local y = math.floor(worldgen.y_at_point(x, z, ni, biome, tempdiff, noise_base, noise_overlay, noise_overlay2))

					above_node = biome.above
					top_node = biome.top
					mid_node = biome.middle
					bottom_node = biome.bottom

					if y <= maxp.y and y >= minp.y then
						local vi = area:index(x, y, z)
						local via = area:index(x, y+1, z) -- vi-above
						if y < worldgen.overworld_sealevel then
							data[vi] = mid_node
						else
							data[vi] = top_node
							if above_node ~= c_air then
								data[via] = above_node
							end
						end
					end

					local tl = math.floor((noise_top_layer[ni] + 1))
					if y - tl - 1 <= maxp.y and y - 1 >= minp.y then
						for yy = math.max(y - tl - 1, minp.y), math.min(y - 1, maxp.y) do
							local vi = area:index(x, yy, z)
							data[vi] = mid_node
						end
					end

					local sl = math.floor((noise_second_layer[ni] + 1))
					if y - sl - 2 >= minp.y then
						for yy = minp.y, math.min(y - sl - 2, maxp.y) do
							local vi = area:index(x, yy, z)
							if yy >= worldgen.overworld_bottom then
								data[vi] = bottom_node
							end
						end
					end

					for yy = minp.y, maxp.y do
						local vi = area:index(x, yy, z)
						-- the sea
						if yy <= worldgen.overworld_sealevel and yy >= worldgen.overworld_bottom then
							if data[vi] == c_air then
								data[vi] = biome.liquid
								if yy == worldgen.overworld_sealevel then
									data[vi] = biome.liquid_top
								end
							end
						end
					end
				end
				ni = ni + 1
			end
		end


		-- caves, structures
		local noise_caves = worldgen.get_perlin_map_3d(worldgen.np_caves, {x=sidelen, y=sidelen, z=sidelen}, minp)
		local noise_caves2 = worldgen.get_perlin_map_3d(worldgen.np_caves2, {x=sidelen, y=sidelen, z=sidelen}, minp)
		local noise_caves3 = worldgen.get_perlin_map_3d(worldgen.np_caves2, {x=sidelen, y=sidelen, z=sidelen}, minp)
		local noise_structure = worldgen.get_perlin_map(worldgen.np_caves, {x=sidelen, y=sidelen, z=sidelen}, minp)
		local rand = PcgRandom(blockseed)
		local nixyz = 1
		ni = 1

		-- whether we should try generating a certain structure, given the chance
		local gen_temple = true

		for x = minp.x, maxp.x do
			for z = minp.z, maxp.z do
				for y = minp.y, maxp.y do
					local vi = area:index(x, y, z)

					local cave, cave2, cave3 = noise_caves[nixyz], noise_caves2[nixyz], noise_caves3[nixyz]

					if (cave ^ 2 + cave2 ^ 2 + cave3 ^ 2) < 0.04 then
						if data[vi] ~= air then
							-- If it's ground content, smash our way through it
							if data[vi] == c_stone or
							data[vi] == c_dirt or
							data[vi] == c_grass or
							data[vi] == c_sand or
							data[vi] == c_sandstone then
								data[vi] = c_air
							end
						end
					end

					nixyz = nixyz + 1
				end

				local amount = math.floor(noise_structure[ni] * 9)
				for i = 0, amount do
					if gen_temple and rand:next(0,50000) == 0 then
						worldgen.gen_struct({x=x,z=z, y=rand:next(worldgen.overworld_struct_min, worldgen.overworld_struct_max)}, "temple", "random", rand)
						gen_temple = false -- one per chunk
					end
				end

				ni = ni + 1
			end
		end

		return data
	end
})

worldgen.register_dimension({
	name = "worldgen:dimension_hell",
	y_min = worldgen.hell_bottom,
	y_max = worldgen.hell_top,

	seal_thickness = 4,

	biome_list = {
		worldgen.biome("worldgen:biome_hell_wastes"),
	},

	-- We are *more* compressed than the nether, as it makes sense in the minetest world, chunks being 5x5x5.
	-- It also means that working out distances can be done in your head!
	compression_factor = 10,

	gen_func = function(this, minp, maxp, blockseed, vm, area, data)
		local sidelen = maxp.x - minp.x + 1
		local noise_caves = worldgen.get_perlin_map_3d(worldgen.np_caves_hell, {x=sidelen, y=sidelen, z=sidelen}, minp)
		local nixyz = 1
		for x = minp.x, maxp.x do
			for y = minp.y, maxp.y do
				for z = minp.z, maxp.z do
					local vi = area:index(x, y, z)

					local cave = noise_caves[nixyz]

					if cave < 0.1 then
						if y > worldgen.hell_bottom and y < worldgen.hell_top then
							data[vi] = c_hellstone
						end
					end

					if y <= worldgen.hell_sealevel and y >= worldgen.hell_bottom then
						if data[vi] == c_air then
							data[vi] = c_lava
							if y == worldgen.overworld_sealevel then
								data[vi] = c_lava
							end
						end
					end

					nixyz = nixyz + 1
				end
			end
		end

		return data
	end
})

-- Respawning on the surface
minetest.register_on_respawnplayer(function(player)
	local name = player:get_player_name()
	local has = beds.spawn[name] or nil
	if has then
		return true
	end

	local pos = bobutil.search_for_spawn({x=0, y=70, z=0}, {x=0,y=60,z=0})
	player:set_pos(pos)

	return true

end)
-- Spawning at all on the surface
minetest.register_on_newplayer(function(player)
	local pos = bobutil.search_for_spawn({x=0, y=70, z=0}, {x=0,y=60,z=0})
	player:set_pos(pos)
end)

-- Portal to hell
portals.register_portal("hell_portal", {
	shape = portals.PortalShape_Traditional,
	frame_node_name = "bobcraft_blocks:obsidian",
	wormhole_node_color = 0,
	title = "Hell Portal",

	is_within_realm = function(pos)
		return pos.y > worldgen.hell_bottom and pos.y < worldgen.hell_top
	end,

	find_realm_anchorPos = function(surface_anchorPos, player_name)
		-- divide x and z by hell's shrink factor
		local factor = worldgen.named_dimensions["worldgen:dimension_hell"].compression_factor
		local factor2 = worldgen.named_dimensions["worldgen:dimension_overworld"].compression_factor

		local dest = vector.multiply(surface_anchorPos, factor2)
		dest = vector.divide(dest, factor)

		dest.x = math.floor(dest.x)
		dest.z = math.floor(dest.z)
		-- Get the middle of the dimension
		dest.y = math.floor((worldgen.hell_top+worldgen.hell_bottom)/2)
		
		-- search for existing portals
		local existing_portal_location, existing_portal_orientation = portals.find_nearest_working_portal("hell_portal", dest, factor, 0)

		if existing_portal_location ~= nil then
			return existing_portal_location, existing_portal_orientation
		else
			-- Do it from the sea level up, so we don't ever spawn in the lava (OOPS!)
			local y = math.random(worldgen.hell_sealevel, worldgen.hell_top-25)
			dest.y = y
			return dest
		end
	end,

	find_surface_anchorPos = function (realm_anchorPos, player_name)
		local factor = worldgen.named_dimensions["worldgen:dimension_hell"].compression_factor
		local factor2 = worldgen.named_dimensions["worldgen:dimension_overworld"].compression_factor

		local dest = vector.divide(realm_anchorPos, factor)
		dest = vector.multiply(dest, factor2)

		-- TODO: Clip to world
		dest.y = math.floor((worldgen.overworld_top+worldgen.overworld_bottom)/2)

		local existing_portal_location, existing_portal_orientation = portals.find_nearest_working_portal("hell_portal", dest, factor*factor2, 0)

		if existing_portal_location ~= nil then
			return existing_portal_location, existing_portal_orientation
		else
			-- TODO: actually find surface
			dest.y = 100
			return dest
		end
	end,

	on_ignite = function(portal_def, anchor_pos, orientation)
		local p1, p2 = portal_def.shape:get_p1_and_p2_from_anchorPos(anchor_pos, orientation)
			local pos = vector.divide(vector.add(p1, p2), 2)

			local textureName = portal_def.particle_texture
			if type(textureName) == "table" then textureName = textureName.name end

			minetest.add_particlespawner({
				amount = 110,
				time   = 0.1,
				minpos = {x = pos.x - 0.5, y = pos.y - 1.2, z = pos.z - 0.5},
				maxpos = {x = pos.x + 0.5, y = pos.y + 1.2, z = pos.z + 0.5},
				minvel = {x = -5, y = -1, z = -5},
				maxvel = {x =  5, y =  1, z =  5},
				minacc = {x =  0, y =  0, z =  0},
				maxacc = {x =  0, y =  0, z =  0},
				minexptime = 0.1,
				maxexptime = 0.5,
				minsize = 0.2 * portal_def.particle_texture_scale,
				maxsize = 0.8 * portal_def.particle_texture_scale,
				collisiondetection = false,
				texture = textureName .. "^[colorize:#0F4:alpha",
				animation = portal_def.particle_texture_animation,
				glow = 8
			})
	end,

})

--[[
! WHEN THE
	⠀⠀⠀⠀⠀⠀⠀⠀⣠⣤⣤⣤⣤⣤⣶⣦⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⡿⠛⠉⠙⠛⠛⠛⠛⠻⢿⣿⣷⣤⡀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⠋⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⠈⢻⣿⣿⡄⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣸⣿⡏⠀⠀⠀⣠⣶⣾⣿⣿⣿⠿⠿⠿⢿⣿⣿⣿⣄⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣿⣿⠁⠀⠀⢰⣿⣿⣯⠁⠀⠀⠀⠀⠀⠀⠀⠈⠙⢿⣷⡄⠀
⠀⠀⣀⣤⣴⣶⣶⣿⡟⠀⠀⠀⢸⣿⣿⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣷⠀
⠀⢰⣿⡟⠋⠉⣹⣿⡇⠀⠀⠀⠘⣿⣿⣿⣿⣷⣦⣤⣤⣤⣶⣶⣶⣶⣿⣿⣿⠀
⠀⢸⣿⡇⠀⠀⣿⣿⡇⠀⠀⠀⠀⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃⠀
⠀⣸⣿⡇⠀⠀⣿⣿⡇⠀⠀⠀⠀⠀⠉⠻⠿⣿⣿⣿⣿⡿⠿⠿⠛⢻⣿⡇⠀⠀
⠀⠸⣿⣧⡀⠀⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⠃⠀⠀
⠀⠀⠛⢿⣿⣿⣿⣿⣇⠀⠀⠀⠀⠀⣰⣿⣿⣷⣶⣶⣶⣶⠶⠀⢠⣿⣿⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣿⣿⠀⠀⠀⠀⠀⣿⣿⡇⠀⣽⣿⡏⠁⠀⠀⢸⣿⡇⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣿⣿⠀⠀⠀⠀⠀⣿⣿⡇⠀⢹⣿⡆⠀⠀⠀⣸⣿⠇⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢿⣿⣦⣄⣀⣠⣴⣿⣿⠁⠀⠈⠻⣿⣿⣿⣿⡿⠏⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠈⠛⠻⠿⠿⠿⠿⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
! BOTTOM TEXT⠀⠀ 
]]
bobutil = {}

bobutil.titleize = function(str)
	str = str:gsub("_", " ")
	return str:gsub("^%l", string.upper)
end

-- like minetest.swap_node, but only swaps if the name doesn't match
bobutil.replace_node = function(pos, new_node)
	local node = minetest.get_node(pos)
	if node.name == new_node then
		return
	end
	node.name = new_node
	minetest.swap_node(pos, node)
end

-- Arguabely this falls under the jurisdiction of an inside dependency, but you can fight me on that.
bobutil.foliage_palette = "foliage_palette.png"
bobutil.foliage_palette_indices = {
	-- Unique
	plains = 0,
	desert = 1,
	swamp = 2,
	forest = 3,
	extreme_hills = 4,
	ocean = 5,

	-- Duplicates
}

bobutil.get_new_biome_coloured_block = function(pos, block)
	local biome_data = minetest.get_biome_data(pos)
	local palette_index = bobutil.foliage_palette_indices.plains
	if biome_data then
		local biome_name = minetest.get_biome_name(biome_data.biome)
		local biome_def = minetest.registered_biomes[biome_name]
		if biome_def then
			palette_index = biome_def._palette_index
		end
	end

	return {name = block.name, param2 = palette_index}
end

bobutil.foliage_block_figure = function(pos)
	local self = minetest.get_node(pos)
	if self.param2 == 0 then -- no colour set
		local new_node = bobutil.get_new_biome_coloured_block(pos, self)
		minetest.swap_node(pos, new_node)
	end
	return
end
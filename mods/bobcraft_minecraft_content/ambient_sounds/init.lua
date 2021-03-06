-- Plays ambient sounds. Such as cave sounds, water, lava, music, etc.
-- Reference taken from PilzAdam's ambient mod https://github.com/PilzAdam/MinetestAmbience/blob/master/init.lua
-- And minetest_game's env_sounds mod

-- The range we can hear ambient sounds from their source
local audio_range = {x=16, y=16, z=16}

local music = {
	handler = {},
	frequency = 1,
	positioned = false,
	{name="plainsong", length = 1*60 + 14, gain = 0.3}
}

local lava_sounds = {
	handler = {},
	frequency = 900,
	positioned = true,
	{name="lava_pops", length=3, gain = 0.5}
}
local water_sounds = {
	handler = {},
	frequency = 750,
	positioned = true,
	{name="water_ambience", length=3, gain = 0.25}
}
local waterfall_sounds = {
	handler = {},
	frequency = 1000,
	positioned = true,
	{name="waterfall_ambience", length=2, gain = 0.25}
}

local function get_ambience(player)
	local table = {}

	-- Music
	table.music = music

	-- Ambient Sounds
	local ppos = player:get_pos()
	ppos = vector.add(ppos, player:get_properties().eye_height)
	local areamin = vector.subtract(ppos, audio_range)
	local areamax = vector.add(ppos, audio_range)

	local lava = minetest.find_nodes_in_area(areamin, areamax, {"group:lava"}, true)
	if next(lava) ~= nil then
		table.lava = lava_sounds
		-- calculate avg. position
		local avges = {}
		for blocks, _ in pairs(lava) do
			for _, pos in pairs(lava[blocks]) do
				avges[#avges+1] = pos
			end
		end
		table.lava.position = bobutil.avg_pos(avges) -- the averages of the averages
	end

	local water = minetest.find_nodes_in_area(areamin, areamax, {"group:water_source"}, true)
	if next(water) ~= nil then
		table.water = water_sounds
		-- calculate avg. position
		local avges = {}
		for blocks, _ in pairs(water) do
			for _, pos in pairs(water[blocks]) do
				avges[#avges+1] = pos
			end
		end
		table.water.position = bobutil.avg_pos(avges) -- the averages of the averages
	end

	local waterfall = minetest.find_nodes_in_area(areamin, areamax, {"group:water_flow"}, true)
	if next(waterfall) ~= nil then
		table.waterfall = waterfall_sounds
		-- calculate avg. position
		local avges = {}
		for blocks, _ in pairs(waterfall) do
			for _, pos in pairs(waterfall[blocks]) do
				avges[#avges+1] = pos
			end
		end
		table.waterfall.position = bobutil.avg_pos(avges) -- the averages of the averages
	end

	return table
end

local function play_sound(player, list, number, pos)
	local player_name = player:get_player_name()

	if list.handler[player_name] == nil then
		local gain = 1.0
		if list[number].gain ~= nil then
			gain = list[number].gain
		end

		local handler = minetest.sound_play(list[number].name, {to_player=player_name, gain=gain,
		pos = list.position})

		if handler ~= nil then
			list.handler[player_name] = handler
			minetest.after(list[number].length, function(args)
				local list = args[1]
				local player_name = args[2]
				if list.handler[player_name] ~= nil then
					minetest.sound_stop(list.handler[player_name])
					list.handler[player_name] = nil
				end
			end, {list, player_name})
		end
	end
end

local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer+dtime
	if timer < 1 then
		return
	end
	timer = 0
	
	for _,player in ipairs(minetest.get_connected_players()) do
		local ambiences = get_ambience(player)
		for _,ambience in pairs(ambiences) do
			if math.random(1, 1000) <= ambience.frequency then
				play_sound(player, ambience, math.random(1, #ambience), ambience.position)
			end
		end
	end
end)
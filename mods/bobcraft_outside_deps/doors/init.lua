doors = {}

-- TODO: door textures are currently.... kind-of strange.
-- We need to flip them in a specific way.

local function check_player_priv(def, pos, player)
	def = def or {only_placer_can_open=false}
	if not def.only_placer_can_open then
		return true
	end
	local meta = minetest.get_meta(pos)
	local pn = player:get_player_name()
	return meta:get_string("doors_owner") == pn
end

-- Registers a door
function doors.register_door(name, def)
	def.groups.not_in_creative_inventory = 1

	local box = {{-0.5, -0.5, -0.5, 0.5, 0.5, -0.5+3/16}}

	if not def.node_box_bottom then
		def.node_box_bottom = box
	end
	if not def.node_box_top then
		def.node_box_top = box
	end
	if not def.selection_box_bottom then
		def.selection_box_bottom= box
	end
	if not def.selection_box_top then
		def.selection_box_top = box
	end

	if not def.sound_close_door then
		def.sound_close_door = "door_close"
	end
	if not def.sound_open_door then
		def.sound_open_door = "door_open"
	end
	
	
	minetest.register_craftitem(name, {
		description = def.description,
		inventory_image = def.inventory_image,

		on_place = function(itemstack, placer, pointed_thing)
			if not pointed_thing.type == "node" then
				return itemstack
			end

			local ptu = pointed_thing.under
			local nu = minetest.get_node(ptu)
			if minetest.registered_nodes[nu.name].on_rightclick then
				return minetest.registered_nodes[nu.name].on_rightclick(ptu, nu, placer, itemstack)
			end

			local pt = pointed_thing.above
			local pt2 = {x=pt.x, y=pt.y, z=pt.z}
			pt2.y = pt2.y+1
			if
				not minetest.registered_nodes[minetest.get_node(pt).name].buildable_to or
				not minetest.registered_nodes[minetest.get_node(pt2).name].buildable_to or
				not placer or
				not placer:is_player()
			then
				return itemstack
			end

			if minetest.is_protected(pt, placer:get_player_name()) or
					minetest.is_protected(pt2, placer:get_player_name()) then
				minetest.record_protection_violation(pt, placer:get_player_name())
				return itemstack
			end

			local p2 = minetest.dir_to_facedir(placer:get_look_dir())
			local pt3 = {x=pt.x, y=pt.y, z=pt.z}
			if p2 == 0 then
				pt3.x = pt3.x-1
			elseif p2 == 1 then
				pt3.z = pt3.z+1
			elseif p2 == 2 then
				pt3.x = pt3.x+1
			elseif p2 == 3 then
				pt3.z = pt3.z-1
			end
			if minetest.get_item_group(minetest.get_node(pt3).name, "door") == 0 then
				minetest.set_node(pt, {name=name.."_bottom_closed", param2=p2})
				minetest.set_node(pt2, {name=name.."_top_closed", param2=p2})
			else
				minetest.set_node(pt, {name=name.."_bottom_open", param2=p2})
				minetest.set_node(pt2, {name=name.."_top_open", param2=p2})
				minetest.get_meta(pt):set_int("right", 1)
				minetest.get_meta(pt2):set_int("right", 1)
			end

			if def.only_placer_can_open then
				local pn = placer:get_player_name()
				local meta = minetest.get_meta(pt)
				meta:set_string("doors_owner", pn)
				meta:set_string("infotext", "Owned by "..pn)
				meta = minetest.get_meta(pt2)
				meta:set_string("doors_owner", pn)
				meta:set_string("infotext", "Owned by "..pn)
			end

			if not minetest.setting_getbool("creative_mode") then
				itemstack:take_item()
			end
			return itemstack
		end,
	})

	local tt = def.tiles_top
	local tb = def.tiles_bottom
	
	local function after_dig_node(pos, name, digger)
		local node = minetest.get_node(pos)
		if node.name == name then
			minetest.node_dig(pos, node, digger)
		end
	end

	local function on_rightclick(pos, dir, check_name, replace, replace_dir, params)
		pos.y = pos.y+dir
		if not minetest.get_node(pos).name == check_name then
			return
		end
		local p2 = minetest.get_node(pos).param2
		p2 = params[p2+1]
		
		minetest.swap_node(pos, {name=replace_dir, param2=p2})
		
		pos.y = pos.y-dir
		minetest.swap_node(pos, {name=replace, param2=p2})

		local snd_1 = def.sound_close_door
		local snd_2 = def.sound_open_door 
		if params[1] == 3 then
			snd_1 = def.sound_open_door 
			snd_2 = def.sound_close_door
		end

		if minetest.get_meta(pos):get_int("right") ~= 0 then
			minetest.sound_play(snd_1, {pos = pos, gain = 0.3, max_hear_distance = 10})
		else
			minetest.sound_play(snd_2, {pos = pos, gain = 0.3, max_hear_distance = 10})
		end
	end

	minetest.register_node(name.."_bottom_closed", {
		tiles = {tb[2], tb[2], tb[2], tb[2], tb[1], tb[1]},
		paramtype = "light",
		paramtype2 = "facedir",
		drop = name,
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = def.node_box_bottom
		},
		selection_box = {
			type = "fixed",
			fixed = def.selection_box_bottom
		},
		groups = def.groups,
		
		after_dig_node = function(pos, oldnode, oldmetadata, digger)
			pos.y = pos.y+1
			after_dig_node(pos, name.."_top_closed", digger)
		end,
		
		on_rightclick = function(pos, node, clicker)
			if check_player_priv(pos, clicker) then
				on_rightclick(pos, 1, name.."_top_closed", name.."_bottom_open", name.."_top_open", {1,2,3,0})
			end
		end,
		
		can_dig = check_player_priv,
		sounds = def.sounds,
		sunlight_propagates = def.sunlight,
		hardness = def.hardness
	})

	minetest.register_node(name.."_top_closed", {
		tiles = {tt[2], tt[2], tt[2], tt[2], tt[1].."^[transformfx", tt[1]},
		paramtype = "light",
		paramtype2 = "facedir",
		drop = "",
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = def.node_box_top
		},
		selection_box = {
			type = "fixed",
			fixed = def.selection_box_top
		},
		groups = def.groups,
		
		after_dig_node = function(pos, oldnode, oldmetadata, digger)
			pos.y = pos.y-1
			after_dig_node(pos, name.."_bottom_closed", digger)
		end,
		
		on_rightclick = function(pos, node, clicker)
			if check_player_priv(pos, clicker) then
				on_rightclick(pos, -1, name.."_bottom_closed", name.."_top_open", name.."_bottom_open", {1,2,3,0})
			end
		end,
		
		can_dig = check_player_priv,
		sounds = def.sounds,
		sunlight_propagates = def.sunlight,
		hardness = def.hardness
	})

	minetest.register_node(name.."_bottom_open", {
		tiles = {tb[2], tb[2], tb[2], tb[2], tb[1], tb[1].."^[transformfx"},
		paramtype = "light",
		paramtype2 = "facedir",
		drop = name,
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = def.node_box_bottom
		},
		selection_box = {
			type = "fixed",
			fixed = def.selection_box_bottom
		},
		groups = def.groups,
		
		after_dig_node = function(pos, oldnode, oldmetadata, digger)
			pos.y = pos.y+1
			after_dig_node(pos, name.."_top_open", digger)
		end,
		
		on_rightclick = function(pos, node, clicker)
			if check_player_priv(pos, clicker) then
				on_rightclick(pos, 1, name.."_top_open", name.."_bottom_closed", name.."_top_closed", {3,0,1,2})
			end
		end,
		
		can_dig = check_player_priv,
		sounds = def.sounds,
		sunlight_propagates = def.sunlight,
		hardness = def.hardness
	})

	minetest.register_node(name.."_top_open", {
		tiles = {tt[2], tt[2], tt[2], tt[2], tt[1], tt[1].."^[transformfx"},
		paramtype = "light",
		paramtype2 = "facedir",
		drop = "",
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = def.node_box_top
		},
		selection_box = {
			type = "fixed",
			fixed = def.selection_box_top
		},
		groups = def.groups,
		
		after_dig_node = function(pos, oldnode, oldmetadata, digger)
			pos.y = pos.y-1
			after_dig_node(pos, name.."_bottom_open", digger)
		end,
		
		on_rightclick = function(pos, node, clicker)
			if check_player_priv(pos, clicker) then
				on_rightclick(pos, -1, name.."_bottom_open", name.."_top_closed", name.."_bottom_closed", {3,0,1,2})
			end
		end,
		
		can_dig = check_player_priv,
		sounds = def.sounds,
		sunlight_propagates = def.sunlight,
		hardness = def.hardness
	})

end

function doors.register_trapdoor(name, def)
	-- Registering one of these is exactly the same as a door, except we don't have a top image.
	-- ~~laziness~~ consistensy!

	local function on_rightclick(pos, replace, closed)
		local p2 = minetest.get_node(pos).param2

		minetest.swap_node(pos, {name=replace, param2=p2})

		local snd_1 = def.sound_close_door
		if closed then
			snd_1 = def.sound_open_door 
		end

		minetest.sound_play(snd_1, {pos = pos, gain = 0.3, max_hear_distance = 10})
	end

	minetest.register_craftitem(name, {
		description = def.description,
		inventory_image = def.inventory_image,
		on_place = function(itemstack, placer, pointed_thing)
			if not pointed_thing.type == "node" then
				return itemstack
			end

			local ptu = pointed_thing.under
			local nu = minetest.get_node(ptu)
			if minetest.registered_nodes[nu.name].on_rightclick then
				return minetest.registered_nodes[nu.name].on_rightclick(ptu, nu, placer, itemstack)
			end

			local pt = pointed_thing.above
			if
				not minetest.registered_nodes[minetest.get_node(pt).name].buildable_to or
				not placer or
				not placer:is_player()
			then
				return itemstack
			end

			if minetest.is_protected(pt, placer:get_player_name()) then
				minetest.record_protection_violation(pt, placer:get_player_name())
				return itemstack
			end

			local p2 = minetest.dir_to_facedir(placer:get_look_dir())
			local pt3 = {x=pt.x, y=pt.y, z=pt.z}
			if p2 == 0 then
				pt3.x = pt3.x-1
			elseif p2 == 1 then
				pt3.z = pt3.z+1
			elseif p2 == 2 then
				pt3.x = pt3.x+1
			elseif p2 == 3 then
				pt3.z = pt3.z-1
			end

			minetest.set_node(pt, {name=name.."_bottom_closed", param2=p2})
			
			if def.only_placer_can_open then
				local pn = placer:get_player_name()
				local meta = minetest.get_meta(pt)
				meta:set_string("doors_owner", pn)
				meta:set_string("infotext", "Owned by "..pn)
				meta = minetest.get_meta(pt2)
				meta:set_string("doors_owner", pn)
				meta:set_string("infotext", "Owned by "..pn)
			end

			if not minetest.setting_getbool("creative_mode") then
				itemstack:take_item()
			end
			return itemstack
		end,
	})

	minetest.register_node(name.."_bottom_closed", {
		tiles = {def.tiles[1]},
		paramtype = "light",
		paramtype2 = "facedir",
		drop = def.drop,
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = {
				{ -0.5, -0.5, -0.5,
				  0.5, -0.5 + 3/16, 0.5 }
			}
		},
		groups = def.groups,
		
		on_rightclick = function(pos, node, clicker)
			if check_player_priv(pos, clicker) then
				on_rightclick(pos, name .. "_bottom_open", true)
			end
		end,
		
		can_dig = check_player_priv,
		sounds = def.sounds,
		sunlight_propagates = def.sunlight,
		hardness = def.hardness	
	})
	minetest.register_node(name.."_bottom_open", {
		tiles = {def.tiles[1] .. "^[transformfy"}, -- transformify
		paramtype = "light",
		paramtype2 = "facedir",
		drop = def.drop,
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = {
				{ -0.5, -0.5, 0.5,
				  0.5, 0.5, 0.5 - 3/16 }
			}
		},
		groups = def.groups,
		
		after_dig_node = function(pos, oldnode, oldmetadata, digger)
			pos.y = pos.y-1
		end,
		
		on_rightclick = function(pos, node, clicker)
			if check_player_priv(pos, clicker) then
				on_rightclick(pos, name .. "_bottom_closed", false)
			end
		end,
		
		can_dig = check_player_priv,
		sounds = def.sounds,
		sunlight_propagates = def.sunlight,
		hardness = def.hardness	
	})
end
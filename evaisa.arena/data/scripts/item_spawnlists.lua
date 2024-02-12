local EntityHelper = dofile("mods/evaisa.arena/files/scripts/gamemode/helpers/entity.lua")
spawnlists =
{
	potion_spawnlist =
	{
		rnd_min = 1,
		rnd_max = 91,
		spawns = 
		{
			{
				value_min = 90,
				value_max = 91,
				load_entity_func = 
					function( data, x, y )
						local ox = data.offset_x or 0
						local oy = data.offset_y or 0
						
						if GameHasFlagRun( "greed_curse" ) and ( GameHasFlagRun( "greed_curse_gone" ) == false ) then
							return EntityLoad( "data/entities/items/pickup/physics_gold_orb_greed.xml", x + ox, y + oy )
						else
							return EntityLoad( "data/entities/items/pickup/physics_gold_orb.xml", x + ox, y + oy )
						end
					end,
				offset_y = -2,
			},
			{
				value_min = 86,
				value_max = 89,
				load_entity = "data/entities/items/pickup/broken_wand.xml",
				offset_y = -2,
			},
			{
				value_min = 84,
				value_max = 85,
				load_entity = "data/entities/items/pickup/thunderstone.xml",
				offset_y = -2,
			},
			{
				value_min = 80,
				value_max = 83,
				load_entity = "data/entities/items/pickup/brimstone.xml",
				offset_y = -2,
			},
			{
				value_min = 78,
				value_max = 79,
				load_entity = "data/entities/items/pickup/egg_monster.xml",
				offset_y = -2,
			},
			{
				value_min = 74,
				value_max = 77,
				load_entity = "data/entities/items/pickup/egg_slime.xml",
				offset_y = -2,
			},
			{
				value_min = 73,
				value_max = 73,
				load_entity = "data/entities/items/pickup/egg_purple.xml",
				offset_y = -2,
			},
			{
				value_min = 72,
				value_max = 72,
				load_entity_func = 
					function( data, x, y )
						-- NOTE( Petri ): 6.3.2023 - Changed the SetRandomSeed to be different, so that we might get other runestones than edges
						local opts = { "laser", "fireball", "lava", "slow", "null", "disc", "metal" }
						local rnd = Random( 1, #opts )
						local opt = opts[rnd]
						local ox = data.offset_x or 0
						local oy = data.offset_y or 0
						local entity_id = EntityLoad( "data/entities/items/pickup/runestones/runestone_" .. opt .. ".xml", x + ox, y + oy )
						rnd = Random( 1, 10 )
						if ( rnd == 2 ) then
							runestone_activate( entity_id )
						end
                        return entity_id
					end,
				offset_y = -10,
			},
			{
				value_min = 71,
				value_max = 71,
				load_entity_func = 
					function( data, x, y )
						local ox = data.offset_x or 0
						local oy = data.offset_y or 0
						
						if GameHasFlagRun( "greed_curse" ) and ( GameHasFlagRun( "greed_curse_gone" ) == false ) then
							return EntityLoad( "data/entities/items/pickup/physics_greed_die.xml", x + ox, y + oy )
						else
							return EntityLoad( "data/entities/items/pickup/physics_die.xml", x + ox, y + oy )
						end
					end,
				offset_y = -12,
				spawn_requires_flag = "card_unlocked_duplicate",
			},
			{
				value_min = 66,
				value_max = 70,
				load_entity = "data/entities/items/pickup/powder_stash.xml",
				offset_y = -2,
			},
			{
				value_min = 1,
				value_max = 65,
				load_entity = "data/entities/items/pickup/potion.xml",
				offset_y = -2,
			},
		},
	},
	potion_spawnlist_liquidcave =
	{
		rnd_min = 1,
		rnd_max = 86,
		spawns = 
		{
			{
				value_min = 83,
				value_max = 86,
				load_entity = "data/entities/items/pickup/broken_wand.xml",
				offset_y = -2,
			},
			{
				value_min = 77,
				value_max = 82,
				load_entity = "data/entities/items/pickup/moon.xml",
				offset_y = -2,
			},
			{
				value_min = 71,
				value_max = 76,
				load_entity = "data/entities/items/pickup/thunderstone.xml",
				offset_y = -2,
			},
			{
				value_min = 65,
				value_max = 70,
				load_entity = "data/entities/items/pickup/brimstone.xml",
				offset_y = -2,
			},
			{
				value_min = 59,
				value_max = 64,
				load_entity = "data/entities/items/pickup/egg_monster.xml",
				offset_y = -2,
			},
			{
				value_min = 56,
				value_max = 58,
				load_entity = "data/entities/items/pickup/egg_slime.xml",
				offset_y = -2,
			},
			{
				value_min = 53,
				value_max = 55,
				load_entity = "data/entities/items/pickup/egg_fire.xml",
				offset_y = -2,
			},
			{
				value_min = 50,
				value_max = 52,
				load_entity = "data/entities/items/pickup/egg_purple.xml",
				offset_y = -2,
			},
			{
				value_min = 1,
				value_max = 49,
				load_entity = "data/entities/items/pickup/potion.xml",
				offset_y = -2,
			},
		},
	},
}

function spawn_from_list( listname, x, y, sync )
	local spawnlist

	local rounds = tonumber(GlobalsGetValue("holyMountainCount", "0")) or 0
	local seed_x, seed_y = (x * 3256) + rounds * 765 + (GameGetFrameNum() / 30), (y * 5326) + rounds * 123 + (GameGetFrameNum() / 20)
	if(GameHasFlagRun("shop_sync") or sync)then
        seed_x, seed_y = (x * 3256) + rounds * 765, (y * 5326) + rounds * 123
	end

	--print("Item spawn seed: " .. tostring(seed_x) .. ", " .. tostring(seed_y))
	SetRandomSeed( seed_x, seed_y )

	if ( type( listname ) == "string" ) then
		spawnlist = spawnlists[listname]
	elseif ( type( listname ) == "table" ) then
		spawnlist = listname
	end
	
	if ( spawnlist == nil ) then
		print( "Couldn't find a spawn list with name: " .. tostring( listname ) )
		return
	end
	
	local rndmin = spawnlist.rnd_min or 0
	local rndmax = spawnlist.rnd_max or 100
	
	local rnd = Random( rndmin, rndmax )
	
	--print("Item Spawn Random: " .. tostring(rnd) .. " (" .. tostring(rndmin) .. " - " .. tostring(rndmax) .. ")")

	if ( spawnlist.spawns ~= nil ) then
		for i,data in ipairs( spawnlist.spawns ) do
			local vmin = data.value_min or rndmin
			local vmax = data.value_max or rndmax
			
			if ( rnd >= vmin ) and ( rnd <= vmax ) then
				local ox = data.offset_x or 0
				local oy = data.offset_y or 0
				
				if ( data.load_entity_func ~= nil ) then
					local item_entity = data.load_entity_func( data, x, y )
					EntityHelper.NetworkRegister(item_entity, x, y)
				elseif ( data.load_entity_from_list ~= nil ) then
					
					local item_entity = spawn_from_list( data.load_entity_from_list, x, y )
					EntityHelper.NetworkRegister(item_entity, x, y)
				elseif ( data.load_entity ~= nil ) then
					
					local item_entity = EntityLoad( data.load_entity, x + ox, y + oy )
					EntityHelper.NetworkRegister(item_entity, x, y)
				end
			end
		end
	end
end
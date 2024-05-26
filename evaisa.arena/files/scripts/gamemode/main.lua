arena_log = logger.init("noita-arena.log")
perk_log = logger.init("noita-arena-perk.log")
--perk_info_saved = logger.init("perk_info_saved.lua")
--perk_info_loaded = logger.init("perk_info_loaded.lua")


if(not debugging)then
	arena_log.enabled = false
end


mp_helpers = dofile("mods/evaisa.mp/files/scripts/helpers.lua")
local steamutils = dofile_once("mods/evaisa.mp/lib/steamutils.lua")
game_funcs = dofile("mods/evaisa.mp/files/scripts/game_functions.lua")
EZWand = dofile("mods/evaisa.arena/files/scripts/utilities/EZWand.lua")
smallfolk = dofile("mods/evaisa.arena/lib/smallfolk.lua")

wait = dofile("mods/evaisa.arena/files/scripts/utilities/wait.lua")
local inspect = dofile("mods/evaisa.arena/lib/inspect.lua")

local data_holder = dofile("mods/evaisa.arena/files/scripts/gamemode/data.lua")
local data = nil

last_player_entity = nil

local player = dofile("mods/evaisa.arena/files/scripts/gamemode/helpers/player.lua")
local entity = dofile("mods/evaisa.arena/files/scripts/gamemode/helpers/entity.lua")

--font_helper = dofile("mods/evaisa.arena/lib/font_helper.lua")
--message_handler = dofile("mods/evaisa.arena/files/scripts/gamemode/message_handler_stub.lua")
networking = dofile("mods/evaisa.arena/files/scripts/gamemode/networking.lua")
--spectator_networking = dofile("mods/evaisa.arena/files/scripts/gamemode/spectator_networking.lua")

upgrade_system = dofile("mods/evaisa.arena/files/scripts/gamemode/misc/upgrade_system.lua")
gameplay_handler = dofile("mods/evaisa.arena/files/scripts/gamemode/gameplay.lua")
spectator_handler = dofile("mods/evaisa.arena/files/scripts/gamemode/spectator.lua")

skin_system = dofile("mods/evaisa.arena/files/scripts/gui/skins.lua").init()

if(ModSettingGet("evaisa.arena.custom_parallax"))then
    Parallax = dofile("mods/evaisa.arena/files/scripts/parallax/parallax.lua")
end
local randomized_seed = true

local playerinfo_menu = dofile("mods/evaisa.arena/files/scripts/utilities/playerinfo_menu.lua")

dofile_once("data/scripts/perks/perk_list.lua")
dofile_once("mods/evaisa.arena/content/data.lua")

local applied_seed = 0

perks_sorted = {}
perk_enum = {}
all_perks = {}
all_perks_by_name = {}
perk_sprites = {}
for k, perk in pairs(perk_list) do
    perk_sprites[perk.id] = perk.ui_icon
    table.insert(perks_sorted, perk.id)
    all_perks[perk.id] = perk
    all_perks_by_name[perk.ui_name] = perk
end

table.sort(perks_sorted)

for i, perk_id in ipairs(perks_sorted) do
    perk_enum[perk_id] = i
end


local parallax_textures = {}

if(ModSettingGet("evaisa.arena.custom_parallax"))then
    local max_layers = 1
    for k, arena in pairs(arena_list) do
        if(arena.parallax_layers and arena.parallax_layers > max_layers)then
            max_layers = arena.parallax_layers
        end
        if(arena.parallax_textures)then
            for _, texture in ipairs(arena.parallax_textures) do
                table.insert(parallax_textures, texture)
            end
        end
    end

    Parallax.registerLayers(max_layers)
end
for k, arena in pairs(arena_list) do
    if(arena.init)then
        arena:init()
    end
end
if(ModSettingGet("evaisa.arena.custom_parallax"))then
    Parallax.registerTextures(parallax_textures)

    Parallax.postInit()
end
playermenu = nil

local was_content_mismatched = false

playerRunQueue = {}

local player_mods = "";

function RunWhenPlayerExists(func)
    table.insert(playerRunQueue, func)
end

lobby_member_names = {}

content_hash = content_hash or 0
content_string = content_string or ""

perk_blacklist_data = perk_blacklist_data or {}
perk_blacklist_string = perk_blacklist_string or ""
spell_blacklist_data = spell_blacklist_data or {}
spell_blacklist_string = spell_blacklist_string or ""
map_blacklist_data = map_blacklist_data or {}
map_blacklist_string = map_blacklist_string or ""
card_blacklist_data = card_blacklist_data or {}
card_blacklist_string = card_blacklist_string or ""


sorted_spell_list = sorted_spell_list or nil
sorted_spell_list_ids = sorted_spell_list_ids or nil
sorted_perk_list = sorted_perk_list or nil
sorted_perk_list_ids = sorted_perk_list_ids or nil
sorted_map_list = sorted_map_list or nil
sorted_map_list_ids = sorted_map_list_ids or nil



local function ifind(s, pattern, init, plain)
    return string.find(s:lower(), pattern:lower(), init, plain)
end

dofile("data/scripts/perks/perk_list.lua")
dofile("data/scripts/gun/gun_actions.lua")
dofile("mods/evaisa.arena/files/scripts/gamemode/misc/upgrades.lua")

local function SetNewSeed(lobby)
    local seed = 0
    print("Randomized seed? " .. tostring(randomized_seed))
    print("Is owner? " .. tostring(steam_utils.IsOwner()))
    if(randomized_seed and steam_utils.IsOwner())then
        local a, b, c, d, e, f = GameGetDateAndTimeLocal()
        math.randomseed(GameGetFrameNum() + a + b + c + d + e + f)
        seed = math.random(1, 4294967294)
        steam_utils.TrySetLobbyData(lobby, "seed", tostring(seed))
    else
        seed = tonumber(steam.matchmaking.getLobbyData(lobby, "seed") or 1)
    end
    print("Setting seed to " .. tostring(seed))
    return seed
end

local function TryUpdateData(lobby)

    
    
    if(sorted_spell_list == nil)then
        content_hash = 0
        sorted_spell_list = {}
        sorted_spell_list_ids = {}
        for _, spell in pairs(actions)do
            table.insert(sorted_spell_list, spell)
            table.insert(sorted_spell_list_ids, spell)
            content_hash = content_hash + string.bytes(spell.id)
            content_string = content_string .. spell.id .. "\n"
        end

        table.sort(sorted_spell_list, function(a, b)
            return GameTextGetTranslatedOrNot(a.name) < GameTextGetTranslatedOrNot(b.name)
        end)

        table.sort(sorted_spell_list_ids, function(a, b)
            return GameTextGetTranslatedOrNot(a.id) < GameTextGetTranslatedOrNot(b.id)
        end)
    end

    if(sorted_perk_list == nil)then
        sorted_perk_list = {}
        sorted_perk_list_ids = {}
        for _, perk in pairs(perk_list)do
            table.insert(sorted_perk_list, perk)
            table.insert(sorted_perk_list_ids, perk)
            content_hash = content_hash + string.bytes(perk.id)
            content_string = content_string .. perk.id .. "\n"
        end

        table.sort(sorted_perk_list, function(a, b)
            return GameTextGetTranslatedOrNot(a.ui_name) < GameTextGetTranslatedOrNot(b.ui_name)
        end)

        table.sort(sorted_perk_list_ids, function(a, b)
            return GameTextGetTranslatedOrNot(a.id) < GameTextGetTranslatedOrNot(b.id)
        end)
    end

    if(sorted_map_list == nil)then
        -- sort map list blah
        sorted_map_list = {}
        sorted_map_list_ids = {}
        for _, map in pairs(arena_list)do
            table.insert(sorted_map_list, map)
            table.insert(sorted_map_list_ids, map)
            content_hash = content_hash + string.bytes(map.id)
            content_string = content_string .. map.id .. "\n"
        end

        table.sort(sorted_map_list, function(a, b)
            return GameTextGetTranslatedOrNot(a.name) < GameTextGetTranslatedOrNot(b.name)
        end)

        table.sort(sorted_map_list_ids, function(a, b)
            return GameTextGetTranslatedOrNot(a.id) < GameTextGetTranslatedOrNot(b.id)
        end)
    end

    if(sorted_card_list == nil)then
        -- sort card list blah
        sorted_card_list = {}
        sorted_card_list_ids = {}
        for _, card in pairs(upgrades)do
            table.insert(sorted_card_list, card)
            table.insert(sorted_card_list_ids, card)
            content_hash = content_hash + string.bytes(card.id)
            content_string = content_string .. card.id .. "\n"
        end

        table.sort(sorted_card_list, function(a, b)
            return GameTextGetTranslatedOrNot(a.ui_name) < GameTextGetTranslatedOrNot(b.ui_name)
        end)

        table.sort(sorted_card_list_ids, function(a, b)
            return GameTextGetTranslatedOrNot(a.id) < GameTextGetTranslatedOrNot(b.id)
        end)
    end


    GlobalsSetValue("content_string", tostring(content_string))

    if(tostring(content_hash) ~= steam.matchmaking.getLobbyData(lobby, "content_hash") and not steam_utils.IsOwner())then
        print("content mismatch!")
        return
    end

    if(lobby_data_last_frame["perk_blacklist_data"] ~= nil and perk_blacklist_string ~= lobby_data_last_frame["perk_blacklist_data"])then
        print("Updating perk blacklist data")
        -- split byte string into table
        perk_blacklist_data = {}
        perk_blacklist_string = lobby_data_last_frame["perk_blacklist_data"]
        for i = 1, #perk_blacklist_string do
            local enabled = perk_blacklist_string:sub(i, i) == "1"
            if(enabled)then
                perk_blacklist_data[sorted_perk_list_ids[i].id] = enabled
            else
                perk_blacklist_data[sorted_perk_list_ids[i].id] = nil
            end
        end
    end

    if(lobby_data_last_frame["spell_blacklist_data"] ~= nil and spell_blacklist_string ~= lobby_data_last_frame["spell_blacklist_data"])then
        print("Updating spell blacklist data")
        -- split byte string into table
        spell_blacklist_data = {}
        spell_blacklist_string = lobby_data_last_frame["spell_blacklist_data"]
        for i = 1, #spell_blacklist_string do
            local enabled = spell_blacklist_string:sub(i, i) == "1"
            if(enabled)then
                spell_blacklist_data[sorted_spell_list_ids[i].id] = enabled
            else
                spell_blacklist_data[sorted_spell_list_ids[i].id] = nil
            end
        end
    end

    if(lobby_data_last_frame["map_blacklist_data"] ~= nil and map_blacklist_string ~= lobby_data_last_frame["map_blacklist_data"])then
        print("Updating map blacklist data")
        -- split byte string into table
        map_blacklist_data = {}
        map_blacklist_string = lobby_data_last_frame["map_blacklist_data"]
        for i = 1, #map_blacklist_string do
            local enabled = map_blacklist_string:sub(i, i) == "1"
            if(enabled)then
                map_blacklist_data[sorted_map_list_ids[i].id] = enabled
            else
                map_blacklist_data[sorted_map_list_ids[i].id] = nil
            end
        end
    end

    -- card blacklist
    if(lobby_data_last_frame["card_blacklist_data"] ~= nil and card_blacklist_string ~= lobby_data_last_frame["card_blacklist_data"])then
        print("Updating card blacklist data")
        -- split byte string into table
        card_blacklist_data = {}
        card_blacklist_string = lobby_data_last_frame["card_blacklist_data"]
        for i = 1, #card_blacklist_string do
            local enabled = card_blacklist_string:sub(i, i) == "1"
            if(enabled)then
                card_blacklist_data[sorted_card_list_ids[i].id] = enabled
            else
                card_blacklist_data[sorted_card_list_ids[i].id] = nil
            end
        end
    end

    content_hash = "tourney:"..tostring(content_hash)
    
end

local function SendLobbyData(lobby)

    if(sorted_perk_list_ids)then
        local perk_blacklist_string_temp = ""
        for _, perk in pairs(sorted_perk_list_ids)do
            if(perk_blacklist_data[perk.id] == nil)then
                perk_blacklist_string_temp = perk_blacklist_string_temp .. "0"
            else
                perk_blacklist_string_temp = perk_blacklist_string_temp .. (perk_blacklist_data[perk.id] and "1" or "0")
            end
        end
        --print(perk_blacklist_string_temp)
        steam_utils.TrySetLobbyData(lobby, "perk_blacklist_data", perk_blacklist_string_temp)
    end

    if(sorted_spell_list_ids)then
        local spell_blacklist_string_temp = ""
        for _, spell in pairs(sorted_spell_list_ids)do
            if(spell_blacklist_data[spell.id] == nil)then
                spell_blacklist_string_temp = spell_blacklist_string_temp .. "0"
            else
                spell_blacklist_string_temp = spell_blacklist_string_temp .. (spell_blacklist_data[spell.id] and "1" or "0")
            end
        end
        --print(spell_blacklist_string_temp)
        steam_utils.TrySetLobbyData(lobby, "spell_blacklist_data", spell_blacklist_string_temp)
    end

    if(sorted_map_list_ids)then
        local map_blacklist_string_temp = ""
        for _, map in pairs(sorted_map_list_ids)do
            if(map_blacklist_data[map.id] == nil)then
                map_blacklist_string_temp = map_blacklist_string_temp .. "0"
            else
                map_blacklist_string_temp = map_blacklist_string_temp .. (map_blacklist_data[map.id] and "1" or "0")
            end
        end
        --print(map_blacklist_string_temp)
        steam_utils.TrySetLobbyData(lobby, "map_blacklist_data", map_blacklist_string_temp)
    end

    if(sorted_card_list_ids)then
        local card_blacklist_string_temp = ""
        for _, card in pairs(sorted_card_list_ids)do
            if(card_blacklist_data[card.id] == nil)then
                card_blacklist_string_temp = card_blacklist_string_temp .. "0"
            else
                card_blacklist_string_temp = card_blacklist_string_temp .. (card_blacklist_data[card.id] and "1" or "0")
            end
        end
        --print(card_blacklist_string_temp)
        steam_utils.TrySetLobbyData(lobby, "card_blacklist_data", card_blacklist_string_temp)
    end
        
    steam.matchmaking.sendLobbyChatMsg(lobby, "refresh")
end


np.SetGameModeDeterministic(true)

ArenaMode = {
    id = "arena",
    name = "$arena_gamemode_name",
    version = 164,
    required_online_version = 351,
    version_display = function(version_string)
        return version_string .. " - " .. tostring(content_hash)
    end,
    version_flavor_text = "$arena_dev",
    custom_lobby_string = function(lobby)
        return string.format(GameTextGetTranslatedOrNot("$arena_lobby_string"), tostring(tonumber(steam.matchmaking.getLobbyData(lobby, "holyMountainCount")) or "0") + 1)
    end,
    spectator_unfinished_warning = false,
    enable_spectator = true,--not ModSettingGet("evaisa.arena.spectator_unstable"),
    enable_presets = true,
    custom_enter_check = function(lobby)
        local lobby_state = steam.matchmaking.getLobbyData(lobby, "arena_state") or "lobby"

        -- if we are the only player in the lobby and arena state is not lobby, allow entry
        if(steam_utils.getNumLobbyMembers() == 1 and lobby_state ~= "lobby")then
            return true, "Preparing in Holy Mountain"
        end

        if(lobby_state == "lobby")then
            return true, "Preparing in Holy Mountain"
        else
            return false, "Game is in progress, please wait"
        end
    end,
    custom_spectator_check = function(lobby)
        local lobby_state = steam.matchmaking.getLobbyData(lobby, "arena_state") or "lobby"

        -- if we are the only player in the lobby and arena state is not lobby, allow entry
        if(steam_utils.getNumLobbyMembers() == 1 and lobby_state ~= "lobby")then
            return true, "Preparing in Holy Mountain"
        end

        if(lobby_state == "lobby")then
            return true, "Preparing in Holy Mountain"
        else
            return false, "Game is in progress, please wait"
        end
    end,
    binding_register = function(bindings)
        print("Registering bindings for Noita Arena")
        -- Arena Spectator keyboard bindings
        bindings:RegisterBinding("arena_spectator_up", "Arena - Spectator [keyboard]", "Up", "Key_w", "key", false, true, false, false)
        bindings:RegisterBinding("arena_spectator_down", "Arena - Spectator [keyboard]", "Down", "Key_s", "key", false, true, false, false)
        bindings:RegisterBinding("arena_spectator_left", "Arena - Spectator [keyboard]", "Left", "Key_a", "key", false, true, false, false)
        bindings:RegisterBinding("arena_spectator_right", "Arena - Spectator [keyboard]", "Right", "Key_d", "key", false, true, false, false)
        bindings:RegisterBinding("arena_spectator_switch_left", "Arena - Spectator [keyboard]", "Switch Player Left", "Key_q", "key", false, true, false, false)
        bindings:RegisterBinding("arena_spectator_switch_right", "Arena - Spectator [keyboard]", "Switch Player Right", "Key_e", "key", false, true, false, false)
        bindings:RegisterBinding("arena_spectator_fast_move", "Arena - Spectator [keyboard]", "Move Fast", "Key_LSHIFT", "key", false, true, false, false)

        -- Arena Spectator gamepad bindings
        bindings:RegisterBinding("arena_spectator_quick_switch", "Arena - Spectator [keyboard]", "Quick select", "Key_SPACE", "key", false, true, false, false)
        bindings:RegisterBinding("arena_spectator_move_joy", "Arena - Spectator [gamepad]", "Movement stick", "gamepad_left_stick", "axis", false, false, false, true)
        bindings:RegisterBinding("arena_spectator_switch_stick_joy", "Arena - Spectator [gamepad]", "Quick select stick", "gamepad_right_stick", "axis", false, false, false, true)
        bindings:RegisterBinding("arena_spectator_quick_switch_joy", "Arena - Spectator [gamepad]", "Quick select", "gamepad_left_trigger", "axis_button", false, false, false, false, true)
        bindings:RegisterBinding("arena_spectator_quick_switch_joy_confirm", "Arena - Spectator [gamepad]", "Quick switch confirm", "gamepad_right_trigger", "axis_button", false, false, false, false, true)
        bindings:RegisterBinding("arena_spectator_switch_left_joy", "Arena - Spectator [gamepad]", "Switch Player Left", "JOY_BUTTON_LEFT_SHOULDER", "joy", false, false, true, false)
        bindings:RegisterBinding("arena_spectator_switch_right_joy", "Arena - Spectator [gamepad]", "Switch Player Right", "JOY_BUTTON_RIGHT_SHOULDER", "joy", false, false, true, false)
        bindings:RegisterBinding("arena_spectator_fast_move_joy", "Arena - Spectator [gamepad]", "Move Fast", "gamepad_right_trigger", "axis_button", false, false, false, false, true)
    
        -- Card system keyboard bindings
        bindings:RegisterBinding("arena_cards_select_card", "Arena - Cards [keyboard]", "Take selected card", "Key_e", "key", false, true, false, false)

        -- Card system gamepad bindings
        bindings:RegisterBinding("arena_cards_select_card_joy", "Arena - Cards [gamepad]", "Take selected card", "JOY_BUTTON_A", "joy", false, false, true, false)
        
    end,
    default_presets = {
        ["Wand Locked"] = {
            ["version"] = 2,
            ["settings"] = {
                ["zone_speed"] = 30,
                ["shop_start_level"] = 0,
                ["shop_random_ratio"] = 50,
                ["shop_type"] = "spell_only",
                ["shop_jump"] = 1,
                ["zone_step_interval"] = 30,
                ["upgrades_catchup"] = "losers",
                ["damage_cap"] = "0.25",
                ["shop_scaling"] = 2,
                ["zone_shrink"] = "static",
                ["shop_wand_chance"] = 40,
                ["max_shop_level"] = 5,
                ["shop_price_multiplier"] = 0,
                ["perk_catchup"] = "losers",
                ["upgrades_system"] = true,         
            }
        }
    }, 
    settings = {
        {
            id = "random_seed",
            name = "$arena_settings_random_seed_name",
            description = "$arena_settings_random_seed_description",
            type = "bool",
            default = true
        },  
        {
            id = "arena_gamemode",
            name = "$arena_settings_gamemode_name",
            description = "$arena_settings_gamemode_description",
            type = "enum",
            options = { { "ffa", "$arena_settings_gamemode_ffa" }, { "continuous", "$arena_settings_gamemode_continuous", {"$arena_settings_experimental", "$arena_settings_experimental_desc"} }, },
            default = "ffa"
        },
        {
            id = "map_picker",
            name = "$arena_settings_map_picker_name",
            description = "$arena_settings_map_picker_description",
            type = "enum",
            options = { { "ordered", "$arena_settings_map_picker_enum_order" }, { "random", "$arena_settings_map_picker_enum_random" }, { "vote", "$arena_settings_map_picker_enum_vote" } },
            default = "random"
        },
        {
			id = "map_vote_timer",
            require = function(setting_self)
                return GlobalsGetValue("map_picker", "random") == "vote"
            end,
			name = "$arena_settings_map_vote_timer_name",
			description = "$arena_settings_map_vote_timer_description",
			type = "slider",
			min = 15,
			max = 300,
			default = 90;
			display_multiplier = 1,
			formatting_func = function(value)
                -- trim spaces around value
                value = value:match("^%s*(.-)%s*$")
                -- if under 60, show seconds
                if(tonumber(value) < 60)then
                    return " "..tostring(value) .. "s"
                else
                    return " "..tostring(math.floor(value / 60)) .. "m"
                end
            end,
			width = 100
		},
        {
            id = "win_condition",
            name = "$arena_settings_win_condition_name",
            description = "$arena_settings_win_condition_description",
            type = "enum",
            options = { { "unlimited", "$arena_settings_win_condition_enum_unlimited" }, { "first_to", "$arena_settings_win_condition_enum_first_to" }, { "best_of", "$arena_settings_win_condition_enum_best_of" }, { "winstreak", "$arena_settings_win_condition_enum_winstreak" }},
            default = "unlimited"
        },
        {
			id = "win_condition_value",
            require = function(setting_self)
                return GlobalsGetValue("setting_next_win_condition", "unlimited") ~= "unlimited"
            end,
			name = "$arena_settings_win_condition_value_name",
			description = "$arena_settings_win_condition_value_description",
			type = "slider",
			min = 1,
			max = 20,
			default = 5;
			display_multiplier = 1,
			formatting_string = " $0",
			width = 100
		},
        {
            id = "win_condition_end_match",
            require = function(setting_self)
                return GlobalsGetValue("setting_next_win_condition", "unlimited") ~= "unlimited"
            end,
            name = "$arena_settings_win_condition_end_match_name",
            description = "$arena_settings_win_condition_end_match_description",
            type = "bool",
            default = true
        },
        {
            id = "perk_catchup",
            name = "$arena_settings_perk_reward_system_name",
            description = "$arena_settings_perk_reward_system_description",
            type = "enum",
            options = { { "everyone", "$arena_settings_reward_enum_everyone" }, { "winner", "$arena_settings_reward_enum_winner" }, { "losers", "$arena_settings_reward_enum_losers" }, { "first_death", "$arena_settings_reward_enum_first_death" }},
            default = "losers"
        },
        {
            id = "perk_sync",
            name = "$arena_settings_perk_sync_name",
            description = "$arena_settings_perk_sync_description",
            type = "bool",
            default = false
        },  
        {
            id = "item_shop",
            name = "$arena_settings_item_shop_name",
            description = "$arena_settings_item_shop_description",
            type = "bool",
            default = true
        },  
        {
            id = "shop_no_tiers",
			name = "$arena_settings_shop_disable_tiers_name",
			description = "$arena_settings_shop_disable_tiers_description",
            type = "bool",
            default = false
        },
		{
			id = "shop_type",
			name = "$arena_settings_shop_type_name",
			description = "$arena_settings_shop_type_description",
			type = "enum",
			options = { { "alternating", "$arena_settings_shop_type_alternating" }, { "random", "$arena_settings_shop_type_random" }, { "mixed", "$arena_settings_shop_type_mixed" },
				{ "spell_only", "$arena_settings_shop_type_spell_only" }, { "wand_only", "$arena_settings_shop_type_wand_only" } },
			default = "random"
		},
        {
            id = "shop_sync",
            name = "$arena_settings_shop_sync_name",
            description = "$arena_settings_shop_sync_description",
            type = "bool",
            default = false
        },  
		{
			id = "shop_wand_chance",
            require = function(setting_self)
                return GlobalsGetValue("setting_next_shop_type", "random") == "mixed"
            end,
			name = "$arena_settings_shop_wand_chance_name",
			description = "$arena_settings_shop_wand_chance_description",
			type = "slider",
			min = 20,
			max = 80,
			default = 40;
			display_multiplier = 1,
			formatting_string = " $0%",
			width = 100
		},
        {
            id = "shop_start_level",
			name = "$arena_settings_shop_start_level_name",
			description = "$arena_settings_shop_start_level_description",
			type = "slider",
			min = 0,
			max = 10,
			default = 0;
			display_multiplier = 1,
			formatting_string = " $0",
			width = 100
        },
        {
			id = "shop_random_ratio",
			require = function(setting_self)
                return GlobalsGetValue("setting_next_shop_type", "random") == "random"
            end,
			name = "$arena_settings_shop_random_ratio_name",
			description = "$arena_settings_shop_random_ratio_description",
			type = "slider",
			min = 10,
			max = 90,
			default = 50;
			display_multiplier = 1,
			formatting_string = " $0%",
			width = 100
		},
        {
            id = "shop_scaling",
			name = "$arena_settings_shop_scaling_name",
			description = "$arena_settings_shop_scaling_description",
			type = "slider",
			min = 1,
			max = 10,
			default = 2;
			display_multiplier = 1,
			formatting_string = " $0",
			width = 100
        },
        {
            id = "shop_jump",
			name = "$arena_settings_shop_jump_name",
			description = "$arena_settings_shop_jump_description",
			type = "slider",
			min = 0,
			max = 10,
			default = 1;
			display_multiplier = 1,
			formatting_string = " $0",
			width = 100
        },
        {
            id = "max_shop_level",
			name = "$arena_settings_max_shop_level_name",
			description = "$arena_settings_max_shop_level_description",
			type = "slider",
			min = 1,
			max = 10,
			default = 5;
			display_multiplier = 1,
			formatting_string = " $0",
			width = 100
        },
        {
            id = "shop_price_multiplier",
			name = "$arena_settings_shop_price_multiplier_name",
			description = "$arena_settings_shop_price_multiplier_description",
			type = "slider",
			min = 0,
			max = 30,
			default = 10;
			display_multiplier = 0.1,
            display_fractions = 1,
            modifier = function(value) 
                return math.floor(value)
            end,
			formatting_string = " $0",
			width = 100
        },
        --[[
        {
            id = "no_shop_cost",
            name = "$arena_settings_no_cost_name",
            description = "$arena_settings_no_cost_description",
            type = "bool",
            default = false
        },
        ]]
        {
            id = "damage_cap",
            name = "$arena_settings_damage_cap_name",
            description = "$arena_settings_damage_cap_description",
            type = "enum",
            options = { { "0.25", "$arena_settings_damage_cap_25" }, { "0.5", "$arena_settings_damage_cap_50" }, { "0.75", "$arena_settings_damage_cap_75" },
                { "disabled", "$arena_settings_damage_cap_disabled" } },
            default = "0.25"
        },
        {
            id = "zone_shrink",
            name = "$arena_settings_zone_shrink_name",
            description = "$arena_settings_zone_shrink_description",
            type = "enum",
            options = { { "disabled", "$arena_settings_zone_shrink_disabled" }, { "static", "$arena_settings_zone_shrink_static" }, { "shrinking_Linear", "$arena_settings_zone_shrink_linear" },
                { "shrinking_step", "$arena_settings_zone_shrink_stepped" } },
            default = "static"
        },
        {
            id = "zone_speed",
            name = "$arena_settings_zone_speed_name",
            description = "$arena_settings_zone_speed_description",
            type = "slider",    
            min = 1,
            max = 100,
            default = 30,
            display_multiplier = 1,
            formatting_string = " $0",
            width = 100
        },
        {
            id = "zone_step_interval",
            name = "$arena_settings_zone_step_interval_name",
            description = "$arena_settings_zone_step_interval_description",
            type = "slider",
            min = 1,
            max = 90,
            default = 30,
            display_multiplier = 1,
            formatting_string = " $0s",
            width = 100
        },
        {
            id = "upgrades_system",
            name = "$arena_settings_upgrades_system_name",
            description = "$arena_settings_upgrades_system_description",
            type = "bool",
            default = false
        },
        {
            id = "upgrades_catchup",
            require = function(setting_self)
                return GlobalsGetValue("setting_next_upgrades_system", "false") == "true"
            end,
            name = "$arena_settings_upgrades_reward_system_name",
            description = "$arena_settings_upgrades_reward_system_description",
            type = "enum",
            options = {{ "everyone", "$arena_settings_reward_enum_everyone" }, { "winner", "$arena_settings_reward_enum_winner" }, { "losers", "$arena_settings_reward_enum_losers" }, { "first_death", "$arena_settings_reward_enum_first_death" }},
            default = "losers"
        },
        {
            id = "wand_removal",
            name = "$arena_settings_wand_removal_name",
            description = "$arena_settings_wand_removal_description",
            type = "enum",
            options = { { "disabled", "$arena_settings_wand_removal_enum_none" }, { "random", "$arena_settings_wand_removal_enum_random" }, { "all", "$arena_settings_wand_removal_enum_all" } },
            default = "disabled"
        },
        {
            id = "wand_removal_who",
            require = function(setting_self)
                return GlobalsGetValue("setting_next_wand_removal", "disabled") ~= "disabled"
            end,
            name = "$arena_settings_wand_removal_who_name",
            description = "$arena_settings_wand_removal_who_description",
            type = "enum",
            options = {{ "everyone", "$arena_settings_reward_enum_everyone" }, { "winner", "$arena_settings_reward_enum_winner" }, { "losers", "$arena_settings_reward_enum_losers" }, { "first_death", "$arena_settings_reward_enum_first_death" }},
            default = "everyone"
        },
        {
            id = "smash_mode",
            name = "$arena_settings_smash_mode_name",
            description = "$arena_settings_smash_mode_description",
            type = "bool",
            default = false
        }, 
        {
            id = "dunce",
            name = "$arena_cosmetics_dunce_hat_name",
            description = "$arena_cosmetics_dunce_hat_description",
            type = "bool",
            default = false
        }, 
        {
            id = "refresh",
            name = "$arena_settings_refresh_name",
            description = "$arena_settings_refresh_description",
            type = "bool",
            default = false
        }, 
        {
            id = "hm_timer_count",
			name = "$arena_settings_hm_timer_count_name",
			description = "$arena_settings_hm_timer_count_description",
			type = "slider",
			min = 0,
			max = 100,
			default = 80;
			display_multiplier = 1,
			formatting_string = " $0%",
			width = 100
        },
        {
			id = "hm_timer_time",
			require = function(setting_self)
                return tonumber(GlobalsGetValue("setting_next_hm_timer_count", "80")) < 100
            end,
			name = "$arena_settings_hm_timer_time_name",
			description = "$arena_settings_hm_timer_time_description",
			type = "slider",
			min = 1,
			max = 5 * 60,
			default = 60;
			display_multiplier = 1,
			formatting_func = function(value)
                value = math.floor(value)
                -- show seconds or minutes, if minutes, round to 1 decimal
                if(value < 60)then
                    return " "..tostring(value) .. "s"
                else
                    -- round to 1 decimal
                    return " "..tostring(math.floor((value / 60) * 100) / 100) .. "m"
                end
            end,
			width = 100
		},
    },
    lobby_menus = {

        {
            id = "perk_blacklist",
            name = "$arena_settings_perk_blacklist_name",
            button_text = "$arena_settings_perk_blacklist_name",
            draw = function(lobby, gui, new_id)
                GuiLayoutBeginVertical(gui, 0, 0, true, 0, 0)
                
                TryUpdateData(lobby)

                local id = new_id("perk_search_input")
                GuiZSetForNextWidget(gui, -5600)
                perk_search_content = GuiTextInput(gui, id, 0, 0, perk_search_content or "", 140, 20)

                local _, _, hover = GuiGetPreviousWidgetInfo(gui)

                if(hover)then
                    GameAddFlagRun("chat_bind_disabled")
                end

                if(steam_utils.IsOwner())then
                    GuiZSetForNextWidget(gui, -5600)
                    if GuiButton(gui, new_id(), 0, 0, "$arena_disable_all") then
                        for i, perk in ipairs(sorted_perk_list)do
  
                            perk_blacklist_data[perk.id] = true
                        end
                        SendLobbyData(lobby)
                    end
                    GuiZSetForNextWidget(gui, -5600)
                    if GuiButton(gui, new_id(), 0, 0, "$arena_enable_all") then
                        for i, perk in ipairs(sorted_perk_list)do
 
                            perk_blacklist_data[perk.id] = false
                        end
                        SendLobbyData(lobby)
                    end
                end
                local iteration = 0
                for i, perk in ipairs(sorted_perk_list)do
                    if(perk_search_content == "" or ifind(string.lower(GameTextGetTranslatedOrNot(perk.ui_name)), string.lower(perk_search_content), 1, true)) then
                        iteration = iteration + 1
                        GuiLayoutBeginHorizontal(gui, 0, -((iteration - 1) * 2), true)
                        local is_blacklisted = perk_blacklist_data[perk.id]--steam.matchmaking.getLobbyData(lobby,"perk_blacklist_"..perk.id) == "true"
                        GuiZSetForNextWidget(gui, -5600)
                        GuiImage(gui, new_id(), 0, 0, perk.ui_icon, is_blacklisted and 0.4 or 1, 1, 1)
                        local visible, clicked, _, hovered = get_widget_info(gui)

                        if(visible and clicked)then
                            if(steam_utils.IsOwner())then
                                GamePlaySound( "data/audio/Desktop/ui.bank", "ui/button_click", GameGetCameraPos() )
                                perk_blacklist_data[perk.id] = not is_blacklisted
                                SendLobbyData(lobby)
                            end
                        end
                        if(visible and hovered)then
                            GuiTooltip(gui, GameTextGetTranslatedOrNot("$arena_settings_hover_tooltip_blacklist"), perk.ui_description)
                        end
                        local icon_width, icon_height = GuiGetImageDimensions(gui, perk.ui_icon)
                        SetRandomSeed(iteration * 21, iteration * 245)
                        local strike_out = "mods/evaisa.arena/files/sprites/ui/strikeout/small_"..tostring(Random(1, 4))..".png"
                        local offset = 0
                        if(is_blacklisted)then
                            GuiZSetForNextWidget(gui, -5610)
                            GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
                            GuiImage(gui, new_id(), -(icon_width - 1), 2, strike_out, 1, 1, 1)
                            offset = 2
                        end
                        local text_width, text_height = GuiGetTextDimensions(gui, perk.ui_name)
                        GuiZSetForNextWidget(gui, -5600)
                        if(GuiButton(gui, new_id(), offset, ((icon_height / 2) - (text_height / 2)), perk.ui_name))then
                            if(steam_utils.IsOwner())then
                                perk_blacklist_data[perk.id] = not is_blacklisted
                                SendLobbyData(lobby)
                            end
                        end
                        local _, _, hovered = GuiGetPreviousWidgetInfo(gui)
                        if(visible and hovered)then
                            GuiTooltip(gui, GameTextGetTranslatedOrNot("$arena_settings_hover_tooltip_blacklist"), perk.ui_description)
                        end
                        GuiLayoutEnd(gui)
                    end
                end
                GuiLayoutEnd(gui)
            end,
            close = function()

            end
        },
        {
            id = "spell_blacklist",
            name = "$arena_settings_spell_blacklist_name",
            button_text = "$arena_settings_spell_blacklist_name",
            draw = function(lobby, gui, new_id)
                GuiLayoutBeginVertical(gui, 0, 0, true, 0, 0)

                TryUpdateData(lobby)

                local id = new_id("spell_search_input")
                GuiZSetForNextWidget(gui, -5600)
                spell_search_content = GuiTextInput(gui, id, 0, 0, spell_search_content or "", 140, 20)

                local _, _, hover = GuiGetPreviousWidgetInfo(gui)

                if(hover)then
                    GameAddFlagRun("chat_bind_disabled")
                end

                if(steam_utils.IsOwner())then
                    GuiZSetForNextWidget(gui, -5600)
                    if GuiButton(gui, new_id(), 0, 0, "$arena_disable_all") then
                        for i, spell in ipairs(sorted_spell_list)do
                            spell_blacklist_data[spell.id] = true
                        end
                        SendLobbyData(lobby)
                    end
                    GuiZSetForNextWidget(gui, -5600)
                    if GuiButton(gui, new_id(), 0, 0, "$arena_enable_all") then
                        for i, spell in ipairs(sorted_spell_list)do
                            spell_blacklist_data[spell.id] = false
                        end
                        SendLobbyData(lobby)
                    end
                end
                
                --GuiIdPushString(gui, "spell_blacklist")

                --[[local id = 21
                local new_id = function()
                    id = id + 1
                    return id
                end]]

                local iteration = 0

                for i, spell in ipairs(sorted_spell_list)do
                    
                    if(spell_search_content == "" or ifind(string.lower(GameTextGetTranslatedOrNot(spell.name)), string.lower(spell_search_content), 1, true)) then
                        iteration = iteration + 1
                        GuiLayoutBeginHorizontal(gui, 0, -((iteration - 1) * 2), true)
                        local is_blacklisted = spell_blacklist_data[spell.id] --steam.matchmaking.getLobbyData(lobby,"spell_blacklist_"..spell.id) == "true"
                        GuiZSetForNextWidget(gui, -5600)
                        GuiImage(gui, new_id(), 0, 0, spell.sprite, is_blacklisted and 0.4 or 1, 1, 1)
                        local visible, clicked, _, hovered = get_widget_info(gui)

                        if(visible and clicked)then
                            if(steam_utils.IsOwner())then
                                GamePlaySound( "data/audio/Desktop/ui.bank", "ui/button_click", GameGetCameraPos() )
                                spell_blacklist_data[spell.id] = not is_blacklisted
                                SendLobbyData(lobby)
                            end
                        end
                        if(visible and hovered)then
                            GuiTooltip(gui, GameTextGetTranslatedOrNot("$arena_settings_hover_tooltip_blacklist"), spell.description)
                        end
                        local icon_width, icon_height = GuiGetImageDimensions(gui, spell.sprite)
                        SetRandomSeed(iteration * 21, iteration * 245)
                        local strike_out = "mods/evaisa.arena/files/sprites/ui/strikeout/small_"..tostring(Random(1, 4))..".png"
                        local offset = 0
                        if(is_blacklisted)then
                            GuiZSetForNextWidget(gui, -5610)
                            GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
                            GuiImage(gui, new_id(), -(icon_width - 1), 2, strike_out, 1, 1, 1)
                            offset = 2
                        end
                        local text_width, text_height = GuiGetTextDimensions(gui, spell.name)
                        --GuiText(gui, offset, ((icon_height / 2) - (text_height / 2)), spell.name)
                        GuiZSetForNextWidget(gui, -5600)
                        if(GuiButton(gui, new_id(), offset, ((icon_height / 2) - (text_height / 2)), spell.name))then
                            if(steam_utils.IsOwner())then
                                spell_blacklist_data[spell.id] = not is_blacklisted
                                SendLobbyData(lobby)
                            end
                        end
                        local _, _, hovered = GuiGetPreviousWidgetInfo(gui)
                        if(visible and hovered)then
                            GuiTooltip(gui, GameTextGetTranslatedOrNot("$arena_settings_hover_tooltip_blacklist"), spell.description)
                        end
                        GuiLayoutEnd(gui)
                    end
                end

                --GuiIdPop(gui)

                GuiLayoutEnd(gui)
            end,
            close = function()

            end
        },
        {
            id = "card_blacklist",
            name = "$arena_settings_card_blacklist_name",
            button_text = "$arena_settings_card_blacklist_name",
            draw = function(lobby, gui, new_id)
                GuiLayoutBeginVertical(gui, 0, 0, true, 0, 0)
                
                TryUpdateData(lobby)

                local id = new_id("card_search_input")
                GuiZSetForNextWidget(gui, -5600)
                card_search_content = GuiTextInput(gui, id, 0, 0, card_search_content or "", 140, 20)

                local _, _, hover = GuiGetPreviousWidgetInfo(gui)

                if(hover)then
                    GameAddFlagRun("chat_bind_disabled")
                end

                if(steam_utils.IsOwner())then
                    GuiZSetForNextWidget(gui, -5600)
                    if GuiButton(gui, new_id(), 0, 0, "$arena_disable_all") then
                        for i, card in ipairs(sorted_card_list)do
  
                            card_blacklist_data[card.id] = true
                        end
                        SendLobbyData(lobby)
                    end
                    GuiZSetForNextWidget(gui, -5600)
                    if GuiButton(gui, new_id(), 0, 0, "$arena_enable_all") then
                        for i, card in ipairs(sorted_card_list)do
 
                            card_blacklist_data[card.id] = false
                        end
                        SendLobbyData(lobby)
                    end
                end
                local iteration = 0
                for i, card in ipairs(sorted_card_list)do
                    if(card_search_content == "" or ifind(string.lower(GameTextGetTranslatedOrNot(card.ui_name)), string.lower(card_search_content), 1, true)) then
                        iteration = iteration + 1
                        GuiLayoutBeginHorizontal(gui, 0, -((iteration - 1) * 2), true)
                        local is_blacklisted = card_blacklist_data[card.id]--steam.matchmaking.getLobbyData(lobby,"card_blacklist_"..card.id) == "true"
                        GuiZSetForNextWidget(gui, -5600)
                        GuiColorSetForNextWidget(gui, card.card_symbol_tint and card.card_symbol_tint[1] or 1, card.card_symbol_tint and card.card_symbol_tint[2] or 1, card.card_symbol_tint and card.card_symbol_tint[3] or 1, 1)
                        GuiImage(gui, new_id(), 0, 0, card.card_symbol, is_blacklisted and 0.4 or 1, 1, 1)
                        local visible, clicked, _, hovered = get_widget_info(gui)

                        if(visible and clicked)then
                            if(steam_utils.IsOwner())then
                                GamePlaySound( "data/audio/Desktop/ui.bank", "ui/button_click", GameGetCameraPos() )
                                card_blacklist_data[card.id] = not is_blacklisted
                                SendLobbyData(lobby)
                            end
                        end
                        if(visible and hovered)then
                            GuiTooltip(gui, GameTextGetTranslatedOrNot("$arena_settings_hover_tooltip_blacklist"), card.ui_description)
                        end
                        local icon_width, icon_height = GuiGetImageDimensions(gui, card.card_symbol)
                        SetRandomSeed(iteration * 21, iteration * 245)
                        local strike_out = "mods/evaisa.arena/files/sprites/ui/strikeout/small_"..tostring(Random(1, 4))..".png"
                        local offset = 0
                        if(is_blacklisted)then
                            GuiZSetForNextWidget(gui, -5610)
                            GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
                            GuiImage(gui, new_id(), -(icon_width - 1), 2, strike_out, 1, 1, 1)
                            offset = 2
                        end
                        local text_width, text_height = GuiGetTextDimensions(gui, card.ui_name)
                        GuiZSetForNextWidget(gui, -5600)
                        if(GuiButton(gui, new_id(), offset, ((icon_height / 2) - (text_height / 2)), card.ui_name))then
                            if(steam_utils.IsOwner())then
                                card_blacklist_data[card.id] = not is_blacklisted
                                SendLobbyData(lobby)
                            end
                        end
                        local _, _, hovered = GuiGetPreviousWidgetInfo(gui)
                        if(visible and hovered)then
                            GuiTooltip(gui, GameTextGetTranslatedOrNot("$arena_settings_hover_tooltip_blacklist"), card.ui_description)
                        end
                        GuiLayoutEnd(gui)
                    end
                end
                GuiLayoutEnd(gui)
            end,
            close = function()

            end
        },
        
        {
            id = "map_pool",
            name = "$arena_settings_map_pool_name",
            button_text = "$arena_settings_map_pool_name",
            draw = function(lobby, gui, new_id)
                GuiLayoutBeginVertical(gui, 0, 0, true, 0, 0)

                TryUpdateData(lobby)

                local id = new_id("map_search_input")
                GuiZSetForNextWidget(gui, -5600)
                map_search_content = GuiTextInput(gui, id, 0, 0, map_search_content or "", 140, 20)

                local _, _, hover = GuiGetPreviousWidgetInfo(gui)

                
                if(hover)then
                    GameAddFlagRun("chat_bind_disabled")
                end

                if(steam_utils.IsOwner())then
                    GuiZSetForNextWidget(gui, -5600)
                    if GuiButton(gui, new_id(), 0, 0, "$arena_disable_all") then
                        for i, map in ipairs(sorted_map_list)do
                            map_blacklist_data[map.id] = true
                        end
                        SendLobbyData(lobby)
                    end

                    if GuiButton(gui, new_id(), 0, 0, "$arena_enable_all") then
                        GuiZSetForNextWidget(gui, -5600)
                        for i, map in ipairs(sorted_map_list)do
                            map_blacklist_data[map.id] = false
                        end
                        SendLobbyData(lobby)
                    end
                end
                
                --GuiIdPushString(gui, "spell_blacklist")

                --[[local id = 21
                local new_id = function()
                    id = id + 1
                    return id
                end]]

                local iteration = 0

                for i, map in ipairs(sorted_map_list)do
                    if(map_search_content == "" or ifind(string.lower(GameTextGetTranslatedOrNot(map.name)), string.lower(map_search_content), 1, true)) then
                        iteration = iteration + 1
                        GuiLayoutBeginHorizontal(gui, 0, ((iteration - 1)), true)
                        local is_blacklisted = map_blacklist_data[map.id]
                        local scale = 1

                        GuiZSetForNextWidget(gui, -5605)
                        local icon_width, icon_height = GuiGetImageDimensions(gui, map.thumbnail or "mods/evaisa.arena/content/arenas/default_thumbnail.png")
                        GuiImage(gui, new_id("map_list_stuff"), 0, 0, map.frame, 1, scale, scale)
                        local frame_width, frame_height = GuiGetImageDimensions(gui, map.frame)

                        
                        if(is_blacklisted)then
                            GuiZSetForNextWidget(gui, -5610)
                            GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
                            GuiImage(gui, new_id(), -frame_width-2, 0, "mods/evaisa.arena/content/arenas/disabled.png", 1, 1, 1)
                        end

                        GuiZSetForNextWidget(gui, -5600)
                        local alpha = 1
                        if(is_blacklisted)then
                            alpha = 0.4
                        end
                        
                        GuiImage(gui, new_id("map_list_stuff"), -(icon_width * scale) - 2.5, 1, map.thumbnail or "mods/evaisa.arena/content/arenas/default_thumbnail.png", alpha, scale * 0.99, scale * 0.99)
                        
                        

                        local visible, clicked, _, hovered = get_widget_info(gui)


                        if(visible and clicked)then
                            if(steam_utils.IsOwner())then
                                map_blacklist_data[map.id] = not is_blacklisted

                                GamePlaySound( "data/audio/Desktop/ui.bank", "ui/button_click", GameGetCameraPos() )
                                SendLobbyData(lobby)
                            end
                        end
                        if(visible and hovered)then
                            CustomTooltip(gui, function() 

                                local widest_string = GuiGetTextDimensions(gui, GameTextGetTranslatedOrNot("$arena_settings_hover_tooltip_blacklist"))

                                local text_width, text_height = GuiGetTextDimensions(gui, GameTextGetTranslatedOrNot(map.name))

                                if text_width > widest_string then
                                    widest_string = text_width
                                end

                                local text_width, text_height = GuiGetTextDimensions(gui, GameTextGetTranslatedOrNot(map.description))

                                if text_width > widest_string then
                                    widest_string = text_width
                                end

                                local text_width, text_height = GuiGetTextDimensions(gui, string.format(GameTextGetTranslatedOrNot("$arena_maps_credits"), GameTextGetTranslatedOrNot(map.credits or "???")))

                                if text_width > widest_string then
                                    widest_string = text_width
                                end



                                --GuiZSetForNextWidget(menu_gui, -5110)
                                GuiColorSetForNextWidget( gui, 1, 0.4, 0.4, 1 )
                                GuiZSetForNextWidget(gui, -7110)
                                GuiText(gui, -widest_string, 0, GameTextGetTranslatedOrNot("$arena_settings_hover_tooltip_blacklist"))
                                GuiColorSetForNextWidget( gui, 1, 1, 1, 1 )
                                GuiZSetForNextWidget(gui, -7110)
                                GuiText(gui, -widest_string, 0, GameTextGetTranslatedOrNot(map.name))
                                GuiColorSetForNextWidget( gui, 1, 1, 1, 0.8 )
                                GuiZSetForNextWidget(gui, -7110)
                                GuiText(gui, -widest_string, 0, GameTextGetTranslatedOrNot(map.description))
                                GuiColorSetForNextWidget( gui, 1, 1, 1, 0.6 )
                                GuiZSetForNextWidget(gui, -7110)
                                GuiText(gui, -widest_string, 0, string.format(GameTextGetTranslatedOrNot("$arena_maps_credits"), GameTextGetTranslatedOrNot(map.credits or "???")))
                            end, -7100, -255, 10)
                            --GuiTooltip(gui, GameTextGetTranslatedOrNot("$arena_settings_hover_tooltip_blacklist"), GameTextGetTranslatedOrNot(map.name))
                        end
                        

                        SetRandomSeed(iteration * 21, iteration * 245)
       
                        GuiZSetForNextWidget(gui, -5630)
                        local text_width, text_height = GuiGetTextDimensions(gui, GameTextGetTranslatedOrNot(map.name))

                        local offset = 6

                        GuiColorSetForNextWidget(gui, 0, 0, 0, 1)
                        GuiText(gui, -(icon_width * scale) + offset, offset, GameTextGetTranslatedOrNot(map.name))
                        GuiZSetForNextWidget(gui, -5631)
                        if(GuiButton(gui, new_id("map_list_stuff"), -(text_width + 2) - 1, offset-1, GameTextGetTranslatedOrNot(map.name)))then
                            if(steam_utils.IsOwner())then
                                map_blacklist_data[map.id] = not is_blacklisted
                                SendLobbyData(lobby)
                            end
                        end
                        local clicked, _, hovered = GuiGetPreviousWidgetInfo(gui)
                        --[[if(visible and hovered)then
                            CustomTooltip(gui, function() 
                                --GuiZSetForNextWidget(menu_gui, -5110)
                                GuiColorSetForNextWidget( gui, 1, 1, 1, 0.8 )
                                --GuiText(menu_gui, 0, 0, "Show Code")
                                GuiZSetForNextWidget(gui, -5110)
                                GuiText(gui, 0, 0, GameTextGetTranslatedOrNot("$arena_settings_hover_tooltip_blacklist"))
                                GuiText(gui, 0, 0, GameTextGetTranslatedOrNot(map.name))
                                GuiText(gui, 0, 0, GameTextGetTranslatedOrNot(map.description))
                                GuiText(gui, 0, 0, string.format(GameTextGetTranslatedOrNot("$arena_maps_credits"), GameTextGetTranslatedOrNot(map.credits)))
                            end, -5100, -68, -20)
                            --GuiTooltip(gui, GameTextGetTranslatedOrNot("$arena_settings_hover_tooltip_blacklist"), GameTextGetTranslatedOrNot(map.name))
                        end]]
                        GuiLayoutEnd(gui)
                    end
                end

                GuiLayoutEnd(gui)
            end,
            close = function()

            end
        },
    },
    commands = {
        ready = function(command_name, arguments)
            if(GameHasFlagRun("lock_ready_state"))then
                return
            end
            
            if(GameHasFlagRun("ready_check"))then
                ChatPrint(GameTextGetTranslatedOrNot("$arena_self_unready"))
                GameAddFlagRun("player_unready")
                GameRemoveFlagRun("ready_check")
                GameRemoveFlagRun("player_ready")
            else
                ChatPrint(GameTextGetTranslatedOrNot("$arena_self_ready"))
                GameAddFlagRun("player_ready")
                GameAddFlagRun("ready_check")
                GameRemoveFlagRun("player_unready")
            end


        end
    },
    default_data = {
        total_gold = "0",
        holyMountainCount = "0",
        ready_players = "null",
    },
    save_preset = function(lobby, preset_data)
        preset_data.perk_blacklist_data = perk_blacklist_data
        preset_data.spell_blacklist_data = spell_blacklist_data
        preset_data.map_blacklist_data = map_blacklist_data
        preset_data.card_blacklist_data = card_blacklist_data
        return preset_data
    end,
    load_preset = function(lobby, preset_data)
        perk_blacklist_data = preset_data.perk_blacklist_data or {}
        spell_blacklist_data = preset_data.spell_blacklist_data or {}
        map_blacklist_data = preset_data.map_blacklist_data or {}
        card_blacklist_data = preset_data.card_blacklist_data or {}

        --print(json.stringify(perk_blacklist_data))

        if(steam_utils.IsOwner())then
            SendLobbyData(lobby)
        end
    end,
    refresh = function(lobby)
        print("refreshing arena settings")
        --GamePrint("refreshing arena settings")

        TryUpdateData(lobby)

        if(tostring(content_hash) ~= steam.matchmaking.getLobbyData(lobby,"content_hash"))then
            if(steam_utils.IsOwner())then
                print("content hash mismatch, updating")
                steam_utils.TrySetLobbyData(lobby, "content_hash", content_hash)
                steam_utils.TrySetLobbyData(lobby, "mod_list", player_mods)
            else
                was_content_mismatched = true
                content_hash_popup_active = content_hash_popup_active or false
                if(content_hash_popup_active)then
                    return
                end

                popup.create("content_mismatch", GameTextGetTranslatedOrNot("$arena_content_mismatch_name"),{
					{
						text = GameTextGetTranslatedOrNot("$arena_content_mismatch_description"),
						color = {214 / 255, 60 / 255, 60 / 255, 1}
					},
                    {
						text = GameTextGetTranslatedOrNot("$arena_content_mismatch_description_2"),
						color = {214 / 255, 60 / 255, 60 / 255, 1}
					},
                    GameTextGetTranslatedOrNot("$arena_content_mismatch_description_3")
				}, {
					{
						text = GameTextGetTranslatedOrNot("$mp_close_popup"),
						callback = function()
                            content_hash_popup_active = false
						end
					}
				}, -6000)
            end
        end
  

        dofile("data/scripts/perks/perk_list.lua")
        dofile("data/scripts/gun/gun_actions.lua")

        for i, perk in ipairs(perk_list)do
            local is_blacklisted = perk_blacklist_data[perk.id]--steam.matchmaking.getLobbyData(lobby, "perk_blacklist_"..perk.id) == "true"
            if(is_blacklisted)then
                GameAddFlagRun("perk_blacklist_"..perk.id)
            else
                GameRemoveFlagRun("perk_blacklist_"..perk.id)
            end
        end

        for _, spell in pairs(actions)do
            local is_blacklisted = spell_blacklist_data[spell.id]--steam.matchmaking.getLobbyData(lobby, "spell_blacklist_"..spell.id) == "true"
            if(is_blacklisted)then
                GameAddFlagRun("spell_blacklist_"..spell.id)
            else
                GameRemoveFlagRun("spell_blacklist_"..spell.id)
            end
        end

        for _, map in pairs(arena_list)do
            local is_blacklisted = map_blacklist_data[map.id]--steam.matchmaking.getLobbyData(lobby, "map_blacklist_"..map.id) == "true"
            if(is_blacklisted)then
                GameAddFlagRun("map_blacklist_"..map.id)
            else
                GameRemoveFlagRun("map_blacklist_"..map.id)
            end
        end

        for _, card in pairs(upgrades)do
            local is_blacklisted = card_blacklist_data[card.id]--steam.matchmaking.getLobbyData(lobby, "card_blacklist_"..card.id) == "true"
            if(is_blacklisted)then
                GameAddFlagRun("card_blacklist_"..card.id)
            else
                GameRemoveFlagRun("card_blacklist_"..card.id)
            end
        end

        local random_seeds = steam.matchmaking.getLobbyData(lobby, "setting_random_seed")
        if (random_seeds == nil) then
            random_seeds = "true"
        end
        local old_randomized_seed = randomized_seed
        randomized_seed = random_seeds == "true"
        --[[if(randomized_seed and randomized_seed ~= old_randomized_seed)then
            SetNewSeed(lobby)
        end]]

        local gamemode = steam.matchmaking.getLobbyData(lobby, "setting_arena_gamemode")
        if (gamemode == nil) then
            gamemode = "ffa"
        end
        GlobalsSetValue("arena_gamemode", tostring(gamemode))

        local map_picker = steam.matchmaking.getLobbyData(lobby, "setting_map_picker")
        if (map_picker == nil) then
            map_picker = "random"
        end
        GlobalsSetValue("map_picker", tostring(map_picker))

        local map_vote_timer = tonumber(tonumber(steam.matchmaking.getLobbyData(lobby, "setting_map_vote_timer")))
        if (map_vote_timer == nil) then
            map_vote_timer = 90
        end
        GlobalsSetValue("map_vote_timer", tostring(map_vote_timer))

        local win_condition = steam.matchmaking.getLobbyData(lobby, "setting_win_condition")
        if (win_condition == nil)then
            win_condition = "unlimited"
        end
        GlobalsSetValue("win_condition", tostring(win_condition))

        local win_condition_value = tonumber(steam.matchmaking.getLobbyData(lobby, "setting_win_condition_value"))
        if (win_condition_value == nil)then
            win_condition_value = 5
        end
        GlobalsSetValue("win_condition_value", tostring(math.floor(win_condition_value)))

        local win_condition_end_match = steam.matchmaking.getLobbyData(lobby, "setting_win_condition_end_match")
        if (win_condition_end_match == nil)then
            win_condition_end_match = "true"
        end
        if(win_condition_end_match == "true")then
            GameAddFlagRun("win_condition_end_match")
        else
            GameRemoveFlagRun("win_condition_end_match")
        end

        local perk_catchup = steam.matchmaking.getLobbyData(lobby, "setting_perk_catchup")
        if (perk_catchup == nil) then
            perk_catchup = "losers"
        end
        GlobalsSetValue("perk_catchup", tostring(perk_catchup))

        local perk_sync = steam.matchmaking.getLobbyData(lobby, "setting_perk_sync")
        if (perk_sync == nil) then
            perk_sync = "false"
        end
        if(perk_sync == "true")then
            GameAddFlagRun("perk_sync")
        else
            GameRemoveFlagRun("perk_sync")
        end
        

		local shop_type = steam.matchmaking.getLobbyData(lobby, "setting_shop_type")
		if (shop_type == nil) then
			shop_type = "random"
		end
        --print("shop_type: " .. shop_type)
		GlobalsSetValue("shop_type", tostring(shop_type))

        local shop_sync = steam.matchmaking.getLobbyData(lobby, "setting_shop_sync")
        if (shop_sync == nil) then
            shop_sync = "false"
        end
        if(shop_sync == "true")then
            GameAddFlagRun("shop_sync")
        else
            GameRemoveFlagRun("shop_sync")
        end

        local item_shop = steam.matchmaking.getLobbyData(lobby, "setting_item_shop")
        if (item_shop == nil) then
            item_shop = "true"
        end
        if(item_shop == "true")then
            GameAddFlagRun("item_shop")
        else
            GameRemoveFlagRun("item_shop")
        end

        local shop_no_tiers = steam.matchmaking.getLobbyData(lobby, "setting_shop_no_tiers")
        if (shop_no_tiers == nil) then
            shop_no_tiers = "false"
        end
        if(shop_no_tiers == "true")then
            GameAddFlagRun("shop_no_tiers")
        else
            GameRemoveFlagRun("shop_no_tiers")
        end

		local shop_wand_chance = steam.matchmaking.getLobbyData(lobby, "setting_shop_wand_chance")
		if (shop_wand_chance == nil) then
			shop_wand_chance = 20
		end
		GlobalsSetValue("shop_wand_chance", tostring(shop_wand_chance))

        local shop_random_ratio = steam.matchmaking.getLobbyData(lobby, "setting_shop_random_ratio")
        if (shop_random_ratio == nil) then
            shop_random_ratio = 50
        end
        GlobalsSetValue("shop_random_ratio", tostring(shop_random_ratio))

        local shop_start_level = tonumber(steam.matchmaking.getLobbyData(lobby, "setting_shop_start_level"))
        if (shop_start_level == nil) then
            shop_start_level = 0
        end
        GlobalsSetValue("shop_start_level", tostring(shop_start_level))

        local shop_scaling = tonumber(steam.matchmaking.getLobbyData(lobby, "setting_shop_scaling"))
        if (shop_scaling == nil) then
            shop_scaling = 2
        end
        GlobalsSetValue("shop_scaling", tostring(shop_scaling))

        local shop_jump = tonumber(steam.matchmaking.getLobbyData(lobby, "setting_shop_jump"))
        if (shop_jump == nil) then
            shop_jump = 1
        end
        GlobalsSetValue("shop_jump", tostring(shop_jump))

        local max_shop_level = tonumber(steam.matchmaking.getLobbyData(lobby, "setting_max_shop_level"))
        if (max_shop_level == nil) then
            max_shop_level = 5
        end
        GlobalsSetValue("max_shop_level", tostring(max_shop_level))

        shop_price_multiplier = tonumber(steam.matchmaking.getLobbyData(lobby, "setting_shop_price_multiplier"))
        if (shop_price_multiplier == nil) then
            shop_price_multiplier = 10
        end
        GlobalsSetValue("shop_price_multiplier", tostring(shop_price_multiplier * 0.1))
        if(shop_price_multiplier < 1)then
            GlobalsSetValue("no_shop_cost", "true")
        else
            GlobalsSetValue("no_shop_cost", "false")
        end

        --[[local no_shop_cost = steam.matchmaking.getLobbyData(lobby, "setting_no_shop_cost")	
        if (no_shop_cost == nil) then
            no_shop_cost = false
        end
        print("no_shop_cost: " .. tostring(no_shop_cost))
        GlobalsSetValue("no_shop_cost", tostring(no_shop_cost))]]
        

        local damage_cap = tonumber(steam.matchmaking.getLobbyData(lobby, "setting_damage_cap"))
        if (damage_cap == nil) then
            damage_cap = 0.25
        end
        GlobalsSetValue("damage_cap", tostring(damage_cap))

        local zone_shrink = steam.matchmaking.getLobbyData(lobby, "setting_zone_shrink")
        if (zone_shrink == nil) then
            zone_shrink = "static"
        end
        GlobalsSetValue("zone_shrink", tostring(zone_shrink))

        local zone_speed = tonumber(steam.matchmaking.getLobbyData(lobby, "setting_zone_speed"))
        if (zone_speed == nil) then
            zone_speed = 30
        end
        GlobalsSetValue("zone_speed", tostring(zone_speed))

        local zone_step_interval = tonumber(steam.matchmaking.getLobbyData(lobby, "setting_zone_step_interval"))
        if (zone_step_interval == nil) then
            zone_step_interval = 30
        end
        GlobalsSetValue("zone_step_interval", tostring(zone_step_interval))

        local upgrades_system = steam.matchmaking.getLobbyData(lobby, "setting_upgrades_system")
        if (upgrades_system == nil) then
            upgrades_system = false
        end
        GlobalsSetValue("upgrades_system", tostring(upgrades_system))

        local upgrades_catchup = steam.matchmaking.getLobbyData(lobby, "setting_upgrades_catchup")
        if (upgrades_catchup == nil) then
            upgrades_catchup = "losers"
        end
        GlobalsSetValue("upgrades_catchup", tostring(upgrades_catchup))

        local wand_removal = steam.matchmaking.getLobbyData(lobby, "setting_wand_removal")
        if (wand_removal == nil) then
            wand_removal = "disabled"
        end
        GlobalsSetValue("wand_removal", tostring(wand_removal))

        local wand_removal_who = steam.matchmaking.getLobbyData(lobby, "setting_wand_removal_who")
        if (wand_removal_who == nil) then
            wand_removal_who = "everyone"
        end
        GlobalsSetValue("wand_removal_who", tostring(wand_removal_who))

        local smash_mode = steam.matchmaking.getLobbyData(lobby, "setting_smash_mode")
        if (smash_mode == nil) then
            smash_mode = "false"
        end
        if(smash_mode == "true")then
            GameAddFlagRun("smash_mode")
        else
            GameRemoveFlagRun("smash_mode")
        end

        local dunce = steam.matchmaking.getLobbyData(lobby, "setting_dunce")
        if (dunce == nil) then
            dunce = "false"
        end
        if(dunce == "true")then
            GameAddFlagRun("dunce")
        else
            GameRemoveFlagRun("dunce")
        end

        local refresh = steam.matchmaking.getLobbyData(lobby, "setting_refresh")
        if (refresh == nil) then
            refresh = "false"
        end
        if(refresh == "true")then
            GameAddFlagRun("refresh_all_charges")
        else
            GameRemoveFlagRun("refresh_all_charges")
        end

        local hm_timer_count = tonumber(steam.matchmaking.getLobbyData(lobby, "setting_hm_timer_count"))
        if (hm_timer_count == nil) then
            hm_timer_count = 0
        end
        GlobalsSetValue("hm_timer_count", tostring(math.floor(hm_timer_count)))

        local hm_timer_time = tonumber(steam.matchmaking.getLobbyData(lobby, "setting_hm_timer_time"))
        if (hm_timer_time == nil) then
            hm_timer_time = 60
        end
        GlobalsSetValue("hm_timer_time", tostring(math.floor(hm_timer_time)))
        

        arena_log:print("Lobby data refreshed")
    end,
    start_data = function(lobby)
        applied_seed = SetNewSeed(lobby)
        lobby_seed = applied_seed
        return applied_seed
    end,
    apply_start_data = function(lobby, start_data)
        applied_seed = start_data
        lobby_seed = applied_seed
    end,
    enter = function(lobby)

        was_content_mismatched = false

        player_mods = ""
        local mod_data = ModData()
        if (mod_data ~= nil) then
            for i, v in ipairs(mod_data)do
                player_mods = player_mods .. (v.name .. (v.id ~= nil and " ( "..v.id.." )" or "")) .. (i < #mod_data and ", " or "")
            end
        end
        
        if(steam_utils.IsOwner())then
            steam_utils.TrySetLobbyData(lobby, "mod_list", player_mods)
            steam_utils.TrySetLobbyData(lobby, "custom_lobby_string", "( round 0 )")
        end

        print("MP Version: " .. MP_VERSION .." < " .. ArenaMode.required_online_version)

        if(MP_VERSION < ArenaMode.required_online_version)then
            invalid_version_popup_active = invalid_version_popup_active or false
            if(not invalid_version_popup_active)then
                popup.create("bad_online", GameTextGetTranslatedOrNot("$arena_bad_online_version"), string.format(GameTextGetTranslatedOrNot("$arena_bad_online_version_desc"), ArenaMode.required_online_version), {
                    {
                        text = GameTextGetTranslatedOrNot("$arena_online_update"),
                        callback = function()
                            invalid_version_popup_active = false
                            os.execute("start explorer \"" .. noita_online_download .. "\"")
                        end
                    },
                    {
                        text = GameTextGetTranslatedOrNot("$mp_close_popup"),
                        callback = function()
                            invalid_version_popup_active = false
                        end
                    }
                }, -6000)

                disconnect({
                    lobbyID = lobby,
                    message = GameTextGetTranslatedOrNot("$arena_bad_online_version")
                })
            end
        end
        
        GlobalsSetValue("holyMountainCount", "0")
        GameAddFlagRun("player_unloaded")

        local player = player.Get()
        if (player ~= nil) then
            EntityKill(player)
        end
        
        print("Game mode deterministic? "..tostring(GameIsModeFullyDeterministic()))

        --print("WE GOOD???")

        --debug_log:print(GameTextGetTranslatedOrNot("$arena_predictive_netcode_name"))

        arena_log:print("Enter called!!!")

        GlobalsSetValue("TEMPLE_PERK_REROLL_COUNT", "0")

        local upgrade_translation_keys = ""
        local upgrade_translation_values = ""
        for k, v in ipairs(upgrades)do
            local id = v.id
            local ui_name = v.ui_name
            local ui_description = v.ui_description

            upgrade_translation_keys = upgrade_translation_keys .. "arena_upgrades_" .. string.lower(id) .. "_name\n"
            upgrade_translation_keys = upgrade_translation_keys .. "arena_upgrades_" .. string.lower(id) .. "_description\n"

            upgrade_translation_values = upgrade_translation_values .. ui_name .. "\n"
            upgrade_translation_values = upgrade_translation_values .. ui_description .. "\n"
        end

        -- write to files
        local upgrade_translation_keys_file = io.open("noita_online_logs/arena_upgrades_keys.txt", "w")
        upgrade_translation_keys_file:write(upgrade_translation_keys)
        upgrade_translation_keys_file:close()

        local upgrade_translation_values_file = io.open("noita_online_logs/arena_upgrades_values.txt", "w")
        upgrade_translation_values_file:write(upgrade_translation_values)
        upgrade_translation_values_file:close()

        ArenaMode.refresh(lobby)

        applied_seed = SetNewSeed(lobby)
        lobby_seed = applied_seed

        --[[
        local game_in_progress = steam.matchmaking.getLobbyData(lobby, "in_progress") == "true"
        if(game_in_progress)then
            ArenaMode.start(lobby, true)
        end
        ]]
        --message_handler.send.Handshake(lobby)
    end,
    stop = function(lobby)
        arena_log:print("Stop called!!!")
        delay.reset()
        wait.reset()
        if (data ~= nil) then
            ArenaGameplay.GracefulReset(lobby, data)
        end

        ArenaMode.refresh(lobby)
        
        gameplay_handler.ResetEverything(lobby)

        data = nil

        steamutils.RemoveLocalLobbyData(lobby, "player_data")
        steamutils.RemoveLocalLobbyData(lobby, "reroll_count")

        BiomeMapLoad_KeepPlayer("mods/evaisa.arena/files/scripts/world/map_arena.lua")
    end,
    start = function(lobby, was_in_progress)
        RunWhenPlayerExists(function()
            skin_system.load(lobby)
        end)

        for i, v in ipairs(EntityGetWithTag("player_unit"))do
            EntityKill(v)
        end
        
        print("Start called.")
        arena_log:print("Start called!!!")

        if(was_content_mismatched)then
            -- reopen lobby menu
            in_game = false
            gui_closed = false
            invite_menu_open = false 
            selected_player = nil
            -- show content mismatch popup
            ArenaMode.refresh(lobby)
            return
        end

        delay.reset()
        wait.reset()
        if (data ~= nil) then
            ArenaGameplay.GracefulReset(lobby, data)
        end

        GameRemoveFlagRun("DeserializedHolyMountain")
        
        ArenaMode.refresh(lobby)

        data = data_holder:New()
        data.state = "lobby"
        data.spectator_mode = steamutils.IsSpectator(lobby)
        data:DefinePlayers(lobby)

        
        gameplay_handler.ResetEverything(lobby)

        if (not was_in_progress or data.spectator_mode) then
            steamutils.RemoveLocalLobbyData(lobby, "player_data")
            steamutils.RemoveLocalLobbyData(lobby, "reroll_count")
        else
            local unique_game_id_server = steam.matchmaking.getLobbyData(lobby, "unique_game_id") or "0"
            local unique_game_id_client = steamutils.GetLocalLobbyData(lobby, "unique_game_id") or "1523523"
    
            if (unique_game_id_server ~= unique_game_id_client) then
                arena_log:print("Unique game id mismatch, removing player data")
                GlobalsSetValue("TEMPLE_PERK_REROLL_COUNT", "0")
                steamutils.RemoveLocalLobbyData(lobby, "player_data")
                steamutils.RemoveLocalLobbyData(lobby, "reroll_count")
            else
                gameplay_handler.GetGameData(lobby, data)
            end
        end



        GameAddFlagRun("player_unloaded")

        SetWorldSeed(applied_seed)


        local player_entity = player.Get()



        --local local_seed = data.random.range(100, 10000000)

        --GlobalsSetValue("local_seed", tostring(local_seed))

        --local unique_seed = data.random.range(100, 10000000)
        --GlobalsSetValue("unique_seed", tostring(unique_seed))

        if (steam_utils.IsOwner()) then
            local unique_game_id = data.random.range(100, 10000000)
            steam_utils.TrySetLobbyData(lobby, "unique_game_id", tostring(unique_game_id))
        end

        if (not data.spectator_mode and player_entity == nil) then
            gameplay_handler.LoadPlayer(lobby, data)
        end

        gameplay_handler.LoadLobby(lobby, data, true, true)

        if (playermenu ~= nil) then
            playermenu:Destroy()
        end

        playermenu = playerinfo_menu:New()

        -- request ready states
        networking.send.request_ready_states(lobby)
        networking.send.request_skins(lobby)

        --message_handler.send.Handshake(lobby)
    end,
    --[[
    spectate = function(lobby, was_in_progress)
        arena_log:print("Spectate called!!!")

        if(was_content_mismatched)then
            -- reopen lobby menu
            in_game = false
            gui_closed = false
            invite_menu_open = false 
            selected_player = nil
            -- show content mismatch popup
            ArenaMode.refresh(lobby)
            return
        end


        delay.reset()
        wait.reset()
        if (data ~= nil) then
            ArenaGameplay.GracefulReset(lobby, data)
        end
        
        if (not was_in_progress) then
            steamutils.RemoveLocalLobbyData(lobby, "player_data")
            steamutils.RemoveLocalLobbyData(lobby, "reroll_count")
        end

        gameplay_handler.ResetEverything(lobby)

        local unique_game_id_server = steam.matchmaking.getLobbyData(lobby, "unique_game_id") or "0"
        local unique_game_id_client = steamutils.GetLocalLobbyData(lobby, "unique_game_id") or "1523523"

        if (unique_game_id_server ~= unique_game_id_client) then
            arena_log:print("Unique game id mismatch, removing player data")
            steamutils.RemoveLocalLobbyData(lobby, "player_data")
            steamutils.RemoveLocalLobbyData(lobby, "reroll_count")
        end

        GameAddFlagRun("player_unloaded")

        local seed = tonumber(steam.matchmaking.getLobbyData(lobby, "seed") or 1)

        SetWorldSeed(seed)

        ArenaMode.refresh(lobby)

        data = data_holder:New()
        data.state = "lobby"
        data.spectator_mode = steamutils.IsSpectator(lobby)
        data:DefinePlayers(lobby)

        --local local_seed = data.random.range(100, 10000000)

        --GlobalsSetValue("local_seed", tostring(local_seed))

        --local unique_seed = data.random.range(100, 10000000)
        --GlobalsSetValue("unique_seed", tostring(unique_seed))

        if (steam_utils.IsOwner()) then
            local unique_game_id = data.random.range(100, 10000000)
            steam_utils.TrySetLobbyData(lobby, "unique_game_id", tostring(unique_game_id))
        end

        gameplay_handler.GetGameData(lobby, data)
        gameplay_handler.LoadLobby(lobby, data, true, true)

        if (playermenu ~= nil) then
            playermenu:Destroy()
        end

        playermenu = playerinfo_menu:New()

    end,
    ]]
    update = function(lobby)

        if(Parallax)then
            Parallax.update()
        end

        if (data == nil) then
            return
        end

        --delay.update()
        wait.update()

        if (data == nil) then
            return
        end

        if(steam_utils.IsOwner() and data.last_state ~= data.state)then
            data.last_state = data.state
            if(GlobalsGetValue("arena_gamemode", "ffa") ~= "continuous")then
                steam_utils.TrySetLobbyData(lobby, "arena_state", data.state)
            end
        elseif(not steam_utils.IsOwner())then
            data.last_state = nil
        end

        skin_system.editor_open = GameHasFlagRun("wardrobe_open") and not GameHasFlagRun("game_paused") and gui_closed
        skin_system.draw(lobby, data)

        if(GameGetFrameNum() % 10 == 0)then
            local mortals = EntityGetWithTag("mortal")
            for i = 0, #mortals do
                local mortal = mortals[i]
                EntityAddTag(mortal, "homing_target")
            end
        end

        data.spectator_mode = steamutils.IsSpectator(lobby)

        data.using_controller = GameGetIsGamepadConnected()

        if (GameGetFrameNum() % 61 == 0) then
            if (data ~= nil) then
                local unique_game_id = steamutils.GetLobbyData( "unique_game_id") or "0"
                steamutils.SetLocalLobbyData(lobby, "unique_game_id", tostring(unique_game_id))
            end

            local members = steamutils.getLobbyMembers(lobby)
            for k, member in pairs(members) do
                if (member.id ~= steam_utils.getSteamID()) then
                    local name = steamutils.getTranslatedPersonaName(member.id)
                    if (name ~= nil) then
                        lobby_member_names[tostring(member.id)] = name
                    end
                end
            end


            networking.send.handshake(lobby)

            


            --local unique_seed = data.random.range(100, 10000000)
            --GlobalsSetValue("unique_seed", tostring(unique_seed))
        end

        -- no fog allowed!!
        local world_state = GameGetWorldStateEntity()
        local world_state_component = EntityGetFirstComponentIncludingDisabled(world_state, "WorldStateComponent")

        ComponentSetValue2(world_state_component, "fog", 0)
        ComponentSetValue2(world_state_component, "intro_weather", true)

        --[[local update_seed = steamutils.GetLobbyData( "update_seed")
        if (update_seed == nil) then
            update_seed = "0"
        end

        GlobalsSetValue("update_seed", update_seed)]]

        if (data ~= nil) then

            gameplay_handler.Update(lobby, data)
   

            if (not IsPaused()) then
                if (playermenu ~= nil) then
                    playermenu:Update(data, lobby)
                end
            end
        end

        --[[if(input:WasKeyPressed("f10"))then
            if(steam_utils.IsOwner())then
                ArenaGameplay.AddRound(lobby)
                delay.new(5, function()
                    ArenaGameplay.LoadLobby(lobby, data, false)
                    networking.send.load_lobby(lobby)
                end)
            end
        elseif(input:WasKeyPressed("f9"))then
            EntityKill(GameGetWorldStateEntity())
        elseif(input:WasKeyPressed("f6"))then
            local player_entity = EntityGetWithTag("player_unit")[1]
            local x, y = EntityGetTransform(player_entity)
            EntityInflictDamage(player_entity, 10000, "DAMAGE_SLICE", "player", "BLOOD_EXPLOSION", 0, 0, GameGetWorldStateEntity(), x, y, 0)
        --elseif (input:WasKeyPressed("f5")) then
            
            -- global table snapshot
            -- json stringify global table
            local json_string = inspect(data)
            -- write to file

            --print(type(json_string))

            --GamePrint(tostring(json_string).."wawa")

        elseif (input:WasKeyPressed("f3")) then
            if(not dev_log or not dev_log.enabled)then
                dev_log = logger.init("arena-dev.log")
                print("Dev log enabled")
                dev_log.enabled = true
                dev_log:print("Dev log enabled")
            else
                dev_log.enabled = false
            end


            
        end]]


        --print("Did something go wrong?")
    end,
    late_update = function(lobby)
        if (data == nil) then
            return
        end

        gameplay_handler.LateUpdate(lobby, data)


        

    end,
    player_enter = function(lobby, user)

        if(data and data.players[tostring(user)] ~= nil)then
            
            data.players[tostring(user)].entity = nil
            data.players[tostring(user)].alive = false
        end

        if(steamutils.IsOwner())then
            SendLobbyData(lobby)
            
            print("Player joined - Sending lobby data!")
        end
    end,
    leave = function(lobby)
        GameAddFlagRun("player_unloaded")
        if(gameplay_handler == nil)then
            return
        end
        gameplay_handler.ResetEverything(lobby)

        local keybinds_global = GlobalsGetValue("evaisa.mp.keybinds", "{}")
        local keybinds_order_global = GlobalsGetValue("evaisa.mp.keybinds_order", "{}")
        
        ComponentSetValue(EntityGetFirstComponent(GameGetWorldStateEntity(), "WorldStateComponent"), "lua_globals", "")

        GlobalsSetValue("evaisa.mp.keybinds", keybinds_global)
        GlobalsSetValue("evaisa.mp.keybinds_order", keybinds_order_global)
    end,
    --[[
    message = function(lobby, message, user)
        message_handler.handle(lobby, message, user, data)
    end,
    ]]
    received = function(lobby, event, message, user)
        if (user == steam_utils.getSteamID() or data == nil) then
            return
        end

        if (not data.players[tostring(user)]) then
            data:DefinePlayer(lobby, user)
        end

        if (data ~= nil) then
            if (networking.receive[event]) then
                networking.receive[event](lobby, message, user, data)
            end

        end
        --print("Received event: " .. event)

    end,
    on_projectile_fired = function(lobby, shooter_id, projectile_id, rng, position_x, position_y, target_x, target_y,
                                   send_message, unknown1, multicast_index, unknown3)
        --[[print(tostring(send_message))
        print(tostring(unknown1))
        print(tostring(unknown2))
        print(tostring(unknown3))]]

        --print("Projectile fired")

        if (EntityHasTag(shooter_id, "client")) then
            EntityAddTag(shooter_id, "player_unit")
        end

        if (data ~= nil) then
            gameplay_handler.OnProjectileFired(lobby, data, shooter_id, projectile_id, rng, position_x, position_y,
                target_x, target_y, send_message, unknown1, multicast_index, unknown3)
        end
    end,
    on_projectile_fired_post = function(lobby, shooter_id, projectile_id, rng, position_x, position_y, target_x, target_y,
                                        send_message, unknown1, multicast_index, unknown3)
        if (EntityHasTag(shooter_id, "client")) then
            EntityRemoveTag(shooter_id, "player_unit")
        end

        if (data ~= nil) then
            gameplay_handler.OnProjectileFiredPost(lobby, data, shooter_id, projectile_id, rng, position_x, position_y,
                target_x, target_y, send_message, unknown1, multicast_index, unknown3)
        end
    end
}

table.insert(gamemodes, ArenaMode)

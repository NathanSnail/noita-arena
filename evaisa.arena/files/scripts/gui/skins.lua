dofile("mods/evaisa.arena/files/scripts/gui/image.lua")

local color_picker = dofile("mods/evaisa.arena/files/scripts/gui/color_picker.lua")
local fs = require("fs")
local lfs = require("lfs")


local skins = {}

function uniqueFileName()
    -- generate a unique file name 
    return os.date("%Y%m%d%H%M%S") .. math.random(1000, 9999)
end

local cache_folder = "data/evaisa.arena/cache/"
local skins_folder = "data/evaisa.arena/skins/"

-- remove contents of cache folder with lfs
for file in lfs.dir(cache_folder)do
    if file ~= "." and file ~= ".." then
        local file_path = cache_folder..file
        fs.remove(file_path)
    end
end

-- create skins folder
fs.mkdir(skins_folder, true)

skins.init = function()
    local self = {
        gui = GuiCreate(),
        editor_open = true,
        color_picker = color_picker.new(),
        last_file_name = uniqueFileName(),
        selected_tool = 1,
        hovered_tool = 0,
        selected_skin = {
            name = "New Skin",
            path = "",
            img = nil
        },
        last_hovered_skin = nil,
        last_player_skins = {},
        active_skin_data = nil,
    }

    local player_default_img = loadImage("mods/evaisa.arena/files/gfx/skins/player_default.png")
    local player_modified_img = loadImage("mods/evaisa.arena/files/gfx/skins/player_default.png")


    self.loaded_skins = {}

    self.refresh_skins = function()
        self.loaded_skins = {}
        for file in lfs.dir(skins_folder)do
            if file ~= "." and file ~= ".." then
                local file_path = skins_folder..file
                local status, img = pcall(loadImage, file_path)
                if status then
                    -- check if dimensions are correct
                    if(img.w == player_default_img.w and img.h == player_default_img.h)then
                        local skin_name = file:match("(.+)%..+")
                        local temp_path = cache_folder..uniqueFileName()..".png"
                        saveImage(img, temp_path)
                        table.insert(self.loaded_skins, {name = skin_name, path = file_path, temp_path = temp_path, img = img})
                    end
                end
            end
        end
    end

    self.refresh_skins()


    self.last_file_name = cache_folder..uniqueFileName()..".png"
    saveImage(player_modified_img, self.last_file_name)

    self.tools = {
        {
            id = "pencil",
            icon = "mods/evaisa.arena/files/gfx/skins/tool_icons/pencil.png",
            name = "$arena_skins_tools_pencil",
            description = "$arena_skins_tools_pencil_description",
            action = function(relative_x, relative_y)
                if(InputIsMouseButtonDown( 1 ))then

                    -- get relative mouse position to player
    
                    -- get color at relative position
                    local r, g, b, a = getPixel(player_modified_img, relative_x, relative_y)
    
                    -- check if alpha is 255
                    if(a == 255)then
                        -- set pixel color to picked color
                        --GamePrint("Setting pixel color to " .. self.color_picker.picked_color)
    
                        -- check if pixel color is different from picked color
                        if(r ~= self.color_picker.current_red or g ~= self.color_picker.current_green or b ~= self.color_picker.current_blue)then
                            --GamePrint("Setting pixel color to " .. self.color_picker.picked_color)
                                
    
                            setPixel(player_modified_img, relative_x, relative_y, self.color_picker.current_red, self.color_picker.current_green, self.color_picker.current_blue, 255)
                            -- destroy old file
                            -- save new file
                            fs.remove(self.last_file_name)
    
                            self.last_file_name = "data/evaisa.skins/cache/"..uniqueFileName()..".png"
                            saveImage(player_modified_img, self.last_file_name)
                        end
                    end
                elseif(InputIsMouseButtonDown( 2 ))then
                    -- reset pixel color to default
                    local r, g, b, a = getPixel(player_default_img, relative_x, relative_y)
                    local pixel_r, pixel_g, pixel_b, pixel_a = getPixel(player_modified_img, relative_x, relative_y)
    
                    -- check if pixel color is different from default color
                    if a == 255 and (r ~= pixel_r or g ~= pixel_g or b ~= pixel_b or a ~= pixel_a) then
                        --GamePrint("Setting pixel color to " .. self.color_picker.picked_color)
                        setPixel(player_modified_img, relative_x, relative_y, r, g, b, 255)
                        -- destroy old file
                        -- save new file
    
                        fs.remove(self.last_file_name)
    
                        self.last_file_name = "data/evaisa.skins/cache/"..uniqueFileName()..".png"
                        saveImage(player_modified_img, self.last_file_name)
                    end
                end
            end
        },
        {
            id = "eraser",
            icon = "mods/evaisa.arena/files/gfx/skins/tool_icons/eraser.png",
            name = "$arena_skins_tools_eraser",
            description = "$arena_skins_tools_eraser_description",
            action = function(relative_x, relative_y)
                if(InputIsMouseButtonDown( 1 ))then
                    -- reset pixel color to default
                    local r, g, b, a = getPixel(player_default_img, relative_x, relative_y)
                    local pixel_r, pixel_g, pixel_b, pixel_a = getPixel(player_modified_img, relative_x, relative_y)
    
                    -- check if pixel color is different from default color
                    if a == 255 and (r ~= pixel_r or g ~= pixel_g or b ~= pixel_b or a ~= pixel_a) then
                        --GamePrint("Setting pixel color to " .. self.color_picker.picked_color)
                        setPixel(player_modified_img, relative_x, relative_y, r, g, b, 255)
                        -- destroy old file
                        -- save new file
    
                        fs.remove(self.last_file_name)
    
                        self.last_file_name = "data/evaisa.skins/cache/"..uniqueFileName()..".png"
                        saveImage(player_modified_img, self.last_file_name)
                    end
                end
            end
        },
        {
            id = "picker",
            icon = "mods/evaisa.arena/files/gfx/skins/tool_icons/picker.png",
            name = "$arena_skins_tools_picker",
            description = "$arena_skins_tools_picker_description",
            action = function(relative_x, relative_y)
                if(InputIsMouseButtonDown( 1 ))then
                    -- get color at relative position
                    local r, g, b, a = getPixel(player_modified_img, relative_x, relative_y)
                    if(a == 255)then
                        self.color_picker.picked_color = color_merge(r, g, b, a)
                        self.color_picker.current_hex = rgb_to_hex(r, g, b)
                        self.color_picker.current_red = r
                        self.color_picker.current_green = g
                        self.color_picker.current_blue = b
                        self.color_picker.calculateBarIndexAndPickerPosition()
                    end
                end
            end
        },
        {
            id = "fill",
            icon = "mods/evaisa.arena/files/gfx/skins/tool_icons/fill.png",
            name = "$arena_skins_tools_fill",
            description = "$arena_skins_tools_fill_description",
            action = function(relative_x, relative_y)
                if(InputIsMouseButtonDown( 1 ))then
                    -- get color at relative position
                    local r, g, b, a = getPixel(player_modified_img, relative_x, relative_y)
                    if(a == 255 and (r ~= self.color_picker.current_red or g ~= self.color_picker.current_green or b ~= self.color_picker.current_blue))then
                        -- flood fill all attached pixels that are the same color
                        local function fillNeighbors(x, y)
                            local neighbors = {
                                {x = x, y = y - 1},
                                {x = x, y = y + 1},
                                {x = x - 1, y = y},
                                {x = x + 1, y = y}
                            }
                        
                            for i, neighbor in ipairs(neighbors) do
                                local n_x = neighbor.x
                                local n_y = neighbor.y
                                if n_x >= 0 and n_x < player_modified_img.w and n_y >= 0 and n_y < player_modified_img.h then
                                    local n_r, n_g, n_b, n_a = getPixel(player_modified_img, n_x, n_y)
                                    -- Check if the neighbor pixel matches the original color and is not already the target color
                                    if n_a == a and n_r == r and n_g == g and n_b == b then
                                        setPixel(player_modified_img, n_x, n_y, self.color_picker.current_red, self.color_picker.current_green, self.color_picker.current_blue, 255)
                                        fillNeighbors(n_x, n_y)
                                    end
                                end
                            end
                        end
                        

                        setPixel(player_modified_img, relative_x, relative_y, self.color_picker.current_red, self.color_picker.current_green, self.color_picker.current_blue, 255)

                        fillNeighbors(relative_x, relative_y)

                        -- destroy old file
                        -- save new file
                        fs.remove(self.last_file_name)
    
                        self.last_file_name = "data/evaisa.skins/cache/"..uniqueFileName()..".png"
                        saveImage(player_modified_img, self.last_file_name)
                    end
                elseif(InputIsMouseButtonDown( 2 ))then
                    -- reset pixel color to default
                    local r, g, b, a = getPixel(player_default_img, relative_x, relative_y)
                    local pixel_r, pixel_g, pixel_b, pixel_a = getPixel(player_modified_img, relative_x, relative_y)
    
                    -- check if pixel color is different from default color
                    if a == 255 and (r ~= pixel_r or g ~= pixel_g or b ~= pixel_b or a ~= pixel_a) then
                        --GamePrint("Setting pixel color to " .. self.color_picker.picked_color)
                        local function fillNeighbors(x, y)
                            local neighbors = {
                                {x = x, y = y - 1},
                                {x = x, y = y + 1},
                                {x = x - 1, y = y},
                                {x = x + 1, y = y}
                            }
                        
                            for i, neighbor in ipairs(neighbors) do
                                local n_x = neighbor.x
                                local n_y = neighbor.y
                                if n_x >= 0 and n_x < player_modified_img.w and n_y >= 0 and n_y < player_modified_img.h then
                                    local default_r, default_g, default_b, default_a = getPixel(player_default_img, n_x, n_y)
                                    local n_r, n_g, n_b, n_a = getPixel(player_modified_img, n_x, n_y)

                                    -- Check if the neighbor pixel matches the original color and is not already the target color
                                    if n_r == pixel_r and n_g == pixel_g and n_b == pixel_b and n_a == 255 then
                                        setPixel(player_modified_img, n_x, n_y, default_r, default_g, default_b, 255)
                                        fillNeighbors(n_x, n_y)
                                    end
                                end
                            end
                        end

                        fillNeighbors(relative_x, relative_y)
                        setPixel(player_modified_img, relative_x, relative_y, r, g, b, 255)


                        -- destroy old file
                        -- save new file
    
                        fs.remove(self.last_file_name)
    
                        self.last_file_name = "data/evaisa.skins/cache/"..uniqueFileName()..".png"
                        saveImage(player_modified_img, self.last_file_name)
                    end
                    
                end
            end
        },
        {
            id = "replace",
            icon = "mods/evaisa.arena/files/gfx/skins/tool_icons/replace.png",
            name = "$arena_skins_tools_replace",
            description = "$arena_skins_tools_replace_description",
            action = function(relative_x, relative_y)
                if(InputIsMouseButtonDown( 1 ))then
                    local r, g, b, a = getPixel(player_modified_img, relative_x, relative_y)
                    if(a == 255 and (r ~= self.color_picker.current_red or g ~= self.color_picker.current_green or b ~= self.color_picker.current_blue))then
                        for y = 0, player_modified_img.h - 1 do
                            for x = 0, player_modified_img.w - 1 do
                                local p_r, p_g, p_b, p_a = getPixel(player_modified_img, x, y)
                                if(p_a == 255 and (p_r == r and p_g == g and p_b == b))then
                                    setPixel(player_modified_img, x, y, self.color_picker.current_red, self.color_picker.current_green, self.color_picker.current_blue, 255)
                                end
                            end
                        end

                        -- destroy old file
                        -- save new file
                        fs.remove(self.last_file_name)

                        self.last_file_name = "data/evaisa.skins/cache/"..uniqueFileName()..".png"
                        saveImage(player_modified_img, self.last_file_name)
                    end
                elseif(InputIsMouseButtonDown( 2 ))then
                    local r, g, b, a = getPixel(player_default_img, relative_x, relative_y)
                    local pixel_r, pixel_g, pixel_b, pixel_a = getPixel(player_modified_img, relative_x, relative_y)
                    if(a == 255 and (r ~= pixel_r or g ~= pixel_g or b ~= pixel_b))then
                        for y = 0, player_modified_img.h - 1 do
                            for x = 0, player_modified_img.w - 1 do
                                local p_r, p_g, p_b, p_a = getPixel(player_modified_img, x, y)
                                local orig_r, orig_g, orig_b, orig_a = getPixel(player_default_img, x, y)
                                if(p_a == 255 and (p_r ~= orig_r or p_g ~= orig_g or p_b ~= orig_b))then
                                    setPixel(player_modified_img, x, y, orig_r, orig_g, orig_b, 255)
                                end
                            end
                        end

                        -- destroy old file
                        -- save new file
                        fs.remove(self.last_file_name)

                        self.last_file_name = "data/evaisa.skins/cache/"..uniqueFileName()..".png"
                        saveImage(player_modified_img, self.last_file_name)
                    end
                end
            end
        },
        --[[
        {
            id = "apply",
            icon = "mods/evaisa.arena/files/gfx/skins/tool_icons/apply.png",
            name = "Apply Skin",
            description = "Apply skin to player.",
            button = function()
                self.generate_skin()
                self.editor_open = false
            end
        }
        ]]
    }

    local id = 21523
    local new_id = function()
        id = id + 1
        return id
    end

    self.draw = function(lobby, data)
        if(not self.editor_open)then
            if(self.gui)then
                GuiDestroy(self.gui)
                self.gui = nil
            end
            if(self.color_picker.gui)then
                GuiDestroy(self.color_picker.gui)
                self.color_picker.gui = nil
            end
            return
        end

        id = 21523

        if(self.gui == nil)then
            self.gui = GuiCreate()
        end

        GuiStartFrame(self.gui)

        local screen_width, screen_height = GuiGetScreenDimensions(self.gui)

        local main_container_width = 200
        local main_container_height = 200

        local x = screen_width / 2 - main_container_width / 2
        local y = screen_height / 2 - main_container_height / 2

        local container_x, container_y = x, y

        -- draw window bars
        
        GuiBeginAutoBox( self.gui )

        local z_index = -3900
        GuiZSet( self.gui, z_index - 1 )
        GuiColorSetForNextWidget( self.gui, 0, 0, 0, 0.3 )

        local bar_y = y - 14
        local title = GameTextGetTranslatedOrNot("$arena_skins_skin_editor")

        GuiText(self.gui, x, bar_y, " "..title)

        local w = 202

        GuiLayoutBeginLayer( self.gui )
        GuiLayoutBeginHorizontal( self.gui, 0, 0, true, 0, 0)
        if(CustomButton(self.gui, "sagsadshds", x + (w - 10), bar_y + 1, z_index - 600, 1, "mods/evaisa.mp/files/gfx/ui/minimize.png", 0, 0, 0, 0.5))then
            self.editor_open = false
            GameRemoveFlagRun("wardrobe_open")
        end
        GuiLayoutEnd( self.gui )
        GuiLayoutEndLayer( self.gui )


        GuiZSetForNextWidget( self.gui, z_index )
        GuiOptionsAddForNextWidget(self.gui, GUI_OPTION.IsExtraDraggable)
        GuiEndAutoBoxNinePiece( self.gui, 0, w, 8, false, 0, "mods/evaisa.mp/files/gfx/ui/9piece_window_bar.png", "mods/evaisa.mp/files/gfx/ui/9piece_window_bar.png")

        -- color bar

        GuiBeginAutoBox( self.gui )

        GuiZSet( self.gui, z_index - 1 )
        GuiColorSetForNextWidget( self.gui, 0, 0, 0, 0.3 )

        local title = GameTextGetTranslatedOrNot("$arena_skins_color_picker")

        GuiText(self.gui, x + 200 + 8, bar_y, " "..title)

        w = 70

        GuiZSetForNextWidget( self.gui, z_index )
        GuiOptionsAddForNextWidget(self.gui, GUI_OPTION.IsExtraDraggable)
        GuiEndAutoBoxNinePiece( self.gui, 0, w, 8, false, 0, "mods/evaisa.mp/files/gfx/ui/9piece_window_bar.png", "mods/evaisa.mp/files/gfx/ui/9piece_window_bar.png")

        -- saved skins bar
        GuiBeginAutoBox( self.gui )

        GuiZSet( self.gui, z_index - 1 )
        GuiColorSetForNextWidget( self.gui, 0, 0, 0, 0.3 )

        local title = GameTextGetTranslatedOrNot("$arena_skins_storage")

        GuiText(self.gui, x - 138, bar_y, " "..title)

        w = 132

        GuiZSetForNextWidget( self.gui, z_index )
        GuiOptionsAddForNextWidget(self.gui, GUI_OPTION.IsExtraDraggable)
        GuiEndAutoBoxNinePiece( self.gui, 0, w, 8, false, 0, "mods/evaisa.mp/files/gfx/ui/9piece_window_bar.png", "mods/evaisa.mp/files/gfx/ui/9piece_window_bar.png")


        -- draw saved skins container

        local saved_skins_control_height = 50

        GuiZSetForNextWidget(self.gui, -3900)
        GuiBeginScrollContainer(self.gui, 5243643 + (GameGetFrameNum() % 2), x - 138, y, 130, saved_skins_control_height, false, 1, 1)
        GuiLayoutBeginVertical(self.gui, 0, 0, true, 2, 2)

        if(GuiButton(self.gui, new_id(), 0, 0, GameTextGetTranslatedOrNot("$arena_skins_open_folder")))then
            os.execute("start \"\" \"data\\evaisa.arena\\skins\"")
        end
        GuiTooltip(self.gui, GameTextGetTranslatedOrNot("$arena_skins_open_folder"), GameTextGetTranslatedOrNot("$arena_skins_open_folder_description"))

        GuiLayoutBeginHorizontal(self.gui, 0, 5, true, 1)
        GuiText(self.gui, 0, 0, GameTextGetTranslatedOrNot("$arena_skins_skin_name"))
        GuiZSetForNextWidget(self.gui, -3950)
        self.selected_skin.name = GuiTextInput(self.gui, new_id(), 0, 0, self.selected_skin.name, 80, 16)

        local illegal_chars = {
            "/",
            "\\",
            ":",
            "*",
            "?",
            "\"",
            "<",
            ">",
            "|",
        }

        local _, _, hov = GuiGetPreviousWidgetInfo(self.gui)

        if(hov)then
            GameAddFlagRun("no_wardrobe_close")
        else
            GameRemoveFlagRun("no_wardrobe_close")
        end

        for i, char in ipairs(illegal_chars)do
            self.selected_skin.name = self.selected_skin.name:gsub(char, "")
        end

        -- remove control characters
        self.selected_skin.name = self.selected_skin.name:gsub("%c", "")
        GuiLayoutEnd(self.gui)
        
        if(GuiButton(self.gui, new_id(), 0, 3, GameTextGetTranslatedOrNot("$arena_skins_save_skin")))then
            -- save skin
            if(self.selected_skin.path)then
                fs.remove(self.selected_skin.path)
            end

            if(self.selected_skin.temp_path)then
                fs.remove(self.selected_skin.temp_path)
            end
            saveImage(player_modified_img, skins_folder..self.selected_skin.name..".png")
            self.refresh_skins()
        end
        GuiTooltip(self.gui, GameTextGetTranslatedOrNot("$arena_skins_save_skin"), GameTextGetTranslatedOrNot("$arena_skins_save_skin_description"))

        if(GuiButton(self.gui, new_id(), 0, -2, GameTextGetTranslatedOrNot("$arena_skins_apply_skin")))then
            -- apply skin 
            self.apply_skin(lobby)
            self.editor_open = false
            GameRemoveFlagRun("wardrobe_open")
        end
        GuiTooltip(self.gui, GameTextGetTranslatedOrNot("$arena_skins_apply_skin"), GameTextGetTranslatedOrNot("$arena_skins_apply_skin_description"))


        GuiLayoutEnd(self.gui)
        GuiEndScrollContainer(self.gui)


        GuiZSetForNextWidget(self.gui, -3900)
        GuiBeginScrollContainer(self.gui, 53252534, x - 138, y + saved_skins_control_height + 7, 130, 200 - saved_skins_control_height - 7, false, 1, 1)
        GuiLayoutBeginVertical(self.gui, 0, 0, true)

        local any_hovered = false
        for i, skin in ipairs(self.loaded_skins)do
            if(GuiImageButton(self.gui, new_id(), 0, 0, "", skin.temp_path))then
                self.selected_skin = skin
                player_modified_img = loadImage(skin.path)

                fs.remove(self.last_file_name)
                self.last_file_name = "data/evaisa.skins/cache/"..uniqueFileName()..".png"
                saveImage(player_modified_img, self.last_file_name)
                GamePlaySound("data/audio/Desktop/ui.bank", "ui/button_click", 0, 0)
            end
            local clicked, right_clicked, hovered = GuiGetPreviousWidgetInfo(self.gui)
            if(hovered)then
                if(self.last_hovered_skin ~= i)then
                    GamePlaySound("data/audio/Desktop/ui.bank", "ui/button_select", 0, 0)
                    self.last_hovered_skin = i
                end
                any_hovered = true
            end

            GuiText(self.gui, skin.img.w + 2, -skin.img.h, skin.name)
            if(GuiButton(self.gui, new_id(), skin.img.w + 2, -1, GameTextGetTranslatedOrNot("$arena_skins_overwrite")))then
                -- overwrite skin
                fs.remove(skin.temp_path)
                saveImage(player_modified_img, skin.path)
                self.refresh_skins()
            end
            local width, height = GuiGetTextDimensions(self.gui, GameTextGetTranslatedOrNot("$arena_skins_overwrite"))
            if (GuiButton(self.gui, new_id(), skin.img.w + 2 + width + 4, -height, GameTextGetTranslatedOrNot("$arena_skins_remove_skin"))) then
                -- delete skin
                fs.remove(skin.path)
                fs.remove(skin.temp_path)
                self.refresh_skins()
            end
        end

        if(not any_hovered)then
            self.last_hovered_skin = nil
        end


        GuiLayoutEnd(self.gui)
        GuiEndScrollContainer(self.gui)

        -- draw t0ols
        GuiZSetForNextWidget(self.gui, -3900)
        GuiBeginScrollContainer(self.gui, 2453256, x, y + 208, 200, 16, false, 1, 1)

        GuiLayoutBeginHorizontal(self.gui, 0, 0, true, 3, 3)

        local any_hovered = false
        for i, tool in ipairs(self.tools)do
            GuiZSetForNextWidget(self.gui, -3900)

            local tool_scale = self.hovered_tool == i and 1.1 or 1
            local tool_image_width, tool_image_height = GuiGetImageDimensions(self.gui, tool.icon)
            -- calculate negative offset when hovered
            local tool_offset_x = -(((tool_image_width * tool_scale) - tool_image_width) / 2)
            local tool_offset_y = -(((tool_image_height * tool_scale) - tool_image_height) / 2)

            GuiImage(self.gui, new_id(), tool_offset_x, tool_offset_y, tool.icon, self.selected_tool ~= i and 0.6 or 1, tool_scale, tool_scale)

            local clicked, right_clicked, hovered = GuiGetPreviousWidgetInfo(self.gui)

            if(clicked)then
                GamePlaySound("data/audio/Desktop/ui.bank", "ui/button_click", 0, 0)
                if(not tool.button)then
                    self.selected_tool = i
                else
                    tool.button()
                end
            elseif(hovered)then
                if(self.hovered_tool ~= i)then
                    self.hovered_tool = i
                    
                    GamePlaySound("data/audio/Desktop/ui.bank", "ui/button_select", 0, 0)
                end
                any_hovered = true
            end

            GuiTooltip(self.gui, tool.name, tool.description)
        end

        if(not any_hovered)then
            self.hovered_tool = 0
        end

        GuiLayoutEnd(self.gui)

        GuiEndScrollContainer(self.gui)
        

        --[[local illegal_chars = {
            "/",
            "\\",
            ":",
            "*",
            "?",
            "\"",
            "<",
            ">",
            "|",
        }

        for i, char in ipairs(illegal_chars)do
            self.current_skin_name = self.current_skin_name:gsub(char, "")
        end

        -- remove control characters
        self.current_skin_name = self.current_skin_name:gsub("%c", "")]]

        GuiZSetForNextWidget(self.gui, -3900)
        GuiBeginScrollContainer(self.gui, 6434252 + (GameGetFrameNum() % 2), x, y, 200, 200, false, 1, 1)

        local scale = 8

        -- in center of container, draw player bounds
        local player_x = (main_container_width / 2) - ((player_default_img.w * scale) / 2)
        local player_y = (main_container_height / 2) - ((player_default_img.h * scale) / 2)

        local player_offset_x = player_x + container_x + 2
        local player_offset_y = player_y + container_y + 2

        GuiZSetForNextWidget(self.gui, -4000)
        GuiImage(self.gui, new_id(), player_x, player_y, self.last_file_name, 1, scale, scale)
        -- check if player clicked within bounds
        local mouse_x, mouse_y = input:GetUIMousePos(self.gui)
        
        if(mouse_x > player_offset_x and mouse_x < player_offset_x + (player_default_img.w * scale) and mouse_y > player_offset_y and mouse_y < player_offset_y + (player_default_img.h * scale))then

            --GamePrint("Mouse is within bounds")
            
            -- display draw cursor
            local relative_x = math.floor((mouse_x - player_offset_x) / scale)
            local relative_y = math.floor((mouse_y - player_offset_y) / scale)

            GuiZSetForNextWidget(self.gui, -4001)
            GuiImage(self.gui, new_id(), player_x + relative_x * scale, player_y + relative_y * scale, "mods/evaisa.arena/files/gfx/skins/draw_cursor.png", 1, 1, 1)

            self.tools[self.selected_tool].action(relative_x, relative_y)

        end


        GuiEndScrollContainer(self.gui) 

        self.color_picker.draw(x + main_container_width + 8, y)
    end

    self.generate_skin = function(texture, is_content)
        local uv_map = "mods/evaisa.arena/files/gfx/skins/player.png"
        local uv_map_img = loadImage(uv_map)

        local skin_texture_img = nil--loadImage(texture_path)
        local status = false
        if is_content then
            -- catch errors pcall
            status, skin_texture_img = pcall(loadImageFromString, texture)
            
        else
            status, skin_texture_img = pcall(loadImage, texture)
        end

        if not status then
            GamePrint("Failed to load skin texture.")
            return
        end

        -- loop through uv map pixels
        for y = 0, uv_map_img.h - 1 do
            for x = 0, uv_map_img.w - 1 do
                local r, g, b, a = getPixel(uv_map_img, x, y)
                if(a == 255)then
                    local uv_x, uv_y = r, g
                    -- check if uv_x and uv_y are within bounds of player_modified_img
                    if(uv_x >= 0 and uv_x < skin_texture_img.w and uv_y >= 0 and uv_y < skin_texture_img.h)then
                        local p_r, p_g, p_b, p_a = getPixel(skin_texture_img, uv_x, uv_y)
                        setPixel(uv_map_img, x, y, p_r, p_g, p_b, p_a)
                    end
                end
            end
        end

        local arm_uv_map = "mods/evaisa.arena/files/gfx/skins/player_arm.png"
        local arm_uv_map_img = loadImage(arm_uv_map)

        -- loop through uv map pixels
        for y = 0, arm_uv_map_img.h - 1 do
            for x = 0, arm_uv_map_img.w - 1 do
                local r, g, b, a = getPixel(arm_uv_map_img, x, y)
                if(a == 255)then
                    local uv_x, uv_y = r, g
                    -- check if uv_x and uv_y are within bounds of player_modified_img
                    if(uv_x >= 0 and uv_x < skin_texture_img.w and uv_y >= 0 and uv_y < skin_texture_img.h)then
                        local p_r, p_g, p_b, p_a = getPixel(skin_texture_img, uv_x, uv_y)
                        setPixel(arm_uv_map_img, x, y, p_r, p_g, p_b, p_a)
                    end
                end
            end
        end

        -- save uv_map_img to cache
        local file_name = uniqueFileName()
        local temp_path = cache_folder..file_name.."_base.png"
        local temp_path_arm = cache_folder..file_name.."_arm.png"
        saveImage(uv_map_img, temp_path)
        saveImage(arm_uv_map_img, temp_path_arm)

        return temp_path, temp_path_arm, file_name

    end

    self.apply_skin_to_entity = function(lobby, entity, user, data)

        if user then
            if(not data.players[tostring(user)])then
                return
            end
            local data = data.players[tostring(user)].skin_data
            if not data or data == "" then
                return
            end
            if self.last_player_skins[tostring(user)] then
                -- remove old skin
                local old_skin_path = self.last_player_skins[tostring(user)].path
                fs.remove(old_skin_path)

                local old_skin_path_arm = self.last_player_skins[tostring(user)].arm_path
                fs.remove(old_skin_path_arm)
            end

            -- generate skin
            local temp_path, arm_path, path_name = self.generate_skin(data, true)
            if(temp_path == nil)then
                return
            end

            local texture_file = string.format(get_content("mods/evaisa.arena/files/gfx/skins/player.xml"), temp_path)
            local texture_file_name = "data/evaisa.arena/cache/skin_"..tostring(user).."_"..path_name..".xml"
            set_content(texture_file_name, texture_file)

            local texture_file_arm = string.format(get_content("mods/evaisa.arena/files/gfx/skins/player_arm.xml"), arm_path)
            local texture_file_name_arm = "data/evaisa.arena/cache/skin_arm_"..tostring(user).."_"..path_name..".xml"
            set_content(texture_file_name_arm, texture_file_arm)
            
            local comp = EntityGetFirstComponentIncludingDisabled(entity, "SpriteComponent", "skin_root")
            if(comp)then
                ComponentSetValue2(comp, "image_file", texture_file_name)
            end

            local children = EntityGetAllChildren(entity) or {}
            for i, child in ipairs(children)do
                if(EntityHasTag(child, "player_arm_r"))then
                    local comp = EntityGetFirstComponent(child, "SpriteComponent")
                    if(comp)then
                        ComponentSetValue2(comp, "image_file", texture_file_name_arm)
                    end
                end
            end

            self.last_player_skins[tostring(user)] = {path = temp_path, xml_path = texture_file_name, arm_path = arm_path, arm_xml_path = texture_file_name_arm}
            
        elseif(self.last_player_skins["self"])then
            local comp = EntityGetFirstComponentIncludingDisabled(entity, "SpriteComponent", "skin_root")
            if(comp)then
                ComponentSetValue2(comp, "image_file", self.last_player_skins["self"].xml_path)
            end

            local children = EntityGetAllChildren(entity) or {}
            for i, child in ipairs(children)do
                if(EntityHasTag(child, "player_arm_r"))then
                    local comp = EntityGetFirstComponent(child, "SpriteComponent")
                    if(comp)then
                        ComponentSetValue2(comp, "image_file", self.last_player_skins["self"].arm_xml_path)
                    end
                end
            end
            
           
        end
    end

    self.apply_skin = function(lobby)
        if self.last_player_skins["self"] then
            -- remove old skin
            local old_skin_path = self.last_player_skins["self"].path
            fs.remove(old_skin_path)

            local old_skin_path_arm = self.last_player_skins["self"].arm_path
            fs.remove(old_skin_path_arm)
        end

        print("Applying skin to self")

        -- generate skin
        local temp_path, arm_path, file_name = self.generate_skin(self.last_file_name)

        if(temp_path == nil)then
            print("Invalid skin detected.")
            return
        end

        -- read last file name path data
        local file = io.open(self.last_file_name, "rb")
        local data = file:read("*all")
        file:close()

        if(data and data ~= "")then
            -- write data to user data
            self.active_skin_data = data
            networking.send.send_skin(lobby, data)
        end

        local texture_file = string.format(get_content("mods/evaisa.arena/files/gfx/skins/player.xml"), temp_path)
        local texture_file_name = "data/evaisa.arena/cache/skin_self_"..file_name..".xml"
        set_content(texture_file_name, texture_file)

        local texture_file_arm = string.format(get_content("mods/evaisa.arena/files/gfx/skins/player_arm.xml"), arm_path)
        local texture_file_name_arm = "data/evaisa.arena/cache/skin_arm_self_"..file_name..".xml"
        set_content(texture_file_name_arm, texture_file_arm)

        local players = EntityGetWithTag("player_unit")
        for i, player in ipairs(players)do
            local comp = EntityGetFirstComponentIncludingDisabled(player, "SpriteComponent", "skin_root")
            if(comp)then
                ComponentSetValue2(comp, "image_file", texture_file_name)
            end

            local children = EntityGetAllChildren(player) or {}
            for i, child in ipairs(children)do
                if(EntityHasTag(child, "player_arm_r"))then
                    local comp = EntityGetFirstComponent(child, "SpriteComponent")
                    if(comp)then
                        ComponentSetValue2(comp, "image_file", texture_file_name_arm)
                    end
                end
            end
        end

        self.last_player_skins["self"] = {path = temp_path, xml_path = texture_file_name, arm_path = arm_path, arm_xml_path = texture_file_name_arm}


    end

    return self
end

return skins
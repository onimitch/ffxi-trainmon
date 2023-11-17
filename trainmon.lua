addon.name      = 'trainmon';
addon.author    = 'onimitch';
addon.version   = '1.0';
addon.desc      = 'Tracks training monster kill counts and displays them onscreen.';
addon.link      = '';

require('common')
local chat = require('chat')
local fonts = require('fonts')
local settings = require('settings')
local imgui = require('imgui')
-- local scaling = require('scaling')

local ffi = require("ffi")
local d3d = require('d3d8')
local C = ffi.C
local d3d8dev = d3d.get_device()

local config_jp = require('rules_jp')
local config_en = require('rules_en')


-- local function print_char_codes(str)
--     local char_codes = ''
--     str:gsub('.', function(ch)
--         char_codes = char_codes .. string.byte(ch) .. '|'
--     end)
--     print(chat.header(addon.name):append(chat.message(string.format('Char code for "%s" = %s', str, char_codes))))
-- end

local function on_load_callback()
    -- print_char_codes('、')
end


-- Non persistent Data
local trainmon = T{
    lang = 1, -- 1 = English, 2 = Japanese
    loaded = false,

    rules = {
        config_en.rules,
        config_jp.rules,
    },
    tests = {
        config_en.test_commands,
        config_jp.test_commands,
    },

    target_monsters = {},
    target_zone_id = {},

    target_monsters_options = {},
    target_monsters_repeat = {},
    last_target_count = 0,
    last_target_total = 0,

    player_job_main = nil,
    player_job_sub = nil,
    player_zone_id = -1,

    waiting_zone_confirmation = false,
    
    processing_message = false,
};

-- Persistant Data
local train_data = {}
local train_data_defaults = T{
    target_monsters = {},
    target_zone_id = -1,
}

-- local screen = T{
--     width = scaling.window.w,
--     height = scaling.window.h,
--     center_x = scaling.window.w / 2,
--     center_y = scaling.window.h / 2,
-- };

-- Settings
local user_settings = {}
local default_settings = T{
    icon_scale = 20,
    entry_icon_scale = 12,
    window_width = 200,

    title = T{
        visible = true,
        locked = true,
        font_family = 'Consolas',  -- Default font family
        font_height = 15,  -- Default font height
        color = 0xFFFFFF99,  -- Default text color
        color_outline = 0xFF000000,  -- Default text outline color
        draw_flags = 0x10,
        padding = 0.1,  -- Default text padding
        bold = true,  -- Default bold text setting
        italic = false,  -- Default italic text setting
        background = T{
            visible = false,  -- Whether the background is visible
            color = 0x80000000,  -- Background color
        },
    },
    entry = T{
        visible = true,
        locked = true,
        font_family = 'Consolas',  -- Default font family
        font_height = 12,  -- Default font height
        color = 0xFFFFFFFF,  -- Default text color
        color_outline = 0xFF000000,  -- Default text outline color
        draw_flags = 0x10,
        padding = 0.1,  -- Default text padding
        bold = true,  -- Default bold text setting
        italic = false,  -- Default italic text setting
        background = T{
            visible = false,  -- Whether the background is visible
            color = 0x80000000,  -- Background color
        },
    },
    entry_count = T{
        visible = true,
        locked = true,
        font_family = 'Consolas',  -- Default font family
        font_height = 12,  -- Default font height
        color = 0xFFFFFFFF,  -- Default text color
        color_outline = 0xFF000000,  -- Default text outline color
        draw_flags = 0x10,
        padding = 0.1,  -- Default text padding
        bold = true,  -- Default bold text setting
        italic = false,  -- Default italic text setting
        right_justified = false,
        background = T{
            visible = false,  -- Whether the background is visible
            color = 0x80000000,  -- Background color
        },
    },
};

-- UI objects
local trainmon_ui = T{
    title_text = {},
    row_entries = {},
    icon_texture = nil,
    icon_texture_data = nil,
    entry_texture = nil,
    entry_texture_data = nil,
};


local function load_texture(textureName)
    local textures = T{}
    -- Load the texture for usage..
    local texture_ptr = ffi.new('IDirect3DTexture8*[1]')
    local res = C.D3DXCreateTextureFromFileA(d3d8dev, string.format('%s/assets/%s.png', addon.path, textureName), texture_ptr)
    if (res ~= C.S_OK) then
--      error(('Failed to load image texture: %08X (%s)'):fmt(res, d3d.get_error(res)));
        return nil
    end
    textures.image = ffi.new('IDirect3DTexture8*', texture_ptr[0])
    d3d.gc_safe_release(textures.image)

    return textures
end


-- local function split_string(inputstr, sep)
--     if sep == nil then
--        sep = "%s"
--     end

--     local t={}
--     for str in string.gmatch(inputstr, '([^'..sep..']+)') do
--        table.insert(t, str)
--     end
--     -- if #t == 0 then
--     --     table.insert(t, inputstr)
--     -- end
--     return t
-- end

local function reset_training_data()
    trainmon.target_monsters = {}
    trainmon.target_monsters_repeat = {}
    trainmon.target_monsters_options = {}
    trainmon.target_zone_id = -1
    trainmon.last_target_count = 0
    trainmon.last_target_total = 0
end

local function load_training_data()
    reset_training_data()
    train_data.settings = settings.load(train_data_defaults, 'training_data')
    trainmon.target_monsters = train_data.settings.target_monsters
    trainmon.target_zone_id = tonumber(train_data.settings.target_zone_id)
end

local function save_train_data()
    train_data.settings.target_monsters = trainmon.target_monsters
    train_data.settings.target_zone_id = trainmon.target_zone_id
    settings.save('training_data')
end

local function _process_incoming_message(str)
    if string.find(str, 'trainmon', 1, true) then
        return
    end

    local rules = trainmon.rules[trainmon.lang]

    -- Confirming training
    if string.find(str, rules.confirmed) then
        for monster_index, monster_name, count, total in string.gmatch(str, rules.confirmed) do
            -- print(chat.header(addon.name):append(chat.message(string.format('confirmed: %d, %s (%d/%d)', monster_index, monster_name, count, total))))
            
            if monster_index == 1 then
                -- Don't lose zone_id when we reset, because confirming can happen in another zone
                local zone_id = trainmon.target_zone_id
                reset_training_data()
                trainmon.target_zone_id = zone_id
            end

            local is_family = string.find(monster_name, rules.monster_family, 1, true) ~= nil

            trainmon.target_monsters[tonumber(monster_index)] = {
                name = monster_name,
                count = tonumber(count),
                total = tonumber(total),
                is_family = is_family
            };
            save_train_data()
        end

        trainmon.waiting_zone_confirmation = true
        return
    end

    -- Confirming zone
    if trainmon.waiting_zone_confirmation and string.find(str, rules.confirmed_zone) then
        local zone_name = string.match(str, rules.confirmed_zone)
        local zone_id = AshitaCore:GetResourceManager():GetString("zones.names", zone_name)
        if zone_id ~= -1 then
            -- print(chat.header(addon.name):append(chat.message(string.format('Training zone: %s (%d)', zone_name, zone_id))))
            trainmon.target_zone_id = zone_id
            save_train_data()
            trainmon.waiting_zone_confirmation = false
        end
        return
    end

    -- Viewing training options
    if string.find(str, rules.options) then
        for monster_index, monster_name, total in string.gmatch(str, rules.options) do
            -- print(chat.header(addon.name):append(chat.message(string.format('options: %d, %s (%d)', monster_index, monster_name, total))))
            if monster_index == 1 then
                reset_training_data()
            end

            local is_family = string.find(monster_name, rules.monster_family, 1, true) ~= nil

            trainmon.target_monsters_options[tonumber(monster_index)] = {
                name = monster_name,
                count = 0,
                total = tonumber(total),
                is_family = is_family
            };
        end

        trainmon.waiting_zone_confirmation = false
        return
    end

    -- User accepted the last viewed training options
    if string.find(str, rules.accepted, 1, true) then
        if #trainmon.target_monsters_options > 0 then
            -- Use the last options we parsed
            trainmon.target_monsters = trainmon.target_monsters_options
            trainmon.target_monsters_options = {}
            trainmon.target_zone_id = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
            save_train_data()
        end
        return
    end

    -- Training was cancelled
    if string.find(str, rules.cancelled, 1, true) then
        reset_training_data()
        save_train_data()
        return
    end


    -- Active Training
    if #trainmon.target_monsters > 0 then
        
        -- A target monster was killed. We don't know what the monster is yet, so make a note of the totals
        if string.find(str, rules.target_monster_killed) then
            local count, total = string.match(str, rules.target_monster_killed)
            trainmon.last_target_count = tonumber(count)
            trainmon.last_target_total = tonumber(total)
            return
        end
        
        -- Monster killed, if this happens after a target_monster_killed message then we link them together
        local killed_by, monster_name = string.match(str, rules.monster_killed_by)
        if monster_name == nil then
            monster_name = string.match(str, rules.monster_killed)
        end
        if monster_name ~= nil then
            if trainmon.last_target_total == 0 then
                return
            end

            -- print(chat.header(addon.name):append(chat.message('Monster killed "%s" by "%s"')):fmt(monster_name, killed_by))

            -- Monster has now been killed, so get the monster name and link it to the last count update
            local total = trainmon.last_target_total
            local count = trainmon.last_target_count
            local expected_count = count - 1

            -- Find the target monster in our list
            local monster_index = 0;
            for i, v in ipairs(trainmon.target_monsters) do
                if v.name == monster_name then
                    monster_index = i
                    break
                end
            end

            -- If we didn't find the monster name, it might be a family of monsters
            -- For now we fall back to match by total & expected_count on a family
            -- The better way to do this would be to have a table that maps monster names to family of monsters
            if monster_index == 0 then
                for i, v in ipairs(trainmon.target_monsters) do
                    if v.is_family and v.total == total and v.count == expected_count then
                        monster_index = i
                        break
                    end
                end
            end

            -- Still no luck matching family, so search without is_family
            if monster_index == 0 then
                print(chat.header(addon.name):append(chat.message('Failed to find Monster family "%s" (%d/%d)')):fmt(monster_name, count, total))
                for i, v in ipairs(trainmon.target_monsters) do
                    if v.total == total and v.count == expected_count then
                        monster_index = i
                        break
                    end
                end
            end

            if monster_index == 0 then
                print(chat.header(addon.name):append(chat.error('Failed to find Monster in Training Data "%s" (%d/%d)')):fmt(monster_name, count, total))
                trainmon.last_target_count = 0
                trainmon.last_target_total = 0
                return
            end

            trainmon.target_monsters[monster_index].count = count
            trainmon.last_target_count = 0
            trainmon.last_target_total = 0
            save_train_data()
            return
        end

        -- A training was just completed
        if string.find(str, rules.completed, 1, true) then
            -- Reset the counts
            for i,v in ipairs(trainmon.target_monsters) do
                v.count = 0
            end

            -- Make a copy of the target_monsters incase we repeat the training
            trainmon.target_monsters_repeat = trainmon.target_monsters
            -- Clear training data
            trainmon.target_monsters = {}
            save_train_data()
            return
        end

        -- Training was repeated
        if string.find(str, rules.repeated, 1, true) then
            trainmon.target_monsters = trainmon.target_monsters_repeat
            trainmon.target_monsters_repeat = {}
            save_train_data()
            return
        end
    end
end

local function process_incoming_message(str)
    if not trainmon.processing_message then
        trainmon.processing_message = true
        
        _process_incoming_message(str)

        trainmon.processing_message = false
    end
end

local function set_text_visible(visible, num_rows)
    trainmon_ui.title_text.visible = visible
    num_rows = num_rows or #trainmon_ui.row_entries
    for i,v in ipairs(trainmon_ui.row_entries) do
        local entry_visible = visible and i <= num_rows
        v.name.visible = entry_visible
        v.count.visible = entry_visible
    end
end

-- Display the latest training status
local function draw_window()

    if #trainmon.target_monsters == 0 or trainmon.target_zone_id ~= trainmon.player_zone_id then
        set_text_visible(false)
    else
        imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always)
        local windowFlags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoBringToFrontOnFocus)
        -- if (gConfig.lockPositions) then
        -- 	windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove);
        -- end

        if (imgui.Begin('TrainMon', true, windowFlags)) then
            local icon_scale = user_settings.settings.icon_scale
            local entry_icon_scale = user_settings.settings.entry_icon_scale
            local entry_name_font = user_settings.settings.entry
            local entry_count_font = user_settings.settings.entry_count
            
            local cursor_x, cursor_y = imgui.GetCursorScreenPos()
            imgui.Image(trainmon_ui.icon_texture_data, { icon_scale, icon_scale })

            trainmon_ui.title_text.text = string.format('Training %s\n', AshitaCore:GetResourceManager():GetString("zones.names", trainmon.target_zone_id))
            trainmon_ui.title_text.position_x = cursor_x + icon_scale + 5
            trainmon_ui.title_text.position_y = cursor_y - 4

            local w, h = trainmon_ui.title_text:get_text_size()

            -- Draw rows
            local offsetY = h / 2
            local col1X = icon_scale + 5
            local col2X = user_settings.settings.window_width
            for i,v in ipairs(trainmon.target_monsters) do
                -- Do we have a entry already?
                local entry = trainmon_ui.row_entries[i]
                if entry == nil then
                    entry = {}
                    entry.name = fonts.new(entry_name_font)
                    entry.count = fonts.new(entry_count_font)
                    trainmon_ui.row_entries[i] = entry
                end

                imgui.SetCursorScreenPos({cursor_x + entry_icon_scale / 2, cursor_y + offsetY + entry_icon_scale / 2})
                imgui.Image(trainmon_ui.entry_texture_data, { entry_icon_scale, entry_icon_scale })

                entry.name.text = v.name
                entry.name.position_x = cursor_x + col1X
                entry.name.position_y = cursor_y + offsetY

                entry.count.text = string.format('(%d/%d)', v.count, v.total)
                entry.count.position_x = cursor_x + col2X
                entry.count.position_y = cursor_y + offsetY
                
                w, h = entry.name:get_text_size()
                offsetY = offsetY + h
            end

            set_text_visible(true, #trainmon.target_monsters)
        end
        imgui.End()
    end
end


--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or args[1] ~= '/tmon') then
        return;
    end

    -- Block all tmon related commands..
    e.blocked = true;

    -- Handle: /tmon test commands

    if (#args == 2 and args[2]:any('st')) then
        if #trainmon.target_monsters == 0 then
            print(chat.header(addon.name):append(chat.message('No training data')))
        else
            local zone_name = AshitaCore:GetResourceManager():GetString("zones.names", trainmon.target_zone_id)
            local player_zone_name = AshitaCore:GetResourceManager():GetString("zones.names", trainmon.player_zone_id)
            print(chat.header(addon.name):append(chat.message(string.format('Training in: %s (Player zone: %s)', zone_name, player_zone_name))))
            
            local current_status = ''
            for i,v in ipairs(trainmon.target_monsters) do
                current_status = current_status .. string.format('%d: %s (%d/%d)', i, v.name, v.count, v.total)
                if i < #trainmon.target_monsters then
                    current_status = current_status .. '\n'
                end
            end
            print(chat.header(addon.name):append(chat.message(current_status)))
        end
    end

    if (#args == 2 and args[2]:any('reset')) then
        reset_training_data()
        save_train_data()
        return;
    end


    -- TESTING COMMANDS

    local test_commands = trainmon.tests[trainmon.lang]

    if (#args == 2 and args[2]:any('options')) then
        process_incoming_message(test_commands.options)
        return;
    end

    if (#args == 2 and args[2]:any('accepted')) then
        process_incoming_message(test_commands.accepted)
        return;
    end

    if (#args == 2 and args[2]:any('confirmed')) then
        trainmon.target_zone_id = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
        process_incoming_message(test_commands.confirmed)
        return;
    end

    if (#args == 2 and args[2]:any('cancelled')) then
        process_incoming_message(test_commands.cancelled)
        return;
    end

    if (#args == 2 and args[2]:any('killed')) then
        process_incoming_message(test_commands.target_monster_killed)
        process_incoming_message(test_commands.monster_killed_by)
        return;
    end

    if (#args == 2 and args[2]:any('completed')) then
        process_incoming_message(test_commands.completed)
        return;
    end

    if (#args == 2 and args[2]:any('repeated')) then
        process_incoming_message(test_commands.repeated)
        return;
    end
end)

--[[
* event: load
* desc : Event called when the addon is being loaded.
--]]
ashita.events.register('load', 'load_cb', function()
    -- Load User settings
    user_settings.settings = default_settings --settings.load(default_settings)

    -- Load Training data
    load_training_data()

    -- Get language
    local lang = AshitaCore:GetConfigurationManager():GetInt32('boot', 'ashita.language', 'playonline', 2)
    if lang == 1 then
        trainmon.lang = 2
    else
        trainmon.lang = 1
    end

    -- Init data
    trainmon.player_job_main = 0
    trainmon.player_job_sub = 0
    trainmon.player_zone_id = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
    trainmon.processing_message = false

    -- Init UI
    trainmon_ui.title_text = fonts.new(user_settings.settings.title)
    trainmon_ui.icon_texture = load_texture("Cursor")
    trainmon_ui.icon_texture_data = tonumber(ffi.cast("uint32_t", trainmon_ui.icon_texture.image))
    trainmon_ui.entry_texture = load_texture("Range")
    trainmon_ui.entry_texture_data = tonumber(ffi.cast("uint32_t", trainmon_ui.entry_texture.image))

    trainmon.loaded = true

    on_load_callback()
end)

--[[
* event: packet_in
* desc : Event called when the addon is processing incoming packets.
--]]
ashita.events.register('packet_in', 'packet_in_cb', function(event)
    -- Zone change packet
    if event.id == 0x0A then
        trainmon.player_zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    end
end)

--[[
* event: text_in
* desc : Event called when the addon is processing incoming text.
--]]
ashita.events.register('text_in', 'text_in_cb', function (e)
    if trainmon.loaded then
        process_incoming_message(e.message_modified)
    end
end)

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb', function()
    -- Check if player's job changed, then training will be reset
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    local job_main = player:GetMainJob()
    local job_sub = player:GetSubJob()

    -- If we've got training data, make sure the player_zone_id is up to date
    -- For now this is a workaround, as the zone change packet isn't always picking up a change of zone
    trainmon.player_zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)

    if job_main ~= 0 then
        if trainmon.player_job_main == 0 then
            -- Load inital player job so we can keep track of when it changes
            trainmon.player_job_main = job_main
            trainmon.player_job_sub = job_sub
            --print(chat.header(addon.name):append(chat.message(string.format('Job data: %d %d', job_main, job_sub))))
        elseif trainmon.player_job_main ~= job_main or trainmon.player_job_sub ~= job_sub then
            trainmon.player_job_main = job_main
            trainmon.player_job_sub = job_sub
            print(chat.header(addon.name):append(chat.message('Job changed, resetting training data')))
            reset_training_data()
        end

        draw_window()
    end
end)

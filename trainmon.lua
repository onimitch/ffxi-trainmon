addon.name      = 'trainmon'
addon.author    = 'onimitch'
addon.version   = '1.0'
addon.desc      = 'Tracks training monster kill counts and displays them onscreen.'
addon.link      = 'https://github.com/onimitch/ffxi-trainmon'

require('common')
local chat = require('chat')
local settings = require('settings')
local imgui = require('imgui')
local gdi = require('gdifonts.include')
local encoding = require('gdifonts.encoding')

local ffi = require("ffi")
local d3d = require('d3d8')
local C = ffi.C
local d3d8dev = d3d.get_device()

local config_jp = require('rules_jp')
local config_en = require('rules_en')


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

    settings = {},
    default_settings = T{
        icon_scale = 20,
        entry_icon_scale = 12,
        window_width = 200,
    
        title = T{
            font_alignment = gdi.Alignment.Left,
            font_color = 0xFFFFFF99,
            font_family = 'Consolas',
            font_flags = gdi.FontFlags.Bold,
            font_height = 20,
            outline_color = 0xFF000000,
            outline_width = 2,
        },
        entry = T{
            font_alignment = gdi.Alignment.Left,
            font_color = 0xFFFFFFFF,
            font_family = 'Consolas',
            font_flags = gdi.FontFlags.Bold,
            font_height = 16,
            outline_color = 0xFF000000,
            outline_width = 2,
        },
        entry_count = T{
            font_alignment = gdi.Alignment.Left,
            font_color = 0xFFFFFFFF,
            font_family = 'Consolas',
            font_flags = gdi.FontFlags.Bold,
            font_height = 16,
            outline_color = 0xFF000000,
            outline_width = 2,
        },
    },
}

-- Persistant Data
local train_data = {}
local train_data_defaults = T{
    target_monsters = {},
    target_zone_id = -1,
}

-- UI objects
local trainmon_ui = T{
    title_text = nil,
    row_entries = {},
    icon_texture = nil,
    icon_texture_data = nil,
    entry_texture = nil,
    entry_texture_data = nil,
}

local function load_texture(textureName)
    local textures = T{}
    -- Load the texture for usage..
    local texture_ptr = ffi.new('IDirect3DTexture8*[1]')
    local res = C.D3DXCreateTextureFromFileA(d3d8dev, string.format('%s/assets/%s.png', addon.path, textureName), texture_ptr)
    if (res ~= C.S_OK) then
--      error(('Failed to load image texture: %08X (%s)'):fmt(res, d3d.get_error(res)))
        return nil
    end
    textures.image = d3d.gc_safe_release(ffi.new('IDirect3DTexture8*', texture_ptr[0]))
    return textures
end

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
            }
            save_train_data()
        end

        trainmon.waiting_zone_confirmation = true
        return
    end

    -- Confirming zone
    if trainmon.waiting_zone_confirmation and string.find(str, rules.confirmed_zone) then
        local zone_name = string.match(str, rules.confirmed_zone)
        local zone_id = AshitaCore:GetResourceManager():GetString('zones.names', zone_name)
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
            }
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
            local monster_index = 0
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
    trainmon_ui.title_text:set_visible(visible)
    num_rows = num_rows or #trainmon_ui.row_entries
    for i,v in ipairs(trainmon_ui.row_entries) do
        local entry_visible = visible and i <= num_rows
        v.name:set_visible(entry_visible)
        v.count:set_visible(entry_visible)
    end
end

-- Display the latest training status
local function draw_window()
    if #trainmon.target_monsters == 0 or trainmon.target_zone_id ~= trainmon.player_zone_id then
        set_text_visible(false)
        return
    end

    imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always)
    local windowFlags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoBringToFrontOnFocus)
    -- if (gConfig.lockPositions) then
    -- 	windowFlags = bit.bor(windowFlags, ImGuiWindowFlags_NoMove)
    -- end

    if (imgui.Begin('TrainMon', true, windowFlags)) then
        local icon_scale = trainmon.settings.icon_scale
        local entry_icon_scale = trainmon.settings.entry_icon_scale
        local entry_name_font = trainmon.settings.entry
        local entry_count_font = trainmon.settings.entry_count
        
        local cursor_x, cursor_y = imgui.GetCursorScreenPos()
        imgui.Image(trainmon_ui.icon_texture_data, { icon_scale, icon_scale })
        
        local zone_name = encoding:ShiftJIS_To_UTF8(AshitaCore:GetResourceManager():GetString('zones.names', trainmon.target_zone_id), true)
        trainmon_ui.title_text:set_text(zone_name) --string.format('Training %s', zone_name))
        local w, h = trainmon_ui.title_text:get_text_size()

        trainmon_ui.title_text:set_position_x(cursor_x + icon_scale + 5)
        trainmon_ui.title_text:set_position_y(cursor_y - 2)

        -- Draw rows
        local rowSpacing = entry_icon_scale / 1
        local offsetY = h + rowSpacing / 2
        local col1X = icon_scale + 5
        local col2X = trainmon.settings.window_width
        for i,v in ipairs(trainmon.target_monsters) do
            -- Do we have a entry already?
            local entry = trainmon_ui.row_entries[i]
            if entry == nil then
                entry = {}
                entry.name = gdi:create_object(entry_name_font)
                entry.count = gdi:create_object(entry_count_font)
                trainmon_ui.row_entries[i] = entry
            end

            entry.name:set_text(encoding:ShiftJIS_To_UTF8(v.name, true))
            entry.count:set_text(string.format('(%d/%d)', v.count, v.total))
            w, h = entry.name:get_text_size()

            imgui.SetCursorScreenPos({cursor_x + entry_icon_scale / 2, cursor_y + offsetY + 2})
            imgui.Image(trainmon_ui.entry_texture_data, { entry_icon_scale, entry_icon_scale })

            entry.name:set_position_x(cursor_x + col1X)
            entry.name:set_position_y(cursor_y + offsetY)
            
            entry.count:set_position_x(cursor_x + col2X)
            entry.count:set_position_y(cursor_y + offsetY)
            
            offsetY = offsetY + entry_icon_scale + rowSpacing
        end

        set_text_visible(true, #trainmon.target_monsters)
    end
    imgui.End()
end

local function initialise_ui()
    -- Image textures
    -- TODO: Replace texture_data and just render Sprites instead rather than using IMGUI (req: support our own drag to move window)
    trainmon_ui.icon_texture = load_texture('Cursor')
    trainmon_ui.icon_texture_data = tonumber(ffi.cast('uint32_t', trainmon_ui.icon_texture.image))
    trainmon_ui.entry_texture = load_texture('Range')
    trainmon_ui.entry_texture_data = tonumber(ffi.cast('uint32_t', trainmon_ui.entry_texture.image))

    -- Text
    if trainmon_ui.title_text ~= nil then
        gdi:destroy_object(trainmon_ui.title_text)
    end
    trainmon_ui.title_text = gdi:create_object(trainmon.settings.title)

    -- Clear out old font objects
    for i,v in ipairs(trainmon_ui.row_entries) do
        if v ~= nil then
            gdi:destroy_object(v.name)
            gdi:destroy_object(v.count)
        end
    end
    trainmon_ui.row_entries = {}
end


--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'trainmon_command', function (e)
    -- Parse the command arguments..
    local args = e.command:args()
    if (#args == 0 or args[1] ~= '/tmon' and args[1] ~= '/trainmon') then
        return
    end

    -- Block all tmon related commands..
    e.blocked = true

    -- Handle: /tmon (st | status)
    if (#args == 2 and args[2]:any('st', 'status')) then
        if #trainmon.target_monsters == 0 then
            print(chat.header(addon.name):append(chat.message('No training data')))
        else
            local zone_name = AshitaCore:GetResourceManager():GetString('zones.names', trainmon.target_zone_id)
            local player_zone_name = AshitaCore:GetResourceManager():GetString('zones.names', trainmon.player_zone_id)
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

    -- Handle: /tmon reset
    if (#args == 2 and args[2]:any('reset')) then
        reset_training_data()
        save_train_data()
        return
    end

    -- Handle: /tmon test commands
    local test_commands = trainmon.tests[trainmon.lang]

    if (#args == 2 and args[2]:any('options')) then
        process_incoming_message(test_commands.options)
        return
    end

    if (#args == 2 and args[2]:any('accepted')) then
        process_incoming_message(test_commands.accepted)
        return
    end

    if (#args == 2 and args[2]:any('confirmed')) then
        trainmon.target_zone_id = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
        process_incoming_message(test_commands.confirmed)
        return
    end

    if (#args == 2 and args[2]:any('cancelled')) then
        process_incoming_message(test_commands.cancelled)
        return
    end

    if (#args == 2 and args[2]:any('killed')) then
        process_incoming_message(test_commands.target_monster_killed)
        process_incoming_message(test_commands.monster_killed_by)
        return
    end

    if (#args == 2 and args[2]:any('completed')) then
        process_incoming_message(test_commands.completed)
        return
    end

    if (#args == 2 and args[2]:any('repeated')) then
        process_incoming_message(test_commands.repeated)
        return
    end
end)

--[[
* event: load
* desc : Event called when the addon is being loaded.
--]]
ashita.events.register('load', 'trainmon_load', function()
    -- Load User settings
    trainmon.settings = settings.load(trainmon.default_settings)

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
    initialise_ui()

    trainmon.loaded = true
    print('trainmon loaded')
end)

ashita.events.register('unload', 'trainmon_unload', function ()
    print("trainmon unloaded")
    gdi:destroy_interface()
end)

--[[
* event: packet_in
* desc : Event called when the addon is processing incoming packets.
--]]
ashita.events.register('packet_in', 'trainmon_packet_in', function(event)
    -- Zone change packet
    if event.id == 0x0A then
        trainmon.player_zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    end
end)

--[[
* event: text_in
* desc : Event called when the addon is processing incoming text.
--]]
ashita.events.register('text_in', 'trainmon_text_in', function (e)
    if trainmon.loaded then
        process_incoming_message(e.message_modified)
    end
end)

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'trainmon_present', function()
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

local function update_settings(s)
    if (s ~= nil) then
        trainmon.settings = s
    end
    settings.save()
    initialise_ui()
end

-- Registers a callback for the settings to monitor for character switches.
settings.register('settings', 'settings_update', update_settings)

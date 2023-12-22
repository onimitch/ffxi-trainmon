addon.name      = 'trainmon'
addon.author    = 'onimitch'
addon.version   = '1.2'
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

local monitor = require('monitor')
local chat_modes = require('chat_modes')

local module_path = debug.getinfo(1, 'S').source:sub(2)
local trainmon_tests_file = string.gsub(module_path, 'trainmon%.lua', 'test/tests.lua')
local test_runner = ashita.fs.exists(trainmon_tests_file) and require('test.tests') or nil


local trainmon = T{
    monitor = nil,
    processing_message = false,

    player_job_main = nil,
    player_job_sub = nil,
    player_zone_id = -1,

    settings = {},
    default_settings = T{
        visible = true,
        always_show = false,

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

-- UI objects
local trainmon_ui = T{
    title_text = nil,
    row_entries = {},
    icon_texture = nil,
    icon_texture_data = nil,
    entry_texture = nil,
    entry_texture_data = nil,
}

local function print_shiftjis(message)
    local encoded_message = encoding:UTF8_To_ShiftJIS(message)
    print(encoded_message)
end

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

local function process_incoming_message(mode, message)
    -- We can straight up ignore any message which isn't in the modes we look for
    if not chat_modes:any(function (v) return v == mode end) then
        return
    end

    if not trainmon.processing_message then
        trainmon.processing_message = true

        -- Monitor deals with UTF8
        local message_utf8 = encoding:ShiftJIS_To_UTF8(message)
        trainmon.monitor:process_input(mode, message_utf8)

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
    local visible = #trainmon.monitor._target_monsters > 0
    visible = visible and trainmon.settings.visible
    visible = visible and (trainmon.settings.always_show or trainmon.monitor._target_zone_id == trainmon.player_zone_id)
    if not visible then
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

        local zone_name = encoding:ShiftJIS_To_UTF8(AshitaCore:GetResourceManager():GetString('zones.names', trainmon.monitor._target_zone_id), true)
        trainmon_ui.title_text:set_text(zone_name)
        local w, h = trainmon_ui.title_text:get_text_size()

        trainmon_ui.title_text:set_position_x(cursor_x + icon_scale + 5)
        trainmon_ui.title_text:set_position_y(cursor_y - 2)

        -- Draw rows
        local rowSpacing = entry_icon_scale / 1
        local offsetY = h + rowSpacing / 2
        local col1X = icon_scale + 5
        local col2X = 0
        for i,v in ipairs(trainmon.monitor._target_monsters) do
            -- Do we have a entry already?
            local entry = trainmon_ui.row_entries[i]
            if entry == nil then
                entry = {}
                entry.name = gdi:create_object(entry_name_font)
                entry.count = gdi:create_object(entry_count_font)
                trainmon_ui.row_entries[i] = entry
            end

            entry.name:set_text(v.name)
            entry.count:set_text(string.format('(%d/%d)', v.count, v.total))
            -- w, h = entry.name:get_text_size()

            imgui.SetCursorScreenPos({cursor_x + entry_icon_scale / 2, cursor_y + offsetY + 2})
            imgui.Image(trainmon_ui.entry_texture_data, { entry_icon_scale, entry_icon_scale })

            entry.count:set_position_x(cursor_x + col1X)
            entry.count:set_position_y(cursor_y + offsetY)

            if col2X == 0 then
                local countW, countH = entry.count:get_text_size()
                col2X = col1X + countW + 5
            end

            entry.name:set_position_x(cursor_x + col2X)
            entry.name:set_position_y(cursor_y + offsetY)

            offsetY = offsetY + entry_icon_scale + rowSpacing
        end

        set_text_visible(true, #trainmon.monitor._target_monsters)
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

local pGameMenu = ashita.memory.find('FFXiMain.dll', 0, "8B480C85C974??8B510885D274??3B05", 16, 0)
local pEventSystem = ashita.memory.find('FFXiMain.dll', 0, "A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3", 0, 0)
local pInterfaceHidden = ashita.memory.find('FFXiMain.dll', 0, "8B4424046A016A0050B9????????E8????????F6D81BC040C3", 0, 0)

local function get_game_menu_name()
    local subPointer = ashita.memory.read_uint32(pGameMenu)
    local subValue = ashita.memory.read_uint32(subPointer)
    if (subValue == 0) then
        return ''
    end
    local menuHeader = ashita.memory.read_uint32(subValue + 4)
    local menuName = ashita.memory.read_string(menuHeader + 0x46, 16)
    return string.gsub(menuName, '\x00', '')
end

local function is_event_system_active()
    if (pEventSystem == 0) then
        return false
    end
    local ptr = ashita.memory.read_uint32(pEventSystem + 1)
    if (ptr == 0) then
        return false
    end

    return (ashita.memory.read_uint8(ptr) == 1)
end

local function is_game_interface_hidden()
    if (pEventSystem == 0) then
        return false
    end
    local ptr = ashita.memory.read_uint32(pInterfaceHidden + 10)
    if (ptr == 0) then
        return false
    end

    return (ashita.memory.read_uint8(ptr + 0xB4) == 1)
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
        if #trainmon.monitor._target_monsters == 0 then
            print(chat.header(addon.name):append(chat.message('No training data')))
        else
            local zone_name = AshitaCore:GetResourceManager():GetString('zones.names', trainmon.monitor._target_zone_id)
            local player_zone_name = AshitaCore:GetResourceManager():GetString('zones.names', trainmon.player_zone_id)

            local current_status = string.format('Training in: %s\nCurrent zone: %s\n', zone_name, player_zone_name)
            for i,v in ipairs(trainmon.monitor._target_monsters) do
                current_status = current_status .. string.format('%d: %s (%d/%d)', i, v.name, v.count, v.total)
                if i < #trainmon.monitor._target_monsters then
                    current_status = current_status .. '\n'
                end
            end
            print(chat.header(addon.name):append(chat.message(current_status)))
        end
    end

    -- Handle: /tmon reset
    if (#args == 2 and args[2]:any('reset')) then
        trainmon.monitor:reset_training_data()
        trainmon.monitor:save_train_data()
        print(chat.header(addon.name):append(chat.message('Training data reset')))
        return
    end

    -- Handle: /tmon show <always>
    if (#args >= 2 and args[2]:any('show')) then
        trainmon.settings.visible = true
        trainmon.settings.always_show = #args >= 3 and args[3] == 'always'
        settings.save()
        return
    end

    -- Handle: /tmon hide
    if (#args == 2 and args[2]:any('hide')) then
        trainmon.settings.visible = false
        trainmon.settings.always_show = false
        settings.save()
        return
    end

    -- Handle: /tmon test
    if (#args == 2 and args[2]:any('test')) then
        if test_runner ~= nil then
            trainmon.processing_message = true
            print(chat.header(addon.name):append(chat.message('Running tests...')))
            test_runner()
            trainmon.processing_message = false
        end
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

    -- Get language and init monitor
    local lang = AshitaCore:GetConfigurationManager():GetInt32('boot', 'ashita.language', 'playonline', 2)
    if lang == 1 then
        trainmon.monitor = monitor:new('ja', print_shiftjis)
    else
        trainmon.monitor = monitor:new('en', print_shiftjis)
    end

    -- Init data
    trainmon.player_job_main = 0
    trainmon.player_job_sub = 0
    trainmon.player_zone_id = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
    trainmon.processing_message = false

    -- Init UI
    initialise_ui()

    print(chat.header(addon.name):append(chat.message('Loaded, language: ' .. trainmon.monitor._lang_code)))
end)

ashita.events.register('unload', 'trainmon_unload', function ()
    gdi:destroy_interface()
end)

--[[
* event: packet_in
* desc : Event called when the addon is processing incoming packets.
--]]
ashita.events.register('packet_in', 'trainmon_packet_in', function(event)
    -- Zone change packet
    if event.id == 0x0A then
        trainmon.player_zone_id = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
    end
end)

--[[
* event: text_in
* desc : Event called when the addon is processing incoming text.
--]]
ashita.events.register('text_in', 'trainmon_text_in', function (e)
    -- Ignore text in from Ashita addons/plugins
    if e.injected then
        return
    end

    local mode = bit.band(e.mode,  0x000000FF)
    process_incoming_message(mode, e.message)
end)

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'trainmon_present', function()
    -- Don't render until we have a player entity
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    local player_ent = GetPlayerEntity()
    if player == nil or player.isZoning or player_ent == nil then
		set_text_visible(false)
		return
	end
    -- Hide when map open
    if string.match(get_game_menu_name(), 'map') then
		set_text_visible(false)
		return
	end
    -- Hide if event active or interface hidden
    if is_game_interface_hidden() or is_event_system_active() then
		set_text_visible(false)
		return
	end

    local job_main = player:GetMainJob()
    local job_sub = player:GetSubJob()

    -- If we've got training data, make sure the player_zone_id is up to date
    -- For now this is a workaround, as the zone change packet isn't always picking up a change of zone
    trainmon.player_zone_id = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))

    if job_main ~= 0 then
        if trainmon.player_job_main == 0 then
            -- Load inital player job so we can keep track of when it changes
            trainmon.player_job_main = job_main
            trainmon.player_job_sub = job_sub
            --print(chat.header(addon.name):append(chat.message(string.format('Job data: %d %d', job_main, job_sub))))
        elseif trainmon.player_job_main ~= job_main or trainmon.player_job_sub ~= job_sub then
            trainmon.player_job_main = job_main
            trainmon.player_job_sub = job_sub
            -- print(chat.header(addon.name):append(chat.message('Job changed, training data reset')))
            trainmon.monitor:reset_training_data()
            trainmon.monitor:save_training_data()
        end

        draw_window()
    end
end)

local function update_settings(s)
    if (s ~= nil) then
        trainmon.settings = s
    end
    initialise_ui()
end

-- Registers a callback for the settings to monitor for character switches.
settings.register('settings', 'settings_update', update_settings)

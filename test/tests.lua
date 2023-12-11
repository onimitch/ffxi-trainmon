-- Detect if we're running inside Ashita env
local running_in_ashita = true
if addon == nil then
    running_in_ashita = false
    addon = {
        name = 'trainmon'
    }
end

-- Setup search paths
local module_path = debug.getinfo(1, 'S').source:sub(2)
local addons_root_dir = string.gsub(module_path, '[\\/]' .. addon.name .. '[\\/]test[\\/]tests%.lua', '/')

-- This dir
package.path = addons_root_dir .. addon.name .. '/test/?.lua' .. ';' .. package.path

-- Setup environment if we're not running in Ashita
if not running_in_ashita then
    -- Addon dir
    package.path = addons_root_dir .. addon.name .. '/?.lua' .. ';' .. package.path
    -- Add Ashita libs dir
    package.path = addons_root_dir .. 'libs/?.lua' .. ';' .. package.path

    require('ashita-env')
end


-- Define tests

require('common')
local chat = require('chat')
local monitor = require('monitor')
local ansicolors = require('ansicolors')
local monster_db = require('monster_db/db')
local encoding = require('gdifonts.encoding')

local test_output = {
    en = require('testdata_en'),
    ja = require('testdata_ja'),
}

local data = {}
local tests_to_run = {
    'parser',
    'init',
    'options',
    'confirmed',
    'cancelled',
    'killed',
    'killed_single_family',
    'killed_multiple_family_same_totals',
    'killed_multiple_family_diff_totals',
    'completed',
}

local function get_str_codes(str)
	return (str:gsub('.', function (c)
		return string.format('[%02X]', string.byte(c))
	end))
end

local log_color = {
    green = running_in_ashita and chat.colors.LawnGreen or ansicolors.green,
    red = running_in_ashita and chat.colors.Tomato or ansicolors.red,
    reset = running_in_ashita and chat.colors.Reset or ansicolors.reset,
    bright = running_in_ashita and '' or ansicolors.bright,
    black = running_in_ashita and chat.colors.Grey or ansicolors.black,
}

local function printenc(str)
    if running_in_ashita then
        local encoded_str = encoding:UTF8_To_ShiftJIS(str)
        print(encoded_str)
    else
        print(str)
    end
end

local function TEST(condition, title)
    local passOrFail = condition and 'PASS' or 'FAIL'
    local color = condition and log_color.green or log_color.red
    print(color .. 'TEST ' .. passOrFail .. ': ' .. title .. log_color.reset)
    return condition
end

local function print_target_monster_data(target_monsters)
    if target_monsters == 0 then
        print('No training data')
    else
        local current_status = ''
        for i,v in ipairs(target_monsters) do
            current_status = current_status .. string.format('%d: %s (%d/%d)', i, v.name, v.count, v.total)
            if i < #target_monsters then
                current_status = current_status .. '\n'
            end
        end
        printenc(current_status)
    end
end

local function present_training_options(data, input_monsters)
    data.mon:process_input(data.output.options_intro)

    local options_list = {}
    for i, v in ipairs(input_monsters) do
        table.append(options_list, data.output.options_entry(i, v.name, v.total)[2])
    end
    data.mon:process_input(data.output.options_intro[1], table.concat(options_list, '\r\n'))

    data.mon:process_input(data.output.options_outro)
end

local function present_confirmed_training_options(data, input_monsters)
    local options_list = {}
    for i, v in ipairs(input_monsters) do
        table.append(options_list, data.output.confirmed_entry(i, v.name, v.count, v.total)[2])
    end
    data.mon:process_input(data.output.confirmed_outro[1], table.concat(options_list, '\r\n'))

    data.mon:process_input(data.output.confirmed_outro)
    data.mon:process_input(data.output.confirmed_end)
end

local function kill_target(input_monsters, monster_index, increment)
    increment = increment or 1
    local killed_by = 'Tenzen'
    local input_monster = input_monsters[monster_index]
    local target_name = input_monster.target_name or input_monster.name
    -- We need to log a seperate entry for each kill, otherwise the monitor might miss information
    -- This is basically the same as it would appear in the game chat logs anyway
    for i=1,increment do
        local current_count = input_monster.count or 0
        local new_count = math.min(current_count + 1, input_monster.total)
        if new_count == input_monster.count then
            break -- already reached total kills
        end
        input_monster.count = new_count
        data.mon:process_input(data.output.target_monster_killed(input_monster.count, input_monster.total))
        data.mon:process_input(data.output.monster_killed_by(target_name, killed_by))
    end
end

local function TEST_KILL_COUNT(input_monsters, target_monsters, monster_index)
    local input_monster = input_monsters[monster_index]
    local target_name = input_monster.target_name or input_monster.name
    local monster = target_monsters[monster_index]
    local count_desc = (input_monster.count == monster.total) and 'all' or '1'
    TEST(monster.count == input_monster.count, 'Killed ' .. count_desc .. ' ' .. target_name .. ', count=' .. input_monster.count)
end

local tests = function(lang_code)
    return {
    init = function ()
        -- Reset data
        data = {}
        data.output = test_output[lang_code]
        data.mon = monitor:new(lang_code, printenc, encoding)

        -- Ensure windows terminal is displaying in utf-8
        if not running_in_ashita then
            os.execute('chcp 65001')
        end

        -- Create some monsters for us to use
        data.monsters = {}

        local monster_keys = {
            'goblin',
            'orc'
        }
        for _, key in ipairs(monster_keys) do
            table.insert(data.monsters, ({
                name = monster_db.families[key].monsters[1],
                family = monster_db.families[key][lang_code],
            }))
            printenc('Monster: ' .. data.monsters[#data.monsters].name .. ', Family: ' .. data.monsters[#data.monsters].family)
        end
    end,
    parser = function()
        -- print('String codes: ' .. get_str_codes('……'))
        -- print('String codes: ' .. get_str_codes('Goblin Thug……4'))
        -- print('String codes: ' .. get_str_codes('ゴブリン族……4'))

        -- -- local pattern = '討伐対象(%d)：([%a%A%s]+)……([%d]+)'
        -- local pattern = '討伐対象(%d)：(.+)……([%d]+)'
        -- -- local pattern = '討伐対象(%d)：([^…]+)……([%d]+)'

        -- local index, name, count = string.match('討伐対象1：Goblin Thug……4', pattern)
        -- print('Parse test 1: ' .. tostring(index) .. ', ' .. tostring(name) .. ', ' .. tostring(count))
        -- print('String codes 1: ' .. get_str_codes(name or ''))

        -- index, name, count = string.match('討伐対象2：ゴブリン族……4', pattern)
        -- print('Parse test 2: ' .. tostring(index) .. ', ' .. tostring(name) .. ', ' .. tostring(count))
        -- print('String codes 2: ' .. get_str_codes(name or ''))
        -- if name == 'ゴブリン族' then
        --     print('MATCH!')
        -- end

        local in_string_utf8 = 'Monster: Goblin Thug, Family: ゴブリン族'
        print('in_string_utf8: ' .. #in_string_utf8)
        local out_string_sjis = encoding:UTF8_To_ShiftJIS(in_string_utf8)
        print('out_string_sjis: ' .. #out_string_sjis)
        local out_string_utf8 = encoding:ShiftJIS_To_UTF8(out_string_sjis)
        print('out_string_utf8: ' .. #out_string_utf8)
    end,
    options = function ()
        -- Training options presented to the player
        local input_monsters = {
            { name = data.monsters[1].name, total = 4 },
            { name = data.monsters[2].name, total = 4 },
        }
        present_training_options(data, input_monsters)

        -- Player accepted the training
        data.mon:process_input(data.output.training_accepted)

        -- Check data matches
        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)
            print('--')
            for i, v in ipairs(input_monsters) do
                TEST(target_monsters[i].name == input_monsters[i].name, 'Target monster[' .. i .. '] name')
                TEST(target_monsters[i].total == input_monsters[i].total, 'Target monster[' .. i .. '] total')
            end
        end
    end,
    confirmed = function ()
        -- Confirmed training options presented to the player
        local input_monsters = {
            { name = data.monsters[1].name, count = 1, total = 4 },
            { name = data.monsters[2].name, count = 2, total = 4 },
        }
        present_confirmed_training_options(data, input_monsters)

        -- Check data matches
        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            for i, v in ipairs(input_monsters) do
                TEST(target_monsters[i].name == input_monsters[i].name, 'Target monster[' .. i .. '] name')
                TEST(target_monsters[i].count == input_monsters[i].count, 'Target monster[' .. i .. '] count')
                TEST(target_monsters[i].total == input_monsters[i].total, 'Target monster[' .. i .. '] total')
            end
        end
    end,
    cancelled = function ()
        data.mon:reset_training_data()

        local input_monsters = {
            { name = data.monsters[1].name, total = 4 },
            { name = data.monsters[2].name, total = 4 },
        }
        present_training_options(data, input_monsters)
        data.mon:process_input(data.output.training_accepted)

        local target_monsters = data.mon._target_monsters
        TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Before training cancelled monster count')

        data.mon:process_input(data.output.training_cancelled)

        -- Check data has been cleared
        target_monsters = data.mon._target_monsters
        TEST(target_monsters ~= nil and #target_monsters == 0, 'Training cancelled monster count is zero')
    end,
    killed = function ()
        data.mon:reset_training_data()

        local input_monsters = {
            { name = data.monsters[1].name, total = 4 },
            { name = data.monsters[2].name, total = 4 },
        }
        present_training_options(data, input_monsters)
        data.mon:process_input(data.output.training_accepted)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            -- Kill 1
            kill_target(input_monsters, 1)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            kill_target(input_monsters, 2)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            print_target_monster_data(target_monsters)

            -- Kill all
            kill_target(input_monsters, 1, 99)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            kill_target(input_monsters, 2, 99)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            print_target_monster_data(target_monsters)
        end
    end,
    killed_single_family = function ()
        data.mon:reset_training_data()

        local input_monsters = {
            { name = data.monsters[1].name, total = 4 },
            { name = data.monsters[2].family, total = 4, target_name = data.monsters[2].name },
        }
        present_training_options(data, input_monsters)
        data.mon:process_input(data.output.training_accepted)
        print_target_monster_data(data.mon._target_monsters)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            kill_target(input_monsters, 1)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            kill_target(input_monsters, 2)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            print_target_monster_data(target_monsters)
        end
    end,
    killed_multiple_family_same_totals = function ()
        data.mon:reset_training_data()

        local input_monsters = {
            { name = data.monsters[1].family, count = 0, total = 4, target_name = data.monsters[1].name },
            { name = data.monsters[2].family, count = 0, total = 4, target_name = data.monsters[2].name },
        }
        present_training_options(data, input_monsters)
        data.mon:process_input(data.output.training_accepted)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            -- If we kill second family first, since they have the same totals these tests fail
            -- For now there isn't anything we can do about this until we add a hardcoded family > monster name map.
            --
            -- Based on https://www.bg-wiki.com/ffxi/Fields_of_Valor and https://www.bg-wiki.com/ffxi/Fields_of_Valor
            -- The following training pages have two or more monster families that share the same count:
            -- Batallia Downs, page 4  (FOV)
            -- Lower Delkfutt's Tower, page 1, 2 (GOV)
            -- Middle Delkfutt's Tower, page 3 (GOV)
            -- Temple of Uggalepih, page 1 (GOV)
            -- Quicksand Caves, page 3, 5 (GOV)
            kill_target(input_monsters, 2)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            kill_target(input_monsters, 1)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            print_target_monster_data(target_monsters)

            -- If we keep going, we should still get the correct counts by the end
            kill_target(input_monsters, 1, 99)
            kill_target(input_monsters, 2, 99)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            print_target_monster_data(target_monsters)
        end
    end,
    killed_multiple_family_diff_totals = function ()
        data.mon:reset_training_data()

        local input_monsters = {
            { name = data.monsters[1].family, total = 5, target_name = data.monsters[1].name },
            { name = data.monsters[2].family, total = 4, target_name = data.monsters[2].name },
        }
        present_training_options(data, input_monsters)
        data.mon:process_input(data.output.training_accepted)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            -- Since they have different totals, these tests should pass
            kill_target(input_monsters, 2)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            kill_target(input_monsters, 1)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            print_target_monster_data(target_monsters)

            kill_target(input_monsters, 2, 99)
            kill_target(input_monsters, 1, 99)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            print_target_monster_data(target_monsters)
        end
    end,
    completed = function ()
        data.mon:reset_training_data()

        local input_monsters = {
            { name = data.monsters[1].name, count = 4, total = 4 },
            { name = data.monsters[2].name, count = 4, total = 4 },
        }
        present_confirmed_training_options(data, input_monsters)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count before completion') then
            print_target_monster_data(target_monsters)
        end

        data.mon:process_input(data.output.training_completed)
        target_monsters = data.mon._target_monsters
        TEST(target_monsters ~= nil and #target_monsters == 0, 'Target monster count after completion is zero')

        data.mon:process_input(data.output.training_repeated)
        target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count after training repeated') then
            for i, v in ipairs(input_monsters) do
                TEST(target_monsters[i].name == input_monsters[i].name, 'Target monster[' .. i .. '] name')
                TEST(target_monsters[i].count == 0, 'Target monster[' .. i .. '] count is zero')
                TEST(target_monsters[i].total == input_monsters[i].total, 'Target monster[' .. i .. '] total')
            end
        end
    end,
    }
end

local function run_tests(desc, tests_table, run_list)
    print(desc)
    for _, test_name in ipairs(run_list) do
        local testf = tests_table[test_name]
        if type(testf) ~= 'function' then
            print('Test not found: ' .. test_name)
        else
            print('Running test: ' .. test_name:upper())
            testf()
            -- raw_print(log_color.bright .. log_color.black .. '------------------------' .. log_color.reset)
        end
    end
end


local function run_all_tests()
    run_tests('Japanese', tests('ja'), tests_to_run)
    --run_tests('English', tests('en'), tests_to_run)
end

-- Run tests
if not running_in_ashita then
    run_all_tests()
end

return run_all_tests
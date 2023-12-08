-- Setup test environment
addon = {
    name = 'trainmon'
}

-- Setup search paths
local module_path = debug.getinfo(1, 'S').source:sub(2)
local search_path_base = string.gsub(module_path, '/' .. addon.name .. '/test/tests%.lua', '/')
print('search_path_base: ' .. search_path_base)

-- Tests dir
package.path = search_path_base .. addon.name .. '/test/?.lua' .. ';' .. package.path
-- Addon dir
package.path = search_path_base .. addon.name .. '/?.lua' .. ';' .. package.path
-- Add Ashita libs dir
package.path = search_path_base .. 'libs/?.lua' .. ';' .. package.path
-- print('module_search_paths: ' .. package.path)

require('ashita-env')
local ansicolors = require('ansicolors')


-- Define tests

require('common')
local monitor = require('monitor')

local test_output = {
    en = require('rules_en').tests,
    ja = require('rules_jp').tests,
}

local data = {}
local tests_to_run = {
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

local function TEST(condition, title)
    local passOrFail = condition and 'PASS' or 'FAIL'
    local color = condition and ansicolors.green or ansicolors.red
    print(color .. 'TEST ' .. passOrFail .. ': ' .. title .. ansicolors.reset)
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
        print(current_status)
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
        data.mon = monitor:new(lang_code)
    end, 
    options = function ()
        -- Training options presented to the player
        local input_monsters = {
            { name = data.output.monsters[1].name, total = 4 },
            { name = data.output.monsters[2].name, total = 4 },
        }
        present_training_options(data, input_monsters)

        -- Player accepted the training
        data.mon:process_input(data.output.training_accepted)

        -- Check data matches
        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            for i, v in ipairs(input_monsters) do
                TEST(target_monsters[i].name == input_monsters[i].name, 'Target monster[' .. i .. '] name')
                TEST(target_monsters[i].total == input_monsters[i].total, 'Target monster[' .. i .. '] total')
            end
        end
    end,
    confirmed = function ()
        -- Confirmed training options presented to the player
        local input_monsters = {
            { name = data.output.monsters[1].name, count = 1, total = 4 },
            { name = data.output.monsters[2].name, count = 2, total = 4 },
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
            { name = data.output.monsters[1].name, total = 4 },
            { name = data.output.monsters[2].name, total = 4 },
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
            { name = data.output.monsters[1].name, total = 4, target_name = data.output.monsters[1].name },
            { name = data.output.monsters[2].name, total = 4, target_name = data.output.monsters[2].name },
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
            { name = data.output.monsters[1].name, total = 4, target_name = data.output.monsters[1].name },
            { name = data.output.monsters[2].family, total = 4, target_name = data.output.monsters[2].name },
        }
        present_training_options(data, input_monsters)
        data.mon:process_input(data.output.training_accepted)

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
            { name = data.output.monsters[1].family, count = 0, total = 4, target_name = data.output.monsters[1].name },
            { name = data.output.monsters[2].family, count = 0, total = 4, target_name = data.output.monsters[2].name },
        }
        present_training_options(data, input_monsters)
        data.mon:process_input(data.output.training_accepted)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            -- If we kill second family first, since they have the same totals these tests fail
            -- For now there isn't anything we can do about this until we add a hardcoded family > monster name map.
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
            { name = data.output.monsters[1].family, total = 5, target_name = data.output.monsters[1].name },
            { name = data.output.monsters[2].family, total = 4, target_name = data.output.monsters[2].name },
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
            { name = data.output.monsters[1].name, count = 4, total = 4 },
            { name = data.output.monsters[2].name, count = 4, total = 4 },
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
            print(ansicolors.bright .. ansicolors.black .. '------------------------' .. ansicolors.reset)
        end
    end
end


-- Run tests

run_tests('Japanese', tests('ja'), tests_to_run)
--run_tests('English', tests('en'), tests_to_run)
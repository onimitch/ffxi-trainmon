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


-- Define tests

require('common')
local chat = require('chat')
local monitor = require('monitor')

local config_jp = require('rules_jp')
local config_en = require('rules_en')

local data = {}
local test_list = {
    'init',
    'options',
    'cancelled',
    'killed',
    'killed_single_family',
    'killed_multiple_family_same_totals',
    'killed_multiple_family_diff_totals',
    'completed',
}

local function TEST(condition, title)
    local passOrFail = condition and 'PASS' or 'FAIL'
    print('TEST: ' .. title .. '...' .. passOrFail)
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
        table.append(options_list, data.output.options_entry(i, v.name, v.total))
    end
    data.mon:process_input(table.concat(options_list, '\r\n'))

    data.mon:process_input(data.output.options_outro)
end

local tests_ja = {
    init = function ()
        -- Reset data
        data = {}
        data.output = config_jp.tests
        data.mon = monitor:new('ja', config_jp.rules)
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

            local killed_by = 'Tenzen'
            local kill_target = function(monster_index, increment)
                local monster = target_monsters[monster_index]
                local target_name = input_monsters[monster_index].target_name
                local new_count = math.min(monster.count + increment, monster.total)
                data.mon:process_input(data.output.target_monster_killed(new_count, monster.total))
                data.mon:process_input(data.output.monster_killed_by(target_name, killed_by))
                local count_desc = (new_count == monster.total) and 'all' or '1'
                TEST(monster.count == new_count, 'Killed ' .. count_desc .. ' ' .. target_name)
            end

            kill_target(1, 1)
            kill_target(2, 1)
            print_target_monster_data(target_monsters)

            kill_target(1, 99)
            kill_target(2, 99)
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

            local killed_by = 'Tenzen'
            local kill_target = function(monster_index, increment)
                local monster = target_monsters[monster_index]
                local target_name = input_monsters[monster_index].target_name
                local new_count = math.min(monster.count + increment, monster.total)
                data.mon:process_input(data.output.target_monster_killed(new_count, monster.total))
                data.mon:process_input(data.output.monster_killed_by(target_name, killed_by))
                local count_desc = (new_count == monster.total) and 'all' or '1'
                TEST(monster.count == new_count, 'Killed ' .. count_desc .. ' ' .. target_name)
            end

            kill_target(1, 1)
            kill_target(2, 1)
            print_target_monster_data(target_monsters)
        end
    end,
    killed_multiple_family_same_totals = function ()
        data.mon:reset_training_data()

        local input_monsters = {
            { name = data.output.monsters[1].family, total = 4, target_name = data.output.monsters[1].name },
            { name = data.output.monsters[2].family, total = 4, target_name = data.output.monsters[2].name },
        }
        present_training_options(data, input_monsters)
        data.mon:process_input(data.output.training_accepted)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            local killed_by = 'Tenzen'
            local kill_target = function(monster_index, increment)
                local monster = target_monsters[monster_index]
                local target_name = input_monsters[monster_index].target_name
                local new_count = math.min(monster.count + increment, monster.total)
                data.mon:process_input(data.output.target_monster_killed(new_count, monster.total))
                data.mon:process_input(data.output.monster_killed_by(target_name, killed_by))
                local count_desc = (new_count == monster.total) and 'all' or '1'
                TEST(monster.count == new_count, 'Killed ' .. count_desc .. ' ' .. target_name)
            end

            -- If we kill second family first, since they have the same totals these tests fail
            -- For now there isn't anything we can do about this until we add a hardcoded family > monster name map.
            kill_target(2, 1)
            kill_target(1, 1)
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

            local killed_by = 'Tenzen'
            local kill_target = function(monster_index, increment)
                local monster = target_monsters[monster_index]
                local target_name = input_monsters[monster_index].target_name
                local new_count = math.min(monster.count + increment, monster.total)
                data.mon:process_input(data.output.target_monster_killed(new_count, monster.total))
                data.mon:process_input(data.output.monster_killed_by(target_name, killed_by))
                local count_desc = (new_count == monster.total) and 'all' or '1'
                TEST(monster.count == new_count, 'Killed ' .. count_desc .. ' ' .. target_name)
            end

            -- Since they have different totals, these tests should pass
            kill_target(2, 1)
            kill_target(1, 1)
            print_target_monster_data(target_monsters)
        end
    end,
    completed = function ()
        data.mon:reset_training_data()

        local input_monsters = {
            { name = data.output.monsters[1].name, total = 5, target_name = data.output.monsters[1].name },
            { name = data.output.monsters[2].name, total = 4, target_name = data.output.monsters[2].name },
        }
        present_training_options(data, input_monsters)
        data.mon:process_input(data.output.training_accepted)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            local killed_by = 'Tenzen'
            local kill_target = function(monster_index, increment)
                local monster = target_monsters[monster_index]
                local target_name = input_monsters[monster_index].target_name
                local new_count = math.min(monster.count + increment, monster.total)
                data.mon:process_input(data.output.target_monster_killed(new_count, monster.total))
                data.mon:process_input(data.output.monster_killed_by(target_name, killed_by))
            end

            kill_target(1, 99)
            kill_target(2, 99)
        end

        data.mon:process_input(data.output.training_completed)
        target_monsters = data.mon._target_monsters
        TEST(target_monsters ~= nil and #target_monsters == 0, 'Target monster count after completion is zero')

        data.mon:process_input(data.output.training_repeated)
        target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count after training repeated') then
            for i, v in ipairs(input_monsters) do
                TEST(target_monsters[i].name == input_monsters[i].name, 'Target monster[' .. i .. '] name')
                TEST(target_monsters[i].total == input_monsters[i].total, 'Target monster[' .. i .. '] total')
            end
        end
    end,
}

local function run_tests(desc, tests, run_list)
    print(desc)
    for _, test_name in ipairs(run_list) do
        local testf = tests[test_name]
        if type(testf) ~= 'function' then
            print('Test not found: ' .. test_name)
        else
            print('Running test: ' .. test_name)
            testf()
        end
    end
end


-- Run tests

run_tests('Japanese', tests_ja, test_list)
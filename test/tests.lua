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

-- Setup test environment if we're not running in Ashita
-- This is not a 1:1 with Ashita, but it's good enough to run tests
if not running_in_ashita then
    -- Addon dir
    package.path = addons_root_dir .. addon.name .. '/?.lua' .. ';' .. package.path
    -- Add Ashita libs dir
    package.path = addons_root_dir .. 'libs/?.lua' .. ';' .. package.path

    require('ashita-env')

    -- Ensure windows terminal is displaying in utf-8
    os.execute('chcp 65001')
end


-- Define tests

require('common')
local chat = require('chat')
local encoding = require('gdifonts.encoding')

local monitor = require('monitor')
local ansicolors = require('ansicolors')
local monster_db = require('monster_db/db')
local chat_modes = require('chat_modes')
local plural_to_singular = require('plural_to_singular')

local test_data = {
    en = require('testdata_en'),
    ja = require('testdata_ja'),
}

local data = {}
local tests_to_run = {
    'string_encoding',
    'init',
    'plurals',
    'options',
    'confirmed',
    'cancelled',
    'killed',
    'killed_single_family',
    'killed_multiple_family',
    'killed_multiple_one_shot',
    'completed',
    'other_chat',
    'types',
}

local test_output_verbose = false
local test_output = {}

local log_color = {
    green = running_in_ashita and chat.colors.LawnGreen or ansicolors.green,
    red = running_in_ashita and chat.colors.Tomato or ansicolors.red,
    reset = running_in_ashita and chat.colors.Reset or ansicolors.reset,
    bright = running_in_ashita and '' or ansicolors.bright,
    black = running_in_ashita and chat.colors.Grey or ansicolors.black,
}

local function printenc(str)
    if not test_output_verbose then
        return
    end
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
    local result = color .. 'TEST ' .. passOrFail .. ': ' .. title .. log_color.reset
    if test_output_verbose then
        print(result)
    end
    if not condition then
        table.insert(test_output.fails, result)
    else
        test_output.pass_count = test_output.pass_count + 1
    end
    return condition
end

local function print_target_monster_data(target_monsters)
    if not test_output_verbose then
        return
    end
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

local function player_is_in_party(player_name)
    local party = AshitaCore:GetMemoryManager():GetParty()
    for i = 0,5 do
        if party:GetMemberName(i) == player_name then
            return true
        end
    end
    return false
end

local function present_training_options(data, input_monsters)
    data.mon:process_input(data.output.options_intro)

    local options_list = {}
    for i, v in ipairs(input_monsters) do
        local localised_name = (data.lang_code == 'en' and v.total > 1) and (v.name .. 's') or v.name
        table.append(options_list, data.output.options_entry(i, localised_name, v.total)[2])
    end
    data.mon:process_input(data.output.options_intro[1], table.concat(options_list, '\r\n'))

    data.mon:process_input(data.output.options_outro)
end

local function present_confirmed_training_options(data, input_monsters)
    local options_list = {}
    for i, v in ipairs(input_monsters) do
        local localised_name = (data.lang_code == 'en' and v.count > 1) and (v.name .. 's') or v.name
        table.append(options_list, data.output.confirmed_entry(i, localised_name, v.count, v.total)[2])
    end
    data.mon:process_input(data.output.confirmed_outro[1], table.concat(options_list, '\r\n'))

    data.mon:process_input(data.output.confirmed_outro)
    data.mon:process_input(data.output.confirmed_end)
end

local function kill_target(killed_by, input_monsters, monster_index, increment)
    increment = increment or 1
    local input_monster = input_monsters[monster_index]
    local target_name = input_monster.target_name or input_monster.name
    local current_count = input_monster.count or 0
    local player_in_party = player_is_in_party(killed_by)

    -- We need to log a seperate entry for each kill, otherwise the monitor might miss information
    -- This is basically the same as it would appear in the game chat logs anyway
    for i=1,increment do
        local new_count = math.min(current_count + 1, input_monster.total)
        if new_count == current_count then
            break -- already reached total kills
        end
        if player_in_party then
            data.mon:process_input(data.output.target_monster_killed(new_count, input_monster.total))
        end
        data.mon:process_input(data.output.monster_killed_by(target_name, killed_by))
        current_count = new_count
    end

    -- The kills should only count if the monster was killed by someone in the party
    if player_in_party then
        input_monster.count = current_count
    end
end

local function TEST_KILL_COUNT(input_monsters, target_monsters, monster_index, killed_by)
    local input_monster = input_monsters[monster_index]
    local target_name = input_monster.target_name or input_monster.name
    local monster = target_monsters[monster_index]
    local count_desc = (input_monster.count == monster.total) and 'all' or '1'
    killed_by = killed_by or AshitaCore:GetMemoryManager():GetParty():GetMemberName(0)
    TEST(monster.count == input_monster.count, killed_by .. ' killed ' .. count_desc .. ' ' .. target_name .. ', count=' .. input_monster.count)
end

local tests = function(lang_code)
    return {
    init = function ()
        -- Reset data
        data = {}
        data.lang_code = lang_code

        -- Initialise monitor
        data.mon = monitor:new(lang_code, printenc, encoding, 'training_data_test')
        -- Monitor auto loads from file so clear any loaded data
        data.mon:reset_training_data()

        -- Init test data
        data.output = test_data[lang_code]
        data.player_name = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0)

        -- Create some monsters for us to use
        data.monsters = {}

        local monster_keys = {
            'bee',
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
    string_encoding = function()
        local in_string_utf8 = 'Monster: Goblin Thug, Family: ゴブリン族'
        print('in_string_utf8: ' .. #in_string_utf8)
        local out_string_sjis = encoding:UTF8_To_ShiftJIS(in_string_utf8)
        print('out_string_sjis: ' .. #out_string_sjis)
        local out_string_utf8 = encoding:ShiftJIS_To_UTF8(out_string_sjis)
        print('out_string_utf8: ' .. #out_string_utf8)
    end,
    plurals = function()
        -- Only run this test for english
        if lang_code ~= 'en' then
            return
        end

        local test_names = {
            { 'Liches', 'Lich' },
            { 'Leeches', 'Leech' },
            { 'Bunnies', 'Bunny' },
            { 'Jellies', 'Jelly' },
            { 'Wolves', 'Wolf' },
            { 'Bandersnatches', 'Bandersnatch' },
            { 'Flies', 'Fly' },
            { 'Bogies', 'Bogy' },
            { 'Gases', 'Gas' },
            { 'Flamingoes', 'Flamingo' },
            { 'Deinonychi', 'Deinonychus' },
            { 'Machairoduses', 'Machairodus' },
            { 'Eotyranni', 'Eotyrannus' },
            { 'Auxiliarii', 'Auxiliarius' },
            { 'Decuriones', 'Decurio' },
            { 'Sagittarii', 'Sagittarius' },
            { 'Essedarii', 'Essedarius' },
            { 'Retiarii', 'Retiarius' },
            { 'Triarii', 'Triarius' },
            { 'Lanistae', 'Lanista' },
            { 'member of the Bee family', 'Bee Family' },
            { 'members of the Bomb Family', 'Bomb Family' },
            { 'Will-o\'-the-Wisps', 'Will-o\'-the-Wisp' },
            { 'Temple Opo-opos', 'Temple Opo-opo' },
            { 'The Greater Demon of the Hellfires', 'The Greater Demon of the Hellfire' },
            -- No change expected
            { 'Seven of Cups' },
            { 'Four of Batons' },
            { 'Five of Swords' },
            { 'Acrophies' },
            { 'Lesser Gaylas' },
            { 'Greater Gaylas' },
        }

        for _, t in ipairs(test_names) do
            local singular = plural_to_singular(t[1])
            local expected = t[2] or t[1]
            TEST(expected == singular, ('%s -> %s = %s'):format(t[1], expected, singular))
        end
    end,
    options = function ()
        data.mon:reset_training_data()

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
            for i, v in ipairs(input_monsters) do
                TEST(target_monsters[i].name == input_monsters[i].name, 'Target monster[' .. i .. '] name')
                TEST(target_monsters[i].total == input_monsters[i].total, 'Target monster[' .. i .. '] total')
            end
        end
    end,
    confirmed = function ()
        data.mon:reset_training_data()

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
            { name = data.monsters[1].name, count = 0, total = 4 },
            { name = data.monsters[2].name, count = 0, total = 4 },
        }
        present_confirmed_training_options(data, input_monsters)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            -- Kill 1
            kill_target(data.player_name, input_monsters, 1)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            kill_target(data.player_name, input_monsters, 2)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            print_target_monster_data(target_monsters)

            -- Test a kill by someone not in the party
            local other_player = 'Other Player'
            kill_target(other_player, input_monsters, 2)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2, other_player)
            kill_target(data.player_name, input_monsters, 2)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            print_target_monster_data(target_monsters)

            -- Kill all
            kill_target(data.player_name, input_monsters, 1, 99)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            kill_target(data.player_name, input_monsters, 2, 99)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            print_target_monster_data(target_monsters)
        end
    end,
    killed_single_family = function ()
        data.mon:reset_training_data()

        local input_monsters = {
            { name = data.monsters[1].name, count = 0, total = 4 },
            { name = data.monsters[2].family, count = 0, total = 4, target_name = data.monsters[2].name },
        }
        present_confirmed_training_options(data, input_monsters)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            kill_target(data.player_name, input_monsters, 1)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            kill_target(data.player_name, input_monsters, 2)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            print_target_monster_data(target_monsters)
        end
    end,
    killed_multiple_family = function ()
        data.mon:reset_training_data()

        local input_monsters = {
            { name = data.monsters[1].family, count = 0, total = 4, target_name = data.monsters[1].name },
            { name = data.monsters[2].family, count = 0, total = 4, target_name = data.monsters[2].name },
        }
        present_confirmed_training_options(data, input_monsters)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            -- Based on https://www.bg-wiki.com/ffxi/Fields_of_Valor and https://www.bg-wiki.com/ffxi/Fields_of_Valor
            -- The following training pages have two or more monster families that share the same count:
            -- Batallia Downs, page 4  (FOV)
            -- Lower Delkfutt's Tower, page 1, 2 (GOV)
            -- Middle Delkfutt's Tower, page 3 (GOV)
            -- Temple of Uggalepih, page 1 (GOV)
            -- Quicksand Caves, page 3, 5 (GOV)
            -- The old monitor logic relied upon matching total required kill count to match up a monster entry to a family
            -- However since the introduction of the monster_db, this logic is no longer necessary, so these test should all pass now
            kill_target(data.player_name, input_monsters, 2)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            kill_target(data.player_name, input_monsters, 1)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            print_target_monster_data(target_monsters)

            -- If we keep going, we should still get the correct counts by the end
            kill_target(data.player_name, input_monsters, 1, 99)
            kill_target(data.player_name, input_monsters, 2, 99)
            TEST_KILL_COUNT(input_monsters, target_monsters, 1)
            TEST_KILL_COUNT(input_monsters, target_monsters, 2)
            print_target_monster_data(target_monsters)
        end
    end,
    killed_multiple_one_shot = function ()
        data.mon:reset_training_data()

        local input_monsters = {
            { name = data.monsters[1].family, count = 0, total = 4, target_name = data.monsters[1].name },
            { name = data.monsters[2].family, count = 0, total = 4, target_name = data.monsters[2].name },
        }
        present_confirmed_training_options(data, input_monsters)

        local target_monsters = data.mon._target_monsters
        if TEST(target_monsters ~= nil and #target_monsters == #input_monsters, 'Target monster count') then
            print_target_monster_data(target_monsters)

            -- Test killing multiple monsters in one go, it causes the logs to output in a diff order
            local monster_countA = input_monsters[1].count + 1
            data.mon:process_input(data.output.target_monster_killed(monster_countA, input_monsters[1].total))

            local monster_countB = input_monsters[2].count + 1
            data.mon:process_input(data.output.target_monster_killed(monster_countB, input_monsters[2].total))
            monster_countB = monster_countB + 1
            data.mon:process_input(data.output.target_monster_killed(monster_countB, input_monsters[2].total))
            input_monsters[2].count = monster_countB

            monster_countA = monster_countA + 1
            data.mon:process_input(data.output.target_monster_killed(monster_countA, input_monsters[1].total))
            input_monsters[1].count = monster_countA

            data.mon:process_input(data.output.monster_killed_by(input_monsters[1].target_name, data.player_name))

            data.mon:process_input(data.output.monster_killed_by(input_monsters[2].target_name, data.player_name))
            data.mon:process_input(data.output.monster_killed_by(input_monsters[2].target_name, data.player_name))

            data.mon:process_input(data.output.monster_killed_by(input_monsters[1].target_name, data.player_name))

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
    other_chat = function()
        data.mon:process_input(chat_modes.system, 'There is no fee for teleporting to Home Point #3 in Port Windurst.')
    end,
    types = function()
        -- Test Undead and Arcana types
        local input_monsters = {}
        if lang_code == 'en' then
            input_monsters = {
                { name = 'Undead-type creatures', count = 0, total = 2, target_name='Foul Meat' },
                { name = 'Arcana-type creatures', count = 0, total = 2, target_name='Boggart' },
            }
        else
            input_monsters = {
                { name = 'アンデッド類', count = 0, total = 2, target_name='Foul Meat' },
                { name = 'アルカナ類', count = 0, total = 2, target_name='Boggart' },
            }
        end

        present_confirmed_training_options(data, input_monsters)

        local target_monsters = data.mon._target_monsters
        print_target_monster_data(target_monsters)

        kill_target(data.player_name, input_monsters, 1)
        TEST_KILL_COUNT(input_monsters, target_monsters, 1)

        kill_target(data.player_name, input_monsters, 2)
        TEST_KILL_COUNT(input_monsters, target_monsters, 2)
        print_target_monster_data(target_monsters)
    end,
    }
end

local function run_tests(desc, tests_table, run_list)
    print(log_color.bright .. log_color.black .. '=========================' .. log_color.reset)
    print(log_color.bright .. log_color.black .. '==  ' .. log_color.reset .. desc:upper())

    local test_report = {}
    for _, test_name in ipairs(run_list) do
        local testf = tests_table[test_name]
        if type(testf) ~= 'function' then
            print(log_color.red .. 'Error: Test not found: "' .. test_name .. '"' .. log_color.reset)
        else
            if test_output_verbose then
                print('Running test: ' .. test_name:gsub('_', ' '):upper())
            end

            test_output = { fails = {}, name = test_name, pass_count = 0 }
            testf()
            table.insert(test_report, test_output)

            if test_output_verbose then
                print(log_color.bright .. log_color.black .. '------------------------' .. log_color.reset)
            end
        end
    end
    if test_output_verbose then
        print('All tests completed.')
    end
    print(log_color.bright .. log_color.black .. '=========================' .. log_color.reset)
    print('Test Summary:')

    for _, v in ipairs(test_report) do
        local passed = #v.fails == 0
        if v.pass_count > 0 or not passed then
            local passOrFail = passed and 'PASSED' or 'FAILED'
            local color = passed and log_color.green or log_color.red
            print(color .. 'Test ' .. v.name:gsub('_', ' ') .. ': ' .. passOrFail .. log_color.reset)
            for _, fail in ipairs(v.fails) do
                print(log_color.red .. '    ' .. fail .. log_color.reset)
            end
        end
    end
end


local function run_all_tests(verbose)
    if verbose then
        test_output_verbose = true
    end
    run_tests('Japanese', tests('ja'), tests_to_run)
    run_tests('English', tests('en'), tests_to_run)
end

-- Run tests
if not running_in_ashita then
    run_all_tests(true)
end

return run_all_tests
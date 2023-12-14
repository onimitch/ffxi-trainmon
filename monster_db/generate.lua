-- Setup test environment
addon = {
    name = 'trainmon'
}

-- Setup search paths
local module_path = debug.getinfo(1, 'S').source:sub(2)
local addons_root_dir = string.gsub(module_path, '/' .. addon.name .. '/monster_db/generate%.lua', '/')

-- This dir
package.path = addons_root_dir .. addon.name .. '/monster_db/?.lua' .. ';' .. package.path
-- Test dir
package.path = addons_root_dir .. addon.name .. '/test/?.lua' .. ';' .. package.path
-- Add Ashita libs dir
package.path = addons_root_dir .. 'libs/?.lua' .. ';' .. package.path

require('ashita-env')


-- Generate monster database

require('common')
local htmlparser = require('htmlparser')

local src_dir = addons_root_dir .. addon.name .. '/monster_db/src'
local dest_dir = addons_root_dir .. addon.name .. '/monster_db/data'
ashita.fs.create_dir(dest_dir)

local monster_key_list = { 
    'goblin', -- https://www.bg-wiki.com/ffxi/Category:Goblin
    'orc', -- https://www.bg-wiki.com/ffxi/Category:Orc
    'bat', -- https://www.bg-wiki.com/ffxi/Category:Bat
    'gigas', -- https://www.bg-wiki.com/ffxi/Category:Gigas
    'tonberry', -- https://www.bg-wiki.com/ffxi/Category:Tonberry
    'bee', -- https://www.bg-wiki.com/ffxi/Category:Bee
    'worm', -- https://www.bg-wiki.com/ffxi/Category:Worm
    'antica', -- https://www.bg-wiki.com/ffxi/Category:Antica
    'sabotender', -- https://www.bg-wiki.com/ffxi/Category:Sabotender
    'evil_weapon', -- https://www.bg-wiki.com/ffxi/Category:Evil_Weapon
    'sahagin', -- https://www.bg-wiki.com/ffxi/Category:Sahagin
    'skeleton', -- https://www.bg-wiki.com/ffxi/Category:Skeleton
    'demon', -- https://www.bg-wiki.com/ffxi/Category:Demon
    'doll', -- https://www.bg-wiki.com/ffxi/Category:Doll
    'quadav', -- https://www.bg-wiki.com/ffxi/Category:Quadav
    'crab', -- https://www.bg-wiki.com/ffxi/Category:Crab
    'pugil', -- https://www.bg-wiki.com/ffxi/Category:Pugil
    'mandragora', -- https://www.bg-wiki.com/ffxi/Category:Mandragora
    'crawler', -- https://www.bg-wiki.com/ffxi/Category:Crawler
    'yagudo', -- https://www.bg-wiki.com/ffxi/Category:Yagudo
    'funguar', -- https://www.bg-wiki.com/ffxi/Category:Funguar
    'hound', -- https://www.bg-wiki.com/ffxi/Category:Hound
    'leech', -- https://www.bg-wiki.com/ffxi/Category:Leech
    'goobbue', -- https://www.bg-wiki.com/ffxi/Category:Goobbue
    'bomb', -- https://www.bg-wiki.com/ffxi/Category:Bomb
    'morbol', -- https://www.bg-wiki.com/ffxi/Category:Morbol
    'ghost', -- https://www.bg-wiki.com/ffxi/Category:Ghost
    'elemental', -- https://www.bg-wiki.com/ffxi/Category:Elemental
    'shadow', -- https://www.bg-wiki.com/ffxi/Category:Fomor
    'fly', -- https://www.bg-wiki.com/ffxi/Category:Fly
    'sapling', -- https://www.bg-wiki.com/ffxi/Category:Sapling
    'beetle', -- https://www.bg-wiki.com/ffxi/Category:Beetle
    'scorpion', -- https://www.bg-wiki.com/ffxi/Category:Scorpion
    'golem', -- https://www.bg-wiki.com/ffxi/Category:Golem
    'wyvern', -- https://www.bg-wiki.com/ffxi/Category:Wyvern
    'cockatrice', -- https://www.bg-wiki.com/ffxi/Category:Cockatrice
    'cardian', -- https://www.bg-wiki.com/ffxi/Category:Cardian
    'corpselight', -- https://www.bg-wiki.com/ffxi/Category:Corpselight
    'corse', -- https://www.bg-wiki.com/ffxi/Category:Corse
    'doomed', -- https://www.bg-wiki.com/ffxi/Category:Doomed
    'dullahan', -- https://www.bg-wiki.com/ffxi/Category:Dullahan
    'naraka', -- https://www.bg-wiki.com/ffxi/Category:Naraka
    'qutrub', -- https://www.bg-wiki.com/ffxi/Category:Qutrub
    'vampyr', -- https://www.bg-wiki.com/ffxi/Category:Vampyr
    'caturae', -- https://www.bg-wiki.com/ffxi/Category:Caturae
    'cluster', -- https://www.bg-wiki.com/ffxi/Category:Cluster
    'spheroid', -- https://www.bg-wiki.com/ffxi/Category:Spheroid
    'iron_giant', -- https://www.bg-wiki.com/ffxi/Category:Iron_Giant
    'magic_pot', -- https://www.bg-wiki.com/ffxi/Category:Magic_Pot
    'marolith', -- https://www.bg-wiki.com/ffxi/Category:Marolith
    'snoll', -- https://www.bg-wiki.com/ffxi/Category:Snoll
}

local monster_type_report = T{}

local function remove_duplicates(tb)
    local exists = {}
    local new_tb = T{}

    for _,v in ipairs(tb) do
        if not exists[v] then
            new_tb[#new_tb + 1] = v
            exists[v] = true
        end
    end

    return new_tb
end

local function save_mob_list(file_path, mob_list)
    local f = io.open(file_path, 'w')
    f:write('return {\n')
    mob_list:each(function (v) f:write('    \'' .. v .. '\',\n') end)
    f:write('}')
    f:close()
end

local function scrape_monster_list(monster_family_key)
    local file = io.input(src_dir .. '/' .. monster_family_key .. '.html')
    local text = io.read("*a") file:close()
    local root = htmlparser.parse(text, 999999)

    -- Get the table container
    local parser_output = root('div.mw-parser-output > *')

    -- Find the monster table
    local mob_table_div = nil
    local next_table_is_mobs = false
    for _, v in ipairs(parser_output) do
        -- print(v.name .. ' ' .. table.concat(v.classes, ','))
        if next_table_is_mobs and v.name == 'div' then
            mob_table_div = v
            break
        elseif v.name == 'h2' and string.find(v:getcontent(), 'Adversaries', 1, true) then
            next_table_is_mobs = true
        end
    end

    if mob_table_div == nil then
        print('Mob table not found for ' .. monster_family_key)
        return
    end

    -- Get all monster rows
    local mob_table_rows = mob_table_div('div.content-table > table > tbody > tr')
    print(monster_family_key .. ' found ' .. #mob_table_rows .. ' table rows')

    local mob_list = T{}
    -- For each row
    for _, v in ipairs(mob_table_rows) do
        local cells = v('td > a')
        -- First anchor is the mob name
        local monster_name = cells[1]:getcontent()
        table.insert(mob_list, (monster_name:gsub('\'', '\\\'')))
    end

    mob_list = remove_duplicates(mob_list)

    -- Grab the type from the page too
    local potential_tables = root('table.Standard.R1-White')
    local monster_type = 'Unknown'
    for _, table in ipairs(potential_tables) do
        local table_rows = table('tbody > tr')

        for _, v in ipairs(table_rows) do
            local columns = v('td')
            if #columns == 2 and columns[1]:getcontent():find('Type') then
                local anchor = columns[2]('a')
                if #anchor == 0 then
                    monster_type = columns[2]:getcontent()
                else
                    monster_type = anchor[1]:getcontent()
                end
            end
        end
    end

    table.append(monster_type_report, { monster_family_key, monster_type })

    -- Save to file
    local dest_file = dest_dir .. '/' .. monster_family_key .. '.lua'
    save_mob_list(dest_file, mob_list)
end

-- Get monster list for each key we have in the db
for _, val in ipairs(monster_key_list) do
    scrape_monster_list(val)
end

local function save_mob_type_list(file_path, type_list)
    local f = io.open(file_path, 'w')
    f:write('return {\n')
    type_list:each(function (v) f:write('    [\'' .. v[1] .. '\'] = \'' .. v[2] .. '\',\n') end)
    f:write('}')
    f:close()
end

-- print('Monster types:')
-- for _, v in ipairs(monster_type_report) do
--     print(v[1] .. ' = ' .. v[2])
-- end

local dest_file = dest_dir .. '/types.lua'
save_mob_type_list(dest_file, monster_type_report)

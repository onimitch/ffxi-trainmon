-- IMPORTANT: This file should be saved as Shift JIS.
local module_path = debug.getinfo(1, 'S').source:sub(2)
local db_dir = string.gsub(module_path, '/db%.lua', '/')
package.path = db_dir .. '?.lua' .. ';' .. package.path


local monster_db = {}

-- Describes monster families and the list of monsters that belong to it
-- Note that this db is not exhaustive. It's only populated from families with appear in Training Regimes for FOV/GOV.
monster_db.families = {
    ['goblin'] = {
        en = 'members of the Goblin family',
        ja = 'ゴブリン族',
        monsters = require('data.goblin'),
    },
    ['orc'] = {
        en = 'members of the Orc family',
        ja = 'オーク族',
        monsters = require('data.orc'),
    },
    ['bat'] = {
        en = 'members of the Bat family',
        ja = 'コウモリ族',
        monsters = require('data.bat'),
    },
    ['gigas'] = {
        en = 'members of the Gigas family',
        ja = '巨人族',
        monsters = require('data.gigas'),
    },
    ['tonberry'] = {
        en = 'members of the Tonberry family',
        ja = 'トンベリ族',
        monsters = require('data.tonberry'),
    },
    ['bee'] = {
        en = 'members of the Bee family',
        ja = '蜂族',
        monsters = require('data.bee'),
    },
    ['worm'] = {
        en = 'members of the Worm famil',
        ja = 'ワーム族',
        monsters = require('data.worm'),
    },
    ['antica'] = {
        en = 'members of the Antica family',
        ja = 'アンティカ族',
        monsters = require('data.antica'),
    },
    ['sabotender'] = {
        en = 'members of the Sabotender family',
        ja = 'サボテンダー族',
        monsters = require('data.sabotender'),
    },
    ['evil_weapon'] = {
        en = 'members of the Evil Weapon family',
        ja = 'イビルウェポン族',
        monsters = require('data.evil_weapon'),
    },
    ['sahagin'] = {
        en = 'members of the Sahagin family',
        ja = 'サハギン族',
        monsters = require('data.sahagin'),
    },
    ['skeleton'] = {
        en = 'members of the Skeleton family',
        ja = 'スケルトン族',
        monsters = require('data.skeleton'),
    },
    ['demon'] = {
        en = 'members of the Demon family',
        ja = 'デーモン族',
        monsters = require('data.demon'),
    },
    ['doll'] = {
        en = 'members of the Doll family',
        ja = 'ドール族',
        monsters = require('data.doll'),
    },
    ['quadav'] = {
        en = 'members of the Quadav family',
        ja = 'クゥダフ族',
        monsters = require('data.quadav'),
    },
    ['crab'] = {
        en = 'members of the Crab family',
        ja = 'クラブ族',
        monsters = require('data.crab'),
    },
    ['pugil'] = {
        en = 'members of the Pugil family',
        ja = 'プギル族',
        monsters = require('data.pugil'),
    },
    ['mandragora'] = {
        en = 'members of the Mandragora family',
        ja = 'マンドラゴラ族',
        monsters = require('data.mandragora'),
    },
    ['crawler'] = {
        en = 'members of the Crawler family',
        ja = 'クロウラー族',
        monsters = require('data.crawler'),
    },
    ['yagudo'] = {
        en = 'members of the Yagudo family',
        ja = 'ヤグード族',
        monsters = require('data.yagudo'),
    },
    ['funguar'] = {
        en = 'members of the Funguar family',
        ja = 'キノコ族',
        monsters = require('data.funguar'),
    },
}

-- Make a flattened list of monster name > monster family key
monster_db.monster_list = {}
for key, family in pairs(monster_db.families) do
    for _, name in ipairs(family.monsters) do
        monster_db.monster_list[name] = key
    end
end

function monster_db:get_family_name(monster_name, lang_code)
    local family_key = monster_db.monster_list[monster_name]
    if family_key ~= nil then
        return monster_db.families[family_key][lang_code]
    end
end

return monster_db
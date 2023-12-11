-- IMPORTANT: This file should be saved as Shift JIS.
local module_path = debug.getinfo(1, 'S').source:sub(2)
local db_dir = string.gsub(module_path, '[\\/]db%.lua', '/')
package.path = db_dir .. '?.lua' .. ';' .. package.path


local monster_db = {}

-- Describes monster families and the list of monsters that belong to it
-- Note that this db is not exhaustive. It's only populated from families with appear in Training Regimes for FOV/GOV.
monster_db.families = {
    ['goblin'] = {
        en = 'goblin family',
        ja = 'ゴブリン族',
        monsters = require('data.goblin'),
    },
    ['orc'] = {
        en = 'orc family',
        ja = 'オーク族',
        monsters = require('data.orc'),
    },
    ['bat'] = {
        en = 'bat family',
        ja = 'コウモリ族',
        monsters = require('data.bat'),
    },
    ['gigas'] = {
        en = 'gigas family',
        ja = '巨人族',
        monsters = require('data.gigas'),
    },
    ['tonberry'] = {
        en = 'tonberry family',
        ja = 'トンベリ族',
        monsters = require('data.tonberry'),
    },
    ['bee'] = {
        en = 'bee family',
        ja = '蜂族',
        monsters = require('data.bee'),
    },
    ['worm'] = {
        en = 'worm family',
        ja = 'ワーム族',
        monsters = require('data.worm'),
    },
    ['antica'] = {
        en = 'antica family',
        ja = 'アンティカ族',
        monsters = require('data.antica'),
    },
    ['sabotender'] = {
        en = 'sabotender family',
        ja = 'サボテンダー族',
        monsters = require('data.sabotender'),
    },
    ['evil_weapon'] = {
        en = 'evil Weapon family',
        ja = 'イビルウェポン族',
        monsters = require('data.evil_weapon'),
    },
    ['sahagin'] = {
        en = 'sahagin family',
        ja = 'サハギン族',
        monsters = require('data.sahagin'),
    },
    ['skeleton'] = {
        en = 'skeleton family',
        ja = 'スケルトン族',
        monsters = require('data.skeleton'),
    },
    ['demon'] = {
        en = 'demon family',
        ja = 'デーモン族',
        monsters = require('data.demon'),
    },
    ['doll'] = {
        en = 'doll family',
        ja = 'ドール族',
        monsters = require('data.doll'),
    },
    ['quadav'] = {
        en = 'quadav family',
        ja = 'クゥダフ族',
        monsters = require('data.quadav'),
    },
    ['crab'] = {
        en = 'crab family',
        ja = 'クラブ族',
        monsters = require('data.crab'),
    },
    ['pugil'] = {
        en = 'pugil family',
        ja = 'プギル族',
        monsters = require('data.pugil'),
    },
    ['mandragora'] = {
        en = 'mandragora family',
        ja = 'マンドラゴラ族',
        monsters = require('data.mandragora'),
    },
    ['crawler'] = {
        en = 'crawler family',
        ja = 'クロウラー族',
        monsters = require('data.crawler'),
    },
    ['yagudo'] = {
        en = 'yagudo family',
        ja = 'ヤグード族',
        monsters = require('data.yagudo'),
    },
    ['funguar'] = {
        en = 'funguar family',
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
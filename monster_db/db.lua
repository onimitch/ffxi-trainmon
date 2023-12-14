local module_path = debug.getinfo(1, 'S').source:sub(2)
local db_dir = string.gsub(module_path, '[\\/]db%.lua', '/')
package.path = db_dir .. '?.lua' .. ';' .. package.path


local monster_db = {}
local monster_types = require('data.types')

-- Map english monster types to Japanese
-- We've only done a handful for now since we only care about what appears on Training objectives
local monster_types_ja = {
    ['Undead'] = 'アンデッド類',
    ['Arcana'] = 'アルカナ類',
}

-- Describes monster families and the list of monsters that belong to it
-- Not guaranteed to be exhaustive
monster_db.families = {
    ['goblin'] = {
        en = 'Goblin Family',
        ja = 'ゴブリン族',
        monsters = require('data.goblin'),
    },
    ['orc'] = {
        en = 'Orc Family',
        ja = 'オーク族',
        monsters = require('data.orc'),
    },
    ['bat'] = {
        en = 'Bat Family',
        ja = 'コウモリ族',
        monsters = require('data.bat'),
    },
    ['gigas'] = {
        en = 'Gigas Family',
        ja = '巨人族',
        monsters = require('data.gigas'),
    },
    ['tonberry'] = {
        en = 'Tonberry Family',
        ja = 'トンベリ族',
        monsters = require('data.tonberry'),
    },
    ['bee'] = {
        en = 'Bee Family',
        ja = '蜂族',
        monsters = require('data.bee'),
    },
    ['worm'] = {
        en = 'Worm Family',
        ja = 'ワーム族',
        monsters = require('data.worm'),
    },
    ['antica'] = {
        en = 'Antica Family',
        ja = 'アンティカ族',
        monsters = require('data.antica'),
    },
    ['sabotender'] = {
        en = 'Sabotender Family',
        ja = 'サボテンダー族',
        monsters = require('data.sabotender'),
    },
    ['evil_weapon'] = {
        en = 'Evil Weapon Family',
        ja = 'イビルウェポン族',
        monsters = require('data.evil_weapon'),
    },
    ['sahagin'] = {
        en = 'Sahagin Family',
        ja = 'サハギン族',
        monsters = require('data.sahagin'),
    },
    ['skeleton'] = {
        en = 'Skeleton Family',
        ja = 'スケルトン族',
        monsters = require('data.skeleton'),
    },
    ['demon'] = {
        en = 'Demon Family',
        ja = 'デーモン族',
        monsters = require('data.demon'),
    },
    ['doll'] = {
        en = 'Doll Family',
        ja = 'ドール族',
        monsters = require('data.doll'),
    },
    ['quadav'] = {
        en = 'Quadav Family',
        ja = 'クゥダフ族',
        monsters = require('data.quadav'),
    },
    ['crab'] = {
        en = 'Crab Family',
        ja = 'クラブ族',
        monsters = require('data.crab'),
    },
    ['pugil'] = {
        en = 'Pugil Family',
        ja = 'プギル族',
        monsters = require('data.pugil'),
    },
    ['mandragora'] = {
        en = 'Mandragora Family',
        ja = 'マンドラゴラ族',
        monsters = require('data.mandragora'),
    },
    ['crawler'] = {
        en = 'Crawler Family',
        ja = 'クロウラー族',
        monsters = require('data.crawler'),
    },
    ['yagudo'] = {
        en = 'Yagudo Family',
        ja = 'ヤグード族',
        monsters = require('data.yagudo'),
    },
    ['funguar'] = {
        en = 'Funguar Family',
        ja = 'キノコ族',
        monsters = require('data.funguar'),
    },
    ['hound'] = {
        en = 'Hound Family',
        ja = '屍犬族',
        monsters = require('data.hound'),
    },
    ['leech'] = {
        en = 'Leech Family',
        ja = 'リーチ族',
        monsters = require('data.leech'),
    },
    ['goobbue'] = {
        en = 'Goobbue Family',
        ja = 'グゥーブー族',
        monsters = require('data.goobbue'),
    },
    ['bomb'] = {
        en = 'Bomb Family',
        ja = 'ボム',
        monsters = require('data.bomb'),
    },
    ['morbol'] = {
        en = 'Morbol Family',
        ja = 'モルボル族',
        monsters = require('data.morbol'),
    },
    ['ghost'] = {
        en = 'Ghost Family',
        ja = 'ゴースト族',
        monsters = require('data.ghost'),
    },
    ['elemental'] = {
        en = 'Elemental Family',
        ja = 'エレメンタル族',
        monsters = require('data.elemental'),
    },
    ['shadow'] = {
        en = 'Shadow Family',
        ja = 'シャドウ族',
        monsters = require('data.shadow'),
    },
    ['fly'] = {
        en = 'Fly Family',
        ja = 'フライ族',
        monsters = require('data.fly'),
    },
    ['sapling'] = {
        en = 'Sapling Family',
        ja = '樹人族',
        monsters = require('data.sapling'),
    },
    ['beetle'] = {
        en = 'Beetle Family',
        ja = '甲虫族',
        monsters = require('data.beetle'),
    },
    ['scorpion'] = {
        en = 'Scorpion Family',
        ja = 'サソリ族',
        monsters = require('data.scorpion'),
    },
    ['golem'] = {
        en = 'Golem Family',
        ja = 'ゴーレム族',
        monsters = require('data.golem'),
    },
    ['wyvern'] = {
        en = 'Wyvern Family',
        ja = 'ワイバーン族',
        monsters = require('data.wyvern'),
    },
    ['cockatrice'] = {
        en = 'Cockatrice Family',
        ja = 'コカトリス族',
        monsters = require('data.cockatrice'),
    },
    ['cardian'] = {
        en = 'Cardian Family',
        ja = 'カーディアン族',
        monsters = require('data.cardian'),
    },
    ['corpselight'] = {
        en = 'Corpselight Family',
        ja = 'カヒライス族',
        monsters = require('data.corpselight'),
    },
    ['corse'] = {
        en = 'Corse Family',
        ja = 'コース族',
        monsters = require('data.corse'),
    },
    ['doomed'] = {
        en = 'Doomed Family',
        ja = 'ドゥーム族',
        monsters = require('data.doomed'),
    },
    ['dullahan'] = {
        en = 'Dullahan Family',
        ja = 'デュラハン族',
        monsters = require('data.dullahan'),
    },
    ['naraka'] = {
        en = 'Naraka Family',
        ja = 'ナラカ族',
        monsters = require('data.naraka'),
    },
    ['qutrub'] = {
        en = 'Qutrub Family',
        ja = 'クトゥルブ族',
        monsters = require('data.qutrub'),
    },
    ['vampyr'] = {
        en = 'Vampyr Family',
        ja = 'ヴァンピール族',
        monsters = require('data.vampyr'),
    },
    ['caturae'] = {
        en = 'Caturae Family',
        ja = 'カトゥラエ族',
        monsters = require('data.caturae'),
    },
    ['cluster'] = {
        en = 'Cluster Family',
        ja = 'クラスター族',
        monsters = require('data.cluster'),
    },
    ['spheroid'] = {
        en = 'Spheroid Family',
        ja = 'スフィアロイド族',
        monsters = require('data.spheroid'),
    },
    ['iron_giant'] = {
        en = 'Iron Giant Family',
        ja = '鉄巨人族',
        monsters = require('data.iron_giant'),
    },
    ['magic_pot'] = {
        en = 'Magic Pot Family',
        ja = 'マジックポット族',
        monsters = require('data.magic_pot'),
    },
    ['marolith'] = {
        en = 'Marolith Family',
        ja = 'マロリス族',
        monsters = require('data.marolith'),
    },
    ['snoll'] = {
        en = 'Snoll Family',
        ja = 'スノール族',
        monsters = require('data.snoll'),
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
    return nil
end

function monster_db:get_type(monster_name, lang_code)
    local family_key = monster_db.monster_list[monster_name]
    if family_key ~= nil then
        local type = monster_types[family_key]
        if type ~= nil then
            if lang_code == 'ja' then
                return monster_types_ja[type]
            else
                return type .. ' Type'
            end
        end
    end
    return nil
end

return monster_db
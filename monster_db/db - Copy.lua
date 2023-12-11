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
        ja = '�S�u������',
        monsters = require('data.goblin'),
    },
    ['orc'] = {
        en = 'members of the Orc family',
        ja = '�I�[�N��',
        monsters = require('data.orc'),
    },
    ['bat'] = {
        en = 'members of the Bat family',
        ja = '�R�E������',
        monsters = require('data.bat'),
    },
    ['gigas'] = {
        en = 'members of the Gigas family',
        ja = '���l��',
        monsters = require('data.gigas'),
    },
    ['tonberry'] = {
        en = 'members of the Tonberry family',
        ja = '�g���x����',
        monsters = require('data.tonberry'),
    },
    ['bee'] = {
        en = 'members of the Bee family',
        ja = '�I��',
        monsters = require('data.bee'),
    },
    ['worm'] = {
        en = 'members of the Worm famil',
        ja = '���[����',
        monsters = require('data.worm'),
    },
    ['antica'] = {
        en = 'members of the Antica family',
        ja = '�A���e�B�J��',
        monsters = require('data.antica'),
    },
    ['sabotender'] = {
        en = 'members of the Sabotender family',
        ja = '�T�{�e���_�[��',
        monsters = require('data.sabotender'),
    },
    ['evil_weapon'] = {
        en = 'members of the Evil Weapon family',
        ja = '�C�r���E�F�|����',
        monsters = require('data.evil_weapon'),
    },
    ['sahagin'] = {
        en = 'members of the Sahagin family',
        ja = '�T�n�M����',
        monsters = require('data.sahagin'),
    },
    ['skeleton'] = {
        en = 'members of the Skeleton family',
        ja = '�X�P���g����',
        monsters = require('data.skeleton'),
    },
    ['demon'] = {
        en = 'members of the Demon family',
        ja = '�f�[������',
        monsters = require('data.demon'),
    },
    ['doll'] = {
        en = 'members of the Doll family',
        ja = '�h�[����',
        monsters = require('data.doll'),
    },
    ['quadav'] = {
        en = 'members of the Quadav family',
        ja = '�N�D�_�t��',
        monsters = require('data.quadav'),
    },
    ['crab'] = {
        en = 'members of the Crab family',
        ja = '�N���u��',
        monsters = require('data.crab'),
    },
    ['pugil'] = {
        en = 'members of the Pugil family',
        ja = '�v�M����',
        monsters = require('data.pugil'),
    },
    ['mandragora'] = {
        en = 'members of the Mandragora family',
        ja = '�}���h���S����',
        monsters = require('data.mandragora'),
    },
    ['crawler'] = {
        en = 'members of the Crawler family',
        ja = '�N���E���[��',
        monsters = require('data.crawler'),
    },
    ['yagudo'] = {
        en = 'members of the Yagudo family',
        ja = '���O�[�h��',
        monsters = require('data.yagudo'),
    },
    ['funguar'] = {
        en = 'members of the Funguar family',
        ja = '�L�m�R��',
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
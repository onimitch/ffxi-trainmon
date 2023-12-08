-- IMPORTANT: This file should be saved as Shift JIS.
local chat_modes = require('chat_modes')

local config = {
    rules = {
        -- �����Ώ�1�FBeach Bunny�c�c4
        -- �����Ώ�2�FSand Lizard�c�c4
        options = '�����Ώ�(%d)�F([^\129]+)�c�c([%d]+)',
        -- �P�����j���[�����肵��
        accepted = '�P�����j���[�����肵��',
        -- �����Ώ�1�FVelociraptor�c�c4/7
        -- �����Ώ�2�FSand Cockatrice�c�c3/3
        confirmed = '�����Ώ�(%d)�F([^\129]+)�c�c([%d]+)/([%d]+)',
        -- �P���G���A�F�e���K����
        confirmed_zone = '�P���G���A�F(.+)',
        -- ���݂̌P�����j���[�͈ȏ�̂悤���B
        confirmed_end = '���݂̌P�����j���[�͈ȏ�̂悤���B',
        -- �P�����j���[���L�����Z������
        cancelled = '�P�����j���[���L�����Z������',
        -- �����Ώۂ̃����X�^�[��|���܂���(1/3)
        target_monster_killed = '�����Ώۂ̃����X�^�[��|���܂���[(]+([%d]+)/([%d]+)',
        -- target_monster_killed_split = '[^%d]+([%d]+)/([%d]+)',
        -- Velociraptor��|����
        monster_killed = '([%a%s%d]+)��|����',
        -- Tenzen�́ABeach Bunny��|����
        monster_killed_by = '([%a%s%d]+)�́A([%a%s%d]+)��|����',
        -- �P�����j���[����������
        completed = '�P�����j���[����������',
        -- �����P�����j���[���p�����܂�
        repeated = '�����P�����j���[���p�����܂�',
        -- Monster name describes a family of monsters
        monster_family = '��',
    },

    tests = {
        options_intro = { chat_modes.system, [[���̕łł́A���̃����X�^�[��
�키�悤�ɁA�����Ă���B]] },
        options_entry = function(i, name, count) return { chat_modes.system, ('�����Ώ�%d�F%s�c�c%d'):format(i, name, count)} end,
        options_outro = { chat_modes.system, [[�����Ώۂ̖ڈ��F���x��1�`6
�P���G���A�F���T���^�o���^
����P���̒B���Ɠ����ɁA��������P���������I��
�J��Ԃ��ݒ�ɂ��܂����H]] },

        confirmed_entry = function(i, name, count, total) return { chat_modes.system, ('�����Ώ�%d�F%s�c�c%d/%d'):format(i, name, count, total)} end,
        confirmed_outro = { chat_modes.system, ([[�����Ώۂ̖ڈ��F���x��1�`6
�P���G���A�F���T���^�o���^]]) },
        confirmed_end = { chat_modes.system, '���݂̌P�����j���[�͈ȏ�̂悤���B' },

        training_accepted = { chat_modes.unknown, '�P�����j���[�����肵���I' },
        training_cancelled = { chat_modes.unknown, '�P�����j���[���L�����Z������' },
        training_completed = { chat_modes.battle, '�P�����j���[����������' },
        training_repeated = { chat_modes.battle, '�����P�����j���[���p�����܂�' },

        target_monster_killed = function(count, total) return { chat_modes.battle, ('�����Ώۂ̃����X�^�[��|���܂���(%d/%d)'):format(count, total) } end,
        monster_killed_by_self = function(monster_name, player_name) return { chat_modes.player, ('%s�́A%s��|����'):format(player_name, monster_name) } end,
        monster_killed_by = function(monster_name, player_name) return { chat_modes.others, ('%s�́A%s��|����'):format(player_name, monster_name) } end,

        monsters = {
            { name = 'Beach Bunny', family = '�E�T�M��' },
            { name = 'Sand Lizard', family = '�g�J�Q��' },
            { name = 'Mandragora', family = '�}���h���S����' },
        }
    },
}

return config
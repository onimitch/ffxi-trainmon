-- IMPORTANT: This file should be saved as Shift JIS.
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
        options_intro = { 151, [[���̕łł́A���̃����X�^�[��
�키�悤�ɁA�����Ă���B]] },
        options_entry = function(i, name, count) return { 151, ('�����Ώ�%d�F%s�c�c%d'):format(i, name, count)} end,
        options_outro = { 151, [[�����Ώۂ̖ڈ��F���x��1�`6
�P���G���A�F���T���^�o���^
����P���̒B���Ɠ����ɁA��������P���������I��
�J��Ԃ��ݒ�ɂ��܂����H]] },

        confirmed_entry = function(i, name, count, total) return { 151, ('�����Ώ�%d�F%s�c�c%d/%d'):format(i, name, count, total)} end,
        confirmed_outro = { 151, ([[�����Ώۂ̖ڈ��F���x��1�`6
�P���G���A�F���T���^�o���^]]) },
        confirmed_end = { 151, '���݂̌P�����j���[�͈ȏ�̂悤���B' },

        training_accepted = { 148, '�P�����j���[�����肵���I' },
        training_cancelled = { 148, '�P�����j���[���L�����Z������' },
        training_completed = { 122, '�P�����j���[����������' },
        training_repeated = { 122, '�����P�����j���[���p�����܂�' },

        target_monster_killed = function(count, total) return { 122, ('�����Ώۂ̃����X�^�[��|���܂���(%d/%d)'):format(count, total) } end,
        monster_killed_by_self = function(monster_name, player_name) return { 36, ('%s�́A%s��|����'):format(player_name, monster_name) } end,
        monster_killed_by = function(monster_name, player_name) return { 37, ('%s�́A%s��|����'):format(player_name, monster_name) } end,

        monsters = {
            { name = 'Beach Bunny', family = '�E�T�M��' },
            { name = 'Sand Lizard', family = '�g�J�Q��' },
            { name = 'Mandragora', family = '�}���h���S����' },
        }
    },
}

return config
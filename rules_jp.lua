local config = T{
    rules = T{
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

    test_commands = T{
        options = '�����Ώ�1�F�}���h���S�����c�c6\r\n�����Ώ�2�FSand Cockatrice�c�c3',
        accepted = '�P�����j���[�����肵��',
        confirmed = '�����Ώ�1�F�}���h���S�����c�c0/6\r\n�����Ώ�2�FSand Cockatrice�c�c0/3',
        cancelled = '�P�����j���[���L�����Z������',
        target_monster_killed = '�����Ώۂ̃����X�^�[��|���܂���(1/3)',
        monster_killed_by = 'Tenzen�́ASand Cockatrice��|����',
        completed = '�P�����j���[����������',
        repeated = '�����P�����j���[���p�����܂�',
    },
}

return config
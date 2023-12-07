local config = T{
    rules = T{
        options_intro = 'The information on this page instructs you to defeat the following:',
        -- 4 Beach Bunny.
        -- 3 Sand Lizard.
        -- 6 members of the mandragora family.
        options = '([%d]+) ([.]+)',
        accepted = 'New training regime registered!',
        -- 0/4 Carrion Crows.
        -- 0/3 Crawlers.
        confirmed = '([%d]+)/([%d]+) ([.]+).',
        -- Training area: East Sarutabaruta.
        confirmed_zone = 'Training area: (.+).',
        cancelled = 'Training regime canceled',
        -- You defeated a designated target. (Progress: 1/4)
        target_monster_killed = 'You defeated a designated target. [(]+Progress: ([%d]+)/([%d]+)[)]+',
        monster_killed = '',
        -- Tenzen defeats the Beach Bunny.
        monster_killed_by = '',
        completed = '',
        repeated = '',
        monster_family = 'members of the',
    },

    test_commands = T{
        options_intro = 'The information on this page instructs you to defeat the following:',
        options = '4 Beach Bunny.\r\n3 Sand Lizard.\r\n6 members of the mandragora family.',
        accepted = 'New training regime registered!',
        confirmed = '',
        cancelled = 'Training regime canceled',
        target_monster_killed = 'You defeated a designated target. (Progress: 1/4)',
        monster_killed_by = 'Tenzen defeats the Beach Bunny.',
        completed = '',
        repeated = '',
    },
}

return config
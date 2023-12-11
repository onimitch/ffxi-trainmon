local chat_modes = require('chat_modes')

local rules = {
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
}

return config
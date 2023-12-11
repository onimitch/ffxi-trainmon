local chat_modes = require('chat_modes')

local rules = {
    -- \7 is used for midline break (see ashita/addons/logs clean_string)
    line_split = '[^\r\n\7]+',

    -- 4 Beach Bunny.
    -- 3 Sand Lizard.
    -- 6 members of the mandragora family.
    options = '^([%d]+) (.+)%.',
    options_captures = function(v) return { total = v[1], name = v[2] } end,
    accepted = '^New training regime registered!',

    -- 0/4 Carrion Crows.
    -- 0/3 Crawlers.
    confirmed = '^([%d]+)/([%d]+) (.+)%.',
    confirmed_captures = function(v) return { count = v[1], total = v[2], name = v[3] } end,
    -- Training area: East Sarutabaruta.
    confirmed_zone = '^Training area: (.+)%.',
    confirmed_end = '(End of list.)',

    cancelled = '^Training regime canceled',
    completed = '^You have successfully completed the training regime.',
    repeated = '^Your current training regime will begin anew!',

    -- You defeated a designated target. (Progress: 1/4)
    target_monster_killed = '^You defeated a designated target. [(]+Progress: ([%d]+)/([%d]+)[)]+',
    -- Tenzen defeats the Beach Bunny.
    monster_killed_by = '^(.+) defeats the (.+)%.',

    monster_family = 'members of the',
}

return rules
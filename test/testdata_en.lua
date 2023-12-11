local chat_modes = require('chat_modes')

local data = {
    options_intro = { chat_modes.system, 'The information on this page instructs you to defeat the following:' },
    options_entry = function(i, name, count) return { chat_modes.system, ('%d %s.'):format(count, name)} end,
    options_outro = { chat_modes.system, [[Target level range: 1～6.
Training area: East Sarutabaruta.]] },

    confirmed_entry = function(i, name, count, total) return { chat_modes.system, ('%d/%d %s.'):format(count, total, name)} end,
    confirmed_outro = { chat_modes.system, ([[Target level range: 1～6.
Training area: East Sarutabaruta.]]) },
    confirmed_end = { chat_modes.system, '(End of list.)' },

    training_accepted = { chat_modes.unknown, 'New training regime registered!' },
    training_cancelled = { chat_modes.unknown, 'Training regime canceled.' },
    training_completed = { chat_modes.battle, 'You have successfully completed the training regime.' },
    training_repeated = { chat_modes.battle, 'Your current training regime will begin anew!' },

    target_monster_killed = function(count, total) return { chat_modes.battle, ('You defeated a designated target. (Progress: %d/%d)'):format(count, total) } end,
    monster_killed_by_self = function(monster_name, player_name) return { chat_modes.player, ('%s defeats the %s.'):format(player_name, monster_name) } end,
    monster_killed_by = function(monster_name, player_name) return { chat_modes.others, ('%s defeats the %s.'):format(player_name, monster_name) } end,
}

return data
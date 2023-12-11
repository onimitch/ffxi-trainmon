local chat_modes = require('chat_modes')

local data = {
    options_intro = { chat_modes.system, [[その頁では、次のモンスターと
戦うように、教えている。]] },
    options_entry = function(i, name, count) return { chat_modes.system, ('討伐対象%d：%s……%d'):format(i, name, count)} end,
    options_outro = { chat_modes.system, [[討伐対象の目安：レベル1～6
訓練エリア：東サルタバルタ
自主訓練の達成と同時に、同じ自主訓練を自動的に
繰り返す設定にしますか？]] },

    confirmed_entry = function(i, name, count, total) return { chat_modes.system, ('討伐対象%d：%s……%d/%d'):format(i, name, count, total)} end,
    confirmed_outro = { chat_modes.system, ([[討伐対象の目安：レベル1～6
訓練エリア：東サルタバルタ]]) },
    confirmed_end = { chat_modes.system, '現在の訓練メニューは以上のようだ。' },

    training_accepted = { chat_modes.unknown, '訓練メニューを決定した！' },
    training_cancelled = { chat_modes.unknown, '訓練メニューをキャンセルした' },
    training_completed = { chat_modes.battle, '訓練メニューを完遂した' },
    training_repeated = { chat_modes.battle, '同じ訓練メニューを継続します' },

    target_monster_killed = function(count, total) return { chat_modes.battle, ('討伐対象のモンスターを倒しました(%d/%d)'):format(count, total) } end,
    monster_killed_by_self = function(monster_name, player_name) return { chat_modes.player, ('%sは、%sを倒した'):format(player_name, monster_name) } end,
    monster_killed_by = function(monster_name, player_name) return { chat_modes.others, ('%sは、%sを倒した'):format(player_name, monster_name) } end,
}

return data
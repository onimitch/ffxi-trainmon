-- IMPORTANT: This file should be saved as Shift JIS.
local config = {
    rules = {
        -- 討伐対象1：Beach Bunny……4
        -- 討伐対象2：Sand Lizard……4
        options = '討伐対象(%d)：([^\129]+)……([%d]+)',
        -- 訓練メニューを決定した
        accepted = '訓練メニューを決定した',
        -- 討伐対象1：Velociraptor……4/7
        -- 討伐対象2：Sand Cockatrice……3/3
        confirmed = '討伐対象(%d)：([^\129]+)……([%d]+)/([%d]+)',
        -- 訓練エリア：テリガン岬
        confirmed_zone = '訓練エリア：(.+)',
        -- 現在の訓練メニューは以上のようだ。
        confirmed_end = '現在の訓練メニューは以上のようだ。',
        -- 訓練メニューをキャンセルした
        cancelled = '訓練メニューをキャンセルした',
        -- 討伐対象のモンスターを倒しました(1/3)
        target_monster_killed = '討伐対象のモンスターを倒しました[(]+([%d]+)/([%d]+)',
        -- target_monster_killed_split = '[^%d]+([%d]+)/([%d]+)',
        -- Velociraptorを倒した
        monster_killed = '([%a%s%d]+)を倒した',
        -- Tenzenは、Beach Bunnyを倒した
        monster_killed_by = '([%a%s%d]+)は、([%a%s%d]+)を倒した',
        -- 訓練メニューを完遂した
        completed = '訓練メニューを完遂した',
        -- 同じ訓練メニューを継続します
        repeated = '同じ訓練メニューを継続します',
        -- Monster name describes a family of monsters
        monster_family = '族',
    },

    tests = {
        options_intro = { 151, [[その頁では、次のモンスターと
戦うように、教えている。]] },
        options_entry = function(i, name, count) return { 151, ('討伐対象%d：%s……%d'):format(i, name, count)} end,
        options_outro = { 151, [[討伐対象の目安：レベル1～6
訓練エリア：東サルタバルタ
自主訓練の達成と同時に、同じ自主訓練を自動的に
繰り返す設定にしますか？]] },

        confirmed_entry = function(i, name, count, total) return { 151, ('討伐対象%d：%s……%d/%d'):format(i, name, count, total)} end,
        confirmed_outro = { 151, ([[討伐対象の目安：レベル1～6
訓練エリア：東サルタバルタ]]) },
        confirmed_end = { 151, '現在の訓練メニューは以上のようだ。' },

        training_accepted = { 148, '訓練メニューを決定した！' },
        training_cancelled = { 148, '訓練メニューをキャンセルした' },
        training_completed = { 122, '訓練メニューを完遂した' },
        training_repeated = { 122, '同じ訓練メニューを継続します' },

        target_monster_killed = function(count, total) return { 122, ('討伐対象のモンスターを倒しました(%d/%d)'):format(count, total) } end,
        monster_killed_by_self = function(monster_name, player_name) return { 36, ('%sは、%sを倒した'):format(player_name, monster_name) } end,
        monster_killed_by = function(monster_name, player_name) return { 37, ('%sは、%sを倒した'):format(player_name, monster_name) } end,

        monsters = {
            { name = 'Beach Bunny', family = 'ウサギ族' },
            { name = 'Sand Lizard', family = 'トカゲ族' },
            { name = 'Mandragora', family = 'マンドラゴラ族' },
        }
    },
}

return config
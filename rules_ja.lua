local chat_modes = require('chat_modes')

local rules = {
    -- \7 is used for midline break (see ashita/addons/logs clean_string)
    line_split = '[^\r\n\7]+',

    -- 討伐対象1：Beach Bunny……4
    -- 討伐対象2：Sand Lizard……4
    -- options = '討伐対象(%d)：([^…]+)……([%d]+)',
    options = '^討伐対象(%d)：(.+)……([%d]+)',
    options_captures = function(v) return { total = tonumber(v[3]), name = v[2] } end,
    -- 訓練メニューを決定した
    accepted = '^訓練メニューを決定した',

    -- 討伐対象1：Velociraptor……4/7
    -- 討伐対象2：Sand Cockatrice……3/3
    confirmed = '^討伐対象(%d)：(.+)……([%d]+)/([%d]+)',
    confirmed_captures = function(v) return { count = tonumber(v[3]), total = tonumber(v[4]), name = v[2] } end,
    -- 訓練エリア：テリガン岬
    confirmed_zone = '^訓練エリア：([^\127]+)', -- 127=0x7F which is part of prompt chars. This is the only place it's a problem because we match the rest of the line
    -- 現在の訓練メニューは以上のようだ。
    confirmed_end = '^現在の訓練メニューは以上のようだ。',

    -- 訓練メニューをキャンセルした
    cancelled = '^訓練メニューをキャンセルした',
    -- 訓練メニューを完遂した
    completed = '^訓練メニューを完遂した',
    -- 同じ訓練メニューを継続します
    repeated = '^同じ訓練メニューを継続します',

    -- 討伐対象のモンスターを倒しました(1/3)
    target_monster_killed = '^討伐対象のモンスターを倒しました[(]+([%d]+)/([%d]+)',
    -- Tenzenは、Beach Bunnyを倒した
    monster_killed_by = '^([%w%s]+)は、([%w%s]+)を倒した',

    -- Monster name describes a family of monsters
    monster_family = '^族',
}

return rules
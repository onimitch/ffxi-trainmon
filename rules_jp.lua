local config = T{
    rules = T{
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

    test_commands = T{
        options = '討伐対象1：マンドラゴラ族……6\r\n討伐対象2：Sand Cockatrice……3',
        accepted = '訓練メニューを決定した',
        confirmed = '討伐対象1：マンドラゴラ族……0/6\r\n討伐対象2：Sand Cockatrice……0/3',
        cancelled = '訓練メニューをキャンセルした',
        target_monster_killed = '討伐対象のモンスターを倒しました(1/3)',
        monster_killed_by = 'Tenzenは、Sand Cockatriceを倒した',
        completed = '訓練メニューを完遂した',
        repeated = '同じ訓練メニューを継続します',
    },
}

return config
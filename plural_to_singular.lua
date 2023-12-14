local plural_to_singular_rule = {
    -- Some specific ones added to handle some FFXI creatures
    -- Auxiliarii -> Auxiliarius
    { 'rii$', 'rius' },
    -- Lanistae > Lanista, Larvae > Larva
    { '([tv])ae$', '%1a' },
    -- Eotyranni > Eotyrannus
    { 'ranni$', 'rannus' },
    -- Deinonychi > Deinonychus
    { 'ychi$', 'ychus' },
    -- Decuriones > Decurio
    { 'iones$', 'io' },
    -- Gaylas (no change)
    { '(ylas)$', '%1' },
    -- Acrophies (no change)
    { '(acrophies)$', '%1' },
    -- of cups/batons/swords/coins
    { '(of cups)$', '%1' },
    { '(of batons)$', '%1' },
    { '(of swords)$', '%1' },
    { '(of coins)$', '%1' },

    -- Below patterns are modified from flourishlib
    -- https://github.com/flourishlib/flourish-classes/blob/master/fGrammar.php
    { '([ml])ice$', '%1ouse' },
    { '(q)uizzes$', '%1uiz' },
    { '(c)hildren$', '%1hild' },
    { '(p)eople$', '%1erson' },
    { '(m)en$', '%1an' },

    -- Can't do negative look ahead in lua patterns, but hopefully for our purposes a simpler pattern is enough
    -- '((?!sh).)oes$' => '\1o'
    { '([aes])hoes$', '%1oe' },
    { '(.)oes$', '%1o' },

    -- Can't do negative look behind in lua patterns, but hopefully for our purposes a simpler pattern is enough
    -- '((?<!o)[ieu]s|[ieuo]x)es$' => '%1'
    { '([^o][ieu]s)es$', '%1' },
    { '([^o][ieuo]x)es$', '%1' },

    { '([cs]h)es$', '%1' },
    { '(ss)es$', '%1' },
    { '([aeo]l)ves$', '%1f' },
    { '([^d]ea)ves$', '%1' },
    { '(ar)ves$', '%1' },
    { '([nlw]i)ves$', '%1fe' },
    { '([aeiou]y)s$', '%1' },
    { '([^aeiou])ies$', '%1y' },
    { '(a)ses$', '%1s' },
    { '(.)s$', '%1' },
}

local members_of_match = 'member[s]? of the'
local type_creature_match = '%-type creature[s]?'

local function join_title_case(first, rest)
    return first:upper() .. rest:lower()
end
local function title_case(str)
    str = str:gsub("(%a)([%w_']*)", join_title_case)
    str = str:gsub('([^%w])Of([^%w])', '%1of%2')
    str = str:gsub('([^%w])The([^%w])', '%1the%2')
    str = str:gsub('([^%w])O([^%w])', '%1o%2')
    str = str:gsub('([^%w])In([^%w])', '%1in%2')
    str = str:gsub('%-Opo', '-opo')
    return str
end

-- In the english client, monster names can be listed as plural depending on the monster count
local function plural_to_singular(monster_name, count)
    count = count or 0

    -- Lower case all
    monster_name = monster_name:lower()

    -- Shorten "member of" and "members of" so we just have "XXX family"
    if string.find(monster_name, members_of_match) then
        monster_name = monster_name:gsub(members_of_match, ''):trim()
    -- Shorten type creature
    elseif string.find(monster_name, type_creature_match) then
        monster_name = monster_name:gsub(type_creature_match, ' Type'):trim()
    else
        -- Convert plurals to singular
        if count ~= 1 then
            for _, r in pairs(plural_to_singular_rule) do
                if monster_name:find(r[1]) then
                    monster_name = monster_name:gsub(r[1], r[2])
                    break
                end
            end
        end
    end

    -- Convert to title case
    return title_case(monster_name)
end

return plural_to_singular
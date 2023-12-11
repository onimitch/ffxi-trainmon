local chat = require('chat')
local settings = require('settings')
local gdi_encoding = require('gdifonts.encoding')

local chat_modes = require('chat_modes')
local monster_db = require('monster_db/db')

local monitor = {}
monitor.__index = monitor

local train_data_defaults = T{
    target_monsters = {},
    target_zone_id = -1,
}

local test_rules = {
    en = require('rules_en'),
    ja = require('rules_ja'),
}

local function player_is_in_party(player_name)
    local party = AshitaCore:GetMemoryManager():GetParty()
    for i = 0,5 do
        if party:GetMemberName(i) == player_name then
            return true
        end
    end
    return false
end

local function shorten_family_name(family_name)
    if string.find(family_name, 'members of the ') or string.find(family_name, 'member of the ') then
        family_name = family_name:gsub('members of the ', '')
        family_name = family_name:gsub('member of the ', '')
        family_name = family_name:lower()
    end
    return family_name
end

function monitor:new(lang_code, print_func, encoding_module, storage_key)
    local instance = {}
    setmetatable(instance, self)

    instance.print = print_func or print
    instance.encoding = encoding_module or gdi_encoding
    instance._storage_key = storage_key or 'training_data'
    instance._lang_code = lang_code
    instance._rules = test_rules[lang_code]
    instance._data = {}

    instance:load_training_data()

    return instance
end

function monitor:reset_training_data()
    self._target_monsters = {}
    self._target_monsters_repeat = {}
    self._target_monsters_options = {}
    self._target_zone_id = -1
    self._target_monster_kills = {}
    self._waiting_confirm_end = false
end

function monitor:load_training_data()
    self:reset_training_data()
    self._data.settings = settings.load(train_data_defaults, self._storage_key)
    self._target_monsters = self._data.settings.target_monsters
    self._target_zone_id = tonumber(self._data.settings.target_zone_id)
end

function monitor:save_train_data()
    self._data.settings.target_monsters = self._target_monsters
    self._data.settings.target_zone_id = self._target_zone_id
    settings.save(self._storage_key)
end

local function codes(str)
	return (str:gsub('.', function (c)
		return string.format('[%02X]', string.byte(c))
	end))
end

function monitor:process_input(mode, input)
    if type(mode) == 'table' then
        mode, input = unpack(mode)
    end

    -- Confirming training
    if mode == chat_modes.system and string.find(input, self._rules.confirmed) then
        -- Split by new lines
        local monster_index = 1
        for line in string.gmatch(input, self._rules.line_split) do
            local captures = { string.match(line, self._rules.confirmed) }
            if #captures > 0 then
                local capture_data = self._rules.confirmed_captures(captures)
                self.print(chat.header(addon.name):append(chat.message(string.format('confirmed: %d, %s (%d/%d)', monster_index, capture_data.name, capture_data.count, capture_data.total))))

                local is_family = string.find(capture_data.name, self._rules.monster_family) ~= nil
                local monster_name = not is_family and capture_data.name or shorten_family_name(capture_data.name)

                self._target_monsters_options[tonumber(monster_index)] = {
                    name = monster_name,
                    count = tonumber(capture_data.count),
                    total = tonumber(capture_data.total),
                    is_family = is_family
                }
                monster_index = monster_index + 1
            end
        end

        self._waiting_confirm_end = true
        return
    end

    -- Confirming zone
    if mode == chat_modes.system and self._waiting_confirm_end and string.find(input, self._rules.confirmed_zone) then
        local zone_name = string.match(input, self._rules.confirmed_zone):trim()
        local zone_id = AshitaCore:GetResourceManager():GetString('zones.names', self.encoding:UTF8_To_ShiftJIS(zone_name, true))
        if zone_id ~= -1 then
            self.print(chat.header(addon.name):append(chat.message(string.format('Training zone: %s (%d)', zone_name, zone_id))))
            self._target_zone_id = zone_id
            self:save_train_data()
        else
            self.print(chat.header(addon.name):append(chat.error(string.format('Unknown Training zone: "%s"', zone_name))))
            local player_zone_id = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
            local player_zone_name = self.encoding:ShiftJIS_To_UTF8(AshitaCore:GetResourceManager():GetString('zones.names', player_zone_id), true)
            self.print(chat.header(addon.name):append(chat.message(string.format('Player zone: %s (%d)', player_zone_name, player_zone_id))))
        end
        return
    end

    -- Confirming end
    if mode == chat_modes.system and self._waiting_confirm_end and string.find(input, self._rules.confirmed_end) then
        self._waiting_confirm_end = false
        if #self._target_monsters_options > 0 then
            -- Use the last options we parsed
            self._target_monsters = self._target_monsters_options
            self._target_monsters_options = {}
            self:save_train_data()
        end
        return
    end

    -- Viewing training options
    if mode == chat_modes.system and string.find(input, self._rules.options) then
        self:reset_training_data()

        -- Split by new lines
        local monster_index = 1
        for line in string.gmatch(input, self._rules.line_split) do
            local captures = { string.match(line, self._rules.options) }
            if #captures > 0 then
                local capture_data = self._rules.options_captures(captures)
                self.print(chat.header(addon.name):append(chat.message(string.format('options: %d, %s (%d)', monster_index, capture_data.name, capture_data.total))))

                local is_family = string.find(capture_data.name, self._rules.monster_family, 1, true) ~= nil
                local monster_name = not is_family and capture_data.name or shorten_family_name(capture_data.name)

                self._target_monsters_options[tonumber(monster_index)] = {
                    name = monster_name,
                    count = 0,
                    total = tonumber(capture_data.total),
                    is_family = is_family
                }
                monster_index = monster_index + 1
            end
        end
        return
    end

    -- User accepted the last viewed training options
    if mode == chat_modes.unknown and string.find(input, self._rules.accepted) then
        if #self._target_monsters_options > 0 then
            -- Use the last options we parsed
            self._target_monsters = self._target_monsters_options
            self._target_monsters_options = {}
            self._target_zone_id = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
            self:save_train_data()
        end
        return
    end

    -- Training was cancelled
    if mode == chat_modes.unknown and string.find(input, self._rules.cancelled) then
        self:reset_training_data()
        self:save_train_data()
        return
    end

    -- Active Training
    if #self._target_monsters > 0 then
        -- A target monster was killed. We don't know what the monster is yet, so make a note of the totals
        if mode == chat_modes.battle and string.find(input, self._rules.target_monster_killed) then
            local count, total = string.match(input, self._rules.target_monster_killed)
            table.insert(self._target_monster_kills, ({ count = tonumber(count), total = tonumber(total) }))
            return
        end

        -- Monster killed, if this happens after a target_monster_killed message then we link them together
        if #self._target_monster_kills > 0 and (mode == chat_modes.player or mode == chat_modes.others) then
            local killed_by, monster_name = string.match(input, self._rules.monster_killed_by)

            if monster_name ~= nil and player_is_in_party(killed_by) then
                -- Monster has now been killed, so get the monster name and link it to the last count update
                local last_target_kill = self._target_monster_kills[1]
                -- local total = last_target_kill.total
                local new_count = last_target_kill.count
                local expected_count = new_count - 1

                -- Find the target monster in our list
                local monster_index = 0
                for i, v in ipairs(self._target_monsters) do
                    if v.name == monster_name then
                        monster_index = i
                        break
                    end
                end

                -- If we didn't find the monster name, it might be for a family of monsters
                -- Get the family name from the monster db
                local family_name = monster_db:get_family_name(monster_name, self._lang_code)
                if family_name ~= nil then
                    for i, v in ipairs(self._target_monsters) do
                        if v.name == family_name then
                            monster_index = i
                            break
                        end
                    end
                end

                -- Check the counts match with what we're expecting
                if monster_index > 0 then
                    local target_monster = self._target_monsters[monster_index]
                    if target_monster.count ~= expected_count then
                        -- Expected count doesn't match, which means the data has got out of sync
                        -- If we only have this single target kill recorded, it should be safe to use this
                        -- If we have more than one target kill pending, then we can't be sure this is a match
                        if #self._target_monster_kills > 1 then
                            self.print(chat.header(addon.name):append(chat.error('Error: Found "%s" in training data but data is out of sync (count=%d, expected=%d).\r\nPlease reconfirm training data at a Field Manual.')):fmt(monster_name, target_monster.count, expected_count))
                            self:reset_training_data()
                            self:save_train_data()
                            return
                        end
                    end
                end

                -- If we couldn't match by family name, then fall back to match by total & expected_count on a family
                -- if monster_index == 0 then
                --     for i, v in ipairs(self._target_monsters) do
                --         if v.is_family and v.total == total and v.count == expected_count then
                --             monster_index = i
                --             break
                --         end
                --     end
                --     -- We did find a match, but it might not be correct
                --     if monster_index ~= 0 then
                --         -- TODO: Print a warning?
                --     end
                -- end

                if monster_index == 0 then
                    -- Monster not found, ignore since it's not part of our training
                    -- self.print(chat.header(addon.name):append(chat.error('Failed to find "%s" in Training Data (%d/%d)')):fmt(monster_name, new_count, total))
                    return
                end

                self._target_monsters[monster_index].count = new_count
                table.remove(self._target_monster_kills, 1)
                self:save_train_data()
                return
            end
        end

        -- A training was just completed
        if mode == chat_modes.battle and string.find(input, self._rules.completed) then
            -- Reset the counts
            for i,v in ipairs(self._target_monsters) do
                v.count = 0
            end

            -- Make a copy of the target_monsters incase we repeat the training
            self._target_monsters_repeat = self._target_monsters
            -- Clear training data
            self._target_monsters = {}
            self:save_train_data()
            return
        end
    end

    -- Training was repeated
    if mode == chat_modes.battle and #self._target_monsters_repeat > 0 and string.find(input, self._rules.repeated) then
        self._target_monsters = self._target_monsters_repeat
        self._target_monsters_repeat = {}
        self:save_train_data()
        return
    end
end

return monitor
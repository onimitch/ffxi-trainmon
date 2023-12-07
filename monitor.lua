local chat = require('chat')
local settings = require('settings')

local monitor = {}
monitor.__index = monitor

local chat_modes = T{
    message = 150,
    system = 151,
    player = 36, -- Onishiro defeats the Tiny Mandragora.
    npc = 37, -- Tenzen defeats the Beach Bunny.
    battle = 122, -- You defeated a designated target. (Progress: 1/4)
}
local train_data_defaults = T{
    target_monsters = {},
    target_zone_id = -1,
}
local train_data_settings_key = 'training_data'

function monitor:new(lang_code, rules)
    local instance = {}
    setmetatable(instance, self)

    instance._lang_code = lang_code
    instance._rules = rules
    if lang_code == 'ja' then
        instance.process_input = monitor.process_input_japanese
    else
        instance.process_input = monitor.process_input_english
    end

    instance._waiting_zone_confirmation = false
    instance._data = {}

    instance:load_training_data()

    return instance
end

function monitor:reset_training_data()
    self._target_monsters = {}
    self._target_monsters_repeat = {}
    self._target_monsters_options = {}
    self._target_zone_id = -1
    self._last_target_count = 0
    self._last_target_total = 0
    self._waiting_zone_confirmation = false
end

function monitor:load_training_data()
    self:reset_training_data()
    self._data.settings = settings.load(train_data_defaults, train_data_settings_key)
    self._target_monsters = self._data.settings.target_monsters
    self._target_zone_id = tonumber(self._data.settings.target_zone_id)
end

function monitor:save_train_data()
    self._data.settings.target_monsters = self._target_monsters
    self._data.settings.target_zone_id = self._target_zone_id
    settings.save(train_data_settings_key)
end

function monitor:process_input_japanese(mode, input)
    -- print(input)

    -- -- Confirming training
    -- if string.find(str, rules.confirmed) then
    --     for monster_index, monster_name, count, total in string.gmatch(str, rules.confirmed) do
    --         print(chat.header(addon.name):append(chat.message(string.format('confirmed: %d, %s (%d/%d)', monster_index, monster_name, count, total))))
            
    --         if monster_index == 1 then
    --             -- Don't lose zone_id when we reset, because confirming can happen in another zone
    --             local zone_id = self._target_zone_id
    --             reset_training_data()
    --             self._target_zone_id = zone_id
    --         end

    --         local is_family = string.find(monster_name, rules.monster_family, 1, true) ~= nil

    --         self._target_monsters[tonumber(monster_index)] = {
    --             name = monster_name,
    --             count = tonumber(count),
    --             total = tonumber(total),
    --             is_family = is_family
    --         }
    --         save_train_data()
    --     end

    --     self._waiting_zone_confirmation = true
    --     return
    -- end

    -- -- Confirming zone
    -- if self._waiting_zone_confirmation and string.find(str, rules.confirmed_zone) then
    --     local zone_name = string.match(str, rules.confirmed_zone)
    --     local zone_id = AshitaCore:GetResourceManager():GetString('zones.names', zone_name)
    --     if zone_id ~= -1 then
    --         print(chat.header(addon.name):append(chat.message(string.format('Training zone: %s (%d)', zone_name, zone_id))))
    --         self._target_zone_id = zone_id
    --         save_train_data()
    --         self._waiting_zone_confirmation = false
    --     end
    --     return
    -- end

    -- Viewing training options
    if string.find(input, self._rules.options) then
        self:reset_training_data()

        for monster_index, monster_name, total in string.gmatch(input, self._rules.options) do
            -- print(chat.header(addon.name):append(chat.message(string.format('options: %d, %s (%d)', monster_index, monster_name, total))))

            local is_family = string.find(monster_name, self._rules.monster_family, 1, true) ~= nil

            self._target_monsters_options[tonumber(monster_index)] = {
                name = monster_name,
                count = 0,
                total = tonumber(total),
                is_family = is_family
            }
        end
        return
    end

    -- User accepted the last viewed training options
    if string.find(input, self._rules.accepted, 1, true) then
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
    if string.find(input, self._rules.cancelled, 1, true) then
        self:reset_training_data()
        self:save_train_data()
        return
    end


    -- Active Training
    if #self._target_monsters > 0 then
        -- A target monster was killed. We don't know what the monster is yet, so make a note of the totals
        if string.find(input, self._rules.target_monster_killed) then
            local count, total = string.match(input, self._rules.target_monster_killed)
            self._last_target_count = tonumber(count)
            self._last_target_total = tonumber(total)
            return
        end

        -- Monster killed, if this happens after a target_monster_killed message then we link them together
        local killed_by, monster_name = string.match(input, self._rules.monster_killed_by)
        if monster_name == nil then
            monster_name = string.match(input, self._rules.monster_killed)
        end
        if monster_name ~= nil then
            if self._last_target_total == 0 then
                return
            end

            -- print(chat.header(addon.name):append(chat.message('Monster killed "%s" by "%s" -- last_total: %d, last_count: %d')):fmt(monster_name, killed_by, self._last_target_total, self._last_target_count))

            -- Monster has now been killed, so get the monster name and link it to the last count update
            local total = self._last_target_total
            local count = self._last_target_count
            local expected_count = count - 1

            -- Find the target monster in our list
            local monster_index = 0
            for i, v in ipairs(self._target_monsters) do
                if v.name == monster_name then
                    monster_index = i
                    break
                end
            end

            -- If we didn't find the monster name, it might be a family of monsters
            -- For now we fall back to match by total & expected_count on a family
            -- The better way to do this would be to have a table that maps monster names to family of monsters
            if monster_index == 0 then
                for i, v in ipairs(self._target_monsters) do
                    if v.is_family and v.total == total and v.count == expected_count then
                        monster_index = i
                        break
                    end
                end
            end

            -- Still no luck matching family, so search without is_family
            if monster_index == 0 then
                print(chat.header(addon.name):append(chat.message('Failed to find Monster family "%s" (%d/%d)')):fmt(monster_name, count, total))
                for i, v in ipairs(self._target_monsters) do
                    if v.total == total and v.count == expected_count then
                        monster_index = i
                        break
                    end
                end
            end

            if monster_index == 0 then
                print(chat.header(addon.name):append(chat.error('Failed to find Monster in Training Data "%s" (%d/%d)')):fmt(monster_name, count, total))
                self._last_target_count = 0
                self._last_target_total = 0
                return
            end

            self._target_monsters[monster_index].count = count
            self._last_target_count = 0
            self._last_target_total = 0
            self:save_train_data()
            return
        end

        -- A training was just completed
        if string.find(input, self._rules.completed, 1, true) then
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
    if #self._target_monsters_repeat > 0 and string.find(input, self._rules.repeated, 1, true) then
        self._target_monsters = self._target_monsters_repeat
        self._target_monsters_repeat = {}
        self:save_train_data()
        return
    end
end

function monitor:process_input_english(input)
    print('EN:' .. input)
end

return monitor
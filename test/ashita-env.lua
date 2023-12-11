-- Simulate some of Ashita in order to run our tests
-- This is mostly to enable settings.save/load

AshitaCore = {}

local module_path = debug.getinfo(1, 'S').source:sub(2)
local ashita_install_dir = string.gsub(module_path, '/addons/' .. addon.name .. '/test/ashita%-env%.lua', '/')


function AshitaCore:GetInstallPath()
    return ashita_install_dir
end

function AshitaCore:GetMemoryManager()
    return {
        GetPlayer = function(...)
            return {
                GetLoginStatus = function(...)
                    return 2
                end
            }
        end,
        GetParty = function(...)
            return {
                GetMemberZone = function(...)
                    return 0
                end,
                GetMemberName = function(...)
                    return 'Player'
                end
            }
        end,
    }
end

function AshitaCore:GetResourceManager()
    return {
        GetString = function(self, table_name, name_or_id, ...)
            if table_name == 'zones.names' then
                return type(name_or_id) == 'string' and 0 or 'Test Zone name'
            end
            return type(name_or_id) == 'string' and 0 or 'Test<' .. table_name .. '>'
        end,
    }
end

function GetPlayerEntity()
    return {
        ServerId = 123456, 
        Name = 'Test',
    }
end

ashita = {
    events = {
        register = function (...) end,
    },
    fs = {}
}
ashita.fs.exists = function(path)
    local command = ('if exist "%s" (echo 0) else (echo 1)'):format(path)

    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()

    return tonumber(result) == 0
end
ashita.fs.create_dir = function(path)
    if ashita.fs.exists(path) then
        return
    end
    os.execute(('mkdir "%s"'):format(path))
end


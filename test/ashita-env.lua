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
                end
            }
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
    local isok, errstr, errcode = os.execute(('if exist "%s" (exit 0) else (exit 1)'):format(path))
    return isok and errcode == 0
end
ashita.fs.create_dir = function(path)
    if ashita.fs.exists(path) then
        return
    end
    os.execute(('mkdir "%s"'):format(path))
end


-- Run the actual alliance loops without initializing the map or dev UI.
local sandbox = setmetatable({}, {__index = _G})
local _ENV = sandbox
local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end
PLAYER_CAP, bj_MAX_PLAYER_SLOTS = 6, 28
MAP_CONTROL_USER = "human"
ALLIANCE_SHARED_VISION, ALLIANCE_SHARED_CONTROL = "vision", "control"
Player = function(id) assert(id >= 0 and id < 28); return id end
GetPlayerController = function(id) return id < 2 and "human" or "computer" end
local vision, control
SetPlayerAlliance = function(source, recipient, kind, enabled)
    local entries = kind == "vision" and vision or control
    entries[source .. ":" .. recipient] = enabled
end
local function run(path, start_marker, end_marker, simulated)
    vision, control = {}, {}
    -- Model stale map/editor permissions so the loops must explicitly revoke them.
    for source = 0, PLAYER_CAP - 1 do
        for recipient = 0, bj_MAX_PLAYER_SLOTS - 1 do
            vision[source .. ":" .. recipient] = true
        end
    end
    local source = read(path)
    local first = assert(source:find(start_marker, 1, true))
    local last = assert(source:find(end_marker, first, true))
    assert(load(source:sub(first, last - 1), path, "t", sandbox))()
    for owner = 0, PLAYER_CAP - 1 do
        for recipient = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if owner ~= recipient then
                local key = owner .. ":" .. recipient
                local expected = recipient < PLAYER_CAP
                    and (simulated or (owner < 2 and recipient < 2))
                assert(vision[key] == expected, "Incorrect shared vision: " .. key)
                assert(control[key] == false, "Shared control enabled: " .. key)
            end
        end
    end
end
run("cotlua/src/bootstrap/map_setup.lua", "    -- Share human vision", "    -- turn off gold bounty", false)
run("cotlua/src/devtools/dev.lua", "        -- Include simulated hero players", "    end\n\n    local function preload_items", true)
print("PASS: co-op and simulated-player vision stays within hero slots; enemy vision is revoked.")

-- Iceylands remote loader
-- Private repo development URL:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Sadek2002/iceylands/refs/heads/main/loader.lua"))()

local OWNER = "Sadek2002"
local REPO = "iceylands"
local BRANCH = "main"

local baseUrl = ("https://raw.githubusercontent.com/%s/%s/refs/heads/%s/"):format(OWNER, REPO, BRANCH)
local cache = {}

local function fetch(path)
    local ok, result = pcall(function()
        return game:HttpGet(baseUrl .. path)
    end)

    if not ok or type(result) ~= "string" or result == "" then
        error(("Iceylands failed to fetch %s"):format(path), 2)
    end

    return result
end

local Runtime = {
    BaseUrl = baseUrl,
    LoadModule = function(path)
        if cache[path] then
            return cache[path]
        end

        local source = fetch(path)
        local chunk = assert(loadstring(source, "Iceylands/" .. path))
        local module = chunk()
        cache[path] = module
        return module
    end,
}

_G.IceylandsLoader = Runtime

local Main = Runtime.LoadModule("src/main.lua")
Main.Start()

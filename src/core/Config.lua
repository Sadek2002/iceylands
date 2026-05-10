local HttpService = game:GetService("HttpService")
local Runtime = _G.IceylandsLoader
local Constants = Runtime.LoadModule("src/shared/Constants.lua")

local Config = {}

Config.Defaults = {
    ExampleToggle = true,
    ExampleSlider = 75,
}

local function cloneDefaults()
    local output = {}
    for key, value in pairs(Config.Defaults) do
        output[key] = value
    end
    return output
end

local function canUseFiles()
    return typeof(isfile) == "function"
        and typeof(readfile) == "function"
        and typeof(writefile) == "function"
        and typeof(makefolder) == "function"
        and typeof(isfolder) == "function"
end

local function ensureFolder()
    if canUseFiles() and not isfolder(Constants.Folder) then
        makefolder(Constants.Folder)
    end
end

function Config.Encode(state)
    return HttpService:JSONEncode(state)
end

function Config.Decode(json)
    return HttpService:JSONDecode(json)
end

function Config.Load()
    local state = cloneDefaults()

    if not canUseFiles() or not isfile(Constants.ConfigFile) then
        return state
    end

    local ok, decoded = pcall(function()
        return Config.Decode(readfile(Constants.ConfigFile))
    end)

    if ok and type(decoded) == "table" then
        for key in pairs(Config.Defaults) do
            if decoded[key] ~= nil then
                state[key] = decoded[key]
            end
        end
    end

    return state
end

function Config.Save(state)
    if not canUseFiles() then
        return false, "File APIs are not available."
    end

    ensureFolder()
    writefile(Constants.ConfigFile, Config.Encode(state))
    return true, Constants.ConfigFile
end

function Config.Export(state)
    return Config.Encode(state)
end

function Config.Copy(text)
    if typeof(setclipboard) ~= "function" then
        return false, "Clipboard API is not available."
    end

    setclipboard(text)
    return true
end

return Config

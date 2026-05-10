local Runtime = _G.IceylandsLoader
local Constants = Runtime.LoadModule("src/shared/Constants.lua")

local files = {
    SnowflakeCircleLarge = "snowflake_circle_large.png",
    SnowflakeCircleSmall = "snowflake_circle_small.png",
    MinimizedIcon = "minimized_icon.png",
    SnowflakeLarge = "snowflake_large.png",
    SnowflakeSmall = "snowflake_small.png",
    Home = "home_icon.png",
    Lock = "lock_icon.png",
}

local Assets = {
    Files = files,
    Fallback = {
        SnowflakeCircleLarge = "❄",
        SnowflakeCircleSmall = "❄",
        MinimizedIcon = "❄",
        SnowflakeLarge = "❄",
        SnowflakeSmall = "❄",
        Home = "⌂",
        Lock = "🔒",
    },
}

local function canUseFiles()
    return typeof(isfile) == "function"
        and typeof(writefile) == "function"
        and typeof(makefolder) == "function"
        and typeof(isfolder) == "function"
        and typeof(getcustomasset) == "function"
end

local function ensureFolders()
    if not canUseFiles() then
        return false
    end

    if not isfolder(Constants.Folder) then
        makefolder(Constants.Folder)
    end

    if not isfolder(Constants.AssetFolder) then
        makefolder(Constants.AssetFolder)
    end

    return true
end

function Assets.Get(key)
    local fileName = files[key]
    if not fileName or not ensureFolders() then
        return nil
    end

    local localPath = Constants.AssetFolder .. "/" .. fileName

    if not isfile(localPath) then
        local ok, bytes = pcall(function()
            return game:HttpGet(Runtime.BaseUrl .. "assets/" .. fileName)
        end)

        if not ok or type(bytes) ~= "string" or bytes == "" then
            return nil
        end

        writefile(localPath, bytes)
    end

    local ok, customAsset = pcall(getcustomasset, localPath)
    if ok then
        return customAsset
    end

    return nil
end

return Assets

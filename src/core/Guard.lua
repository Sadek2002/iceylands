local Runtime = _G.IceylandsLoader
local Constants = Runtime.LoadModule("src/shared/Constants.lua")

local Guard = {}

function Guard.IsAllowed()
    return game.PlaceId == Constants.PlaceId and game.GameId == Constants.GameId
end

return Guard

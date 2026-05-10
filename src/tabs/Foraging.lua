local Runtime = _G.IceylandsLoader
local Components = Runtime.LoadModule("src/ui/Components.lua")
local DemoWorld = Runtime.LoadModule("src/core/DemoWorld.lua")

local Foraging = {}

local function updateUiClickGuard(services)
    if getgenv then
        getgenv().IceylandsIgnoreReopenClicks = services.State.MovementDemo == true
    end
end

function Foraging.Mount(parent, services)
    Components.Toggle(parent, "Tree Movement", "Finds the nearest live tree, equips your best axe, and walks beside it.", services.State.MovementDemo, function(value)
        services.State.MovementDemo = value
        services.State.AutoCollectDemo = false
        services.State.OverlayDemo = false
        updateUiClickGuard(services)

        if value then
            DemoWorld.EquipBestAxe()
        end

        DemoWorld.SetMovementDemo(value)
        services.Toasts:Push(value and "Tree movement enabled" or "Tree movement disabled", "success")
    end)
end

return Foraging

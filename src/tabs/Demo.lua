local Runtime = _G.IceylandsLoader
local Components = Runtime.LoadModule("src/ui/Components.lua")
local DemoWorld = Runtime.LoadModule("src/core/DemoWorld.lua")

local Demo = {}

function Demo.Mount(parent, services)
    Components.TextBlock(parent, "Universal Demo Mode", "This tab only uses workspace.IceylandsDemo objects created for Studio/offline testing. It does not inspect remotes or interact with live game systems.", 118)

    Components.Button(parent, "Spawn Demo Objects", "Creates local collectible blocks for safe UI and movement demonstrations.", "Spawn", function()
        DemoWorld.EnsureObjects()
        if services.State.OverlayDemo then
            DemoWorld.SetOverlayDemo(services.Root, true)
        end
        services.Toasts:Push("Demo objects ready", "success")
    end)

    Components.Button(parent, "Spawn At Tree Positions", "Places demo collectibles at detected tree-like part positions.", "Spawn", function()
        local count = DemoWorld.SpawnObjectsAtTreePositions(10)
        if services.State.OverlayDemo then
            DemoWorld.SetOverlayDemo(services.Root, true)
        end
        services.Toasts:Push(count > 0 and ("Spawned " .. count .. " demo tree points") or "No tree positions found", count > 0 and "success" or "warn")
    end)

    Components.Toggle(parent, "Movement Demo", "Moves toward demo collectibles only. Intended for private Studio testing.", services.State.MovementDemo, function(value)
        services.State.MovementDemo = value
        DemoWorld.SetMovementDemo(value)
        services.Toasts:Push(value and "Movement demo enabled" or "Movement demo disabled", "success")
    end)

    Components.Toggle(parent, "Overlay Demo", "Shows ESP-style labels only on Iceylands demo objects.", services.State.OverlayDemo, function(value)
        services.State.OverlayDemo = value
        DemoWorld.SetOverlayDemo(services.Root, value)
        services.Toasts:Push(value and "Overlay demo enabled" or "Overlay demo disabled", "success")
    end)

    Components.Toggle(parent, "Auto-Collect Demo", "Simulates collection using only local demo objects.", services.State.AutoCollectDemo, function(value)
        services.State.AutoCollectDemo = value
        DemoWorld.SetAutoCollectDemo(value, function(name)
            services.Toasts:Push("Collected " .. name, "success")
        end)
        services.Toasts:Push(value and "Auto-collect demo enabled" or "Auto-collect demo disabled", "success")
    end)

    Components.Button(parent, "Clear Demo Objects", "Removes the local demo folder and markers.", "Clear", function()
        DemoWorld.Restore()
        DemoWorld.ClearObjects()
        services.State.MovementDemo = false
        services.State.OverlayDemo = false
        services.State.AutoCollectDemo = false
        services.Toasts:Push("Demo objects cleared", "success")
    end)
end

return Demo

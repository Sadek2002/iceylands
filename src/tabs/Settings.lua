local Runtime = _G.IceylandsLoader
local Components = Runtime.LoadModule("src/ui/Components.lua")
local Performance = Runtime.LoadModule("src/core/Performance.lua")

local Settings = {}

function Settings.Mount(parent, services)
    Components.Toggle(parent, "Disable Rendering", "Turns off 3D rendering and leaves a plain white backdrop.", services.State.DisableRendering, function(value)
        services.State.DisableRendering = value
        Performance.SetRenderingDisabled(services.Root, value)
        services.Toasts:Push(value and "Rendering disabled" or "Rendering restored", "success")
    end)

    Components.Toggle(parent, "FPS Boost", "Lowers local visual effects for better performance.", services.State.FpsBoost, function(value)
        services.State.FpsBoost = value
        Performance.SetFpsBoost(value)
        services.Toasts:Push(value and "FPS boost enabled" or "FPS boost disabled", "success")
    end)

    Components.Button(parent, "Save Config", "Stores your current Iceylands settings locally.", "Save", function()
        local ok, message = services.Config.Save(services.State)
        services.Toasts:Push(ok and ("Config saved: " .. message) or message, ok and "success" or "warn")
    end)

    Components.Button(parent, "Load Config", "Loads your saved config file.", "Load", function()
        local loaded = services.Config.Load()
        for key, value in pairs(loaded) do
            services.State[key] = value
        end

        Performance.SetRenderingDisabled(services.Root, services.State.DisableRendering)
        Performance.SetFpsBoost(services.State.FpsBoost)
        services.Toasts:Push("Config loaded", "success")
    end)

    Components.Button(parent, "Export Config", "Copies the current config JSON to your clipboard.", "Copy JSON", function()
        local json = services.Config.Export(services.State)
        local ok = services.Config.Copy(json)
        services.Toasts:Push(ok and "JSON copied" or json, ok and "success" or "warn")
    end)

    Components.Button(parent, "Kill Script", "Removes Iceylands from the current session.", "Kill", function()
        Performance.Restore()

        if services.Toasts then
            services.Toasts:Push("Iceylands removed", "success")
            task.wait(0.15)
        end

        if services.Destroy then
            services.Destroy()
        end
    end)
end

return Settings

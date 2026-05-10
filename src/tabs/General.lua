local Runtime = _G.IceylandsLoader
local Components = Runtime.LoadModule("src/ui/Components.lua")

local General = {}

function General.Mount(parent, services)
    Components.Toggle(parent, "Example Toggle", "This is a placeholder toggle.", services.State.ExampleToggle, function(value)
        services.State.ExampleToggle = value
        services.Toasts:Push("Example toggle: " .. tostring(value), "success")
    end)

    Components.Slider(parent, "Example Slider", "Adjust the saved demo value.", 0, 100, services.State.ExampleSlider, function(value)
        services.State.ExampleSlider = value
    end)

    Components.Button(parent, "Example Button", "This button is reserved for future modules.", "Click Me", function()
        services.Toasts:Push("Button clicked", "success")
    end)
end

return General

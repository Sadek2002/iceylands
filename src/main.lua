local Runtime = _G.IceylandsLoader

local Constants = Runtime.LoadModule("src/shared/Constants.lua")
local Guard = Runtime.LoadModule("src/core/Guard.lua")
local Config = Runtime.LoadModule("src/core/Config.lua")
local LoadingScreen = Runtime.LoadModule("src/ui/LoadingScreen.lua")
local Window = Runtime.LoadModule("src/ui/Window.lua")
local Notifications = Runtime.LoadModule("src/core/Notifications.lua")
local GeneralTab = Runtime.LoadModule("src/tabs/General.lua")

local Main = {}

local function getParent()
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui
        end
    end

    return game:GetService("CoreGui")
end

function Main.Start()
    if not Guard.IsAllowed() then
        warn(Constants.Name .. " is not enabled for this experience.")
        return
    end

    if getgenv then
        local genv = getgenv()
        if genv.IceylandsDestroy then
            pcall(genv.IceylandsDestroy)
        end
    end

    local root = Instance.new("ScreenGui")
    root.Name = Constants.GuiName
    root.IgnoreGuiInset = true
    root.ResetOnSpawn = false
    root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    root.Parent = getParent()

    local state = Config.Load()
    local toasts = Notifications.new(root)

    local loading = LoadingScreen.new(root)
    loading:Play({
        { label = "Loading Interface", duration = 0.55 },
        { label = "Preparing Config", duration = 0.45 },
        { label = "Mounting Iceylands", duration = 0.35 },
        { label = "Done", duration = 0.25 },
    })

    task.wait(1.75)
    loading:Destroy()

    local function destroy()
        if getgenv then
            getgenv().IceylandsDestroy = nil
        end

        if root then
            root:Destroy()
            root = nil
        end
    end

    local app = Window.new(root, {
        Config = Config,
        State = state,
        Toasts = toasts,
        Destroy = destroy,
    })

    app:AddTab("General", "Home", function(container)
        GeneralTab.Mount(container, {
            Config = Config,
            State = state,
            Toasts = toasts,
        })
    end)

    app:AddTab("Combat", "Lock", function() end)
    app:AddTab("Foraging", "Lock", function() end)
    app:SelectTab("General")

    if getgenv then
        getgenv().IceylandsDestroy = destroy
    end
end

return Main

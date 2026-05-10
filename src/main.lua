local Runtime = _G.IceylandsLoader

local Constants = Runtime.LoadModule("src/shared/Constants.lua")
local Guard = Runtime.LoadModule("src/core/Guard.lua")
local Config = Runtime.LoadModule("src/core/Config.lua")
local LoadingScreen = Runtime.LoadModule("src/ui/LoadingScreen.lua")
local Window = Runtime.LoadModule("src/ui/Window.lua")
local Notifications = Runtime.LoadModule("src/core/Notifications.lua")
local Performance = Runtime.LoadModule("src/core/Performance.lua")
local DemoWorld = Runtime.LoadModule("src/core/DemoWorld.lua")
local GeneralTab = Runtime.LoadModule("src/tabs/General.lua")
local DemoTab = Runtime.LoadModule("src/tabs/Demo.lua")
local ForagingTab = Runtime.LoadModule("src/tabs/Foraging.lua")
local SettingsTab = Runtime.LoadModule("src/tabs/Settings.lua")

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

local function getExistingDestroy()
    if getgenv then
        local genv = getgenv()
        if type(genv.IceylandsDestroy) == "function" then
            return genv.IceylandsDestroy
        end
    end

    return nil
end

local function hasExistingGui(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == Constants.GuiName then
            return true
        end
    end

    return false
end

local function cleanupExisting(parent, destroyExisting)
    if destroyExisting then
        pcall(destroyExisting)
    end

    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == Constants.GuiName then
            child:Destroy()
        end
    end
end

local function confirmReinject(parent)
    local promptGui = Instance.new("ScreenGui")
    promptGui.Name = Constants.GuiName .. "ReinjectPrompt"
    promptGui.IgnoreGuiInset = true
    promptGui.ResetOnSpawn = false
    promptGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    promptGui.Parent = parent

    local shade = Instance.new("Frame")
    shade.BackgroundColor3 = Color3.fromRGB(7, 13, 22)
    shade.BackgroundTransparency = 0.32
    shade.BorderSizePixel = 0
    shade.Size = UDim2.fromScale(1, 1)
    shade.Parent = promptGui

    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(390, 190)
    panel.BackgroundColor3 = Color3.fromRGB(28, 49, 76)
    panel.BackgroundTransparency = 0.08
    panel.Parent = shade
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(127, 174, 218)
    stroke.Transparency = 0.42
    stroke.Parent = panel

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(22, 18)
    title.Size = UDim2.new(1, -44, 0, 28)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(242, 248, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Iceylands is already injected"
    title.Parent = panel

    local body = Instance.new("TextLabel")
    body.BackgroundTransparency = 1
    body.Position = UDim2.fromOffset(22, 56)
    body.Size = UDim2.new(1, -44, 0, 54)
    body.Font = Enum.Font.Gotham
    body.TextSize = 14
    body.TextWrapped = true
    body.TextColor3 = Color3.fromRGB(190, 211, 232)
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.Text = "A running Iceylands session was found. Reinjecting will close the current UI and start a fresh one."
    body.Parent = panel

    local result = Instance.new("BindableEvent")

    local function button(text, x, color, value)
        local item = Instance.new("TextButton")
        item.Position = UDim2.new(1, x, 1, -58)
        item.Size = UDim2.fromOffset(116, 38)
        item.BackgroundColor3 = color
        item.BackgroundTransparency = 0.08
        item.Font = Enum.Font.GothamBold
        item.TextSize = 14
        item.TextColor3 = Color3.fromRGB(242, 248, 255)
        item.Text = text
        item.Parent = panel
        Instance.new("UICorner", item).CornerRadius = UDim.new(0, 7)
        item.MouseButton1Click:Connect(function()
            result:Fire(value)
        end)
    end

    button("Cancel", -258, Color3.fromRGB(54, 76, 101), false)
    button("Confirm", -134, Color3.fromRGB(75, 157, 255), true)

    local confirmed = result.Event:Wait()
    result:Destroy()
    promptGui:Destroy()
    return confirmed
end

function Main.Start()
    if not Guard.IsAllowed() then
        warn(Constants.Name .. " is not enabled for this experience.")
        return
    end

    local parent = getParent()
    local destroyExisting = getExistingDestroy()

    if destroyExisting or hasExistingGui(parent) then
        warn(Constants.Name .. " has already been injected.")

        if not confirmReinject(parent) then
            return
        end

        cleanupExisting(parent, destroyExisting)
    end

    local root = Instance.new("ScreenGui")
    root.Name = Constants.GuiName
    root.IgnoreGuiInset = true
    root.ResetOnSpawn = false
    root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    root.Parent = parent

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

    local app

    local function destroy()
        Performance.Restore()
        DemoWorld.Restore()

        if app then
            app:Destroy()
            app = nil
        end

        if getgenv then
            getgenv().IceylandsDestroy = nil
        end

        if root then
            root:Destroy()
            root = nil
        end
    end

    app = Window.new(root, {
        Config = Config,
        State = state,
        Toasts = toasts,
        Destroy = destroy,
        Root = root,
    })

    app:AddTab("General", "Home", function(container)
        GeneralTab.Mount(container, {
            Config = Config,
            State = state,
            Toasts = toasts,
        })
    end)

    app:AddTab("Combat", "Lock", function() end)
    app:AddTab("Demo", "Demo", function(container)
        DemoTab.Mount(container, {
            Config = Config,
            State = state,
            Toasts = toasts,
            Root = root,
        })
    end)
    app:AddTab("Foraging", "Foraging", function(container)
        ForagingTab.Mount(container, {
            Config = Config,
            State = state,
            Toasts = toasts,
        })
    end)
    app:AddTab("Settings", "Settings", function(container)
        SettingsTab.Mount(container, {
            Config = Config,
            State = state,
            Toasts = toasts,
            Destroy = destroy,
            Root = root,
            Window = app,
        })
    end, { Bottom = true })
    app:SelectTab("General")

    local perfOk, perfErr = pcall(function()
        Performance.SetRenderingDisabled(root, state.DisableRendering)
        Performance.SetFpsBoost(state.FpsBoost)
    end)

    if not perfOk then
        warn(Constants.Name .. " performance setup failed: " .. tostring(perfErr))
    end

    local hotkeyOk, hotkeyErr = pcall(function()
        return app:SetHotkey(state.ToggleKey)
    end)

    if not hotkeyOk then
        warn(Constants.Name .. " hotkey setup failed: " .. tostring(hotkeyErr))
    end

    pcall(function()
        DemoWorld.SetMovementDemo(state.MovementDemo)
        DemoWorld.SetOverlayDemo(root, state.OverlayDemo)
        DemoWorld.SetAutoCollectDemo(state.AutoCollectDemo, function(name)
            toasts:Push("Collected " .. name, "success")
        end)
    end)

    if getgenv then
        getgenv().IceylandsDestroy = destroy
    end
end

return Main

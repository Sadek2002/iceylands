local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Runtime = _G.IceylandsLoader
local Theme = Runtime.LoadModule("src/shared/Theme.lua")
local Assets = Runtime.LoadModule("src/shared/Assets.lua")
local Constants = Runtime.LoadModule("src/shared/Constants.lua")

local LoadingScreen = {}
LoadingScreen.__index = LoadingScreen

function LoadingScreen.new(root)
    local self = setmetatable({}, LoadingScreen)

    local blur = Instance.new("BlurEffect")
    blur.Name = "IceylandsBlur"
    blur.Size = 8
    blur.Parent = Lighting

    local overlay = Instance.new("Frame")
    overlay.Name = "LoadingOverlay"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(11, 25, 42)
    overlay.BackgroundTransparency = 0.32
    overlay.Parent = root

    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(420, 330)
    panel.BackgroundColor3 = Theme.Colors.Panel
    panel.BackgroundTransparency = 0.2
    panel.Parent = overlay
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Colors.Stroke
    stroke.Transparency = 0.45
    stroke.Parent = panel

    local iconImage = Assets.Get("SnowflakeLarge")
    local icon
    if iconImage then
        icon = Instance.new("ImageLabel")
        icon.Image = iconImage
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.fromOffset(88, 88)
    else
        icon = Instance.new("TextLabel")
        icon.BackgroundTransparency = 1
        icon.Font = Theme.FontBold
        icon.Text = Assets.Fallback.SnowflakeLarge
        icon.TextColor3 = Theme.Colors.AccentSoft
        icon.TextSize = 66
        icon.Size = UDim2.fromOffset(88, 88)
    end
    icon.AnchorPoint = Vector2.new(0.5, 0)
    icon.Position = UDim2.new(0.5, 0, 0, 36)
    icon.Parent = panel

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(0, 135)
    title.Size = UDim2.new(1, 0, 0, 34)
    title.Font = Theme.FontBold
    title.TextSize = 28
    title.TextColor3 = Theme.Colors.Text
    title.Text = Constants.Name
    title.Parent = panel

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Position = UDim2.fromOffset(0, 184)
    status.Size = UDim2.new(1, 0, 0, 22)
    status.Font = Theme.Font
    status.TextSize = 15
    status.TextColor3 = Theme.Colors.Text
    status.Text = "Loading..."
    status.Parent = panel

    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(70, 226)
    bar.Size = UDim2.new(1, -140, 0, 16)
    bar.BackgroundColor3 = Theme.Colors.Black
    bar.BackgroundTransparency = 0.35
    bar.Parent = panel
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = Theme.Colors.Accent
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local percent = Instance.new("TextLabel")
    percent.BackgroundTransparency = 1
    percent.Position = UDim2.fromOffset(0, 255)
    percent.Size = UDim2.new(1, 0, 0, 22)
    percent.Font = Theme.FontBold
    percent.TextSize = 14
    percent.TextColor3 = Theme.Colors.Text
    percent.Text = "0%"
    percent.Parent = panel

    self.Blur = blur
    self.Overlay = overlay
    self.Icon = icon
    self.Fill = fill
    self.Status = status
    self.Percent = percent
    self.Running = true

    task.spawn(function()
        while self.Running and icon.Parent do
            TweenService:Create(icon, TweenInfo.new(1.1, Enum.EasingStyle.Linear), { Rotation = icon.Rotation + 180 }):Play()
            task.wait(1.1)
        end
    end)

    return self
end

function LoadingScreen:Play(steps)
    task.spawn(function()
        local total = #steps
        for index, step in ipairs(steps) do
            local alpha = index / total
            self.Status.Text = step.label .. "..."
            self.Percent.Text = tostring(math.floor(alpha * 100)) .. "%"
            TweenService:Create(self.Fill, TweenInfo.new(step.duration), {
                Size = UDim2.fromScale(alpha, 1),
            }):Play()
            task.wait(step.duration)
        end
    end)
end

function LoadingScreen:Destroy()
    self.Running = false
    if self.Blur then
        self.Blur:Destroy()
    end
    if self.Overlay then
        self.Overlay:Destroy()
    end
end

return LoadingScreen

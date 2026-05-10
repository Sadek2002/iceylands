local TweenService = game:GetService("TweenService")
local Runtime = _G.IceylandsLoader
local Theme = Runtime.LoadModule("src/shared/Theme.lua")

local Notifications = {}
Notifications.__index = Notifications

function Notifications.new(root)
    local self = setmetatable({}, Notifications)

    local holder = Instance.new("Frame")
    holder.Name = "Toasts"
    holder.AnchorPoint = Vector2.new(1, 1)
    holder.Position = UDim2.new(1, -18, 1, -18)
    holder.Size = UDim2.fromOffset(280, 240)
    holder.BackgroundTransparency = 1
    holder.Parent = root

    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.VerticalAlignment = Enum.VerticalAlignment.Bottom
    list.Padding = UDim.new(0, 8)
    list.Parent = holder

    self.Holder = holder
    return self
end

function Notifications:Push(message, tone)
    local colors = Theme.Colors

    local toast = Instance.new("Frame")
    toast.BackgroundColor3 = colors.Panel
    toast.BackgroundTransparency = 0.12
    toast.Size = UDim2.fromOffset(260, 52)
    toast.Parent = self.Holder

    Instance.new("UICorner", toast).CornerRadius = Theme.Corner

    local stroke = Instance.new("UIStroke")
    stroke.Color = tone == "success" and colors.Success or colors.Stroke
    stroke.Transparency = 0.45
    stroke.Parent = toast

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(14, 0)
    label.Size = UDim2.new(1, -28, 1, 0)
    label.Font = Theme.Font
    label.TextSize = 14
    label.TextColor3 = colors.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = message
    label.Parent = toast

    toast.BackgroundTransparency = 1
    TweenService:Create(toast, TweenInfo.new(0.18), { BackgroundTransparency = 0.12 }):Play()

    task.delay(2.4, function()
        if toast.Parent then
            TweenService:Create(toast, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
            task.wait(0.2)
            toast:Destroy()
        end
    end)
end

return Notifications

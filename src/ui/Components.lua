local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Runtime = _G.IceylandsLoader
local Theme = Runtime.LoadModule("src/shared/Theme.lua")

local Components = {}

local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = radius or Theme.Corner
    item.Parent = parent
    return item
end

local function stroke(parent)
    local item = Instance.new("UIStroke")
    item.Color = Theme.Colors.Stroke
    item.Transparency = 0.65
    item.Parent = parent
    return item
end

function Components.Card(parent, height)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Theme.Colors.Panel
    card.BackgroundTransparency = 0.28
    card.Size = UDim2.new(1, 0, 0, height)
    card.Parent = parent
    corner(card)
    stroke(card)
    return card
end

function Components.Toggle(parent, title, description, initial, callback)
    local card = Components.Card(parent, 82)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.fromOffset(14, 12)
    titleLabel.Size = UDim2.new(1, -126, 0, 20)
    titleLabel.Font = Theme.FontBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = Theme.Colors.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Text = title
    titleLabel.Parent = card

    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.Position = UDim2.fromOffset(14, 36)
    desc.Size = UDim2.new(1, -126, 0, 34)
    desc.Font = Theme.Font
    desc.TextSize = 12
    desc.TextColor3 = Theme.Colors.Muted
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.TextWrapped = true
    desc.TextTruncate = Enum.TextTruncate.AtEnd
    desc.Text = description
    desc.Parent = card

    local button = Instance.new("TextButton")
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -14, 0.5, 0)
    button.Size = UDim2.fromOffset(52, 26)
    button.Text = ""
    button.AutoButtonColor = false
    button.BackgroundColor3 = initial and Theme.Colors.Accent or Theme.Colors.PanelLight
    button.Parent = card
    corner(button, UDim.new(1, 0))

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(20, 20)
    knob.Position = initial and UDim2.new(1, -23, 0.5, -10) or UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = Theme.Colors.Text
    knob.Parent = button
    corner(knob, UDim.new(1, 0))

    local enabled = initial
    button.MouseButton1Click:Connect(function()
        enabled = not enabled
        TweenService:Create(button, TweenInfo.new(0.16), {
            BackgroundColor3 = enabled and Theme.Colors.Accent or Theme.Colors.PanelLight,
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.16), {
            Position = enabled and UDim2.new(1, -23, 0.5, -10) or UDim2.fromOffset(3, 3),
        }):Play()
        callback(enabled)
    end)

    return card
end

function Components.Slider(parent, title, description, min, max, initial, callback)
    local card = Components.Card(parent, 102)
    local value = initial

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.fromOffset(14, 12)
    titleLabel.Size = UDim2.new(1, -100, 0, 20)
    titleLabel.Font = Theme.FontBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = Theme.Colors.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = title
    titleLabel.Parent = card

    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.Position = UDim2.fromOffset(14, 36)
    desc.Size = UDim2.new(1, -100, 0, 18)
    desc.Font = Theme.Font
    desc.TextSize = 12
    desc.TextColor3 = Theme.Colors.Muted
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Text = description
    desc.Parent = card

    local valueBox = Instance.new("TextLabel")
    valueBox.AnchorPoint = Vector2.new(1, 0)
    valueBox.Position = UDim2.new(1, -14, 0, 42)
    valueBox.Size = UDim2.fromOffset(66, 36)
    valueBox.BackgroundColor3 = Theme.Colors.Black
    valueBox.BackgroundTransparency = 0.35
    valueBox.Font = Theme.FontBold
    valueBox.TextSize = 14
    valueBox.TextColor3 = Theme.Colors.Text
    valueBox.Text = tostring(value)
    valueBox.Parent = card
    corner(valueBox, UDim.new(0, 6))
    stroke(valueBox)

    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(14, 72)
    bar.Size = UDim2.new(1, -106, 0, 5)
    bar.BackgroundColor3 = Theme.Colors.Black
    bar.BackgroundTransparency = 0.35
    bar.Parent = card
    corner(bar, UDim.new(1, 0))

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Theme.Colors.Accent
    fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
    fill.Parent = bar
    corner(fill, UDim.new(1, 0))

    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Size = UDim2.new(1, 0, 0, 28)
    hit.Position = UDim2.fromOffset(0, -11)
    hit.Parent = bar

    local dragging = false
    local function setFromX(x)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * alpha + 0.5)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        valueBox.Text = tostring(value)
        callback(value)
    end

    hit.MouseButton1Down:Connect(function(x)
        dragging = true
        setFromX(x)
    end)

    game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)

    return card
end

function Components.Button(parent, title, description, buttonText, callback)
    local card = Components.Card(parent, 84)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.fromOffset(14, 13)
    titleLabel.Size = UDim2.new(1, -166, 0, 20)
    titleLabel.Font = Theme.FontBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = Theme.Colors.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Text = title
    titleLabel.Parent = card

    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.Position = UDim2.fromOffset(14, 38)
    desc.Size = UDim2.new(1, -166, 0, 34)
    desc.Font = Theme.Font
    desc.TextSize = 12
    desc.TextColor3 = Theme.Colors.Muted
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.TextWrapped = true
    desc.TextTruncate = Enum.TextTruncate.AtEnd
    desc.Text = description
    desc.Parent = card

    local button = Instance.new("TextButton")
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -14, 0.5, 0)
    button.Size = UDim2.fromOffset(104, 36)
    button.BackgroundColor3 = Theme.Colors.Accent
    button.BackgroundTransparency = 0.05
    button.Font = Theme.FontBold
    button.TextSize = 13
    button.TextColor3 = Theme.Colors.Text
    button.Text = buttonText
    button.Parent = card
    corner(button, UDim.new(0, 6))

    button.MouseButton1Click:Connect(callback)
    return card
end

function Components.Keybind(parent, title, description, initial, callback, captureChanged)
    local card = Components.Card(parent, 84)
    local current = initial or "RightShift"
    local waiting = false
    local captureConnection

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.fromOffset(14, 13)
    titleLabel.Size = UDim2.new(1, -180, 0, 20)
    titleLabel.Font = Theme.FontBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = Theme.Colors.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Text = title
    titleLabel.Parent = card

    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.Position = UDim2.fromOffset(14, 38)
    desc.Size = UDim2.new(1, -180, 0, 34)
    desc.Font = Theme.Font
    desc.TextSize = 12
    desc.TextColor3 = Theme.Colors.Muted
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.TextWrapped = true
    desc.TextTruncate = Enum.TextTruncate.AtEnd
    desc.Text = description
    desc.Parent = card

    local button = Instance.new("TextButton")
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -14, 0.5, 0)
    button.Size = UDim2.fromOffset(118, 36)
    button.BackgroundColor3 = Theme.Colors.PanelLight
    button.BackgroundTransparency = 0.28
    button.Font = Theme.FontBold
    button.TextSize = 13
    button.TextColor3 = Theme.Colors.Text
    button.Text = current
    button.Parent = card
    corner(button, UDim.new(0, 6))
    stroke(button)

    local control = {}

    function control.SetValue(value)
        current = value or current
        button.Text = current
    end

    local function stopCapture()
        waiting = false
        if captureChanged then
            captureChanged(false)
        end

        if captureConnection then
            captureConnection:Disconnect()
            captureConnection = nil
        end
    end

    button.MouseButton1Click:Connect(function()
        if waiting then
            stopCapture()
            button.Text = current
            return
        end

        waiting = true
        button.Text = "Press key..."
        if captureChanged then
            captureChanged(true)
        end

        captureConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode == Enum.KeyCode.Unknown then
                return
            end

            stopCapture()
            control.SetValue(input.KeyCode.Name)
            callback(input.KeyCode.Name)
        end)
    end)

    return control
end

return Components

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Runtime = _G.IceylandsLoader
local Theme = Runtime.LoadModule("src/shared/Theme.lua")
local Assets = Runtime.LoadModule("src/shared/Assets.lua")
local Constants = Runtime.LoadModule("src/shared/Constants.lua")
local SnowflakeSymbol = utf8.char(0x2744)

local Window = {}
Window.__index = Window

local function makeDraggable(handle, target)
    local dragging = false
    local dragStart
    local startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function Window.new(root, services)
    local self = setmetatable({}, Window)
    self.Services = services
    self.Tabs = {}

    local frame = Instance.new("Frame")
    frame.Name = "MainWindow"
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.Size = UDim2.fromOffset(560, 430)
    frame.BackgroundColor3 = Theme.Colors.Panel
    frame.BackgroundTransparency = 0.14
    frame.Parent = root
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Colors.Stroke
    stroke.Transparency = 0.48
    stroke.Parent = frame

    local header = Instance.new("Frame")
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 56)
    header.Parent = frame
    makeDraggable(header, frame)

    local logo = Instance.new("TextLabel")
    logo.BackgroundTransparency = 1
    logo.Position = UDim2.fromOffset(18, 13)
    logo.Size = UDim2.fromOffset(28, 28)
    logo.Font = Theme.FontBold
    logo.Text = SnowflakeSymbol
    logo.TextSize = 23
    logo.TextColor3 = Theme.Colors.AccentSoft
    logo.Parent = header

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(52, 0)
    title.Size = UDim2.new(1, -140, 1, 0)
    title.Font = Theme.FontBold
    title.TextSize = 16
    title.TextColor3 = Theme.Colors.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = Constants.Name
    title.Parent = header

    local close = Instance.new("TextButton")
    close.AnchorPoint = Vector2.new(1, 0)
    close.Position = UDim2.new(1, -16, 0, 12)
    close.Size = UDim2.fromOffset(32, 32)
    close.BackgroundTransparency = 1
    close.Font = Theme.Font
    close.Text = "X"
    close.TextSize = 26
    close.TextColor3 = Theme.Colors.Text
    close.Parent = header

    local sidebar = Instance.new("Frame")
    sidebar.Position = UDim2.fromOffset(0, 56)
    sidebar.Size = UDim2.fromOffset(164, 314)
    sidebar.BackgroundColor3 = Theme.Colors.Black
    sidebar.BackgroundTransparency = 0.65
    sidebar.Parent = frame

    local tabList = Instance.new("UIListLayout")
    tabList.Padding = UDim.new(0, 8)
    tabList.SortOrder = Enum.SortOrder.LayoutOrder
    tabList.Parent = sidebar

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingTop = UDim.new(0, 10)
    tabPad.PaddingLeft = UDim.new(0, 14)
    tabPad.PaddingRight = UDim.new(0, 10)
    tabPad.Parent = sidebar

    local content = Instance.new("Frame")
    content.Position = UDim2.fromOffset(164, 56)
    content.Size = UDim2.new(1, -164, 1, -126)
    content.BackgroundTransparency = 1
    content.Parent = frame

    local footer = Instance.new("Frame")
    footer.AnchorPoint = Vector2.new(0, 1)
    footer.Position = UDim2.new(0, 0, 1, 0)
    footer.Size = UDim2.new(1, 0, 0, 60)
    footer.BackgroundColor3 = Theme.Colors.Black
    footer.BackgroundTransparency = 0.72
    footer.Parent = frame

    local iconButton = Instance.new("ImageButton")
    iconButton.Name = "MinimizedIcon"
    iconButton.AnchorPoint = Vector2.new(0.5, 0.5)
    iconButton.Position = UDim2.fromScale(0.5, 0.5)
    iconButton.Size = UDim2.fromOffset(68, 68)
    iconButton.BackgroundColor3 = Theme.Colors.Black
    iconButton.BackgroundTransparency = 0.08
    iconButton.Visible = false
    iconButton.Parent = root
    Instance.new("UICorner", iconButton).CornerRadius = UDim.new(1, 0)
    makeDraggable(iconButton, iconButton)

    local iconAsset = Assets.Get("SnowflakeCircleSmall")
    if iconAsset then
        iconButton.Image = iconAsset
    else
        iconButton.ImageTransparency = 1
        local fallback = Instance.new("TextLabel")
        fallback.BackgroundTransparency = 1
        fallback.Size = UDim2.fromScale(1, 1)
        fallback.Font = Theme.FontBold
        fallback.Text = SnowflakeSymbol
        fallback.TextSize = 34
        fallback.TextColor3 = Theme.Colors.AccentSoft
        fallback.Parent = iconButton
    end

    local footerScroll = Instance.new("ScrollingFrame")
    footerScroll.BackgroundTransparency = 1
    footerScroll.BorderSizePixel = 0
    footerScroll.Position = UDim2.fromOffset(14, 0)
    footerScroll.Size = UDim2.new(1, -28, 1, 0)
    footerScroll.CanvasSize = UDim2.fromOffset(0, 0)
    footerScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
    footerScroll.ScrollBarThickness = 3
    footerScroll.ScrollingDirection = Enum.ScrollingDirection.X
    footerScroll.Parent = footer

    local footerLayout = Instance.new("UIListLayout")
    footerLayout.FillDirection = Enum.FillDirection.Horizontal
    footerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    footerLayout.Padding = UDim.new(0, 12)
    footerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    footerLayout.Parent = footerScroll

    local function footerButton(text, callback, width)
        local button = Instance.new("TextButton")
        button.Size = UDim2.fromOffset(width or 142, 38)
        button.BackgroundColor3 = Theme.Colors.PanelLight
        button.BackgroundTransparency = 0.42
        button.Font = Theme.FontBold
        button.TextSize = 13
        button.TextColor3 = Theme.Colors.Text
        button.Text = text
        button.Parent = footerScroll
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
        button.MouseButton1Click:Connect(callback)
    end

    footerButton("Save Config", function()
        local ok, message = services.Config.Save(services.State)
        services.Toasts:Push(ok and ("Config saved: " .. message) or message, ok and "success" or "warn")
    end)

    footerButton("Load Config", function()
        services.State = services.Config.Load()
        services.Toasts:Push("Config loaded", "success")
    end)

    footerButton("Export Config", function()
        local json = services.Config.Export(services.State)
        local ok = services.Config.Copy(json)
        services.Toasts:Push(ok and "JSON copied" or json, ok and "success" or "warn")
    end)

    footerButton("Kill Script", function()
        if services.Toasts then
            services.Toasts:Push("Iceylands removed", "success")
            task.wait(0.15)
        end

        if services.Destroy then
            services.Destroy()
        end
    end, 128)

    close.MouseButton1Click:Connect(function()
        TweenService:Create(frame, TweenInfo.new(0.18), { Size = UDim2.fromOffset(520, 390), BackgroundTransparency = 1 }):Play()
        task.wait(0.18)
        frame.Visible = false
        iconButton.Visible = true
    end)

    iconButton.MouseButton1Click:Connect(function()
        frame.Visible = true
        frame.Size = UDim2.fromOffset(540, 410)
        frame.BackgroundTransparency = 0.3
        iconButton.Visible = false
        TweenService:Create(frame, TweenInfo.new(0.18), { Size = UDim2.fromOffset(560, 430), BackgroundTransparency = 0.14 }):Play()
    end)

    self.Root = root
    self.Frame = frame
    self.Sidebar = sidebar
    self.Content = content
    return self
end

function Window:AddTab(name, icon, mount)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 46)
    button.BackgroundColor3 = Theme.Colors.PanelLight
    button.BackgroundTransparency = 1
    button.Font = Theme.Font
    button.TextSize = 14
    button.TextColor3 = Theme.Colors.Muted
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Text = "   " .. name
    button.Parent = self.Sidebar
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)

    button.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)

    self.Tabs[name] = {
        Button = button,
        Mount = mount,
    }
end

function Window:SelectTab(name)
    local tab = self.Tabs[name]
    if not tab then
        return
    end

    for tabName, item in pairs(self.Tabs) do
        local selected = tabName == name
        item.Button.BackgroundTransparency = selected and 0.18 or 1
        item.Button.TextColor3 = selected and Theme.Colors.Text or Theme.Colors.Muted
    end

    self.Content:ClearAllChildren()

    local page = Instance.new("Frame")
    page.BackgroundTransparency = 1
    page.Position = UDim2.fromOffset(20, 14)
    page.Size = UDim2.new(1, -40, 1, -24)
    page.Parent = self.Content

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 34)
    title.Font = Theme.FontBold
    title.TextSize = 22
    title.TextColor3 = Theme.Colors.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = name
    title.Parent = page

    local list = Instance.new("ScrollingFrame")
    list.Position = UDim2.fromOffset(0, 48)
    list.Size = UDim2.new(1, 0, 1, -48)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ScrollBarThickness = 4
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.Parent = page

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = list

    tab.Mount(list)
end

return Window

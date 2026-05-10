local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Runtime = _G.IceylandsLoader
local TreeScanner = Runtime.LoadModule("src/core/TreeScanner.lua")

local DemoWorld = {
    FolderName = "IceylandsDemo",
    MovementConnection = nil,
    OverlayItems = {},
    AutoCollectRunning = false,
}

local function getCharacter()
    local player = Players.LocalPlayer
    return player and player.Character
end

local function getRoot()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getFolder()
    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = DemoWorld.FolderName
        folder.Parent = Workspace
    end

    return folder
end

local function makePart(name, position, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.Size = Vector3.new(2.5, 2.5, 2.5)
    part.Position = position
    part.Material = Enum.Material.Ice
    part.Color = color
    part.Parent = getFolder()
    return part
end

local function makeTreePoint(name, position)
    local part = makePart(name, position, Color3.fromRGB(106, 202, 255))
    part.Size = Vector3.new(1.25, 1.25, 1.25)
    part.Shape = Enum.PartType.Ball
    part.Material = Enum.Material.Neon
    part.Transparency = 0.12
    return part
end

function DemoWorld.EnsureObjects()
    local folder = getFolder()
    local root = getRoot()
    local origin = root and root.Position or Vector3.new(0, 8, 0)

    local count = 0
    for _, item in ipairs(folder:GetChildren()) do
        if item:GetAttribute("IceylandsDemoObject") then
            count += 1
        end
    end

    if count > 0 then
        return folder
    end

    local offsets = {
        Vector3.new(18, 1, 0),
        Vector3.new(-16, 1, 12),
        Vector3.new(8, 1, -20),
        Vector3.new(26, 1, 18),
        Vector3.new(-24, 1, -14),
    }

    for index, offset in ipairs(offsets) do
        local part = makePart("DemoCollectible" .. index, origin + offset, Color3.fromRGB(106, 202, 255))
        part:SetAttribute("IceylandsDemoObject", true)
        part:SetAttribute("Collected", false)
    end

    return folder
end

function DemoWorld.SpawnObjectsAtTreePositions(maxObjects)
    DemoWorld.ClearObjects()

    local folder = getFolder()
    local clusters = TreeScanner.GetClusters(maxObjects or 10)

    local created = 0
    for index, cluster in ipairs(clusters) do
        if created >= (maxObjects or 10) then
            break
        end

        local part = makeTreePoint("DemoTreePoint" .. index, cluster.Position)
        part:SetAttribute("IceylandsDemoObject", true)
        part:SetAttribute("Collected", false)
        part:SetAttribute("SourceTreeName", cluster.RawName)
        part.Parent = folder
        created += 1
    end

    if created == 0 then
        DemoWorld.EnsureObjects()
    end

    return created
end

function DemoWorld.ClearObjects()
    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if folder then
        folder:Destroy()
    end
end

function DemoWorld.GetCollectibles()
    local folder = DemoWorld.EnsureObjects()
    local items = {}

    for _, item in ipairs(folder:GetChildren()) do
        if item:IsA("BasePart") and item:GetAttribute("IceylandsDemoObject") and not item:GetAttribute("Collected") then
            table.insert(items, item)
        end
    end

    return items
end

function DemoWorld.GetNearestCollectible()
    local root = getRoot()
    if not root then
        return nil
    end

    local nearest
    local nearestDistance = math.huge

    for _, item in ipairs(DemoWorld.GetCollectibles()) do
        local distance = (root.Position - item.Position).Magnitude
        if distance < nearestDistance then
            nearest = item
            nearestDistance = distance
        end
    end

    return nearest, nearestDistance
end

function DemoWorld.SetMovementDemo(enabled)
    if DemoWorld.MovementConnection then
        DemoWorld.MovementConnection:Disconnect()
        DemoWorld.MovementConnection = nil
    end

    if not enabled then
        return
    end

    DemoWorld.EnsureObjects()

    DemoWorld.MovementConnection = RunService.RenderStepped:Connect(function(deltaTime)
        local root = getRoot()
        local target = DemoWorld.GetNearestCollectible()
        if not root or not target then
            return
        end

        local offset = target.Position - root.Position
        if offset.Magnitude <= 4 then
            return
        end

        local step = math.min(offset.Magnitude, 18 * deltaTime)
        root.CFrame = CFrame.new(root.Position + offset.Unit * step, target.Position)
    end)
end

function DemoWorld.SetOverlayDemo(rootGui, enabled)
    for _, item in ipairs(DemoWorld.OverlayItems) do
        if item then
            item:Destroy()
        end
    end
    table.clear(DemoWorld.OverlayItems)

    if not enabled then
        return
    end

    for _, part in ipairs(DemoWorld.GetCollectibles()) do
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "IceylandsDemoMarker"
        billboard.Adornee = part
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.fromOffset(140, 36)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.Parent = rootGui

        local label = Instance.new("TextLabel")
        label.BackgroundColor3 = Color3.fromRGB(20, 38, 60)
        label.BackgroundTransparency = 0.18
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextColor3 = Color3.fromRGB(242, 248, 255)
        label.Text = part.Name
        label.Parent = billboard
        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)

        table.insert(DemoWorld.OverlayItems, billboard)
    end
end

function DemoWorld.SetAutoCollectDemo(enabled, onCollect)
    DemoWorld.AutoCollectRunning = enabled
    if not enabled then
        return
    end

    DemoWorld.EnsureObjects()

    task.spawn(function()
        while DemoWorld.AutoCollectRunning do
            local root = getRoot()
            local target = DemoWorld.GetNearestCollectible()

            if not root or not target then
                task.wait(0.25)
                continue
            end

            local distance = (root.Position - target.Position).Magnitude
            if distance > 4 then
                root.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
                task.wait(0.25)
            else
                target:SetAttribute("Collected", true)
                target.Transparency = 0.75
                target.CanTouch = false
                target.CanQuery = false
                if onCollect then
                    onCollect(target.Name)
                end
                task.wait(0.4)
            end
        end
    end)
end

function DemoWorld.Restore()
    DemoWorld.SetMovementDemo(false)
    DemoWorld.SetOverlayDemo(nil, false)
    DemoWorld.SetAutoCollectDemo(false)
end

return DemoWorld

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local PathfindingService = game:GetService("PathfindingService")

local Runtime = _G.IceylandsLoader
local TreeScanner = Runtime.LoadModule("src/core/TreeScanner.lua")

local AxePriority = {
    woodAxe = 1,
    stoneAxe = 2,
    ironAxe = 3,
    gildedSteelAxe = 4,
    diamondAxe = 5,
    opalAxe = 6,
    voidMattock = 7,
}

local DemoWorld = {
    FolderName = "IceylandsDemo",
    MovementConnection = nil,
    OverlayItems = {},
    AutoCollectRunning = false,
    ClickInterval = 0.32,
    LastTreeClick = 0,
    CurrentMoveTree = nil,
    CurrentTPTree = nil,
    LastPathWarn = 0,
    ToastSink = nil,
}

local function getCharacter()
    local player = Players.LocalPlayer
    return player and player.Character
end

local function getRoot()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
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

local function flatDistance(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function toast(message, kind)
    if DemoWorld.ToastSink then
        DemoWorld.ToastSink(message, kind or "warn")
    else
        warn("Iceylands: " .. message)
    end
end

function DemoWorld.SetToastSink(callback)
    DemoWorld.ToastSink = callback
end

local function makePart(name, position, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.Size = Vector3.new(1.25, 1.25, 1.25)
    part.Position = position
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = 0.35
    part.Parent = getFolder()
    return part
end

local function makeTreePoint(tree, index)
    local part = makePart("TreeTarget" .. index, tree.Position, Color3.fromRGB(106, 202, 255))
    part.Shape = Enum.PartType.Ball
    part:SetAttribute("IceylandsDemoObject", true)
    part:SetAttribute("SourceTreeName", tree.Name or tree.RawName or "Tree")
    part:SetAttribute("TreeDistance", tree.Distance or 0)
    return part
end

function DemoWorld.EnsureObjects()
    return getFolder()
end

function DemoWorld.ClearObjects()
    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if folder then
        folder:Destroy()
    end
    DemoWorld.CurrentMoveTree = nil
    DemoWorld.CurrentTPTree = nil
end

function DemoWorld.SpawnObjectsAtTreePositions(maxObjects)
    DemoWorld.ClearObjects()

    local folder = getFolder()
    local trees = TreeScanner.GetClusters(maxObjects or 25)

    local created = 0
    for index, tree in ipairs(trees) do
        if created >= (maxObjects or 25) then
            break
        end
        local part = makeTreePoint(tree, index)
        part.Parent = folder
        created += 1
    end

    return created
end

local function findBestAxeIn(container)
    if not container then
        return nil, -math.huge
    end

    local bestTool
    local bestPriority = -math.huge

    for _, item in ipairs(container:GetChildren()) do
        if item:IsA("Tool") then
            local priority = AxePriority[item.Name]
            if priority and priority > bestPriority then
                bestTool = item
                bestPriority = priority
            end
        end
    end

    return bestTool, bestPriority
end

function DemoWorld.GetBestAxe()
    local player = Players.LocalPlayer
    if not player then
        return nil
    end

    local character = player.Character
    local backpack = player:FindFirstChild("Backpack")

    local backpackTool, backpackPriority = findBestAxeIn(backpack)
    local characterTool, characterPriority = findBestAxeIn(character)

    if characterTool and characterPriority >= backpackPriority then
        return characterTool
    end

    return backpackTool
end

function DemoWorld.EquipBestAxe()
    local tool = DemoWorld.GetBestAxe()
    if not tool then
        toast("No axe found in inventory/backpack.", "warn")
        return false
    end

    local character = getCharacter()
    if tool.Parent == character then
        return true
    end

    local humanoid = getHumanoid()
    if humanoid then
        humanoid:EquipTool(tool)
        return true
    end

    return false
end

local function getTrunk(tree)
    local inst = tree and tree.Instance
    if not inst or not inst.Parent then
        return nil
    end

    local trunk = tree.Trunk
    if trunk and trunk.Parent then
        return trunk
    end

    for _, child in ipairs(inst:GetDescendants()) do
        if child:IsA("BasePart") and string.lower(child.Name) == "trunk" then
            tree.Trunk = child
            return child
        end
    end

    return nil
end

local function isTreeLive(tree)
    return tree and tree.Instance and TreeScanner.IsLiveTree(tree)
end

local function getStandPosition(tree)
    local root = getRoot()
    local trunk = getTrunk(tree)
    if not root or not trunk then
        return nil
    end

    local base = Vector3.new(trunk.Position.X, trunk.Position.Y - trunk.Size.Y / 2 + 2.5, trunk.Position.Z)
    local away = root.Position - base
    away = Vector3.new(away.X, 0, away.Z)
    if away.Magnitude < 1 then
        away = Vector3.new(1, 0, 0)
    end

    return base + away.Unit * math.max(4.5, math.min(7, (trunk.Size.X + trunk.Size.Z) * 0.25))
end

local function getNearestTree(exclude, forceRefresh)
    local trees = TreeScanner.GetClusters(25, forceRefresh)
    local root = getRoot()
    local bestTree
    local bestDistance = math.huge

    for _, tree in ipairs(trees) do
        if tree ~= exclude and isTreeLive(tree) then
            local trunk = getTrunk(tree)
            local pos = trunk and trunk.Position or tree.Position
            if root and pos then
                local d = flatDistance(root.Position, pos)
                if d < bestDistance then
                    bestDistance = d
                    bestTree = tree
                end
            elseif not bestTree then
                bestTree = tree
            end
        end
    end

    return bestTree
end

function DemoWorld.GetCollectibles()
    return TreeScanner.GetClusters(30)
end

function DemoWorld.GetNearestCollectible()
    local tree = getNearestTree()
    return tree, tree and tree.Distance or nil
end

local function pressLeftClick(tree)
    local camera = Workspace.CurrentCamera
    local x, y

    if camera and tree then
        local trunk = getTrunk(tree)
        if trunk then
            local screenPos, visible = camera:WorldToViewportPoint(trunk.Position)
            if visible then
                x = screenPos.X
                y = screenPos.Y
            end
        end
    end

    if mouse1click then
        pcall(mouse1click)
        return
    end

    if mouse1press and mouse1release then
        pcall(mouse1press)
        task.wait(0.03)
        pcall(mouse1release)
        return
    end

    local viewportSize = camera and camera.ViewportSize or Vector2.new(800, 600)
    x = x or (viewportSize.X / 2)
    y = y or (viewportSize.Y / 2)

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

function DemoWorld.ActivateHeldAxe(tree)
    local player = Players.LocalPlayer
    local character = player and player.Character
    local tool = DemoWorld.GetBestAxe()

    if not tool then
        return false
    end

    if character and tool.Parent ~= character then
        DemoWorld.EquipBestAxe()
        character = player and player.Character
        tool = DemoWorld.GetBestAxe()
    end

    if not tool or tool.Parent ~= character then
        return false
    end

    pcall(function()
        tool:Activate()
    end)

    pressLeftClick(tree)
    return true
end

local function faceTree(tree)
    local root = getRoot()
    local trunk = getTrunk(tree)
    if root and trunk then
        root.CFrame = CFrame.new(root.Position, Vector3.new(trunk.Position.X, root.Position.Y, trunk.Position.Z))
    end
end

local function chopTree(tree)
    if not isTreeLive(tree) then
        return false
    end

    DemoWorld.EquipBestAxe()
    faceTree(tree)
    DemoWorld.ActivateHeldAxe(tree)
    return true
end

local function computePath(toPosition)
    local root = getRoot()
    if not root or not toPosition then
        return nil
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 6,
    })

    local ok = pcall(function()
        path:ComputeAsync(root.Position, toPosition)
    end)

    if ok and path.Status == Enum.PathStatus.Success then
        return path:GetWaypoints()
    end

    return nil
end

local function shouldJumpForStep(root)
    local humanoid = getHumanoid()
    if not humanoid then
        return false
    end

    local state = humanoid:GetState()
    if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
        return false
    end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { getCharacter() }
    params.FilterType = Enum.RaycastFilterType.Exclude

    local forward = root.CFrame.LookVector
    local lowOrigin = root.Position + Vector3.new(0, -1.4, 0)
    local lowHit = Workspace:Raycast(lowOrigin, forward * 3, params)
    if not lowHit then
        return false
    end

    local highOrigin = root.Position + Vector3.new(0, 2.4, 0)
    local highHit = Workspace:Raycast(highOrigin, forward * 3, params)
    return highHit == nil
end

local function movementTick(state)
    local root = getRoot()
    local humanoid = getHumanoid()
    if not root or not humanoid then
        return
    end

    if not state.Tree or not isTreeLive(state.Tree) then
        if os.clock() < (state.NextScanTime or 0) then
            return
        end
        state.Tree = getNearestTree(nil, true)
        state.NextScanTime = os.clock() + 1.0
        state.Waypoints = nil
        state.Index = 1
        state.LastPathTime = 0
        state.LastPos = root.Position
        state.StuckSince = os.clock()
    end

    local tree = state.Tree
    if not tree then
        return
    end

    local trunk = getTrunk(tree)
    local stand = getStandPosition(tree)
    if not trunk or not stand then
        state.Tree = nil
        return
    end

    local flatToTrunk = flatDistance(root.Position, trunk.Position)
    local yDiff = math.abs(root.Position.Y - (trunk.Position.Y - trunk.Size.Y / 2 + 2.5))

    if flatToTrunk <= 8 and yDiff <= 8 then
        humanoid:Move(Vector3.zero, false)
        faceTree(tree)
        if os.clock() - DemoWorld.LastTreeClick >= DemoWorld.ClickInterval then
            DemoWorld.LastTreeClick = os.clock()
            chopTree(tree)
        end
        return
    end

    if not state.Waypoints or not state.Waypoints[state.Index] or os.clock() - (state.LastPathTime or 0) > 4 then
        state.Waypoints = computePath(stand)
        state.Index = 2
        state.LastPathTime = os.clock()

        if not state.Waypoints then
            if os.clock() - DemoWorld.LastPathWarn > 4 then
                DemoWorld.LastPathWarn = os.clock()
                toast("Can't pathfind to nearest tree, trying another.", "warn")
            end
            state.Tree = nil
            state.NextScanTime = os.clock() + 1.0
            return
        end
    end

    local waypoint = state.Waypoints[state.Index]
    if not waypoint then
        state.Waypoints = nil
        return
    end

    local target = waypoint.Position
    local flatToWaypoint = flatDistance(root.Position, target)
    if flatToWaypoint < 3.5 then
        state.Index += 1
        return
    end

    humanoid:MoveTo(target)

    if waypoint.Action == Enum.PathWaypointAction.Jump and os.clock() - (state.LastJump or 0) > 0.8 then
        state.LastJump = os.clock()
        humanoid.Jump = true
    end

    if os.clock() - (state.LastStuckCheck or 0) > 0.5 then
        local moved = (root.Position - (state.LastPos or root.Position)).Magnitude
        if moved < 0.8 then
            if os.clock() - (state.StuckSince or os.clock()) > 1.25 then
                state.Waypoints = nil
                state.LastPathTime = 0
                state.StuckSince = os.clock()
            end
        else
            state.StuckSince = os.clock()
        end
        state.LastPos = root.Position
        state.LastStuckCheck = os.clock()
    end
end

function DemoWorld.SetMovementDemo(enabled)
    if DemoWorld.MovementConnection then
        DemoWorld.MovementConnection:Disconnect()
        DemoWorld.MovementConnection = nil
    end

    if not enabled then
        DemoWorld.CurrentMoveTree = nil
        return
    end

    DemoWorld.EquipBestAxe()
    if TreeScanner.RefreshCache then
        TreeScanner.RefreshCache(25)
    end
    local state = {
        Tree = nil,
        Waypoints = nil,
        Index = 1,
        LastPathTime = 0,
        LastPos = getRoot() and getRoot().Position or Vector3.zero,
        StuckSince = os.clock(),
    }

    DemoWorld.MovementConnection = RunService.Heartbeat:Connect(function()
        movementTick(state)
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

    local parent = rootGui or Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    for index, tree in ipairs(TreeScanner.GetClusters(25)) do
        local marker = makeTreePoint(tree, index)
        marker.Transparency = 1

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "IceylandsTreeMarker"
        billboard.Adornee = marker
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.fromOffset(160, 34)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.Parent = parent

        local label = Instance.new("TextLabel")
        label.BackgroundColor3 = Color3.fromRGB(20, 38, 60)
        label.BackgroundTransparency = 0.18
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextColor3 = Color3.fromRGB(242, 248, 255)
        label.Text = string.format("%s • %.0f studs", tree.Name or "Tree", tree.Distance or 0)
        label.Parent = billboard
        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)

        table.insert(DemoWorld.OverlayItems, billboard)
        table.insert(DemoWorld.OverlayItems, marker)
    end
end

local function teleportBesideTree(tree)
    local root = getRoot()
    local trunk = getTrunk(tree)
    if not root or not trunk then
        return false
    end

    local stand = getStandPosition(tree)
    if not stand then
        return false
    end

    root.CFrame = CFrame.new(stand + Vector3.new(0, 2.5, 0), Vector3.new(trunk.Position.X, stand.Y + 2.5, trunk.Position.Z))
    return true
end

function DemoWorld.SetAutoCollectDemo(enabled, onCollect)
    DemoWorld.AutoCollectRunning = enabled
    if not enabled then
        DemoWorld.CurrentTPTree = nil
        return
    end

    DemoWorld.EquipBestAxe()

    task.spawn(function()
        while DemoWorld.AutoCollectRunning do
            local root = getRoot()
            if not root then
                task.wait(0.2)
                continue
            end

            if not DemoWorld.CurrentTPTree or not isTreeLive(DemoWorld.CurrentTPTree) then
                DemoWorld.CurrentTPTree = getNearestTree(nil, true)
                if DemoWorld.CurrentTPTree and onCollect then
                    onCollect((DemoWorld.CurrentTPTree.Name or "Tree") .. " target", nil)
                end
            end

            local tree = DemoWorld.CurrentTPTree
            if not tree then
                task.wait(1.0)
                continue
            end

            local trunk = getTrunk(tree)
            if not trunk then
                DemoWorld.CurrentTPTree = nil
                continue
            end

            local distance = flatDistance(root.Position, trunk.Position)
            if distance > 8 then
                teleportBesideTree(tree)
                task.wait(0.25)
            else
                if os.clock() - DemoWorld.LastTreeClick >= DemoWorld.ClickInterval then
                    DemoWorld.LastTreeClick = os.clock()
                    chopTree(tree)
                end
                task.wait(0.08)
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

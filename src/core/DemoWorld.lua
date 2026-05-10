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
    ClickInterval = 0.30,
    LastTreeClick = 0,
    CurrentTPTree = nil,
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

function DemoWorld.EnsureObjects()
    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = DemoWorld.FolderName
        folder.Parent = Workspace
    end
    return folder
end

function DemoWorld.ClearObjects()
    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if folder then
        folder:Destroy()
    end
    DemoWorld.CurrentTPTree = nil
end

function DemoWorld.SpawnObjectsAtTreePositions(maxObjects)
    local trees = TreeScanner.GetClusters(maxObjects or 25, true)
    return #trees
end

local function findBestAxeIn(container)
    if not container then
        return nil, -math.huge
    end

    local bestTool, bestPriority = nil, -math.huge
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

    local backpackTool, backpackPriority = findBestAxeIn(player:FindFirstChild("Backpack"))
    local characterTool, characterPriority = findBestAxeIn(player.Character)

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
    local inst = tree and (tree.Instance or tree.Container)
    if not inst or not inst.Parent then
        return nil
    end

    if tree.Trunk and tree.Trunk.Parent then
        return tree.Trunk
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

local function groundAt(x, z, extraIgnore)
    local ignore = { getCharacter() }
    if extraIgnore then
        for _, obj in ipairs(extraIgnore) do
            table.insert(ignore, obj)
        end
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore

    local hit = Workspace:Raycast(Vector3.new(x, 180, z), Vector3.new(0, -320, 0), params)
    if hit and hit.Instance and hit.Instance.CanCollide then
        return hit.Position
    end
    return nil
end

local function getStandPosition(tree)
    local root = getRoot()
    local trunk = getTrunk(tree)
    if not root or not trunk then
        return nil
    end

    local base = Vector3.new(trunk.Position.X, trunk.Position.Y - trunk.Size.Y / 2 + 2.8, trunk.Position.Z)
    local radius = math.clamp(math.max(trunk.Size.X, trunk.Size.Z) * 0.5 + 3.5, 5, 9)
    local dirs = {
        Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
        Vector3.new(1, 0, 1).Unit, Vector3.new(1, 0, -1).Unit,
        Vector3.new(-1, 0, 1).Unit, Vector3.new(-1, 0, -1).Unit,
    }

    local best, bestScore = nil, math.huge
    for _, dir in ipairs(dirs) do
        local wanted = base + dir * radius
        local ground = groundAt(wanted.X, wanted.Z, { trunk })
        if ground and math.abs(ground.Y - base.Y) <= 10 then
            local stand = Vector3.new(wanted.X, ground.Y + 2.8, wanted.Z)
            local score = flatDistance(root.Position, stand)
            if score < bestScore then
                best = stand
                bestScore = score
            end
        end
    end

    if best then
        return best
    end

    local away = root.Position - base
    away = Vector3.new(away.X, 0, away.Z)
    if away.Magnitude < 1 then
        away = Vector3.new(1, 0, 0)
    end
    return base + away.Unit * radius
end

local function getNearestTree(forceRefresh)
    local root = getRoot()
    if not root then
        return nil
    end

    local trees = TreeScanner.GetClusters(40, forceRefresh)
    local best, bestDistance = nil, math.huge
    for _, tree in ipairs(trees) do
        if isTreeLive(tree) then
            local trunk = getTrunk(tree)
            local pos = trunk and trunk.Position or tree.Position
            if pos then
                local d = flatDistance(root.Position, pos)
                if d < bestDistance then
                    best = tree
                    bestDistance = d
                end
            end
        end
    end
    return best
end

function DemoWorld.GetCollectibles()
    return TreeScanner.GetClusters(30)
end

function DemoWorld.GetNearestCollectible()
    local tree = getNearestTree(false)
    return tree, tree and tree.Distance or nil
end

local function pressLeftClick(tree)
    if mouse1click then
        pcall(mouse1click)
        return
    end

    if mouse1press and mouse1release then
        pcall(mouse1press)
        task.wait(0.025)
        pcall(mouse1release)
        return
    end

    local camera = Workspace.CurrentCamera
    local x, y
    local trunk = getTrunk(tree)
    if camera and trunk then
        local screenPos, visible = camera:WorldToViewportPoint(trunk.Position)
        if visible then
            x, y = screenPos.X, screenPos.Y
        end
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
    local character = getCharacter()
    local tool = DemoWorld.GetBestAxe()
    if not tool then
        return false
    end
    if character and tool.Parent ~= character then
        DemoWorld.EquipBestAxe()
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
    return DemoWorld.ActivateHeldAxe(tree)
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
        WaypointSpacing = 7,
    })

    local ok = pcall(function()
        path:ComputeAsync(root.Position, toPosition)
    end)

    if ok and path.Status == Enum.PathStatus.Success then
        return path:GetWaypoints()
    end
    return nil
end

local function moveDirectOrPath(state, humanoid, root, target)
    if not target then
        return
    end

    if flatDistance(root.Position, target) < 4 then
        return
    end

    if not state.Waypoints or not state.Waypoints[state.Index] or os.clock() - (state.LastPathTime or 0) > 5 then
        state.Waypoints = computePath(target)
        state.Index = 2
        state.LastPathTime = os.clock()
    end

    if state.Waypoints and state.Waypoints[state.Index] then
        local wp = state.Waypoints[state.Index]
        if flatDistance(root.Position, wp.Position) < 5 then
            state.Index += 1
            wp = state.Waypoints[state.Index]
        end
        if wp then
            humanoid:MoveTo(wp.Position)
            if wp.Action == Enum.PathWaypointAction.Jump and os.clock() - (state.LastJump or 0) > 0.9 then
                state.LastJump = os.clock()
                humanoid.Jump = true
            end
            return
        end
    end

    humanoid:MoveTo(target)
end

local function stuckCheck(state, humanoid, root)
    if os.clock() - (state.LastStuckCheck or 0) < 0.65 then
        return
    end
    state.LastStuckCheck = os.clock()

    local last = state.LastPos or root.Position
    local moved = (root.Position - last).Magnitude
    state.LastPos = root.Position

    if moved < 0.45 then
        state.StuckCount = (state.StuckCount or 0) + 1
    else
        state.StuckCount = 0
    end

    if (state.StuckCount or 0) >= 3 then
        state.Waypoints = nil
        state.LastPathTime = 0
        state.StuckCount = 0
        if os.clock() - (state.LastJump or 0) > 1.2 then
            state.LastJump = os.clock()
            humanoid.Jump = true
        end
    end
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
        state.Tree = getNearestTree(true)
        state.NextScanTime = os.clock() + 1.5
        state.Waypoints = nil
        state.Index = 2
        state.LastPathTime = 0
        state.LastPos = root.Position
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

    local trunkBaseY = trunk.Position.Y - trunk.Size.Y / 2 + 2.8
    local flatToTrunk = flatDistance(root.Position, trunk.Position)
    local yDiff = math.abs(root.Position.Y - trunkBaseY)

    if flatToTrunk <= 10 and yDiff <= 8 then
        humanoid:Move(Vector3.zero, false)
        faceTree(tree)
        if os.clock() - DemoWorld.LastTreeClick >= DemoWorld.ClickInterval then
            DemoWorld.LastTreeClick = os.clock()
            if not chopTree(tree) then
                state.Tree = nil
            end
        end
        return
    end

    moveDirectOrPath(state, humanoid, root, stand)
    stuckCheck(state, humanoid, root)
end

function DemoWorld.SetMovementDemo(enabled)
    if DemoWorld.MovementConnection then
        DemoWorld.MovementConnection:Disconnect()
        DemoWorld.MovementConnection = nil
    end

    if not enabled then
        return
    end

    DemoWorld.EquipBestAxe()
    TreeScanner.RefreshCache(40)

    local state = {
        Tree = nil,
        Waypoints = nil,
        Index = 2,
        LastPathTime = 0,
        LastPos = getRoot() and getRoot().Position or Vector3.zero,
        NextScanTime = 0,
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

    root.CFrame = CFrame.new(stand + Vector3.new(0, 1.5, 0), Vector3.new(trunk.Position.X, stand.Y + 1.5, trunk.Position.Z))
    return true
end

function DemoWorld.SetAutoCollectDemo(enabled, onCollect)
    DemoWorld.AutoCollectRunning = enabled
    if not enabled then
        DemoWorld.CurrentTPTree = nil
        return
    end

    DemoWorld.EquipBestAxe()
    TreeScanner.RefreshCache(40)

    task.spawn(function()
        while DemoWorld.AutoCollectRunning do
            local root = getRoot()
            if not root then
                task.wait(0.2)
                continue
            end

            if not DemoWorld.CurrentTPTree or not isTreeLive(DemoWorld.CurrentTPTree) then
                DemoWorld.CurrentTPTree = getNearestTree(true)
                if DemoWorld.CurrentTPTree and onCollect then
                    onCollect((DemoWorld.CurrentTPTree.Name or "Tree") .. " selected", nil)
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
                task.wait(0.15)
                continue
            end

            if flatDistance(root.Position, trunk.Position) > 10 then
                teleportBesideTree(tree)
                task.wait(0.18)
            else
                faceTree(tree)
                if os.clock() - DemoWorld.LastTreeClick >= DemoWorld.ClickInterval then
                    DemoWorld.LastTreeClick = os.clock()
                    if not chopTree(tree) then
                        DemoWorld.CurrentTPTree = nil
                    end
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

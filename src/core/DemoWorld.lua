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

local removeDemoAxe
local getLiveTreeForMarker
local getFlatDistance

local DemoWorld = {
    FolderName = "IceylandsDemo",
    MovementConnection = nil,
    OverlayItems = {},
    AutoCollectRunning = false,
    HitsRequired = 3,
    ClickInterval = 0.22,
    LastTreeClick = 0,
    CurrentMoveTarget = nil,
    CurrentTeleportTarget = nil,
    MoveToIssuedAt = 0,
    PathWaypoints = nil,
    PathIndex = 1,
    PathTarget = nil,
    LastPathCompute = 0,
    LastPathFailToast = 0,
    LastStuckCheck = 0,
    LastStuckPosition = nil,
    StuckSince = nil,
    JumpIssuedAt = 0,
    ToastSink = nil,
    TargetSearchInterval = 0.6,
    LastTargetSearch = 0,
    EquipIssuedAt = 0,
}

local function isLiveTarget(target)
    if not target or not target.Parent or target:GetAttribute("Collected") then
        return false
    end

    local sourcePath = target:GetAttribute("SourceTreePath")
    if sourcePath and sourcePath ~= "" then
        return getLiveTreeForMarker(target) ~= nil
    end

    local hitsRemaining = target:GetAttribute("HitsRemaining")
    return hitsRemaining == nil or hitsRemaining > 0
end

local function equipBestAxeThrottled(force)
    if force or os.clock() - DemoWorld.EquipIssuedAt >= 1.0 then
        DemoWorld.EquipIssuedAt = os.clock()
        removeDemoAxe()
        DemoWorld.EquipBestAxe()
    end
end

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

function removeDemoAxe()
    local player = Players.LocalPlayer
    local character = player and player.Character
    local backpack = player and player:FindFirstChild("Backpack")
    local workspaceCharacter = player and Workspace:FindFirstChild(player.Name)

    for _, container in ipairs({ character, backpack, workspaceCharacter, Workspace }) do
        if container then
            for _, item in ipairs(container:GetDescendants()) do
                if item.Name == "Iceylands Demo Axe" then
                    item:Destroy()
                end
            end
        end
    end
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

local function resolveWorkspacePath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    local current = game
    for segment in string.gmatch(path, "[^%.]+") do
        if segment == "game" then
            current = game
        elseif segment == "Workspace" or segment == "workspace" then
            current = Workspace
        elseif current then
            current = current:FindFirstChild(segment)
        end

        if not current then
            return nil
        end
    end

    return current
end

local function getInstancePosition(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance.Position
    end

    if instance:IsA("Model") then
        local base = instance:FindFirstChild(instance.Name, true)
        if base and base:IsA("BasePart") then
            return base.Position
        end

        local trunk = instance:FindFirstChild("trunk", true)
        if trunk and trunk:IsA("BasePart") then
            -- Use the trunk X/Z but keep the position near the base so we do not walk onto leaves.
            return Vector3.new(trunk.Position.X, math.max(trunk.Position.Y - (trunk.Size.Y * 0.5), trunk.Position.Y - 12), trunk.Position.Z)
        end

        local ok, pivot = pcall(function()
            return instance:GetPivot()
        end)
        if ok and pivot then
            return pivot.Position
        end
    end

    local part = instance:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

function getLiveTreeForMarker(marker)
    if not marker then
        return nil
    end

    local path = marker:GetAttribute("SourceTreePath")
    local tree = resolveWorkspacePath(path)
    if tree and tree.Parent then
        return tree
    end

    return nil
end

local function getTreePosition(marker)
    local tree = getLiveTreeForMarker(marker)
    return getInstancePosition(tree) or (marker and marker.Position) or nil
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
        part:SetAttribute("HitsRemaining", DemoWorld.HitsRequired)
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
        part:SetAttribute("HitsRemaining", DemoWorld.HitsRequired)
        part:SetAttribute("SourceTreeName", cluster.RawName)
        part:SetAttribute("SourceTreePath", cluster.Path or "")
        part.Parent = folder
        created += 1
    end

    -- Do not create fake/demo trees when no real tree locations are found.
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
    removeDemoAxe()

    local tool = DemoWorld.GetBestAxe()
    if not tool then
        warn("Iceylands: no test axe found in inventory/backpack.")
        return false
    end

    local character = getCharacter()
    if tool.Parent == character then
        return true
    end

    local humanoid = getHumanoid()
    if humanoid then
        humanoid:EquipTool(tool)
        return tool.Parent == character
    end

    return false
end

-- Backwards-compatible name used by older Foraging.lua builds.
-- This now equips the best real test axe instead of creating a demo axe.
function DemoWorld.EnsureDemoAxe()
    return DemoWorld.EquipBestAxe()
end

local function getTargetPart(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance
    end

    if instance:IsA("Model") then
        local preferred
        for _, part in ipairs(instance:GetDescendants()) do
            if part:IsA("BasePart") then
                local n = string.lower(part.Name)
                if string.find(n, "trunk", 1, true) or string.find(n, "log", 1, true) or string.find(n, "wood", 1, true) then
                    return part
                end
                preferred = preferred or part
            end
        end
        return preferred
    end

    return instance:FindFirstChildWhichIsA("BasePart", true)
end

function DemoWorld.ActivateHeldAxe(target)
    local player = Players.LocalPlayer
    local character = player and player.Character

    removeDemoAxe()
    if not DemoWorld.EquipBestAxe() then
        return false
    end

    character = player and player.Character
    local tool = DemoWorld.GetBestAxe()
    if not tool or tool.Parent ~= character then
        return false
    end

    tool:SetAttribute("LastDemoTarget", target and target.Name or "")
    tool:SetAttribute("DemoSwingCount", (tool:GetAttribute("DemoSwingCount") or 0) + 1)

    pcall(function()
        tool:Activate()
    end)

    -- Some axe tools only chop when their internal remotes are fired. Try common
    -- RemoteEvent/RemoteFunction descendants with a few safe argument shapes.
    for _, remote in ipairs(tool:GetDescendants()) do
        if remote:IsA("RemoteEvent") then
            pcall(function() remote:FireServer(target) end)
            pcall(function() remote:FireServer(target, target and target.Position) end)
            pcall(function() remote:FireServer("hit", target) end)
            pcall(function() remote:FireServer("swing", target) end)
        elseif remote:IsA("RemoteFunction") then
            pcall(function() remote:InvokeServer(target) end)
            pcall(function() remote:InvokeServer(target, target and target.Position) end)
            pcall(function() remote:InvokeServer("hit", target) end)
            pcall(function() remote:InvokeServer("swing", target) end)
        end
    end

    return true
end


local function pressLeftClick(target)
    local camera = Workspace.CurrentCamera
    local x, y = 400, 300

    if camera then
        local viewportSize = camera.ViewportSize
        x = viewportSize.X / 2
        y = viewportSize.Y / 2

        local targetPart = getTargetPart(target)
        if targetPart then
            local screenPoint, onScreen = camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                x = screenPoint.X
                y = screenPoint.Y
            end
        end
    end

    local clicked = false

    if type(mouse1click) == "function" then
        clicked = pcall(mouse1click) or clicked
    end

    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        clicked = pcall(function()
            mouse1press()
            task.wait(0.05)
            mouse1release()
        end) or clicked
    end

    clicked = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end) or clicked

    return clicked
end

local function damageDemoTree(target, onCollect)
    if not target or target:GetAttribute("Collected") then
        return false
    end

    local sourceTree = getLiveTreeForMarker(target)
    local clickTarget = getTargetPart(sourceTree) or getTargetPart(target) or sourceTree or target

    equipBestAxeThrottled(false)
    pressLeftClick(clickTarget)
    DemoWorld.ActivateHeldAxe(clickTarget)

    if target:GetAttribute("SourceTreePath") and not getLiveTreeForMarker(target) then
        target:SetAttribute("Collected", true)
        target:Destroy()
        if onCollect then
            onCollect(target.Name, 0)
        end
        return true
    end

    -- Demo fallback only: when there is no real source tree, keep the older hit-counter behavior.
    if not target:GetAttribute("SourceTreePath") or target:GetAttribute("SourceTreePath") == "" then
        local hitsRemaining = target:GetAttribute("HitsRemaining")
        if type(hitsRemaining) ~= "number" then
            hitsRemaining = DemoWorld.HitsRequired
        end

        hitsRemaining -= 1
        target:SetAttribute("HitsRemaining", hitsRemaining)

        if onCollect then
            onCollect(target.Name, hitsRemaining)
        end

        if hitsRemaining <= 0 then
            target:SetAttribute("Collected", true)
            target.Transparency = 1
            target.CanTouch = false
            target.CanQuery = false
            target.CanCollide = false
        else
            target.Transparency = math.clamp(0.12 + ((DemoWorld.HitsRequired - hitsRemaining) * 0.16), 0.12, 0.85)
        end
    end

    return true
end

function DemoWorld.ClearObjects()
    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if folder then
        folder:Destroy()
    end
end

function DemoWorld.GetCollectibles()
    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if not folder then
        DemoWorld.SpawnObjectsAtTreePositions(10)
        folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    end

    local items = {}
    if not folder then
        return items
    end

    for _, item in ipairs(folder:GetChildren()) do
        if item:IsA("BasePart") and item:GetAttribute("IceylandsDemoObject") and not item:GetAttribute("Collected") then
            local sourcePath = item:GetAttribute("SourceTreePath")
            if sourcePath and sourcePath ~= "" and not getLiveTreeForMarker(item) then
                item:SetAttribute("Collected", true)
                item:Destroy()
            else
                table.insert(items, item)
            end
        end
    end

    if #items == 0 then
        DemoWorld.SpawnObjectsAtTreePositions(10)
        folder = Workspace:FindFirstChild(DemoWorld.FolderName)
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                if item:IsA("BasePart") and item:GetAttribute("IceylandsDemoObject") and not item:GetAttribute("Collected") then
                    table.insert(items, item)
                end
            end
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
        local distance = getFlatDistance(root.Position, item.Position)
        if distance < nearestDistance then
            nearest = item
            nearestDistance = distance
        end
    end

    return nearest, nearestDistance
end


local function notifyWarn(message)
    if DemoWorld.ToastSink then
        pcall(DemoWorld.ToastSink, message, "warn")
    else
        warn("Iceylands: " .. message)
    end
end

function DemoWorld.SetToastSink(callback)
    DemoWorld.ToastSink = callback
end

function getFlatDistance(a, b)
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function getTreeStandPosition(targetPosition, rootPosition)
    local away = Vector3.new(rootPosition.X - targetPosition.X, 0, rootPosition.Z - targetPosition.Z)
    if away.Magnitude < 0.1 then
        away = Vector3.new(1, 0, 0)
    end
    return targetPosition + away.Unit * 5
end

local function getSafeTeleportStandPosition(targetPosition, rootPosition)
    if not targetPosition or not rootPosition then
        return nil
    end

    local away = Vector3.new(rootPosition.X - targetPosition.X, 0, rootPosition.Z - targetPosition.Z)
    if away.Magnitude < 0.1 then
        away = Vector3.new(1, 0, 0)
    end

    local base = targetPosition + away.Unit * 5
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    local character = getCharacter()
    if character then
        table.insert(ignore, character)
    end
    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if folder then
        table.insert(ignore, folder)
    end
    params.FilterDescendantsInstances = ignore

    local offsets = {
        Vector3.new(0, 0, 0),
        Vector3.new(2.5, 0, 0),
        Vector3.new(-2.5, 0, 0),
        Vector3.new(0, 0, 2.5),
        Vector3.new(0, 0, -2.5),
        Vector3.new(4, 0, 0),
        Vector3.new(-4, 0, 0),
        Vector3.new(0, 0, 4),
        Vector3.new(0, 0, -4),
    }

    local best
    local bestDist = math.huge
    for _, offset in ipairs(offsets) do
        local probe = base + offset
        local hit = Workspace:Raycast(probe + Vector3.new(0, 35, 0), Vector3.new(0, -90, 0), params)
        if hit and hit.Instance and hit.Instance.CanCollide then
            local yGap = math.abs(hit.Position.Y - targetPosition.Y)
            if yGap <= 10 then
                local candidate = Vector3.new(probe.X, hit.Position.Y + 3.2, probe.Z)
                local dist = getFlatDistance(candidate, targetPosition)
                if dist >= 3.5 and dist < bestDist then
                    best = candidate
                    bestDist = dist
                end
            end
        end
    end

    return best or (base + Vector3.new(0, 3.2, 0))
end

local function computePathTo(goalPosition)
    local root = getRoot()
    if not root then
        return nil
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        AgentJumpHeight = 9,
        AgentMaxSlope = 45,
        WaypointSpacing = 6,
        Costs = { Water = math.huge },
    })

    local ok = pcall(function()
        path:ComputeAsync(root.Position, goalPosition)
    end)

    if not ok or path.Status ~= Enum.PathStatus.Success then
        return nil
    end

    local waypoints = path:GetWaypoints()
    if #waypoints < 2 then
        return nil
    end

    return waypoints
end

local function clearMovementPath()
    DemoWorld.PathWaypoints = nil
    DemoWorld.PathIndex = 1
    DemoWorld.PathTarget = nil
    DemoWorld.LastStuckPosition = nil
    DemoWorld.StuckSince = nil
end

local function maybeJumpForStuck(humanoid)
    local now = os.clock()
    if now - DemoWorld.JumpIssuedAt < 1.2 then
        return
    end

    local state = humanoid:GetState()
    if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics or state == Enum.HumanoidStateType.Landed then
        DemoWorld.JumpIssuedAt = now
        humanoid.Jump = true
    end
end

local function followPathToward(target, targetPosition)
    local root = getRoot()
    local humanoid = getHumanoid()
    if not root or not humanoid or not targetPosition then
        return false
    end

    local standPosition = getTreeStandPosition(targetPosition, root.Position)
    local now = os.clock()

    local shouldRepath = false
    if DemoWorld.PathTarget ~= target then
        shouldRepath = true
    elseif not DemoWorld.PathWaypoints then
        shouldRepath = true
    elseif now - DemoWorld.LastPathCompute > 3.0 then
        shouldRepath = true
    end

    if shouldRepath and now - DemoWorld.LastPathCompute >= 0.35 then
        DemoWorld.LastPathCompute = now
        local waypoints = computePathTo(standPosition)
        if not waypoints then
            if now - DemoWorld.LastPathFailToast >= 3.0 then
                DemoWorld.LastPathFailToast = now
                notifyWarn("Can't pathfind to nearest tree; trying direct movement")
            end
            clearMovementPath()
            humanoid:MoveTo(standPosition)
            return true
        end

        DemoWorld.PathWaypoints = waypoints
        DemoWorld.PathIndex = 2
        DemoWorld.PathTarget = target
        DemoWorld.LastStuckPosition = root.Position
        DemoWorld.StuckSince = nil
    end

    local waypoints = DemoWorld.PathWaypoints
    if not waypoints or not waypoints[DemoWorld.PathIndex] then
        humanoid:MoveTo(standPosition)
        return true
    end

    -- Skip past tiny/behind waypoints so movement stays smooth instead of walking block-by-block.
    while waypoints[DemoWorld.PathIndex] and getFlatDistance(root.Position, waypoints[DemoWorld.PathIndex].Position) < 4 do
        DemoWorld.PathIndex += 1
    end

    local waypoint = waypoints[DemoWorld.PathIndex]
    if not waypoint then
        humanoid:MoveTo(standPosition)
        return true
    end

    if waypoint.Action == Enum.PathWaypointAction.Jump then
        maybeJumpForStuck(humanoid)
    end

    humanoid:MoveTo(waypoint.Position)

    -- Stuck detector: only jump/repath when almost not moving for a while.
    if now - DemoWorld.LastStuckCheck >= 0.45 then
        if DemoWorld.LastStuckPosition then
            local moved = (root.Position - DemoWorld.LastStuckPosition).Magnitude
            if moved < 0.55 then
                DemoWorld.StuckSince = DemoWorld.StuckSince or now
                if now - DemoWorld.StuckSince > 1.0 then
                    maybeJumpForStuck(humanoid)
                    DemoWorld.PathWaypoints = nil
                end
            else
                DemoWorld.StuckSince = nil
            end
        end
        DemoWorld.LastStuckCheck = now
        DemoWorld.LastStuckPosition = root.Position
    end

    return true
end

function DemoWorld.SetMovementDemo(enabled)
    if DemoWorld.MovementConnection then
        DemoWorld.MovementConnection:Disconnect()
        DemoWorld.MovementConnection = nil
    end

    if not enabled then
        DemoWorld.CurrentMoveTarget = nil
        clearMovementPath()
        DemoWorld.SetOverlayDemo(nil, false)
        return
    end

    DemoWorld.CurrentMoveTarget = nil
    DemoWorld.LastTargetSearch = 0
    DemoWorld.MoveToIssuedAt = 0
    clearMovementPath()
    equipBestAxeThrottled(true)
    DemoWorld.SpawnObjectsAtTreePositions(25)

    DemoWorld.MovementConnection = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        local root = getRoot()
        if not root then
            return
        end

        local target = DemoWorld.CurrentMoveTarget
        if not isLiveTarget(target) then
            DemoWorld.CurrentMoveTarget = nil
            target = nil
            clearMovementPath()

            if now - DemoWorld.LastTargetSearch < DemoWorld.TargetSearchInterval then
                return
            end

            DemoWorld.LastTargetSearch = now
            DemoWorld.SpawnObjectsAtTreePositions(25)
            target = DemoWorld.GetNearestCollectible()
            if not isLiveTarget(target) then
                return
            end

            DemoWorld.CurrentMoveTarget = target
            equipBestAxeThrottled(true)
        else
            equipBestAxeThrottled(false)
        end

        local targetPosition = getTreePosition(target)
        if not targetPosition then
            DemoWorld.CurrentMoveTarget = nil
            clearMovementPath()
            return
        end

        local flatDistance = getFlatDistance(root.Position, targetPosition)

        if flatDistance <= 7 then
            local humanoid = getHumanoid()
            if humanoid then
                humanoid:Move(Vector3.zero, false)
            end

            root.CFrame = CFrame.new(root.Position, Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z))
            if Workspace.CurrentCamera then
                Workspace.CurrentCamera.CFrame = CFrame.new(Workspace.CurrentCamera.CFrame.Position, targetPosition)
            end

            if now - DemoWorld.LastTreeClick >= DemoWorld.ClickInterval then
                DemoWorld.LastTreeClick = now
                damageDemoTree(target)
            end
            return
        end

        followPathToward(target, targetPosition)
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
        local hits = part:GetAttribute("HitsRemaining")
        label.Text = hits and (part.Name .. " | " .. hits .. " hits") or part.Name
        label.Parent = billboard
        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)

        table.insert(DemoWorld.OverlayItems, billboard)
    end
end

function DemoWorld.SetAutoCollectDemo(enabled, onCollect)
    DemoWorld.AutoCollectRunning = enabled
    DemoWorld.CurrentTeleportTarget = nil

    if not enabled then
        return
    end

    removeDemoAxe()
    DemoWorld.ClearObjects()
    DemoWorld.SpawnObjectsAtTreePositions(25)
    DemoWorld.EquipBestAxe()

    task.spawn(function()
        while DemoWorld.AutoCollectRunning do
            removeDemoAxe()
            DemoWorld.EquipBestAxe()

            local root = getRoot()
            if not root then
                task.wait(0.25)
                continue
            end

            local target = DemoWorld.CurrentTeleportTarget
            if not isLiveTarget(target) then
                DemoWorld.CurrentTeleportTarget = nil
                DemoWorld.SpawnObjectsAtTreePositions(25)
                target = DemoWorld.GetNearestCollectible()
                if not isLiveTarget(target) then
                    task.wait(0.35)
                    continue
                end
                DemoWorld.CurrentTeleportTarget = target
            end

            local targetPosition = getTreePosition(target)
            if not targetPosition then
                DemoWorld.CurrentTeleportTarget = nil
                task.wait(0.15)
                continue
            end

            -- TP mode: lock to the selected nearest tree, stand beside the trunk/base,
            -- swing until that source tree disappears, then pick the next nearest tree.
            local standPosition = getSafeTeleportStandPosition(targetPosition, root.Position)
            if standPosition then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                root.CFrame = CFrame.new(standPosition, Vector3.new(targetPosition.X, standPosition.Y, targetPosition.Z))
            end

            if Workspace.CurrentCamera then
                Workspace.CurrentCamera.CFrame = CFrame.new(Workspace.CurrentCamera.CFrame.Position, targetPosition)
            end

            damageDemoTree(target, onCollect)

            if not isLiveTarget(target) then
                DemoWorld.CurrentTeleportTarget = nil
                DemoWorld.SpawnObjectsAtTreePositions(25)
            end

            task.wait(DemoWorld.ClickInterval)
        end
    end)
end

-- Compatibility aliases for older Foraging tab names.
DemoWorld.SetTreeMovementDemo = DemoWorld.SetMovementDemo
DemoWorld.SetMovement = DemoWorld.SetMovementDemo
DemoWorld.SetTeleportDemo = DemoWorld.SetAutoCollectDemo
DemoWorld.SetTreeTeleportDemo = DemoWorld.SetAutoCollectDemo
DemoWorld.SetAutoCollect = DemoWorld.SetAutoCollectDemo

function DemoWorld.Restore()
    DemoWorld.SetMovementDemo(false)
    DemoWorld.SetOverlayDemo(nil, false)
    DemoWorld.SetAutoCollectDemo(false)
end

return DemoWorld

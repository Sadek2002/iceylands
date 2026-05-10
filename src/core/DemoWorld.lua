local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
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
    -- No physical demo markers: they can steal mouse clicks and lag.
    local trees = TreeScanner.GetClusters(maxObjects or 25, true)
    return #trees
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

local function groundAt(x, z, ignore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore or { getCharacter() }

    local result = Workspace:Raycast(Vector3.new(x, 220, z), Vector3.new(0, -500, 0), params)
    if result and result.Instance and result.Instance.CanCollide then
        return result.Position
    end
    return nil
end

local function hasHeadClearance(pos)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { getCharacter() }
    local hit = Workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, 4, 0), params)
    return hit == nil
end

local function getStandPosition(tree)
    local root = getRoot()
    local trunk = getTrunk(tree)
    if not root or not trunk then
        return nil
    end

    local base = Vector3.new(trunk.Position.X, trunk.Position.Y - trunk.Size.Y / 2 + 2.5, trunk.Position.Z)
    local radius = math.max(5, math.min(8, (trunk.Size.X + trunk.Size.Z) * 0.25))
    local dirs = {
        Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
        Vector3.new(1, 0, 1).Unit, Vector3.new(1, 0, -1).Unit,
        Vector3.new(-1, 0, 1).Unit, Vector3.new(-1, 0, -1).Unit,
    }

    local best, bestScore
    for _, dir in ipairs(dirs) do
        local wanted = base + dir * radius
        local ground = groundAt(wanted.X, wanted.Z, { getCharacter(), trunk })
        if ground and math.abs(ground.Y - base.Y) <= 8 then
            local stand = Vector3.new(wanted.X, ground.Y + 2.8, wanted.Z)
            if hasHeadClearance(stand) then
                local score = flatDistance(root.Position, stand)
                if not bestScore or score < bestScore then
                    best = stand
                    bestScore = score
                end
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

local function getNearestTree(exclude, forceRefresh)
    local trees = TreeScanner.GetClusters(40, forceRefresh)
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

local function getTreeAimPoint(tree)
    local trunk = getTrunk(tree)
    if not trunk then
        return nil
    end

    -- Click the trunk, not leaves/overlay. Keep the aim low enough that it counts as chopping.
    return trunk.Position + Vector3.new(0, math.clamp(trunk.Size.Y * 0.22, 2.5, 7), 0)
end

local function getTreeScreenPoint(tree)
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil, nil, false
    end

    local point = getTreeAimPoint(tree)
    if not point then
        return nil, nil, false
    end

    local screenPos, visible = camera:WorldToViewportPoint(point)
    if not visible or screenPos.Z <= 0 then
        return nil, nil, false
    end

    local view = camera.ViewportSize
    if screenPos.X < 3 or screenPos.Y < 3 or screenPos.X > view.X - 3 or screenPos.Y > view.Y - 3 then
        return nil, nil, false
    end

    return screenPos.X, screenPos.Y, true
end

local function aimCameraAtTree(tree)
    local camera = Workspace.CurrentCamera
    local point = getTreeAimPoint(tree)
    if not camera or not point then
        return
    end

    -- This does not use the user's pointer. It only makes the target hittable for virtual clicks.
    pcall(function()
        camera.CFrame = CFrame.lookAt(camera.CFrame.Position, point)
    end)
end

local function pressLeftClick(tree)
    aimCameraAtTree(tree)
    task.wait()

    local x, y, visible = getTreeScreenPoint(tree)
    if not visible then
        -- Never click the current mouse/center as a fallback; that was toggling UI buttons off.
        return false
    end

    local pos = Vector2.new(x, y)

    if VirtualUser then
        pcall(function()
            VirtualUser:Button1Down(pos, Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or CFrame.new())
            task.wait(0.045)
            VirtualUser:Button1Up(pos, Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or CFrame.new())
        end)
    end

    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.045)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
    end

    return true
end

local faceTree

function DemoWorld.ActivateHeldAxe(tree)
    local player = Players.LocalPlayer
    local character = player and player.Character

    if not DemoWorld.EquipBestAxe() then
        return false
    end

    character = player and player.Character
    local tool = DemoWorld.GetBestAxe()
    if not tool or tool.Parent ~= character then
        return false
    end

    -- Face first, then use Tool activation plus a virtual click at the tree's screen location.
    faceTree(tree)
    aimCameraAtTree(tree)

    pcall(function()
        tool:Activate()
    end)

    local clicked = pressLeftClick(tree)

    -- A second Activate helps for tools that debounce off the mouse release event.
    pcall(function()
        tool:Activate()
    end)

    return clicked
end

faceTree = function(tree)
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
        WaypointSpacing = 8,
    })

    local ok = pcall(function()
        path:ComputeAsync(root.Position, toPosition)
    end)

    if ok and path.Status == Enum.PathStatus.Success then
        return path:GetWaypoints()
    end

    return nil
end

local function grounded(humanoid)
    if not humanoid then
        return false
    end
    local state = humanoid:GetState()
    return state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.Jumping
end

local function jumpIfStuck(state, humanoid)
    if not humanoid or not grounded(humanoid) then
        return
    end
    if os.clock() - (state.LastJump or 0) < 1.1 then
        return
    end
    state.LastJump = os.clock()
    humanoid.Jump = true
end


local function getGroundYAt(position, ignore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore or {}

    local hit = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -24, 0), params)
    if hit and hit.Instance and hit.Instance.CanCollide then
        return hit.Position.Y, hit.Instance
    end
    return nil, nil
end

local function requestJump(state, humanoid)
    if not humanoid or not grounded(humanoid) then
        return false
    end
    if humanoid.FloorMaterial == Enum.Material.Air then
        return false
    end
    if os.clock() - (state.LastJump or 0) < 0.75 then
        return false
    end
    state.LastJump = os.clock()
    humanoid.Jump = true
    return true
end

local function maybeJumpForLedge(state, root, humanoid, moveTarget)
    if not root or not humanoid or not moveTarget then
        return false
    end
    if not grounded(humanoid) or humanoid.FloorMaterial == Enum.Material.Air then
        return false
    end

    local delta = Vector3.new(moveTarget.X - root.Position.X, 0, moveTarget.Z - root.Position.Z)
    if delta.Magnitude < 1 then
        return false
    end

    local dir = delta.Unit
    local ignore = {getCharacter()}
    local currentGroundY = getGroundYAt(root.Position, ignore)
    if not currentGroundY then
        return false
    end

    -- Check the tile a little in front of the player. In this block world the
    -- next walkable ledge is usually 3 studs higher than the current tile.
    local probe = root.Position + dir * 4
    local nextGroundY, nextGround = getGroundYAt(probe, ignore)
    if nextGroundY then
        local climb = nextGroundY - currentGroundY
        if climb > 0.9 and climb <= 4.2 then
            return requestJump(state, humanoid)
        elseif climb > 4.2 then
            -- Too high to jump cleanly; force a fresh Roblox path instead of
            -- repeatedly walking into the wall.
            state.Waypoints = nil
            state.LastPathTime = 0
            return false
        end
    end

    -- Extra wall check for ledges where the top ray misses due to being close
    -- to the block edge.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    local wallHit = Workspace:Raycast(root.Position + Vector3.new(0, 1.25, 0), dir * 3.25, params)
    if wallHit and wallHit.Instance and wallHit.Instance.CanCollide then
        local part = wallHit.Instance
        local topY = part.Position.Y + part.Size.Y / 2
        local climb = topY - currentGroundY
        if climb > 0.9 and climb <= 4.2 then
            return requestJump(state, humanoid)
        elseif climb > 4.2 then
            state.Waypoints = nil
            state.LastPathTime = 0
        end
    end

    return false
end

local function maybeStuck(state, root)
    if os.clock() - (state.LastStuckCheck or 0) < 0.45 then
        return false
    end

    local moved = (root.Position - (state.LastPos or root.Position)).Magnitude
    state.LastPos = root.Position
    state.LastStuckCheck = os.clock()

    if moved < 0.55 then
        state.StuckCount = (state.StuckCount or 0) + 1
    else
        state.StuckCount = 0
    end

    return (state.StuckCount or 0) >= 3
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
        state.Index = 2
        state.LastPathTime = 0
        state.LastPos = root.Position
        state.StuckCount = 0
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

    local trunkBaseY = trunk.Position.Y - trunk.Size.Y / 2 + 2.5
    local flatToTrunk = flatDistance(root.Position, trunk.Position)
    local yDiff = math.abs(root.Position.Y - trunkBaseY)

    if flatToTrunk <= 9 and yDiff <= 7 then
        humanoid:Move(Vector3.zero, false)
        faceTree(tree)
        if os.clock() - DemoWorld.LastTreeClick >= DemoWorld.ClickInterval then
            DemoWorld.LastTreeClick = os.clock()
            chopTree(tree)
        end
        return
    end

    local directFlat = flatDistance(root.Position, stand)
    if directFlat <= 18 and math.abs(root.Position.Y - stand.Y) <= 8 then
        humanoid:MoveTo(stand)
        maybeJumpForLedge(state, root, humanoid, stand)
    else
        if not state.Waypoints or not state.Waypoints[state.Index] or os.clock() - (state.LastPathTime or 0) > 6 then
            state.Waypoints = computePath(stand)
            state.Index = 2
            state.LastPathTime = os.clock()

            if not state.Waypoints then
                -- Fall back to normal MoveTo instead of doing nothing. Roblox pathfinding often fails on this block world.
                humanoid:MoveTo(stand)
                maybeJumpForLedge(state, root, humanoid, stand)
            end
        end

        if state.Waypoints and state.Waypoints[state.Index] then
            local waypoint = state.Waypoints[state.Index]
            local target = waypoint.Position
            if flatDistance(root.Position, target) < 4.0 then
                state.Index += 1
            else
                humanoid:MoveTo(target)
                maybeJumpForLedge(state, root, humanoid, target)
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    jumpIfStuck(state, humanoid)
                end
            end
        else
            humanoid:MoveTo(stand)
        end
    end

    if maybeStuck(state, root) then
        maybeJumpForLedge(state, root, humanoid, stand)
        jumpIfStuck(state, humanoid)
        state.Waypoints = nil
        state.LastPathTime = 0
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
        local ok, err = pcall(function()
            movementTick(state)
        end)
        if not ok and os.clock() - (DemoWorld.LastPathWarn or 0) > 2 then
            DemoWorld.LastPathWarn = os.clock()
            toast("Tree movement error: " .. tostring(err), "warn")
        end
    end)
end

function DemoWorld.SetOverlayDemo(rootGui, enabled)
    for _, item in ipairs(DemoWorld.OverlayItems) do
        if item then
            item:Destroy()
        end
    end
    table.clear(DemoWorld.OverlayItems)
    -- Overlay is intentionally disabled for now. The previous physical markers
    -- could intercept clicks and caused UpdateIconTree timeouts in the game UI.
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
            local ok, err = pcall(function()
                local root = getRoot()
                if not root then
                    task.wait(0.2)
                    return
                end

                if not DemoWorld.CurrentTPTree or not isTreeLive(DemoWorld.CurrentTPTree) then
                    DemoWorld.CurrentTPTree = getNearestTree(nil, true)
                    if DemoWorld.CurrentTPTree and onCollect then
                        onCollect((DemoWorld.CurrentTPTree.Name or "Tree") .. " target", nil)
                    end
                end

                local tree = DemoWorld.CurrentTPTree
                if not tree then
                    task.wait(0.75)
                    return
                end

                local trunk = getTrunk(tree)
                if not trunk then
                    DemoWorld.CurrentTPTree = nil
                    task.wait(0.15)
                    return
                end

                local distance = flatDistance(root.Position, trunk.Position)
                local trunkBaseY = trunk.Position.Y - trunk.Size.Y / 2 + 2.5
                local yDiff = math.abs(root.Position.Y - trunkBaseY)

                if distance > 8 or yDiff > 7 then
                    teleportBesideTree(tree)
                    task.wait(0.2)
                else
                    faceTree(tree)
                    if os.clock() - DemoWorld.LastTreeClick >= DemoWorld.ClickInterval then
                        DemoWorld.LastTreeClick = os.clock()
                        chopTree(tree)
                    end
                    task.wait(0.08)
                end
            end)

            if not ok then
                if os.clock() - (DemoWorld.LastPathWarn or 0) > 2 then
                    DemoWorld.LastPathWarn = os.clock()
                    toast("Tree TP error: " .. tostring(err), "warn")
                end
                task.wait(0.35)
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

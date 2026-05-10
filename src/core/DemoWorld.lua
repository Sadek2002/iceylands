local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

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
    MovementConnection = nil,
    CurrentTree = nil,
    LastMoveTo = 0,
    MoveToInterval = 0.75,
    StandDistance = 5,
    ChopRange = 8,
    ChopInterval = 1 / 3, -- 3 CPS
    LastChop = 0,
    LockedTrunk = nil,
    LockedContainer = nil,
    LockedHitPosition = nil,
    TargetMarker = nil,
    LastTargetRefresh = 0,
    TargetRefreshInterval = 0.5,
}

local function getPlayer()
    return Players.LocalPlayer
end

local function getCharacter()
    local player = getPlayer()
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
    local player = getPlayer()
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
        warn("Iceylands: no axe found in Backpack/Character.")
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

local function isTreeValid(tree)
    return tree
        and tree.Container
        and tree.Trunk
        and tree.Container:IsDescendantOf(Workspace)
        and tree.Trunk:IsDescendantOf(Workspace)
end

local function getStandPosition(rootPosition, trunkPosition)
    local flatOffset = Vector3.new(rootPosition.X - trunkPosition.X, 0, rootPosition.Z - trunkPosition.Z)
    if flatOffset.Magnitude < 0.1 then
        flatOffset = Vector3.new(1, 0, 0)
    end

    local direction = flatOffset.Unit
    return Vector3.new(
        trunkPosition.X + direction.X * DemoWorld.StandDistance,
        trunkPosition.Y,
        trunkPosition.Z + direction.Z * DemoWorld.StandDistance
    )
end


local function clearTargetMarker()
    -- v46: no visible marker. The previous marker made the target/tree look like it was flickering.
    if DemoWorld.TargetMarker then
        DemoWorld.TargetMarker:Destroy()
        DemoWorld.TargetMarker = nil
    end
end

local function getTrunkAimPosition(trunk)
    -- Fixed lower-middle trunk target. This is cached per tree so animated/shaking parts
    -- do not make the hit point flicker between trunk/leaves/collision boxes.
    if not trunk then
        return nil
    end

    return trunk.Position + Vector3.new(0, math.clamp(trunk.Size.Y * 0.15, 1.5, 5), 0)
end

local function updateTargetMarker(_, _)
    -- v46: marker disabled. Chopping still uses the cached trunk hit position internally.
    clearTargetMarker()
end

local function lockTreeTarget(tree)
    if not isTreeValid(tree) then
        DemoWorld.LockedTrunk = nil
        DemoWorld.LockedContainer = nil
        DemoWorld.LockedHitPosition = nil
        clearTargetMarker()
        return false
    end

    if DemoWorld.LockedTrunk == tree.Trunk and DemoWorld.LockedContainer == tree.Container then
        updateTargetMarker(DemoWorld.LockedTrunk, DemoWorld.LockedHitPosition)
        return true
    end

    DemoWorld.LockedTrunk = tree.Trunk
    DemoWorld.LockedContainer = tree.Container
    DemoWorld.LockedHitPosition = getTrunkAimPosition(tree.Trunk)
    updateTargetMarker(DemoWorld.LockedTrunk, DemoWorld.LockedHitPosition)
    return true
end

local function faceTrunk(root, trunk)
    local aim = DemoWorld.LockedHitPosition or getTrunkAimPosition(trunk)
    local flatAim = Vector3.new(aim.X, root.Position.Y, aim.Z)
    if (flatAim - root.Position).Magnitude > 0.1 then
        root.CFrame = CFrame.lookAt(root.Position, flatAim)
    end
end

local function getAxeHandle(tool)
    if not tool then
        return nil
    end

    local handle = tool:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then
        return handle
    end

    return tool:FindFirstChildWhichIsA("BasePart", true)
end

local function getTrimRemote()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local ok, remote = pcall(function()
        return replicatedStorage.rbxts_include.node_modules["@rbxts"].net.out._NetManaged.CLIENT_TRIM_TREE_REQUEST
    end)

    if ok then
        return remote
    end

    return nil
end

local function tryTouchHit(tool, trunk)
    local handle = getAxeHandle(tool)
    if not handle or not trunk then
        return false
    end

    if typeof(firetouchinterest) ~= "function" then
        return false
    end

    pcall(function()
        firetouchinterest(handle, trunk, 0)
        task.wait(0.02)
        firetouchinterest(handle, trunk, 1)
    end)

    return true
end

local function tryTrimRemote(tree)
    local remote = getTrimRemote()
    local trunk = tree and tree.Trunk
    local container = tree and tree.Container
    if not remote or not trunk or not container then
        return false
    end

    pcall(function()
        remote:InvokeServer(trunk)
    end)

    pcall(function()
        remote:InvokeServer(container)
    end)

    pcall(function()
        remote:InvokeServer({
            tree = container,
            part = trunk,
            trunk = trunk,
        })
    end)

    return true
end

local function screenClickHitPosition(hitPosition)
    local camera = Workspace.CurrentCamera
    if not camera or not hitPosition then
        return false
    end

    local screenPosition, onScreen = camera:WorldToViewportPoint(hitPosition)
    if not onScreen or screenPosition.Z <= 0 then
        return false
    end

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(screenPosition.X, screenPosition.Y, 0, true, game, 0)
        task.wait(0.035)
        VirtualInputManager:SendMouseButtonEvent(screenPosition.X, screenPosition.Y, 0, false, game, 0)
    end)

    return true
end

local function clickTrunk(tree)
    local character = getCharacter()
    local root = getRoot()
    local trunk = DemoWorld.LockedTrunk or (tree and tree.Trunk)
    if not character or not root or not trunk or not trunk:IsDescendantOf(Workspace) then
        return false
    end

    if tree then
        lockTreeTarget(tree)
    end

    DemoWorld.EquipBestAxe()

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then
        return false
    end

    -- v46: stable chop target. No marker and no camera movement.
    -- We face only the character body toward the cached trunk point.
    local hitPosition = DemoWorld.LockedHitPosition or getTrunkAimPosition(trunk)
    faceTrunk(root, trunk)

    -- Try multiple safe methods at the same fixed trunk point.
    -- The VIM click is sent at the trunk screen coordinate, not at the user's real cursor position.
    pcall(function()
        tool:Activate()
    end)

    screenClickHitPosition(hitPosition)
    tryTouchHit(tool, trunk)
    tryTrimRemote(tree)

    return true
end

local function setMovementTarget()
    DemoWorld.CurrentTree = TreeScanner.GetNearestTree()
    return DemoWorld.CurrentTree
end

function DemoWorld.SetMovementDemo(enabled)
    if DemoWorld.MovementConnection then
        DemoWorld.MovementConnection:Disconnect()
        DemoWorld.MovementConnection = nil
    end

    DemoWorld.CurrentTree = nil
    DemoWorld.LockedTrunk = nil
    DemoWorld.LockedContainer = nil
    DemoWorld.LockedHitPosition = nil
    DemoWorld.LastMoveTo = 0
    DemoWorld.LastChop = 0
    clearTargetMarker()

    if not enabled then
        return
    end

    DemoWorld.EquipBestAxe()
    setMovementTarget()

    DemoWorld.MovementConnection = RunService.Heartbeat:Connect(function()
        local root = getRoot()
        local humanoid = getHumanoid()
        if not root or not humanoid then
            return
        end

        DemoWorld.EquipBestAxe()

        local tree = DemoWorld.CurrentTree
        if not isTreeValid(tree) then
            DemoWorld.LockedTrunk = nil
            DemoWorld.LockedContainer = nil
            DemoWorld.LockedHitPosition = nil
            clearTargetMarker()
            tree = setMovementTarget()
        end

        if not isTreeValid(tree) then
            return
        end

        lockTreeTarget(tree)

        local standPosition = getStandPosition(root.Position, tree.Trunk.Position)
        local flatDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(standPosition.X, 0, standPosition.Z)).Magnitude

        local trunkFlatDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(tree.Trunk.Position.X, 0, tree.Trunk.Position.Z)).Magnitude

        if flatDistance <= 3 or trunkFlatDistance <= DemoWorld.ChopRange then
            humanoid:Move(Vector3.zero, false)

            if os.clock() - DemoWorld.LastChop >= DemoWorld.ChopInterval then
                DemoWorld.LastChop = os.clock()
                clickTrunk(tree)
            end

            return
        end

        if os.clock() - DemoWorld.LastMoveTo >= DemoWorld.MoveToInterval then
            DemoWorld.LastMoveTo = os.clock()
            humanoid:MoveTo(standPosition)
        end
    end)
end

-- Compatibility stubs so old calls do not break while the UI is simplified.
function DemoWorld.SetOverlayDemo(_, _)
end

function DemoWorld.SetAutoCollectDemo(_, _)
end

function DemoWorld.ClearObjects()
end

function DemoWorld.Restore()
    DemoWorld.SetMovementDemo(false)
end

return DemoWorld

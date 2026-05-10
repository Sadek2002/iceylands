local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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
    DemoWorld.LastMoveTo = 0

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
            tree = setMovementTarget()
        end

        if not isTreeValid(tree) then
            return
        end

        local standPosition = getStandPosition(root.Position, tree.Trunk.Position)
        local flatDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(standPosition.X, 0, standPosition.Z)).Magnitude

        if flatDistance <= 3 then
            humanoid:Move(Vector3.zero, false)
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

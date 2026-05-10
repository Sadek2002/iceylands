local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")
local PathfindingService = game:GetService("PathfindingService")
local Runtime = _G.IceylandsLoader
local TreeScanner = Runtime.LoadModule("src/core/TreeScanner.lua")

-- Movement/pathing tuning. These must always exist; missing values caused
-- the nil < number error spam and made the movement loop stall.
local GRID_SIZE = 3
local MAX_PATH_RADIUS = 140
local TREE_STAND_MIN_DISTANCE = 5
local TREE_STAND_MAX_DISTANCE = 11
local WAYPOINT_REACHED_DISTANCE = 3.25

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

local DemoWorld = {
    FolderName = "IceylandsDemo",
    MovementConnection = nil,
    OverlayItems = {},
    AutoCollectRunning = false,
    HitsRequired = 3,
    ClickInterval = 0.22,
    LastTreeClick = 0,
    CurrentMoveTarget = nil,
    MoveToIssuedAt = 0,
    TargetSearchInterval = 0.6,
    LastTargetSearch = 0,
    EquipIssuedAt = 0,
    CurrentPath = nil,
    CurrentPathIndex = 1,
    PathIssuedAt = 0,
    IgnoredTargets = {},
    LastFullTreeScan = 0,
    TreeScanCooldown = 3.0,
    LastCollectibleRefresh = 0,
    CollectibleRefreshCooldown = 2.25,
    CachedCollectibles = {},
    CachedTreeSpawnCount = 0,
    LastWaypointDistance = math.huge,
    LastProgressAt = 0,
    LastStuckRepathAt = 0,
    LastPathWarningAt = 0,
}
local function isProbablySaplingOrStump(instance)
    if not instance then
        return true
    end

    local function badName(name)
        name = string.lower(tostring(name or ""))
        return string.find(name, "sapling", 1, true)
            or string.find(name, "seedling", 1, true)
            or string.find(name, "stump", 1, true)
            or string.find(name, "sprout", 1, true)
    end

    if badName(instance.Name) then
        return true
    end

    if instance:IsA("Model") then
        for _, child in ipairs(instance:GetDescendants()) do
            if badName(child.Name) then
                return true
            end
        end
    end

    return false
end

local function isLiveTreeInstance(instance)
    return instance ~= nil and instance.Parent ~= nil and not isProbablySaplingOrStump(instance)
end

local function isLiveTarget(target)
    if not target or not target.Parent or target:GetAttribute("Collected") then
        return false
    end

    local sourcePath = target:GetAttribute("SourceTreePath")
    if sourcePath and sourcePath ~= "" then
        return isLiveTreeInstance(getLiveTreeForMarker(target))
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
    if isLiveTreeInstance(tree) then
        return tree
    end

    -- Important: do not fallback to nearby objects here. After a tree breaks,
    -- a sapling/stump can remain in the same spot and the farm would keep
    -- clicking it forever instead of moving to the next tree.
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

function DemoWorld.SpawnObjectsAtTreePositions(maxObjects, force)
    local now = os.clock()
    local existingFolder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if not force and existingFolder and (now - DemoWorld.LastFullTreeScan) < DemoWorld.TreeScanCooldown then
        local aliveCount = 0
        for _, item in ipairs(existingFolder:GetChildren()) do
            if item:IsA("BasePart") and item:GetAttribute("IceylandsDemoObject") and not item:GetAttribute("Collected") then
                aliveCount += 1
            end
        end
        if aliveCount > 0 then
            return aliveCount
        end
    end

    DemoWorld.LastFullTreeScan = now
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

    -- Yield very briefly so the game can remove/replace the chopped tree before
    -- we decide whether to keep hitting this marker.
    task.wait(0.03)

    if target:GetAttribute("SourceTreePath") and not isLiveTreeInstance(getLiveTreeForMarker(target)) then
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

function DemoWorld.GetCollectibles(forceRefresh)
    local now = os.clock()

    if not forceRefresh and DemoWorld.CachedCollectibles and #DemoWorld.CachedCollectibles > 0 and (now - (DemoWorld.LastCollectibleRefresh or 0)) < DemoWorld.CollectibleRefreshCooldown then
        local liveCached = {}
        for _, item in ipairs(DemoWorld.CachedCollectibles) do
            if isLiveTarget(item) then
                table.insert(liveCached, item)
            end
        end
        if #liveCached > 0 then
            DemoWorld.CachedCollectibles = liveCached
            return liveCached
        end
    end

    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if not folder then
        DemoWorld.SpawnObjectsAtTreePositions(10, true)
        folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    elseif forceRefresh or (now - (DemoWorld.LastFullTreeScan or 0)) >= DemoWorld.TreeScanCooldown then
        DemoWorld.SpawnObjectsAtTreePositions(10, true)
        folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    end

    local items = {}
    if folder then
        for _, item in ipairs(folder:GetChildren()) do
            if item:IsA("BasePart") and item:GetAttribute("IceylandsDemoObject") and not item:GetAttribute("Collected") then
                local sourcePath = item:GetAttribute("SourceTreePath")
                if sourcePath and sourcePath ~= "" and not isLiveTreeInstance(getLiveTreeForMarker(item)) then
                    item:SetAttribute("Collected", true)
                    item:Destroy()
                else
                    table.insert(items, item)
                end
            end
        end
    end

    DemoWorld.CachedCollectibles = items
    DemoWorld.LastCollectibleRefresh = now
    return items
end

local function notifyPathWarning(text)
    if os.clock() - (DemoWorld.LastPathWarningAt or 0) < 4 then
        return
    end
    DemoWorld.LastPathWarningAt = os.clock()
    warn("Iceylands: " .. text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Tree movement",
            Text = text,
            Duration = 3,
        })
    end)
end

local function gridRound(value)
    return math.floor((value / GRID_SIZE) + 0.5) * GRID_SIZE
end

local function gridKey(x, z)
    return tostring(gridRound(x)) .. ":" .. tostring(gridRound(z))
end

local function getGroundNodes(origin, targetPosition)
    local nodes = {}
    local mid = (origin + targetPosition) * 0.5
    local radius = math.clamp((origin - targetPosition).Magnitude * 0.65 + 45, 65, MAX_PATH_RADIUS)

    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide and part.Transparency < 1 then
            local name = string.lower(part.Name)
            local parentName = part.Parent and string.lower(part.Parent.Name) or ""
            local usefulBlock = parentName == "blocks"
                or string.find(name, "block", 1, true)
                or string.find(name, "grass", 1, true)
                or string.find(name, "stone", 1, true)
                or string.find(name, "snow", 1, true)
                or string.find(name, "bridge", 1, true)
                or string.find(name, "log", 1, true)
                or string.find(name, "wood", 1, true)
                or string.find(name, "plank", 1, true)
                or string.find(parentName, "bridge", 1, true)
                or string.find(parentName, "wood", 1, true)

            if (usefulBlock or (part.Size.X >= 2 and part.Size.X <= 6 and part.Size.Z >= 2 and part.Size.Z <= 6 and part.Size.Y <= 6)) and part.Size.X >= 2 and part.Size.Z >= 2 then
                local flatDistance = (Vector3.new(part.Position.X, 0, part.Position.Z) - Vector3.new(mid.X, 0, mid.Z)).Magnitude
                if flatDistance <= radius then
                    local key = gridKey(part.Position.X, part.Position.Z)
                    local topY = part.Position.Y + (part.Size.Y * 0.5)
                    local existing = nodes[key]
                    if not existing or topY > existing.TopY then
                        nodes[key] = {
                            Key = key,
                            X = gridRound(part.Position.X),
                            Z = gridRound(part.Position.Z),
                            TopY = topY,
                            Part = part,
                        }
                    end
                end
            end
        end
    end

    return nodes
end

local function closestNode(nodes, position, minDist, maxDist)
    local best
    local bestScore = math.huge
    local flat = Vector3.new(position.X, 0, position.Z)

    for _, node in pairs(nodes) do
        local nodeFlat = Vector3.new(node.X, 0, node.Z)
        local flatDistance = (nodeFlat - flat).Magnitude
        if (not minDist or flatDistance >= minDist) and (not maxDist or flatDistance <= maxDist) then
            local verticalPenalty = math.abs((position.Y or node.TopY) - node.TopY) * 0.2
            local score = flatDistance + verticalPenalty
            if score < bestScore then
                best = node
                bestScore = score
            end
        end
    end

    return best
end

local function smoothGridPath(path)
    if not path or #path <= 2 then
        return path
    end

    -- Keep turns/elevation changes, but remove every-other point on straight flat runs.
    -- This keeps bridge/void safety from the grid path while making the humanoid move
    -- more like a player instead of stopping on every single block.
    local smoothed = { path[1] }
    for i = 2, #path - 1 do
        local prev = smoothed[#smoothed]
        local current = path[i]
        local nextPoint = path[i + 1]
        local sameLineX = math.abs(prev.X - current.X) < 0.1 and math.abs(current.X - nextPoint.X) < 0.1
        local sameLineZ = math.abs(prev.Z - current.Z) < 0.1 and math.abs(current.Z - nextPoint.Z) < 0.1
        local flatEnough = math.abs(prev.Y - current.Y) < 0.35 and math.abs(current.Y - nextPoint.Y) < 0.35

        if not ((sameLineX or sameLineZ) and flatEnough) then
            table.insert(smoothed, current)
        end
    end
    table.insert(smoothed, path[#path])
    return smoothed
end

local function reconstructPath(cameFrom, current, nodes)
    local reversed = { current }
    while cameFrom[current] do
        current = cameFrom[current]
        table.insert(reversed, current)
    end

    local path = {}
    for i = #reversed, 1, -1 do
        local node = nodes[reversed[i]]
        if node then
            table.insert(path, Vector3.new(node.X, node.TopY + 3.0, node.Z))
        end
    end
    return smoothGridPath(path)
end

local function buildGridPath(startPosition, targetPosition)
    local nodes = getGroundNodes(startPosition, targetPosition)
    local startNode = closestNode(nodes, startPosition, nil, 8)
    local goalNode = closestNode(nodes, targetPosition, TREE_STAND_MIN_DISTANCE, TREE_STAND_MAX_DISTANCE)
        or closestNode(nodes, targetPosition, 3.5, 14)

    if not startNode or not goalNode then
        return nil
    end

    local open = { startNode.Key }
    local openSet = { [startNode.Key] = true }
    local cameFrom = {}
    local gScore = { [startNode.Key] = 0 }
    local fScore = {}

    local function heuristic(aKey, bNode)
        local a = nodes[aKey]
        if not a or not bNode then
            return math.huge
        end
        return math.abs(a.X - bNode.X) + math.abs(a.Z - bNode.Z) + math.abs(a.TopY - bNode.TopY) * 2
    end

    fScore[startNode.Key] = heuristic(startNode.Key, goalNode)

    local directions = {
        { GRID_SIZE, 0 },
        { -GRID_SIZE, 0 },
        { 0, GRID_SIZE },
        { 0, -GRID_SIZE },
    }

    local safetyCounter = 0
    while #open > 0 and safetyCounter < 2500 do
        safetyCounter += 1
        local bestIndex = 1
        local current = open[1]
        local currentScore = fScore[current] or math.huge
        for i = 2, #open do
            local score = fScore[open[i]] or math.huge
            if score < currentScore then
                current = open[i]
                currentScore = score
                bestIndex = i
            end
        end

        table.remove(open, bestIndex)
        openSet[current] = nil

        if current == goalNode.Key then
            return reconstructPath(cameFrom, current, nodes)
        end

        local currentNode = nodes[current]
        if currentNode then
            for _, dir in ipairs(directions) do
                local nextKey = gridKey(currentNode.X + dir[1], currentNode.Z + dir[2])
                local nextNode = nodes[nextKey]
                if nextNode then
                    local dy = nextNode.TopY - currentNode.TopY
                    if dy <= MAX_JUMP_HEIGHT and dy >= -MAX_DROP_HEIGHT then
                        local stepCost = GRID_SIZE + math.max(dy, 0) * 2 + math.max(-dy, 0) * 0.35
                        local tentative = (gScore[current] or math.huge) + stepCost
                        if tentative < (gScore[nextKey] or math.huge) then
                            cameFrom[nextKey] = current
                            gScore[nextKey] = tentative
                            fScore[nextKey] = tentative + heuristic(nextKey, goalNode)
                            if not openSet[nextKey] then
                                table.insert(open, nextKey)
                                openSet[nextKey] = true
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function getTreeStandPosition(startPosition, targetPosition)
    local away = Vector3.new(startPosition.X - targetPosition.X, 0, startPosition.Z - targetPosition.Z)
    if away.Magnitude < 0.1 then
        away = Vector3.new(1, 0, 0)
    end
    return targetPosition + away.Unit * 6
end

local function buildRobloxPath(startPosition, targetPosition)
    local standPosition = getTreeStandPosition(startPosition, targetPosition)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 8,
        AgentMaxSlope = 45,
        WaypointSpacing = 6,
    })

    local ok = pcall(function()
        path:ComputeAsync(startPosition, standPosition)
    end)

    if not ok or path.Status ~= Enum.PathStatus.Success then
        return nil
    end

    local waypoints = path:GetWaypoints()
    if not waypoints or #waypoints == 0 then
        return nil
    end

    local points = {}
    for _, waypoint in ipairs(waypoints) do
        table.insert(points, {
            Position = waypoint.Position,
            Action = waypoint.Action,
        })
    end
    return points
end

local function normalizePathPoint(point)
    if typeof(point) == "Vector3" then
        return point, nil
    end
    if type(point) == "table" then
        return point.Position, point.Action
    end
    return nil, nil
end

local function buildMovementPath(startPosition, targetPosition)
    -- Roblox pathfinding is much smoother and cheaper. The old block-grid
    -- fallback caused heavy FPS drops after trees broke, so movement now
    -- ignores a tree if Roblox cannot pathfind to it.
    return buildRobloxPath(startPosition, targetPosition)
end

local function getNearestReachableCollectible()
    local root = getRoot()
    if not root then
        return nil, nil
    end

    local now = os.clock()
    local candidates = {}
    for _, item in ipairs(DemoWorld.GetCollectibles(false)) do
        if isLiveTarget(item) and (not DemoWorld.IgnoredTargets[item] or DemoWorld.IgnoredTargets[item] < now) then
            local targetPosition = getTreePosition(item)
            if targetPosition then
                table.insert(candidates, {
                    Item = item,
                    Position = targetPosition,
                    Distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(targetPosition.X, 0, targetPosition.Z)).Magnitude,
                })
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.Distance < b.Distance
    end)

    local maxPathChecks = math.min(#candidates, 2)
    for i = 1, maxPathChecks do
        local candidate = candidates[i]
        local path = buildMovementPath(root.Position, candidate.Position)
        if path and #path > 0 then
            return candidate.Item, path
        end

        DemoWorld.IgnoredTargets[candidate.Item] = now + 20
        notifyPathWarning("Can't pathfind to tree; ignoring it.")
    end

    return nil, nil
end

local function followMovementPath(path, targetPosition)
    local humanoid = getHumanoid()
    local root = getRoot()
    if not humanoid or not root or not path or #path == 0 then
        return false, false
    end

    local reachedDistance = tonumber(WAYPOINT_REACHED_DISTANCE) or 3.25
    local index = math.clamp(DemoWorld.CurrentPathIndex or 1, 1, #path)

    -- Advance through already-reached points without forcing a stop per block.
    while index <= #path do
        local point = normalizePathPoint(path[index])
        if not point then
            break
        end
        local flatDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude
        if flatDistance > reachedDistance then
            break
        end
        index += 1
    end

    DemoWorld.CurrentPathIndex = index
    if index > #path then
        return true, false
    end

    local waypoint, action = normalizePathPoint(path[index])
    if not waypoint then
        return true, false
    end
    local waypointDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(waypoint.X, 0, waypoint.Z)).Magnitude

    -- Stuck detection: if we are not getting closer for a short time, rebuild once.
    local now = os.clock()
    if waypointDistance + 0.2 < (DemoWorld.LastWaypointDistance or math.huge) then
        DemoWorld.LastWaypointDistance = waypointDistance
        DemoWorld.LastProgressAt = now
    elseif (now - (DemoWorld.LastProgressAt or now)) > 2.2 and (now - (DemoWorld.LastStuckRepathAt or 0)) > 2.5 then
        DemoWorld.LastStuckRepathAt = now
        DemoWorld.LastWaypointDistance = math.huge
        DemoWorld.LastProgressAt = now
        return false, true
    end

    if action == Enum.PathWaypointAction.Jump or waypoint.Y - root.Position.Y > 1.25 then
        humanoid.Jump = true
    end

    -- Less spam and smoother motion: MoveTo the current safe waypoint and let Roblox keep walking.
    if now - DemoWorld.MoveToIssuedAt >= 0.65 then
        DemoWorld.MoveToIssuedAt = now
        humanoid:MoveTo(waypoint)
    end

    return false, false
end

function DemoWorld.SetMovementDemo(enabled)
    if DemoWorld.MovementConnection then
        DemoWorld.MovementConnection:Disconnect()
        DemoWorld.MovementConnection = nil
    end

    if not enabled then
        DemoWorld.CurrentMoveTarget = nil
        DemoWorld.CurrentPath = nil
        DemoWorld.CurrentPathIndex = 1
        return
    end

    DemoWorld.CurrentMoveTarget = nil
    DemoWorld.CurrentPath = nil
    DemoWorld.CurrentPathIndex = 1
    DemoWorld.LastTargetSearch = 0
    DemoWorld.MoveToIssuedAt = 0
    DemoWorld.IgnoredTargets = {}
    equipBestAxeThrottled(true)
    DemoWorld.SpawnObjectsAtTreePositions(10, true)

    -- Movement mode locks one tree at a time. It does not rescan constantly,
    -- and it releases the target as soon as the original tree is gone/replaced
    -- by a sapling/stump so it can move to the next real tree.
    DemoWorld.MovementConnection = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        local root = getRoot()
        if not root then
            return
        end

        local target = DemoWorld.CurrentMoveTarget
        if not isLiveTarget(target) then
            DemoWorld.CurrentMoveTarget = nil
            DemoWorld.CurrentPath = nil
            DemoWorld.CurrentPathIndex = 1
            target = nil

            if now - DemoWorld.LastTargetSearch < DemoWorld.TargetSearchInterval then
                return
            end

            DemoWorld.LastTargetSearch = now
            -- Refresh once after a tree disappears, then pick the nearest reachable tree.
            DemoWorld.GetCollectibles(true)
            target, DemoWorld.CurrentPath = getNearestReachableCollectible()
            if not isLiveTarget(target) then
                return
            end

            DemoWorld.CurrentMoveTarget = target
            DemoWorld.CurrentPathIndex = 1
            DemoWorld.MoveToIssuedAt = 0
            DemoWorld.LastWaypointDistance = math.huge
            DemoWorld.LastProgressAt = now
            equipBestAxeThrottled(true)
        else
            equipBestAxeThrottled(false)
        end

        local targetPosition = getTreePosition(target)
        if not targetPosition then
            DemoWorld.CurrentMoveTarget = nil
            DemoWorld.CurrentPath = nil
            return
        end

        local flatDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(targetPosition.X, 0, targetPosition.Z)).Magnitude

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
                local hitOk = damageDemoTree(target)
                if hitOk and not isLiveTarget(target) then
                    DemoWorld.CurrentMoveTarget = nil
                    DemoWorld.CurrentPath = nil
                    DemoWorld.CurrentPathIndex = 1
                    DemoWorld.CachedCollectibles = {}
                    DemoWorld.LastTargetSearch = 0
                end
            end
            return
        end

        if not DemoWorld.CurrentPath or #DemoWorld.CurrentPath == 0 then
            local path = buildMovementPath(root.Position, targetPosition)
            if not path or #path == 0 then
                DemoWorld.IgnoredTargets[target] = now + 20
                DemoWorld.CurrentMoveTarget = nil
                DemoWorld.CurrentPath = nil
                notifyPathWarning("Can't pathfind to tree; ignoring it.")
                return
            end
            DemoWorld.CurrentPath = path
            DemoWorld.CurrentPathIndex = 1
        end

        local finishedPath, needsRepath = followMovementPath(DemoWorld.CurrentPath, targetPosition)
        if needsRepath then
            local path = buildMovementPath(root.Position, targetPosition)
            if path and #path > 0 then
                DemoWorld.CurrentPath = path
                DemoWorld.CurrentPathIndex = 1
                DemoWorld.MoveToIssuedAt = 0
                DemoWorld.LastWaypointDistance = math.huge
                DemoWorld.LastProgressAt = now
            else
                DemoWorld.IgnoredTargets[target] = now + 20
                DemoWorld.CurrentMoveTarget = nil
                DemoWorld.CurrentPath = nil
                notifyPathWarning("Can't pathfind to tree; ignoring it.")
            end
            return
        end

        if finishedPath then
            -- Rebuild from the current spot if we reached the last safe block but are still outside axe range.
            local path = buildMovementPath(root.Position, targetPosition)
            if path and #path > 0 then
                DemoWorld.CurrentPath = path
                DemoWorld.CurrentPathIndex = 1
            else
                DemoWorld.IgnoredTargets[target] = now + 20
                DemoWorld.CurrentMoveTarget = nil
                DemoWorld.CurrentPath = nil
                notifyPathWarning("Can't pathfind to tree; ignoring it.")
            end
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
    if not enabled then
        return
    end

    removeDemoAxe()
    DemoWorld.SpawnObjectsAtTreePositions(10, true)
    DemoWorld.EquipBestAxe()

    task.spawn(function()
        while DemoWorld.AutoCollectRunning do
            removeDemoAxe()
            DemoWorld.EquipBestAxe()

            local root = getRoot()
            local target = DemoWorld.GetNearestCollectible()
            local targetPosition = getTreePosition(target)

            if not root or not target or not targetPosition then
                task.wait(0.25)
                continue
            end

            -- TP mode: stand beside the nearest live tree, face it, and keep swinging.
            -- It stays enabled; once the source tree disappears, GetCollectibles removes
            -- this marker and the loop automatically picks the next nearest tree.
            local away = Vector3.new(root.Position.X - targetPosition.X, 0, root.Position.Z - targetPosition.Z)
            if away.Magnitude < 0.1 then
                away = Vector3.new(1, 0, 0)
            end

            local standPosition = targetPosition + away.Unit * 5 + Vector3.new(0, 2, 0)
            root.CFrame = CFrame.new(standPosition, Vector3.new(targetPosition.X, standPosition.Y, targetPosition.Z))
            if Workspace.CurrentCamera then
                Workspace.CurrentCamera.CFrame = CFrame.new(Workspace.CurrentCamera.CFrame.Position, targetPosition)
            end

            damageDemoTree(target, onCollect)
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

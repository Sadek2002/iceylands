local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TreeScanner = {}

-- Reworked for the real island layout shown by debug output:
-- Workspace.Islands.<island>.Blocks.tree3
-- tree roots are direct children of Blocks named tree*, and contain trunk/leaves/LeafSpawner.
-- This avoids Workspace:GetDescendants() every time and prevents wood/log drops being treated as trees.
local CACHE_TTL = 1.25
local cachedAt = 0
local cachedTrees = {}

local function getRoot()
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function roundDistance(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function getFullNameSafe(instance)
    local ok, result = pcall(function()
        return instance:GetFullName()
    end)
    return ok and result or instance.Name
end

local function getTreeRootFromInstance(instance)
    local current = instance
    while current and current ~= Workspace do
        local parent = current.Parent
        if parent and parent.Name == "Blocks" then
            local name = string.lower(current.Name)
            if string.match(name, "^tree[%w_]*$") then
                return current
            end
        end
        current = parent
    end
    return nil
end

local function hasLiveTrunk(treeRoot)
    if not treeRoot or not treeRoot.Parent then
        return false
    end

    -- A live tree root has an actual trunk under it. Wood drops/blocks do not count.
    for _, child in ipairs(treeRoot:GetDescendants()) do
        if child:IsA("BasePart") then
            local name = string.lower(child.Name)
            if string.find(name, "trunk", 1, true) then
                return true
            end
        end
    end

    return false
end

function TreeScanner.IsTreeRoot(instance)
    return getTreeRootFromInstance(instance) == instance
end

function TreeScanner.IsLiveTreeRoot(instance)
    local root = getTreeRootFromInstance(instance)
    return root ~= nil and hasLiveTrunk(root)
end

function TreeScanner.ResolveTreeRoot(instance)
    return getTreeRootFromInstance(instance)
end

local function getTreePosition(treeRoot)
    if not treeRoot then
        return nil
    end

    -- Prefer the root/base part position. It is the stable ground-level tree marker.
    if treeRoot:IsA("BasePart") then
        return treeRoot.Position
    end

    local trunk = treeRoot:FindFirstChild("trunk", true)
    if trunk and trunk:IsA("BasePart") then
        return Vector3.new(trunk.Position.X, treeRoot:GetPivot().Position.Y, trunk.Position.Z)
    end

    if treeRoot:IsA("Model") then
        local ok, pivot = pcall(function()
            return treeRoot:GetPivot()
        end)
        if ok and pivot then
            return pivot.Position
        end
    end

    local part = treeRoot:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

function TreeScanner.GetTreePosition(treeRoot)
    return getTreePosition(getTreeRootFromInstance(treeRoot) or treeRoot)
end

local function scanIslandBlocks()
    local trees = {}
    local root = getRoot()
    local rootPos = root and root.Position
    local islands = Workspace:FindFirstChild("Islands")

    if not islands then
        return trees
    end

    for _, island in ipairs(islands:GetChildren()) do
        local blocks = island:FindFirstChild("Blocks")
        if blocks then
            for _, child in ipairs(blocks:GetChildren()) do
                local name = string.lower(child.Name)
                if string.match(name, "^tree[%w_]*$") and hasLiveTrunk(child) then
                    local position = getTreePosition(child)
                    if position then
                        local flatDistance = rootPos and (Vector3.new(rootPos.X, 0, rootPos.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude or 0
                        table.insert(trees, {
                            Instance = child,
                            Name = child.Name,
                            RawName = child.Name,
                            ClassName = child.ClassName,
                            Path = getFullNameSafe(child),
                            Position = position,
                            Distance = roundDistance(flatDistance),
                            PartCount = #child:GetDescendants(),
                        })
                    end
                end
            end
        end
    end

    table.sort(trees, function(a, b)
        return (a.Distance or math.huge) < (b.Distance or math.huge)
    end)

    return trees
end

function TreeScanner.Refresh()
    cachedTrees = scanIslandBlocks()
    cachedAt = os.clock()
    return cachedTrees
end

function TreeScanner.ClearCache()
    cachedTrees = {}
    cachedAt = 0
end

function TreeScanner.GetClusters(maxClusters, forceRefresh)
    local root = getRoot()
    if forceRefresh or os.clock() - cachedAt > CACHE_TTL then
        TreeScanner.Refresh()
    else
        -- Re-sort by current player position without rescanning instances.
        if root then
            local rootPos = root.Position
            for index = #cachedTrees, 1, -1 do
                local tree = cachedTrees[index]
                if not tree.Instance or not hasLiveTrunk(tree.Instance) then
                    table.remove(cachedTrees, index)
                else
                    local pos = getTreePosition(tree.Instance)
                    tree.Position = pos or tree.Position
                    tree.Distance = pos and roundDistance((Vector3.new(rootPos.X, 0, rootPos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude) or math.huge
                end
            end
            table.sort(cachedTrees, function(a, b)
                return (a.Distance or math.huge) < (b.Distance or math.huge)
            end)
        end
    end

    local results = {}
    local limit = maxClusters or #cachedTrees
    for index = 1, math.min(limit, #cachedTrees) do
        local tree = cachedTrees[index]
        table.insert(results, {
            Name = "Tree " .. index,
            RawName = tree.RawName,
            Path = tree.Path,
            PartCount = tree.PartCount,
            Position = tree.Position,
            Distance = tree.Distance,
        })
    end

    return results
end

return TreeScanner

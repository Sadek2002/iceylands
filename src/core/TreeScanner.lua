local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TreeScanner = {}

TreeScanner.MaxDistance = 260
TreeScanner.CacheTTL = 2.0
TreeScanner._cache = {}
TreeScanner._cacheTime = 0

local TREE_TYPES = {
    tree1 = "Tree 1",
    tree2 = "Tree 2",
    tree3 = "Tree 3",
    tree4 = "Tree 4",
    treeorange = "Orange Tree",
}

local function lowerName(obj)
    return string.lower(obj and obj.Name or "")
end

local function flatDistance(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function getRoot()
    local player = Players.LocalPlayer
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function findPart(container, partName)
    if not container then
        return nil
    end
    local wanted = string.lower(partName)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("BasePart") and string.lower(obj.Name) == wanted then
            return obj
        end
    end
    return nil
end

local function findFirstBasePart(container)
    if not container then
        return nil
    end
    if container:IsA("BasePart") then
        return container
    end
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("BasePart") then
            return obj
        end
    end
    return nil
end

local function getIslandOf(obj)
    local cur = obj
    while cur and cur ~= Workspace do
        if cur.Parent and cur.Parent.Name == "Islands" then
            return cur
        end
        cur = cur.Parent
    end
    return nil
end

local function getIslandFromHit(root)
    if not root then
        return nil
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { Players.LocalPlayer.Character }

    local hit = Workspace:Raycast(root.Position + Vector3.new(0, 8, 0), Vector3.new(0, -80, 0), params)
    if hit and hit.Instance then
        return getIslandOf(hit.Instance)
    end
    return nil
end

local function getNearestIsland(root)
    local islands = Workspace:FindFirstChild("Islands")
    if not islands or not root then
        return nil
    end

    local bestIsland, bestDist = nil, math.huge
    for _, island in ipairs(islands:GetChildren()) do
        local blocks = island:FindFirstChild("Blocks") or island
        for _, part in ipairs(blocks:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                local d = flatDistance(root.Position, part.Position)
                if d < bestDist then
                    bestDist = d
                    bestIsland = island
                end
            end
        end
    end
    return bestIsland
end

local function getPlayerIsland(root)
    return getIslandFromHit(root) or getNearestIsland(root)
end

local function isTreeContainer(obj)
    local raw = lowerName(obj)
    if TREE_TYPES[raw] then
        return true
    end
    return false
end

local function isLiveTreeContainer(container)
    if not container or not container.Parent or not isTreeContainer(container) then
        return false
    end

    local trunk = findPart(container, "trunk")
    if not trunk or not trunk.Parent then
        return false
    end

    -- Saplings/stumps usually lose leaves/spawner. Keep orange/honey variants valid.
    local leaves = findPart(container, "leaves")
    local leafSpawner = container:FindFirstChild("LeafSpawner", true)
    return leaves ~= nil or leafSpawner ~= nil or trunk.Size.Y >= 8
end

local function getTreeBase(container)
    local trunk = findPart(container, "trunk")
    if not trunk then
        return nil, nil
    end
    local y = trunk.Position.Y - (trunk.Size.Y * 0.5) + 2.5
    return Vector3.new(trunk.Position.X, y, trunk.Position.Z), trunk
end

local function countParts(container)
    local count = 0
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("BasePart") then
            count += 1
        end
    end
    return count
end

local function addCandidate(results, seen, container, root, playerIsland, allowOtherIslands)
    if seen[container] or not isLiveTreeContainer(container) then
        return
    end
    seen[container] = true

    local island = getIslandOf(container)
    if playerIsland and island and island ~= playerIsland and not allowOtherIslands then
        return
    end

    local pos, trunk = getTreeBase(container)
    if not pos or not trunk then
        return
    end

    local distance = root and flatDistance(root.Position, pos) or 0
    if root and distance > TreeScanner.MaxDistance then
        return
    end

    local raw = lowerName(container)
    table.insert(results, {
        Name = TREE_TYPES[raw] or container.Name,
        RawName = container.Name,
        Type = raw,
        Path = container:GetFullName(),
        Instance = container,
        Container = container,
        Island = island,
        Trunk = trunk,
        Position = pos,
        PartCount = countParts(container),
        Distance = math.floor(distance * 10 + 0.5) / 10,
    })
end

local function scanBlocksFolder(blocks, results, seen, root, playerIsland, allowOtherIslands)
    if not blocks then
        return
    end

    -- Fast path: trees are direct children of island.Blocks in your export.
    for _, child in ipairs(blocks:GetChildren()) do
        if isTreeContainer(child) then
            addCandidate(results, seen, child, root, playerIsland, allowOtherIslands)
        end
    end

    -- Fallback for replicated worlds where tree folders are nested one level deeper.
    for _, obj in ipairs(blocks:GetDescendants()) do
        if isTreeContainer(obj) then
            addCandidate(results, seen, obj, root, playerIsland, allowOtherIslands)
        end
    end
end

local function scanAll(root)
    local results = {}
    local seen = {}
    local islands = Workspace:FindFirstChild("Islands")
    local playerIsland = getPlayerIsland(root)

    if playerIsland then
        scanBlocksFolder(playerIsland:FindFirstChild("Blocks") or playerIsland, results, seen, root, playerIsland, false)
    end

    -- If player-island detection failed, scan all islands but still obey distance.
    if #results == 0 and islands then
        for _, island in ipairs(islands:GetChildren()) do
            scanBlocksFolder(island:FindFirstChild("Blocks") or island, results, seen, root, nil, true)
        end
    end

    -- Final fallback for non-island testing.
    if #results == 0 then
        scanBlocksFolder(Workspace, results, seen, root, nil, true)
    end

    table.sort(results, function(a, b)
        local ad = a.Distance or math.huge
        local bd = b.Distance or math.huge
        if ad == bd then
            return tostring(a.Path) < tostring(b.Path)
        end
        return ad < bd
    end)

    return results
end

function TreeScanner.IsLiveTree(tree)
    local container = tree and (tree.Instance or tree.Container or tree)
    return isLiveTreeContainer(container)
end

function TreeScanner.RefreshCache(maxTrees)
    local root = getRoot()
    local results = scanAll(root)
    TreeScanner._cache = results
    TreeScanner._cacheTime = os.clock()

    if maxTrees then
        local limited = {}
        for i = 1, math.min(maxTrees, #results) do
            limited[#limited + 1] = results[i]
        end
        return limited
    end
    return results
end

function TreeScanner.GetClusters(maxTrees, forceRefresh)
    if forceRefresh or not TreeScanner._cache or (os.clock() - TreeScanner._cacheTime) > TreeScanner.CacheTTL then
        return TreeScanner.RefreshCache(maxTrees)
    end

    if maxTrees then
        local limited = {}
        for i = 1, math.min(maxTrees, #TreeScanner._cache) do
            limited[#limited + 1] = TreeScanner._cache[i]
        end
        return limited
    end
    return TreeScanner._cache
end

return TreeScanner

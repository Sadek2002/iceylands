local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TreeScanner = {}

TreeScanner.MaxDistance = 180
TreeScanner.CacheTTL = 1.25
TreeScanner._cache = nil
TreeScanner._cacheTime = 0

local TreeFolderNames = {
    tree1 = true,
    tree2 = true,
    tree3 = true,
    tree4 = true,
    treeorange = true,
}

local FriendlyNames = {
    tree1 = "Tree 1",
    tree2 = "Tree 2",
    tree3 = "Tree 3",
    tree4 = "Tree 4",
    treeorange = "Orange Tree",
}

local function getRoot()
    local player = Players.LocalPlayer
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function flatDistance(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function findFirstBasePart(container, name)
    if not container then return nil end
    local wanted = string.lower(name)
    for _, child in ipairs(container:GetDescendants()) do
        if child:IsA("BasePart") and string.lower(child.Name) == wanted then
            return child
        end
    end
    return nil
end

local function isTreeName(name)
    return TreeFolderNames[string.lower(name or "")] == true
end

local function getTreeContainerFrom(obj)
    local cur = obj
    while cur and cur ~= Workspace do
        if (cur:IsA("Folder") or cur:IsA("Model")) and isTreeName(cur.Name) then
            return cur
        end
        cur = cur.Parent
    end
    return nil
end

local function isInsideBlocks(container)
    local cur = container
    while cur and cur ~= Workspace do
        if cur.Name == "Blocks" then
            return true
        end
        cur = cur.Parent
    end
    return false
end

local function getTreePosition(container)
    local trunk = findFirstBasePart(container, "trunk")
    if not trunk then return nil, nil end
    local baseY = trunk.Position.Y - (trunk.Size.Y / 2) + 1.5
    return Vector3.new(trunk.Position.X, baseY, trunk.Position.Z), trunk
end

local function isLiveTree(container)
    if not container or not container.Parent then return false end
    if not isTreeName(container.Name) then return false end
    if not isInsideBlocks(container) then return false end

    local trunk = findFirstBasePart(container, "trunk")
    if not trunk or not trunk.Parent then return false end

    local leaves = findFirstBasePart(container, "leaves")
    local leafSpawner = container:FindFirstChild("LeafSpawner", true)
    return leaves ~= nil or leafSpawner ~= nil
end

local function treeType(container)
    local lower = string.lower(container.Name)
    return FriendlyNames[lower] or container.Name
end

local function getIslandOf(container)
    local cur = container
    local lastBeforeIslands
    while cur and cur ~= Workspace do
        if cur.Parent and cur.Parent.Name == "Islands" then
            return cur
        end
        lastBeforeIslands = cur
        cur = cur.Parent
    end
    return lastBeforeIslands
end

local function getCurrentIsland(root)
    local islands = Workspace:FindFirstChild("Islands")
    if not islands or not root then return nil end

    local bestIsland = nil
    local bestDistance = math.huge

    for _, island in ipairs(islands:GetChildren()) do
        local blocks = island:FindFirstChild("Blocks")
        if blocks then
            -- Sample only direct block parts. This avoids scanning the entire island every frame.
            local checked = 0
            for _, part in ipairs(blocks:GetChildren()) do
                if part:IsA("BasePart") then
                    checked += 1
                    local d = flatDistance(root.Position, part.Position)
                    if d < bestDistance then
                        bestDistance = d
                        bestIsland = island
                    end
                    if checked >= 160 then break end
                end
            end
        end
    end

    if bestDistance <= 260 then return bestIsland end
    return nil
end

local function addTree(results, seen, container, root)
    if not container or seen[container] then return end
    seen[container] = true

    if not isLiveTree(container) then return end

    local pos, trunk = getTreePosition(container)
    if not pos then return end

    local distance = root and flatDistance(root.Position, pos) or 0
    if root and distance > TreeScanner.MaxDistance then return end

    table.insert(results, {
        Name = treeType(container),
        RawName = container.Name,
        Path = container:GetFullName(),
        Instance = container,
        Container = container,
        Island = getIslandOf(container),
        Trunk = trunk,
        Position = pos,
        Distance = math.floor(distance * 10 + 0.5) / 10,
        PartCount = #container:GetDescendants(),
    })
end

local function scanTreeContainers(scanRoot, root)
    local results = {}
    local seen = {}

    -- Main fast path: real tree containers are direct/descendant children of Blocks.
    local blocks = scanRoot and scanRoot:FindFirstChild("Blocks")
    local rootToScan = blocks or scanRoot
    if not rootToScan then return results end

    for _, obj in ipairs(rootToScan:GetDescendants()) do
        local container = nil
        if (obj:IsA("Folder") or obj:IsA("Model")) and isTreeName(obj.Name) then
            container = obj
        elseif obj:IsA("BasePart") and (string.lower(obj.Name) == "trunk" or string.lower(obj.Name) == "leaves") then
            container = getTreeContainerFrom(obj)
        end

        if container then
            addTree(results, seen, container, root)
        end
    end

    table.sort(results, function(a, b)
        return (a.Distance or math.huge) < (b.Distance or math.huge)
    end)

    return results
end

function TreeScanner.IsLiveTree(tree)
    local container = tree and (tree.Instance or tree.Container or tree)
    return isLiveTree(container)
end

function TreeScanner.GetCurrentIsland()
    return getCurrentIsland(getRoot())
end

function TreeScanner.RefreshCache(maxClusters)
    local root = getRoot()
    local island = getCurrentIsland(root)
    local scanRoot = island or (Workspace:FindFirstChild("Islands") or Workspace)
    local results = scanTreeContainers(scanRoot, root)

    TreeScanner._cache = results
    TreeScanner._cacheTime = os.clock()

    if maxClusters then
        local limited = {}
        for i = 1, math.min(maxClusters, #results) do
            table.insert(limited, results[i])
        end
        return limited
    end

    return results
end

function TreeScanner.GetClusters(maxClusters, forceRefresh)
    if forceRefresh or not TreeScanner._cache or (os.clock() - TreeScanner._cacheTime) > TreeScanner.CacheTTL then
        return TreeScanner.RefreshCache(maxClusters)
    end

    local results = TreeScanner._cache
    if maxClusters then
        local limited = {}
        for i = 1, math.min(maxClusters, #results) do
            table.insert(limited, results[i])
        end
        return limited
    end

    return results
end

return TreeScanner

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TreeScanner = {}

TreeScanner.MaxDistance = 220
TreeScanner.CacheTTL = 2.0
TreeScanner._cache = nil
TreeScanner._cacheTime = 0

local TreeNames = {
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

local function lowerName(obj)
    return string.lower(obj and obj.Name or "")
end

local function isTreeContainer(obj)
    return obj and (obj:IsA("Folder") or obj:IsA("Model")) and TreeNames[lowerName(obj)] == true
end

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

local function findPart(container, partName)
    local wanted = string.lower(partName)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("BasePart") and string.lower(obj.Name) == wanted then
            return obj
        end
    end
    return nil
end

local function hasAncestorNamed(obj, name)
    local cur = obj
    while cur and cur ~= Workspace do
        if cur.Name == name then
            return true
        end
        cur = cur.Parent
    end
    return false
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

local function isLiveTree(container)
    if not isTreeContainer(container) or not container.Parent then
        return false
    end

    -- Real trees are stored below island Blocks. This avoids pets, mobs, and random models.
    if not hasAncestorNamed(container, "Blocks") then
        return false
    end

    local trunk = findPart(container, "trunk")
    if not trunk or not trunk.Parent then
        return false
    end

    -- After a tree is chopped, the trunk/leaves structure is removed or becomes incomplete.
    local leaves = findPart(container, "leaves")
    local leafSpawner = container:FindFirstChild("LeafSpawner", true)
    return leaves ~= nil or leafSpawner ~= nil
end

local function getPosition(container)
    local trunk = findPart(container, "trunk")
    if not trunk then
        return nil, nil
    end

    local groundY = trunk.Position.Y - (trunk.Size.Y * 0.5) + 2.5
    return Vector3.new(trunk.Position.X, groundY, trunk.Position.Z), trunk
end

local function addTree(results, seen, container, root)
    if seen[container] or not isLiveTree(container) then
        return
    end
    seen[container] = true

    local pos, trunk = getPosition(container)
    if not pos or not trunk then
        return
    end

    local distance = root and flatDistance(root.Position, pos) or 0
    if root and distance > TreeScanner.MaxDistance then
        return
    end

    local raw = lowerName(container)
    table.insert(results, {
        Name = FriendlyNames[raw] or container.Name,
        RawName = container.Name,
        Path = container:GetFullName(),
        Instance = container,
        Container = container,
        Island = getIslandOf(container),
        Trunk = trunk,
        Position = pos,
        Distance = math.floor(distance * 10 + 0.5) / 10,
    })
end

local function scanUnder(scanRoot, root, results, seen)
    if not scanRoot then
        return
    end

    -- Fast path: tree containers themselves.
    for _, obj in ipairs(scanRoot:GetDescendants()) do
        if isTreeContainer(obj) then
            addTree(results, seen, obj, root)
        end
    end
end

local function scanAll(root)
    local results = {}
    local seen = {}
    local islands = Workspace:FindFirstChild("Islands")

    if islands then
        for _, island in ipairs(islands:GetChildren()) do
            local blocks = island:FindFirstChild("Blocks")
            scanUnder(blocks or island, root, results, seen)
        end
    else
        scanUnder(Workspace, root, results, seen)
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

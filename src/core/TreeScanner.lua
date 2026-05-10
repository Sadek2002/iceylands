local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TreeScanner = {}

TreeScanner.MaxDistance = 180
TreeScanner.CacheTTL = 1.25
TreeScanner._cache = nil
TreeScanner._cacheTime = 0

local TREE_NAMES = {
    tree1 = true,
    tree2 = true,
    tree3 = true,
    tree4 = true,
    treeorange = true,
}

local FRIENDLY_NAMES = {
    tree1 = "Tree 1",
    tree2 = "Tree 2",
    tree3 = "Tree 3",
    tree4 = "Tree 4",
    treeorange = "Orange Tree",
}

local function lowerName(obj)
    return string.lower(obj and obj.Name or "")
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

local function isPlayerCharacter(obj)
    local player = Players.LocalPlayer
    return player and player.Character and obj and obj:IsDescendantOf(player.Character)
end

local function findPart(container, name)
    local wanted = string.lower(name)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("BasePart") and string.lower(obj.Name) == wanted then
            return obj
        end
    end
    return nil
end

local function findAnyPart(container)
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

local function getPlayerIsland(root)
    if not root then
        return nil
    end

    local islands = Workspace:FindFirstChild("Islands")
    if not islands then
        return nil
    end

    local closest, best = nil, math.huge
    for _, island in ipairs(islands:GetChildren()) do
        local blocks = island:FindFirstChild("Blocks") or island
        local any = findAnyPart(blocks)
        if any then
            local d = flatDistance(root.Position, any.Position)
            if d < best then
                closest = island
                best = d
            end
        end
    end
    return closest
end

local function isTreeContainer(obj)
    -- Trees can be Folder, Model, or other containers depending on replication.
    return obj and TREE_NAMES[lowerName(obj)] == true and not isPlayerCharacter(obj)
end

local function isLiveContainer(container)
    if not container or not container.Parent or not isTreeContainer(container) then
        return false
    end

    local trunk = findPart(container, "trunk")
    if not trunk or not trunk.Parent then
        return false
    end

    -- A chopped tree usually loses leaves/spawner. Keep this loose so honey/orange variants still count.
    local leaves = findPart(container, "leaves")
    local spawner = container:FindFirstChild("LeafSpawner", true)
    return leaves ~= nil or spawner ~= nil or trunk.Size.Y > 8
end

local function getTreePosition(container)
    local trunk = findPart(container, "trunk")
    if not trunk then
        return nil, nil
    end

    local baseY = trunk.Position.Y - (trunk.Size.Y * 0.5) + 2.5
    return Vector3.new(trunk.Position.X, baseY, trunk.Position.Z), trunk
end

local function addTree(list, seen, container, root, playerIsland)
    if seen[container] or not isLiveContainer(container) then
        return
    end
    seen[container] = true

    local pos, trunk = getTreePosition(container)
    if not pos or not trunk then
        return
    end

    local island = getIslandOf(container)
    -- Prefer local island; fallback still allows scanning if island detection fails.
    if playerIsland and island and island ~= playerIsland then
        return
    end

    local dist = root and flatDistance(root.Position, pos) or 0
    if root and dist > TreeScanner.MaxDistance then
        return
    end

    local raw = lowerName(container)
    table.insert(list, {
        Name = FRIENDLY_NAMES[raw] or container.Name,
        RawName = container.Name,
        Path = container:GetFullName(),
        Instance = container,
        Container = container,
        Island = island,
        Trunk = trunk,
        Position = pos,
        Distance = math.floor(dist * 10 + 0.5) / 10,
    })
end

local function scanAll(root)
    local results = {}
    local seen = {}
    local playerIsland = getPlayerIsland(root)

    local islands = Workspace:FindFirstChild("Islands")
    local roots = {}

    if playerIsland then
        table.insert(roots, playerIsland)
    elseif islands then
        for _, island in ipairs(islands:GetChildren()) do
            table.insert(roots, island)
        end
    else
        table.insert(roots, Workspace)
    end

    for _, scanRoot in ipairs(roots) do
        for _, obj in ipairs(scanRoot:GetDescendants()) do
            if isTreeContainer(obj) then
                addTree(results, seen, obj, root, playerIsland)
            end
        end
    end

    -- Last-resort fallback for worlds where player-island detection guesses wrong.
    if #results == 0 and islands then
        for _, obj in ipairs(islands:GetDescendants()) do
            if isTreeContainer(obj) then
                addTree(results, seen, obj, root, nil)
            end
        end
    end

    table.sort(results, function(a, b)
        return (a.Distance or math.huge) < (b.Distance or math.huge)
    end)

    return results
end

function TreeScanner.IsLiveTree(tree)
    local container = tree and (tree.Instance or tree.Container or tree)
    return isLiveContainer(container)
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

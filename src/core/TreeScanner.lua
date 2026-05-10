local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TreeScanner = {}

TreeScanner.MaxDistance = 220

local TreeFolderNames = {
    tree1 = true,
    tree2 = true,
    tree3 = true,
    tree4 = true,
    treeorange = true,
}

local FriendlyNames = {
    tree1 = "Tree",
    tree2 = "Tree",
    tree3 = "Tree",
    tree4 = "Tree",
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

local function getCurrentIsland(root)
    local islands = Workspace:FindFirstChild("Islands")
    if not islands or not root then
        return nil
    end

    local bestIsland
    local bestDistance = math.huge

    for _, island in ipairs(islands:GetChildren()) do
        local blocks = island:FindFirstChild("Blocks")
        if blocks then
            for _, part in ipairs(blocks:GetChildren()) do
                if part:IsA("BasePart") then
                    local distance = flatDistance(root.Position, part.Position)
                    if distance < bestDistance then
                        bestDistance = distance
                        bestIsland = island
                    end
                end
            end
        end
    end

    if bestDistance <= 260 then
        return bestIsland
    end

    return nil
end

local function findFirstBasePart(container, name)
    for _, child in ipairs(container:GetDescendants()) do
        if child:IsA("BasePart") and string.lower(child.Name) == string.lower(name) then
            return child
        end
    end
    return nil
end

local function getPivotPosition(container)
    if container:IsA("BasePart") then
        return container.Position
    end

    if container:IsA("Model") then
        local ok, pivot = pcall(function()
            return container:GetPivot()
        end)
        if ok then
            return pivot.Position
        end
    end

    local count = 0
    local sum = Vector3.zero
    for _, child in ipairs(container:GetDescendants()) do
        if child:IsA("BasePart") then
            sum += child.Position
            count += 1
        end
    end

    if count > 0 then
        return sum / count
    end

    return nil
end

local function getTreePosition(container)
    local trunk = findFirstBasePart(container, "trunk")
    if trunk then
        local y = trunk.Position.Y - (trunk.Size.Y / 2) + 1.5
        return Vector3.new(trunk.Position.X, y, trunk.Position.Z), trunk
    end

    local pos = getPivotPosition(container)
    return pos, nil
end

local function isLiveTree(container)
    if not container or not container.Parent then
        return false
    end

    local trunk = findFirstBasePart(container, "trunk")
    local leaves = findFirstBasePart(container, "leaves")
    local leafSpawner = container:FindFirstChild("LeafSpawner", true)

    -- Real trees in this game have a trunk and usually leaves or a LeafSpawner.
    return trunk ~= nil and (leaves ~= nil or leafSpawner ~= nil)
end

local function treeType(container)
    local lower = string.lower(container.Name)
    if lower:find("orange", 1, true) then
        return "Orange Tree"
    end
    return FriendlyNames[lower] or container.Name
end

local function scanTreeContainers(scanRoot, root)
    local results = {}
    local seen = {}

    for _, obj in ipairs(scanRoot:GetDescendants()) do
        local lower = string.lower(obj.Name)
        if (obj:IsA("Folder") or obj:IsA("Model")) and TreeFolderNames[lower] and not seen[obj] then
            seen[obj] = true

            if isLiveTree(obj) then
                local pos, trunk = getTreePosition(obj)
                if pos then
                    local distance = root and flatDistance(root.Position, pos) or 0
                    if not root or distance <= TreeScanner.MaxDistance then
                        table.insert(results, {
                            Name = treeType(obj),
                            RawName = obj.Name,
                            Path = obj:GetFullName(),
                            Instance = obj,
                            Trunk = trunk,
                            Position = pos,
                            Distance = math.floor(distance * 10 + 0.5) / 10,
                            PartCount = #obj:GetDescendants(),
                        })
                    end
                end
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
    return isLiveTree(container)
end

function TreeScanner.GetCurrentIsland()
    return getCurrentIsland(getRoot())
end

function TreeScanner.GetClusters(maxClusters)
    local root = getRoot()
    local island = getCurrentIsland(root)
    local scanRoot = island or Workspace:FindFirstChild("Islands") or Workspace
    local results = scanTreeContainers(scanRoot, root)

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

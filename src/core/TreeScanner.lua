local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TreeScanner = {}

local TREE_NAMES = {
    tree1 = true,
    tree2 = true,
    tree3 = true,
    tree4 = true,
    treeOrange = true,
}

local function getRoot()
    local player = Players.LocalPlayer
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isTreeContainer(obj)
    return TREE_NAMES[obj.Name] == true
end

local function findTrunk(container)
    local trunk = container:FindFirstChild("trunk", true)
    if trunk and trunk:IsA("BasePart") then
        return trunk
    end

    for _, child in ipairs(container:GetDescendants()) do
        if child:IsA("BasePart") and string.lower(child.Name) == "trunk" then
            return child
        end
    end

    return nil
end

local function isAliveTree(container, trunk)
    if not container or not trunk then
        return false
    end

    if not container:IsDescendantOf(Workspace) or not trunk:IsDescendantOf(Workspace) then
        return false
    end

    return true
end

local function makeTreeInfo(container, root)
    local trunk = findTrunk(container)
    if not isAliveTree(container, trunk) then
        return nil
    end

    local position = trunk.Position
    local distance = root and (root.Position - position).Magnitude or 0

    return {
        Name = container.Name,
        RawName = container.Name,
        Container = container,
        Model = container,
        Trunk = trunk,
        Position = position,
        Distance = distance,
        Path = container:GetFullName(),
        PartCount = #container:GetDescendants(),
    }
end

function TreeScanner.GetTrees(maxTrees)
    local root = getRoot()
    local scanRoot = Workspace:FindFirstChild("Islands") or Workspace
    local trees = {}
    local seen = {}

    for _, obj in ipairs(scanRoot:GetDescendants()) do
        if isTreeContainer(obj) and not seen[obj] then
            seen[obj] = true
            local info = makeTreeInfo(obj, root)
            if info then
                table.insert(trees, info)
            end
        end
    end

    table.sort(trees, function(a, b)
        return (a.Distance or math.huge) < (b.Distance or math.huge)
    end)

    if maxTrees then
        local limited = {}
        for index = 1, math.min(maxTrees, #trees) do
            table.insert(limited, trees[index])
        end
        return limited
    end

    return trees
end

function TreeScanner.GetNearestTree()
    return TreeScanner.GetTrees(1)[1]
end

-- Backwards-compatible name used by old UI code.
function TreeScanner.GetClusters(maxClusters)
    return TreeScanner.GetTrees(maxClusters)
end

return TreeScanner

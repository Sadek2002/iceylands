local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TreeScanner = {}

local ValidTreeModelNames = {
    tree1 = true,
    tree2 = true,
    tree3 = true,
    tree4 = true,
    tree5 = true,
    treeorange = true,
}

local function getRoot()
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function round1(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function getPath(obj)
    return obj and obj:GetFullName() or ""
end

local function isTreeModel(model)
    if not model or not model:IsA("Model") then
        return false
    end

    local name = string.lower(model.Name)
    if not ValidTreeModelNames[name] and not string.match(name, "^tree%d+$") and not string.find(name, "treeorange", 1, true) then
        return false
    end

    local parent = model.Parent
    if not parent or parent.Name ~= "Blocks" then
        return false
    end

    return model:FindFirstChild("trunk", true) ~= nil or model:FindFirstChild("leaves", true) ~= nil or model:FindFirstChild(model.Name, true) ~= nil
end

local function getBasePart(model)
    local sameName = model:FindFirstChild(model.Name, true)
    if sameName and sameName:IsA("BasePart") then
        return sameName
    end

    local trunk = model:FindFirstChild("trunk", true)
    if trunk and trunk:IsA("BasePart") then
        return trunk
    end

    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function getTrunkPart(model)
    local trunk = model and model:FindFirstChild("trunk", true)
    if trunk and trunk:IsA("BasePart") then
        return trunk
    end
    return getBasePart(model)
end

local function getTreePosition(model)
    local base = getBasePart(model)
    local trunk = getTrunkPart(model)

    if base then
        return base.Position, trunk
    end

    local ok, pivot = pcall(function()
        return model:GetPivot()
    end)
    if ok and pivot then
        return pivot.Position, trunk
    end

    return nil, trunk
end

function TreeScanner.GetClusters(maxClusters)
    local root = getRoot()
    local scanRoot = Workspace:FindFirstChild("Islands") or Workspace
    local results = {}
    local seen = {}

    for _, model in ipairs(scanRoot:GetDescendants()) do
        if isTreeModel(model) and not seen[model] then
            seen[model] = true
            local position, trunk = getTreePosition(model)
            if position then
                local distance
                if root then
                    local a = Vector3.new(root.Position.X, 0, root.Position.Z)
                    local b = Vector3.new(position.X, 0, position.Z)
                    distance = (a - b).Magnitude
                else
                    distance = 0
                end

                table.insert(results, {
                    Name = model.Name,
                    RawName = model.Name,
                    Path = getPath(model),
                    TrunkPath = trunk and getPath(trunk) or nil,
                    PartCount = 1,
                    Position = position,
                    Distance = round1(distance),
                })
            end
        end
    end

    table.sort(results, function(a, b)
        if a.Distance and b.Distance then
            return a.Distance < b.Distance
        end
        return a.Name < b.Name
    end)

    if maxClusters then
        local limited = {}
        for i = 1, math.min(maxClusters, #results) do
            limited[i] = results[i]
        end
        return limited
    end

    return results
end

return TreeScanner

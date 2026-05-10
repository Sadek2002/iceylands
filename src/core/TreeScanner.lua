local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TreeScanner = {}

local TreeNames = {
    ["Apple Tree"] = true,
    ["Avocado Tree"] = true,
    ["Birch Tree"] = true,
    ["Cherry Blossom Tree"] = true,
    ["Hickory Tree"] = true,
    ["Kiwi Tree"] = true,
    ["Lemon Tree"] = true,
    ["Maple Tree"] = true,
    ["Oak Tree"] = true,
    ["Orange Tree"] = true,
    ["Palm Tree"] = true,
    ["Pine Tree"] = true,
    ["Plum Tree"] = true,
    ["Spirit Tree"] = true,
}

local IgnoreNames = {
    IceylandsDemo = true,
}

local function getRoot()
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isIgnored(item)
    local player = Players.LocalPlayer
    local character = player and player.Character
    if character and item:IsDescendantOf(character) then
        return true
    end

    local backpack = player and player:FindFirstChild("Backpack")
    if backpack and item:IsDescendantOf(backpack) then
        return true
    end

    local current = item
    while current do
        if IgnoreNames[current.Name] then
            return true
        end
        current = current.Parent
    end

    return false
end

local function isTreeCandidate(item)
    if isIgnored(item) then
        return false
    end

    if TreeNames[item.Name] then
        return true
    end

    local name = string.lower(item.Name)
    if string.match(name, "^tree%d*$") or string.match(name, "^tree%a+$") then
        return true
    end

    if item.Parent and item.Parent.Name == "Blocks" and string.find(name, "tree", 1, true) then
        return true
    end

    return false
end

local function getPosition(item)
    if item:IsA("BasePart") then
        return item.Position
    end

    if item:IsA("Model") then
        local trunk
        local firstPart
        for _, part in ipairs(item:GetDescendants()) do
            if part:IsA("BasePart") then
                firstPart = firstPart or part
                local name = string.lower(part.Name)
                if string.find(name, "trunk", 1, true) or string.find(name, "log", 1, true) or string.find(name, "wood", 1, true) then
                    trunk = part
                    break
                end
            end
        end

        if trunk then
            return trunk.Position
        end

        if firstPart then
            return firstPart.Position
        end

        local ok, pivot = pcall(function()
            return item:GetPivot()
        end)

        if ok and pivot then
            return pivot.Position
        end
    end

    return nil
end

local function flatDistance(a, b)
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

function TreeScanner.GetClusters(maxClusters)
    local root = getRoot()
    local candidates = {}

    for _, item in ipairs(Workspace:GetDescendants()) do
        if (item:IsA("Model") or item:IsA("BasePart")) and isTreeCandidate(item) then
            local position = getPosition(item)
            if position then
                table.insert(candidates, {
                    Name = item.Name,
                    ClassName = item.ClassName,
                    Path = item:GetFullName(),
                    Position = position,
                    Distance = root and flatDistance(root.Position, position) or 0,
                })
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.Distance < b.Distance
    end)

    local clusters = {}
    local clusterRadius = 10

    for _, candidate in ipairs(candidates) do
        local assigned = false

        for _, cluster in ipairs(clusters) do
            if flatDistance(candidate.Position, cluster.Center) <= clusterRadius then
                cluster.Count += 1
                cluster.Sum += candidate.Position
                cluster.Center = cluster.Sum / cluster.Count
                cluster.MinY = math.min(cluster.MinY, candidate.Position.Y)
                if candidate.Distance < cluster.Distance then
                    cluster.Distance = candidate.Distance
                    cluster.PrimaryPath = candidate.Path
                    cluster.PrimaryName = candidate.Name
                end
                table.insert(cluster.RawNames, candidate.Name)
                table.insert(cluster.Paths, candidate.Path)
                assigned = true
                break
            end
        end

        if not assigned then
            table.insert(clusters, {
                Count = 1,
                Sum = candidate.Position,
                Center = candidate.Position,
                MinY = candidate.Position.Y,
                Distance = candidate.Distance,
                PrimaryPath = candidate.Path,
                PrimaryName = candidate.Name,
                RawNames = { candidate.Name },
                Paths = { candidate.Path },
            })
        end
    end

    local results = {}
    for index, cluster in ipairs(clusters) do
        local position = Vector3.new(cluster.Center.X, cluster.MinY + 0.75, cluster.Center.Z)
        local distance = root and flatDistance(root.Position, position) or cluster.Distance

        table.insert(results, {
            Name = cluster.PrimaryName or ("Tree Cluster " .. index),
            RawName = table.concat(cluster.RawNames, ", "),
            Path = cluster.PrimaryPath or cluster.Paths[1],
            PartCount = cluster.Count,
            Position = position,
            Distance = distance and math.floor(distance * 10 + 0.5) / 10 or nil,
        })
    end

    table.sort(results, function(a, b)
        if a.Distance and b.Distance then
            return a.Distance < b.Distance
        end

        return a.Name < b.Name
    end)

    if maxClusters then
        local limited = {}
        for index = 1, math.min(maxClusters, #results) do
            table.insert(limited, results[index])
        end
        return limited
    end

    return results
end

return TreeScanner

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

local function getRoot()
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isTreeCandidate(item)
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
        local ok, pivot = pcall(function()
            return item:GetPivot()
        end)

        if ok then
            return pivot.Position
        end
    end

    return nil
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
                    Distance = root and (root.Position - position).Magnitude or 0,
                })
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.Distance < b.Distance
    end)

    local clusters = {}
    local clusterRadius = 16

    for _, candidate in ipairs(candidates) do
        local assigned = false

        for _, cluster in ipairs(clusters) do
            local flatCandidate = Vector3.new(candidate.Position.X, 0, candidate.Position.Z)
            local flatCluster = Vector3.new(cluster.Center.X, 0, cluster.Center.Z)

            if (flatCandidate - flatCluster).Magnitude <= clusterRadius then
                cluster.Count += 1
                cluster.Sum += candidate.Position
                cluster.Center = cluster.Sum / cluster.Count
                cluster.MinY = math.min(cluster.MinY, candidate.Position.Y)
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
                RawNames = { candidate.Name },
                Paths = { candidate.Path },
            })
        end
    end

    local results = {}
    for index, cluster in ipairs(clusters) do
        local position = Vector3.new(cluster.Center.X, cluster.MinY + 0.75, cluster.Center.Z)
        local distance = root and (root.Position - position).Magnitude or cluster.Distance

        table.insert(results, {
            Name = "Tree Cluster " .. index,
            RawName = table.concat(cluster.RawNames, ", "),
            Path = cluster.Paths[1],
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

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Runtime = _G.IceylandsLoader
local Components = Runtime.LoadModule("src/ui/Components.lua")

local Foraging = {}

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

local AxePriority = {
    ["Wooden"] = 1,
    ["Stone"] = 2,
    ["Iron"] = 3,
    ["Gilded Steel"] = 4,
    ["Diamond"] = 5,
    ["Opal"] = 6,
    ["Void Mattock"] = 7,
}

local function getRoot()
    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getModelPosition(model)
    if model:IsA("BasePart") then
        return model.Position
    end

    if model:IsA("Model") then
        local ok, pivot = pcall(function()
            return model:GetPivot()
        end)

        if ok then
            return pivot.Position
        end

        local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position
    end

    return nil
end

local function scanTools()
    local player = Players.LocalPlayer
    local results = {}
    local bestName = "None"
    local bestScore = -1

    local function read(container)
        if not container then
            return
        end

        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(results, item.Name)

                for axeName, score in pairs(AxePriority) do
                    if string.find(string.lower(item.Name), string.lower(axeName), 1, true) and score > bestScore then
                        bestName = item.Name
                        bestScore = score
                    end
                end
            end
        end
    end

    if player then
        read(player:FindFirstChild("Backpack"))
        read(player.Character)
    end

    table.sort(results)

    return {
        BestAxe = bestName,
        Tools = results,
    }
end

local function scanTrees()
    local root = getRoot()
    local trees = {}

    for _, item in ipairs(Workspace:GetDescendants()) do
        if (item:IsA("Model") or item:IsA("BasePart")) and TreeNames[item.Name] then
            local position = getModelPosition(item)
            local distance = root and position and (root.Position - position).Magnitude or nil

            table.insert(trees, {
                Name = item.Name,
                Path = item:GetFullName(),
                Distance = distance and math.floor(distance * 10 + 0.5) / 10 or nil,
            })
        end
    end

    table.sort(trees, function(a, b)
        if a.Distance and b.Distance then
            return a.Distance < b.Distance
        end

        return a.Name < b.Name
    end)

    return trees
end

local function buildSummary(audit)
    local lines = {
        "Best axe: " .. audit.bestAxe,
        "Tools found: " .. tostring(#audit.tools),
        "Trees found: " .. tostring(#audit.trees),
    }

    for index = 1, math.min(6, #audit.trees) do
        local tree = audit.trees[index]
        local distance = tree.Distance and (tostring(tree.Distance) .. " studs") or "unknown distance"
        table.insert(lines, ("%d. %s - %s"):format(index, tree.Name, distance))
    end

    if #audit.trees == 0 then
        table.insert(lines, "No known tree models are currently visible to the client.")
    end

    return table.concat(lines, "\n")
end

local function collectAudit()
    local tools = scanTools()
    local trees = scanTrees()

    return {
        generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        bestAxe = tools.BestAxe,
        tools = tools.Tools,
        trees = trees,
    }
end

function Foraging.Mount(parent, services)
    local audit = collectAudit()
    local _, summaryLabel = Components.TextBlock(parent, "Foraging Audit", buildSummary(audit), 170)

    Components.Button(parent, "Refresh Audit", "Rescans visible tree models and local tool names.", "Refresh", function()
        audit = collectAudit()
        summaryLabel.Text = buildSummary(audit)
        services.Toasts:Push("Foraging audit refreshed", "success")
    end)

    Components.Button(parent, "Export Audit", "Copies a read-only JSON snapshot for project documentation.", "Copy JSON", function()
        audit = collectAudit()
        summaryLabel.Text = buildSummary(audit)

        local json = HttpService:JSONEncode(audit)
        local ok = services.Config.Copy(json)
        services.Toasts:Push(ok and "Foraging audit copied" or json, ok and "success" or "warn")
    end)
end

return Foraging

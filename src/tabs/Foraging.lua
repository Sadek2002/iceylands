local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Runtime = _G.IceylandsLoader
local Components = Runtime.LoadModule("src/ui/Components.lua")
local TreeScanner = Runtime.LoadModule("src/core/TreeScanner.lua")

local Foraging = {}

local AxePriority = {
    ["Wooden"] = 1,
    ["Stone"] = 2,
    ["Iron"] = 3,
    ["Gilded Steel"] = 4,
    ["Diamond"] = 5,
    ["Opal"] = 6,
    ["Void Mattock"] = 7,
}

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
    return TreeScanner.GetClusters()
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
        table.insert(lines, ("%d. %s (%d parts) - %s"):format(index, tree.Name, tree.PartCount or 1, distance))
    end

    if #audit.trees == 0 then
        table.insert(lines, "No known tree models are currently visible to the client.")
    end

    return table.concat(lines, "\n")
end

local function collectAudit()
    local tools = scanTools()
    local trees = {}

    for _, tree in ipairs(scanTrees()) do
        table.insert(trees, {
            Name = tree.Name,
            RawName = tree.RawName,
            Path = tree.Path,
            PartCount = tree.PartCount,
            Distance = tree.Distance,
            Position = tree.Position and {
                X = math.floor(tree.Position.X * 10 + 0.5) / 10,
                Y = math.floor(tree.Position.Y * 10 + 0.5) / 10,
                Z = math.floor(tree.Position.Z * 10 + 0.5) / 10,
            } or nil,
        })
    end

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

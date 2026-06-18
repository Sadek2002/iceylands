local Runtime = _G.IceylandsLoader
local Components = Runtime.LoadModule("src/ui/Components.lua")
local DemoWorld = Runtime.LoadModule("src/core/DemoWorld.lua")
local TreeScanner = Runtime.LoadModule("src/core/TreeScanner.lua")

local Foraging = {}
local FORAGING_VERSION = "v48"

local running = false
local worker = nil
local statusLabel = nil

local function setStatus(services, text)
    services.State.ForagingStatus = text

    if statusLabel then
        statusLabel.Text = text
    end
end

local function getChar()
    local player = game:GetService("Players").LocalPlayer
    local char = player.Character or player.CharacterAdded:Wait()
    return char, char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function moveNear(treeInfo, stopDistance)
    local _, humanoid, root = getChar()
    local position = treeInfo and treeInfo.Position

    if not humanoid or not root or not position then
        return false, "Character not ready"
    end

    local offset = root.Position - position
    if offset.Magnitude < 1 then
        offset = Vector3.new(1, 0, 0)
    end

    local destination = position + offset.Unit * stopDistance
    humanoid:MoveTo(destination)

    local reached = false
    local connection
    connection = humanoid.MoveToFinished:Connect(function(success)
        reached = success == true
        if connection then
            connection:Disconnect()
        end
    end)

    local started = os.clock()
    while running and os.clock() - started < 6 do
        if reached then
            break
        end
        task.wait(0.1)
    end

    if connection then
        connection:Disconnect()
    end

    if reached then
        return true
    end

    return false, "Move timed out"
end

local function chooseTree(radius)
    local trees = TreeScanner.GetTrees()

    for _, tree in ipairs(trees) do
        if (tree.Distance or math.huge) <= radius then
            return tree
        end
    end

    return nil
end

local function stepForaging(services)
    local radius = services.State.ForagingRadius or 120
    local stopDistance = services.State.ForagingStopDistance or 7

    local tree = chooseTree(radius)
    if not tree then
        setStatus(services, "No trees within " .. tostring(radius) .. " studs")
        return
    end

    setStatus(
        services,
        string.format(
            "Targeting %s (%d studs)",
            tree.Name,
            math.floor((tree.Distance or 0) + 0.5)
        )
    )

    pcall(function()
        DemoWorld.EquipBestAxe()
    end)

    local moved, moveError = moveNear(tree, stopDistance)
    if not moved then
        setStatus(services, "Could not reach tree: " .. tostring(moveError))
        return
    end

    setStatus(services, "At tree: " .. tree.Name .. " (interaction placeholder)")

    -- Development-safe placeholder.
    -- Keep the actual harvest/chop behavior in a Studio-owned API or local test harness.
end

local function startLoop(services)
    if worker then
        task.cancel(worker)
    end

    worker = task.spawn(function()
        setStatus(services, "Scanning for trees")

        while running do
            stepForaging(services)
            task.wait(services.State.ForagingDelay or 1.25)
        end

        setStatus(services, "Disabled")
    end)
end

local function stopLoop(services)
    running = false

    if worker then
        task.cancel(worker)
        worker = nil
    end

    setStatus(services, "Disabled")
end

local function setForaging(value, services)
    running = value
    services.State.MovementDemo = value
    services.State.AutoCollectDemo = false
    services.State.OverlayDemo = false

    if getgenv then
        getgenv().IceylandsIgnoreReopenClicks = value == true
    end

    if value then
        startLoop(services)
    else
        stopLoop(services)
    end

    services.Toasts:Push(
        (value and "Auto Foraging enabled" or "Auto Foraging disabled") .. " - Foraging " .. FORAGING_VERSION,
        value and "success" or "info"
    )
end

function Foraging.Mount(parent, services)
    local _, bodyLabel = Components.TextBlock(
        parent,
        "Foraging Status",
        services.State.ForagingStatus or "Disabled",
        96
    )
    statusLabel = bodyLabel

    Components.Toggle(
        parent,
        "Auto Foraging",
        "Scans nearby trees, equips your axe, and walks beside the closest match.",
        services.State.MovementDemo,
        function(value)
            setForaging(value, services)
        end
    )

    if Components.Slider then
        Components.Slider(
            parent,
            "Foraging Radius",
            "How far the scanner checks for trees.",
            25,
            300,
            services.State.ForagingRadius or 120,
            function(value)
                services.State.ForagingRadius = value
                if not running then
                    setStatus(services, "Radius set to " .. tostring(value) .. " studs")
                end
            end
        )

        Components.Slider(
            parent,
            "Stop Distance",
            "How close movement stops next to the target tree.",
            4,
            16,
            services.State.ForagingStopDistance or 7,
            function(value)
                services.State.ForagingStopDistance = value
                if not running then
                    setStatus(services, "Stop distance set to " .. tostring(value) .. " studs")
                end
            end
        )

        Components.Slider(
            parent,
            "Move Delay (x0.1s)",
            "Delay between scans in tenths of a second.",
            2,
            50,
            math.floor(((services.State.ForagingDelay or 1.25) * 10) + 0.5),
            function(value)
                services.State.ForagingDelay = value / 10
                if not running then
                    setStatus(services, string.format("Move delay set to %.1fs", services.State.ForagingDelay))
                end
            end
        )
    end
end

return Foraging

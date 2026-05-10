local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Runtime = _G.IceylandsLoader
local TreeScanner = Runtime.LoadModule("src/core/TreeScanner.lua")

local AxePriority = {
    woodAxe = 1,
    stoneAxe = 2,
    ironAxe = 3,
    gildedSteelAxe = 4,
    diamondAxe = 5,
    opalAxe = 6,
    voidMattock = 7,
}

local removeDemoAxe
local getLiveTreeForMarker

local DemoWorld = {
    FolderName = "IceylandsDemo",
    MovementConnection = nil,
    OverlayItems = {},
    AutoCollectRunning = false,
    HitsRequired = 3,
    ClickInterval = 0.22,
    LastTreeClick = 0,
    CurrentMoveTarget = nil,
    MoveToIssuedAt = 0,
    TargetSearchInterval = 0.6,
    LastTargetSearch = 0,
    EquipIssuedAt = 0,
    Notify = nil,
    LastWarningAt = 0,
}

local function isLiveTarget(target)
    if not target or not target.Parent or target:GetAttribute("Collected") then
        return false
    end

    local sourcePath = target:GetAttribute("SourceTreePath")
    if sourcePath and sourcePath ~= "" then
        return getLiveTreeForMarker(target) ~= nil
    end

    local hitsRemaining = target:GetAttribute("HitsRemaining")
    return hitsRemaining == nil or hitsRemaining > 0
end

local function equipBestAxeThrottled(force)
    if force or os.clock() - DemoWorld.EquipIssuedAt >= 1.0 then
        DemoWorld.EquipIssuedAt = os.clock()
        removeDemoAxe()
        DemoWorld.EquipBestAxe()
    end
end

local function getCharacter()
    local player = Players.LocalPlayer
    return player and player.Character
end

local function getRoot()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end


local function notify(message, kind)
    local now = os.clock()
    if kind == "warn" and now - DemoWorld.LastWarningAt < 3 then
        return
    end
    if kind == "warn" then
        DemoWorld.LastWarningAt = now
    end

    if type(DemoWorld.Notify) == "function" then
        DemoWorld.Notify(message, kind or "warn")
    else
        warn("Iceylands: " .. tostring(message))
    end
end

function DemoWorld.SetNotify(callback)
    DemoWorld.Notify = callback
end

function removeDemoAxe()
    local player = Players.LocalPlayer
    local character = player and player.Character
    local backpack = player and player:FindFirstChild("Backpack")
    local workspaceCharacter = player and Workspace:FindFirstChild(player.Name)

    for _, container in ipairs({ character, backpack, workspaceCharacter, Workspace }) do
        if container then
            for _, item in ipairs(container:GetDescendants()) do
                if item.Name == "Iceylands Demo Axe" then
                    item:Destroy()
                end
            end
        end
    end
end

local function getFolder()
    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = DemoWorld.FolderName
        folder.Parent = Workspace
    end

    return folder
end

local function makePart(name, position, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.Size = Vector3.new(2.5, 2.5, 2.5)
    part.Position = position
    part.Material = Enum.Material.Ice
    part.Color = color
    part.Parent = getFolder()
    return part
end

local function makeTreePoint(name, position)
    local part = makePart(name, position, Color3.fromRGB(106, 202, 255))
    part.Size = Vector3.new(1.25, 1.25, 1.25)
    part.Shape = Enum.PartType.Ball
    part.Material = Enum.Material.Neon
    part.Transparency = 0.12
    return part
end

local function resolveWorkspacePath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    local current = game
    for segment in string.gmatch(path, "[^%.]+") do
        if segment == "game" then
            current = game
        elseif segment == "Workspace" or segment == "workspace" then
            current = Workspace
        elseif current then
            current = current:FindFirstChild(segment)
        end

        if not current then
            return nil
        end
    end

    return current
end

local function getInstancePosition(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance.Position
    end

    if instance:IsA("Model") then
        local ok, pivot = pcall(function()
            return instance:GetPivot()
        end)
        if ok and pivot then
            return pivot.Position
        end
    end

    local part = instance:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

function getLiveTreeForMarker(marker)
    if not marker then
        return nil
    end

    local path = marker:GetAttribute("SourceTreePath")
    local tree = resolveWorkspacePath(path)
    if tree and tree.Parent and (not TreeScanner.IsLiveTreeRoot or TreeScanner.IsLiveTreeRoot(tree)) then
        return tree
    end

    return nil
end

local function getTreePosition(marker)
    local tree = getLiveTreeForMarker(marker)
    if tree and TreeScanner.GetTreePosition then
        return TreeScanner.GetTreePosition(tree)
    end
    return getInstancePosition(tree) or (marker and marker.Position) or nil
end

function DemoWorld.EnsureObjects()
    local folder = getFolder()
    local root = getRoot()
    local origin = root and root.Position or Vector3.new(0, 8, 0)

    local count = 0
    for _, item in ipairs(folder:GetChildren()) do
        if item:GetAttribute("IceylandsDemoObject") then
            count += 1
        end
    end

    if count > 0 then
        return folder
    end

    local offsets = {
        Vector3.new(18, 1, 0),
        Vector3.new(-16, 1, 12),
        Vector3.new(8, 1, -20),
        Vector3.new(26, 1, 18),
        Vector3.new(-24, 1, -14),
    }

    for index, offset in ipairs(offsets) do
        local part = makePart("DemoCollectible" .. index, origin + offset, Color3.fromRGB(106, 202, 255))
        part:SetAttribute("IceylandsDemoObject", true)
        part:SetAttribute("Collected", false)
        part:SetAttribute("HitsRemaining", DemoWorld.HitsRequired)
    end

    return folder
end

function DemoWorld.SpawnObjectsAtTreePositions(maxObjects)
    DemoWorld.ClearObjects()

    local folder = getFolder()
    local clusters = TreeScanner.GetClusters(maxObjects or 10, true)

    local created = 0
    for index, cluster in ipairs(clusters) do
        if created >= (maxObjects or 10) then
            break
        end

        local part = makeTreePoint("DemoTreePoint" .. index, cluster.Position)
        part:SetAttribute("IceylandsDemoObject", true)
        part:SetAttribute("Collected", false)
        part:SetAttribute("HitsRemaining", DemoWorld.HitsRequired)
        part:SetAttribute("SourceTreeName", cluster.RawName)
        part:SetAttribute("SourceTreePath", cluster.Path or "")
        part.Parent = folder
        created += 1
    end

    -- Do not create fake/demo trees when no real tree locations are found.
    return created
end

local function findBestAxeIn(container)
    if not container then
        return nil, -math.huge
    end

    local bestTool
    local bestPriority = -math.huge

    for _, item in ipairs(container:GetChildren()) do
        if item:IsA("Tool") then
            local priority = AxePriority[item.Name]
            if priority and priority > bestPriority then
                bestTool = item
                bestPriority = priority
            end
        end
    end

    return bestTool, bestPriority
end

function DemoWorld.GetBestAxe()
    local player = Players.LocalPlayer
    if not player then
        return nil
    end

    local character = player.Character
    local backpack = player:FindFirstChild("Backpack")

    local backpackTool, backpackPriority = findBestAxeIn(backpack)
    local characterTool, characterPriority = findBestAxeIn(character)

    if characterTool and characterPriority >= backpackPriority then
        return characterTool
    end

    return backpackTool
end

function DemoWorld.EquipBestAxe()
    removeDemoAxe()

    local tool = DemoWorld.GetBestAxe()
    if not tool then
        notify("No test axe found in inventory/backpack.", "warn")
        return false
    end

    local character = getCharacter()
    if tool.Parent == character then
        return true
    end

    local humanoid = getHumanoid()
    if humanoid then
        humanoid:EquipTool(tool)
        return tool.Parent == character
    end

    return false
end

-- Backwards-compatible name used by older Foraging.lua builds.
-- This now equips the best real test axe instead of creating a demo axe.
function DemoWorld.EnsureDemoAxe()
    return DemoWorld.EquipBestAxe()
end

local function getTargetPart(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance
    end

    if instance:IsA("Model") then
        local preferred
        for _, part in ipairs(instance:GetDescendants()) do
            if part:IsA("BasePart") then
                local n = string.lower(part.Name)
                if string.find(n, "trunk", 1, true) or string.find(n, "log", 1, true) or string.find(n, "wood", 1, true) then
                    return part
                end
                preferred = preferred or part
            end
        end
        return preferred
    end

    return instance:FindFirstChildWhichIsA("BasePart", true)
end

function DemoWorld.ActivateHeldAxe(target)
    local player = Players.LocalPlayer
    local character = player and player.Character

    removeDemoAxe()
    if not DemoWorld.EquipBestAxe() then
        return false
    end

    character = player and player.Character
    local tool = DemoWorld.GetBestAxe()
    if not tool or tool.Parent ~= character then
        return false
    end

    tool:SetAttribute("LastDemoTarget", target and target.Name or "")
    tool:SetAttribute("DemoSwingCount", (tool:GetAttribute("DemoSwingCount") or 0) + 1)

    pcall(function()
        tool:Activate()
    end)

    -- Some axe tools only chop when their internal remotes are fired. Try common
    -- RemoteEvent/RemoteFunction descendants with a few safe argument shapes.
    for _, remote in ipairs(tool:GetDescendants()) do
        if remote:IsA("RemoteEvent") then
            pcall(function() remote:FireServer(target) end)
            pcall(function() remote:FireServer(target, target and target.Position) end)
            pcall(function() remote:FireServer("hit", target) end)
            pcall(function() remote:FireServer("swing", target) end)
        elseif remote:IsA("RemoteFunction") then
            pcall(function() remote:InvokeServer(target) end)
            pcall(function() remote:InvokeServer(target, target and target.Position) end)
            pcall(function() remote:InvokeServer("hit", target) end)
            pcall(function() remote:InvokeServer("swing", target) end)
        end
    end

    return true
end


local function pressLeftClick(target)
    local camera = Workspace.CurrentCamera
    local x, y = 400, 300

    if camera then
        local viewportSize = camera.ViewportSize
        x = viewportSize.X / 2
        y = viewportSize.Y / 2

        local targetPart = getTargetPart(target)
        if targetPart then
            local screenPoint, onScreen = camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                x = screenPoint.X
                y = screenPoint.Y
            end
        end
    end

    local clicked = false

    if type(mouse1click) == "function" then
        clicked = pcall(mouse1click) or clicked
    end

    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        clicked = pcall(function()
            mouse1press()
            task.wait(0.05)
            mouse1release()
        end) or clicked
    end

    clicked = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end) or clicked

    return clicked
end

local function damageDemoTree(target, onCollect)
    if not target or target:GetAttribute("Collected") then
        return false
    end

    local sourceTree = getLiveTreeForMarker(target)
    local clickTarget = getTargetPart(sourceTree) or getTargetPart(target) or sourceTree or target

    equipBestAxeThrottled(false)
    pressLeftClick(clickTarget)
    DemoWorld.ActivateHeldAxe(clickTarget)

    if target:GetAttribute("SourceTreePath") and not getLiveTreeForMarker(target) then
        target:SetAttribute("Collected", true)
        target:Destroy()
        if onCollect then
            onCollect(target.Name, 0)
        end
        return true
    end

    -- Demo fallback only: when there is no real source tree, keep the older hit-counter behavior.
    if not target:GetAttribute("SourceTreePath") or target:GetAttribute("SourceTreePath") == "" then
        local hitsRemaining = target:GetAttribute("HitsRemaining")
        if type(hitsRemaining) ~= "number" then
            hitsRemaining = DemoWorld.HitsRequired
        end

        hitsRemaining -= 1
        target:SetAttribute("HitsRemaining", hitsRemaining)

        if onCollect then
            onCollect(target.Name, hitsRemaining)
        end

        if hitsRemaining <= 0 then
            target:SetAttribute("Collected", true)
            target.Transparency = 1
            target.CanTouch = false
            target.CanQuery = false
            target.CanCollide = false
        else
            target.Transparency = math.clamp(0.12 + ((DemoWorld.HitsRequired - hitsRemaining) * 0.16), 0.12, 0.85)
        end
    end

    return true
end

function DemoWorld.ClearObjects()
    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if folder then
        folder:Destroy()
    end
end

function DemoWorld.GetCollectibles()
    local folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    if not folder then
        DemoWorld.SpawnObjectsAtTreePositions(10)
        folder = Workspace:FindFirstChild(DemoWorld.FolderName)
    end

    local items = {}
    if not folder then
        return items
    end

    for _, item in ipairs(folder:GetChildren()) do
        if item:IsA("BasePart") and item:GetAttribute("IceylandsDemoObject") and not item:GetAttribute("Collected") then
            local sourcePath = item:GetAttribute("SourceTreePath")
            if sourcePath and sourcePath ~= "" and not getLiveTreeForMarker(item) then
                item:SetAttribute("Collected", true)
                item:Destroy()
            else
                table.insert(items, item)
            end
        end
    end

    if #items == 0 then
        DemoWorld.SpawnObjectsAtTreePositions(10)
        folder = Workspace:FindFirstChild(DemoWorld.FolderName)
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                if item:IsA("BasePart") and item:GetAttribute("IceylandsDemoObject") and not item:GetAttribute("Collected") then
                    table.insert(items, item)
                end
            end
        end
    end

    return items
end

function DemoWorld.GetNearestCollectible()
    local root = getRoot()
    if not root then
        return nil
    end

    local nearest
    local nearestDistance = math.huge

    for _, item in ipairs(DemoWorld.GetCollectibles()) do
        local distance = (root.Position - item.Position).Magnitude
        if distance < nearestDistance then
            nearest = item
            nearestDistance = distance
        end
    end

    return nearest, nearestDistance
end

function DemoWorld.SetMovementDemo(enabled)
    if DemoWorld.MovementConnection then
        DemoWorld.MovementConnection:Disconnect()
        DemoWorld.MovementConnection = nil
    end

    if not enabled then
        DemoWorld.CurrentMoveTarget = nil
        return
    end

    DemoWorld.CurrentMoveTarget = nil
    DemoWorld.LastTargetSearch = 0
    DemoWorld.MoveToIssuedAt = 0
    equipBestAxeThrottled(true)
    DemoWorld.SpawnObjectsAtTreePositions(10)

    -- Optimised movement mode:
    -- 1) Pick the nearest live tree once.
    -- 2) Stay locked to that target until it disappears/breaks, even if a closer tree spawns.
    -- 3) Only rescan after the locked target is gone, instead of scanning every frame.
    -- 4) Once in axe range, stop walking and only swing/click.
    DemoWorld.MovementConnection = RunService.Heartbeat:Connect(function(deltaTime)
        local now = os.clock()
        local root = getRoot()
        if not root then
            return
        end

        local target = DemoWorld.CurrentMoveTarget
        if not isLiveTarget(target) then
            DemoWorld.CurrentMoveTarget = nil
            target = nil

            if now - DemoWorld.LastTargetSearch < DemoWorld.TargetSearchInterval then
                return
            end

            DemoWorld.LastTargetSearch = now
            DemoWorld.SpawnObjectsAtTreePositions(10)
            target = DemoWorld.GetNearestCollectible()
            if not isLiveTarget(target) then
                notify("No reachable live tree found.", "warn")
                return
            end

            DemoWorld.CurrentMoveTarget = target
            DemoWorld.MoveToIssuedAt = 0
            equipBestAxeThrottled(true)
        else
            equipBestAxeThrottled(false)
        end

        local targetPosition = getTreePosition(target)
        if not targetPosition then
            DemoWorld.CurrentMoveTarget = nil
            notify("Tree target disappeared; finding another tree.", "warn")
            return
        end

        local flatDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(targetPosition.X, 0, targetPosition.Z)).Magnitude

        if flatDistance <= 7 then
            local humanoid = getHumanoid()
            if humanoid then
                humanoid:Move(Vector3.zero, false)
            end

            root.CFrame = CFrame.new(root.Position, Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z))
            if Workspace.CurrentCamera then
                Workspace.CurrentCamera.CFrame = CFrame.new(Workspace.CurrentCamera.CFrame.Position, targetPosition)
            end

            if now - DemoWorld.LastTreeClick >= DemoWorld.ClickInterval then
                DemoWorld.LastTreeClick = now
                damageDemoTree(target)
            end
            return
        end

        -- Walk toward the locked tree, but only issue movement every ~0.6s to avoid jitter/lag.
        if now - DemoWorld.MoveToIssuedAt >= 0.6 then
            DemoWorld.MoveToIssuedAt = now
            local humanoid = getHumanoid()
            local direction = Vector3.new(targetPosition.X - root.Position.X, 0, targetPosition.Z - root.Position.Z)
            local stopPosition = targetPosition
            if direction.Magnitude > 7 then
                stopPosition = targetPosition - direction.Unit * 5
            end

            if humanoid then
                humanoid:MoveTo(stopPosition)
            else
                local step = math.min(flatDistance, 18 * math.max(deltaTime, 1 / 60))
                local nextPosition = root.Position + direction.Unit * step
                root.CFrame = CFrame.new(nextPosition, Vector3.new(targetPosition.X, nextPosition.Y, targetPosition.Z))
            end
        end
    end)
end

function DemoWorld.SetOverlayDemo(rootGui, enabled)
    for _, item in ipairs(DemoWorld.OverlayItems) do
        if item then
            item:Destroy()
        end
    end
    table.clear(DemoWorld.OverlayItems)

    if not enabled then
        return
    end

    for _, part in ipairs(DemoWorld.GetCollectibles()) do
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "IceylandsDemoMarker"
        billboard.Adornee = part
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.fromOffset(140, 36)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.Parent = rootGui

        local label = Instance.new("TextLabel")
        label.BackgroundColor3 = Color3.fromRGB(20, 38, 60)
        label.BackgroundTransparency = 0.18
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextColor3 = Color3.fromRGB(242, 248, 255)
        local hits = part:GetAttribute("HitsRemaining")
        label.Text = hits and (part.Name .. " | " .. hits .. " hits") or part.Name
        label.Parent = billboard
        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)

        table.insert(DemoWorld.OverlayItems, billboard)
    end
end

function DemoWorld.SetAutoCollectDemo(enabled, onCollect)
    DemoWorld.AutoCollectRunning = enabled
    if not enabled then
        return
    end

    removeDemoAxe()
    DemoWorld.SpawnObjectsAtTreePositions(10)
    DemoWorld.EquipBestAxe()

    task.spawn(function()
        while DemoWorld.AutoCollectRunning do
            removeDemoAxe()
            DemoWorld.EquipBestAxe()

            local root = getRoot()
            local target = DemoWorld.GetNearestCollectible()
            local targetPosition = getTreePosition(target)

            if not root or not target or not targetPosition then
                task.wait(0.25)
                continue
            end

            -- TP mode: stand beside the nearest live tree, face it, and keep swinging.
            -- It stays enabled; once the source tree disappears, GetCollectibles removes
            -- this marker and the loop automatically picks the next nearest tree.
            local away = Vector3.new(root.Position.X - targetPosition.X, 0, root.Position.Z - targetPosition.Z)
            if away.Magnitude < 0.1 then
                away = Vector3.new(1, 0, 0)
            end

            local standPosition = targetPosition + away.Unit * 5 + Vector3.new(0, 2, 0)
            root.CFrame = CFrame.new(standPosition, Vector3.new(targetPosition.X, standPosition.Y, targetPosition.Z))
            if Workspace.CurrentCamera then
                Workspace.CurrentCamera.CFrame = CFrame.new(Workspace.CurrentCamera.CFrame.Position, targetPosition)
            end

            damageDemoTree(target, onCollect)
            task.wait(DemoWorld.ClickInterval)
        end
    end)
end

-- Compatibility aliases for older Foraging tab names.
DemoWorld.SetTreeMovementDemo = DemoWorld.SetMovementDemo
DemoWorld.SetMovement = DemoWorld.SetMovementDemo
DemoWorld.SetTeleportDemo = DemoWorld.SetAutoCollectDemo
DemoWorld.SetTreeTeleportDemo = DemoWorld.SetAutoCollectDemo
DemoWorld.SetAutoCollect = DemoWorld.SetAutoCollectDemo

function DemoWorld.Restore()
    DemoWorld.SetMovementDemo(false)
    DemoWorld.SetOverlayDemo(nil, false)
    DemoWorld.SetAutoCollectDemo(false)
end

return DemoWorld

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Performance = {
    RenderingDisabled = false,
    FpsBoostEnabled = false,
    WhiteOverlay = nil,
    LightingState = nil,
    TerrainState = nil,
    EffectStates = nil,
}

local function captureLighting()
    if Performance.LightingState then
        return
    end

    Performance.LightingState = {
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        Brightness = Lighting.Brightness,
    }

    pcall(function()
        Performance.LightingState.EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale
        Performance.LightingState.EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
    end)

    Performance.EffectStates = {}
    for _, item in ipairs(Lighting:GetChildren()) do
        if item:IsA("PostEffect") then
            Performance.EffectStates[item] = item.Enabled
        end
    end

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        Performance.TerrainState = {
            Terrain = terrain,
            Decoration = terrain.Decoration,
        }

        pcall(function()
            Performance.TerrainState.WaterWaveSize = terrain.WaterWaveSize
            Performance.TerrainState.WaterWaveSpeed = terrain.WaterWaveSpeed
            Performance.TerrainState.WaterReflectance = terrain.WaterReflectance
            Performance.TerrainState.WaterTransparency = terrain.WaterTransparency
        end)
    end
end

local function setEffectsEnabled(enabled)
    for _, item in ipairs(Lighting:GetChildren()) do
        if item:IsA("PostEffect") then
            item.Enabled = enabled
        end
    end
end

local function restoreEffects()
    if not Performance.EffectStates then
        return
    end

    for item, enabled in pairs(Performance.EffectStates) do
        if item.Parent then
            item.Enabled = enabled
        end
    end
end

function Performance.SetRenderingDisabled(root, enabled)
    Performance.RenderingDisabled = enabled

    if enabled then
        if not Performance.WhiteOverlay then
            local overlay = Instance.new("Frame")
            overlay.Name = "RenderingDisabledBackdrop"
            overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            overlay.BorderSizePixel = 0
            overlay.Size = UDim2.fromScale(1, 1)
            overlay.ZIndex = 0
            overlay.Parent = root
            Performance.WhiteOverlay = overlay
        end

        Performance.WhiteOverlay.Visible = true
        pcall(function()
            RunService:Set3dRenderingEnabled(false)
        end)
    else
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)

        if Performance.WhiteOverlay then
            Performance.WhiteOverlay.Visible = false
        end
    end
end

function Performance.SetFpsBoost(enabled)
    Performance.FpsBoostEnabled = enabled
    captureLighting()

    if enabled then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.Brightness = 1
        pcall(function()
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
        end)
        setEffectsEnabled(false)

        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.Decoration = false
            pcall(function()
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 1
            end)
        end
    elseif Performance.LightingState then
        Lighting.GlobalShadows = Performance.LightingState.GlobalShadows
        Lighting.FogEnd = Performance.LightingState.FogEnd
        Lighting.Brightness = Performance.LightingState.Brightness
        pcall(function()
            if Performance.LightingState.EnvironmentDiffuseScale then
                Lighting.EnvironmentDiffuseScale = Performance.LightingState.EnvironmentDiffuseScale
            end

            if Performance.LightingState.EnvironmentSpecularScale then
                Lighting.EnvironmentSpecularScale = Performance.LightingState.EnvironmentSpecularScale
            end
        end)
        restoreEffects()

        local state = Performance.TerrainState
        if state and state.Terrain and state.Terrain.Parent then
            state.Terrain.Decoration = state.Decoration
            pcall(function()
                if state.WaterWaveSize then
                    state.Terrain.WaterWaveSize = state.WaterWaveSize
                end

                if state.WaterWaveSpeed then
                    state.Terrain.WaterWaveSpeed = state.WaterWaveSpeed
                end

                if state.WaterReflectance then
                    state.Terrain.WaterReflectance = state.WaterReflectance
                end

                if state.WaterTransparency then
                    state.Terrain.WaterTransparency = state.WaterTransparency
                end
            end)
        end
    end
end

function Performance.Restore()
    Performance.SetRenderingDisabled(nil, false)
    Performance.SetFpsBoost(false)
end

return Performance

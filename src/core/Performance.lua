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
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    }

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
            WaterWaveSize = terrain.WaterWaveSize,
            WaterWaveSpeed = terrain.WaterWaveSpeed,
            WaterReflectance = terrain.WaterReflectance,
            WaterTransparency = terrain.WaterTransparency,
        }
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
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        setEffectsEnabled(false)

        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.Decoration = false
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
        end
    elseif Performance.LightingState then
        Lighting.GlobalShadows = Performance.LightingState.GlobalShadows
        Lighting.FogEnd = Performance.LightingState.FogEnd
        Lighting.Brightness = Performance.LightingState.Brightness
        Lighting.EnvironmentDiffuseScale = Performance.LightingState.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = Performance.LightingState.EnvironmentSpecularScale
        restoreEffects()

        local state = Performance.TerrainState
        if state and state.Terrain and state.Terrain.Parent then
            state.Terrain.Decoration = state.Decoration
            state.Terrain.WaterWaveSize = state.WaterWaveSize
            state.Terrain.WaterWaveSpeed = state.WaterWaveSpeed
            state.Terrain.WaterReflectance = state.WaterReflectance
            state.Terrain.WaterTransparency = state.WaterTransparency
        end
    end
end

function Performance.Restore()
    Performance.SetRenderingDisabled(nil, false)
    Performance.SetFpsBoost(false)
end

return Performance

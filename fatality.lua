local Fatality = loadstring(game:HttpGet("https://raw.githubusercontent.com/4lpaca-pin/Fatality/refs/heads/main/src/source.luau"))()
local Notification = Fatality:CreateNotifier()

Fatality:Loader({
    Name = "FATALITY",
    Duration = 4,
    Scale = 3
})

Notification:Notify({
    Title = "FATALITY",
    Content = "Hello, " .. game.Players.LocalPlayer.Name .. " Welcome back!",
    Icon = "clipboard"
})

local Window = Fatality.new({
    Name = "FATALITY",
    Expire = "1488 days",
    Keybind = "Delete"
})

local RageTab = Window:AddMenu({
    Name = "RAGE",
    Icon = "target"
})

local VisualTab = Window:AddMenu({
    Name = "VISUAL",
    Icon = "eye"
})

local Misc = Window:AddMenu({
    Name = "MISC",
    Icon = "settings"
})

local LuaTab = Window:AddMenu({
    Name = "LUA",
    Icon = "code"
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local aimlockEnabled = false
local activationKey = Enum.KeyCode.Z
local currentTarget = nil
local locked = false
local highlight = nil

local predictionEnabled = false
local predictionStrength = 0.2
local highlightEnabled = true
local highlightColor = Color3.fromRGB(255, 255, 255)
local aimPriority = "Crosshair"

local aimTeamCheck = false
local aimDownedCheck = false

local connections = {}

local function findTarget()
    local camera = Workspace.CurrentCamera or workspace.CurrentCamera
    if not camera then return nil end
    
    local viewport = camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    
    local localPlayer = Players.LocalPlayer
    local myChar = localPlayer and localPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    local closest = nil
    local bestValue = math.huge
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character and p.Character:FindFirstChild("Head") then
            if aimTeamCheck and p.Team == localPlayer.Team then continue end
            
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then continue end
            
            if aimDownedCheck then
                if humanoid:GetState() == Enum.HumanoidStateType.Dead or humanoid:GetState() == Enum.HumanoidStateType.Physics then
                    continue
                end
            end
            
            local head = p.Character.Head
            local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
            
            if onScreen then
                local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
                local currentValue = math.huge
                
                if aimPriority == "Crosshair" then
                    currentValue = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                elseif aimPriority == "Distance" then
                    if myRoot and targetRoot then
                        currentValue = (myRoot.Position - targetRoot.Position).Magnitude
                    end
                end

                if currentValue < bestValue then
                    bestValue = currentValue
                    closest = p.Character
                end
            end
        end
    end
    return closest
end

local function updateHighlight(targetChar)
    if highlight then
        pcall(function() highlight:Destroy() end)
        highlight = nil
    end
    if targetChar and highlightEnabled then
        highlight = Instance.new("Highlight")
        highlight.Parent = targetChar
        highlight.FillColor = highlightColor
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    end
end

local inputBegan = nil
local function setupInput()
    if inputBegan then 
        pcall(function() inputBegan:Disconnect() end) 
        local idx = table.find(connections, inputBegan)
        if idx then table.remove(connections, idx) end
    end
    inputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not aimlockEnabled then return end
        if input.KeyCode == activationKey or input.UserInputType == activationKey then
            locked = not locked
            if locked then
                local targChar = findTarget()
                if targChar then
                    currentTarget = targChar:FindFirstChild("Head")
                    updateHighlight(targChar)
                else
                    locked = false
                end
            else
                currentTarget = nil
                updateHighlight(nil)
            end
        end
    end)
    table.insert(connections, inputBegan)
end
setupInput()

local renderStepped = RunService.RenderStepped:Connect(function()
    if aimlockEnabled and locked then
        local targetValid = false
        if currentTarget and currentTarget.Parent then
            local humanoid = currentTarget.Parent:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                if aimDownedCheck and (humanoid:GetState() == Enum.HumanoidStateType.Dead or humanoid:GetState() == Enum.HumanoidStateType.Physics) then
                    targetValid = false
                else
                    targetValid = true
                end
            end
        end

        if not targetValid then
            local newChar = findTarget()
            if newChar then
                currentTarget = newChar:FindFirstChild("Head")
                updateHighlight(newChar)
            else
                locked = false
                currentTarget = nil
                updateHighlight(nil)
                return
            end
        end

        if currentTarget and currentTarget.Parent then
            local camera = Workspace.CurrentCamera or workspace.CurrentCamera
            if camera then
                local targetPos = currentTarget.Position
                if predictionEnabled then
                    local root = currentTarget.Parent:FindFirstChild("HumanoidRootPart")
                    local velocity = root and root.Velocity or Vector3.new()
                    targetPos = targetPos + velocity * predictionStrength + Vector3.new(0, 0.1, 0)
                end
                camera.CFrame = CFrame.new(camera.CFrame.Position, targetPos)
            end
        end
    end
end)
table.insert(connections, renderStepped)

local function unloadAIM()
    for _, conn in pairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    if highlight then
        pcall(function() highlight:Destroy() end)
        highlight = nil
    end
    aimlockEnabled = false
    locked = false
    currentTarget = nil
end

local aimSection = RageTab:AddSection({
    Name = "AIM",
    Position = 'left'
})

local aimToggle = aimSection:AddToggle({
    Name = "Aimlock",
    Default = false,
    Option = true,
    Callback = function(val)
        aimlockEnabled = val
        if not val then
            locked = false
            currentTarget = nil
            updateHighlight(nil)
        end
    end
})

aimToggle.Option:AddKeybind({
    Name = "Aimlock Key",
    Default = "Z",
    Callback = function(key)
        activationKey = Enum.KeyCode[key] or Enum.UserInputType[key] or Enum.KeyCode.Z
        setupInput()
    end
})

aimToggle.Option:AddToggle({
    Name = "Team Check",
    Default = false,
    Callback = function(val) aimTeamCheck = val end
})

aimToggle.Option:AddToggle({
    Name = "Downed Check",
    Default = false,
    Callback = function(val) aimDownedCheck = val end
})

aimToggle.Option:AddDropdown({
    Name = "Target Priority",
    Values = {"Crosshair", "Distance"},
    Default = "Crosshair",
    Callback = function(val)
        aimPriority = val
    end
})

local predToggle = aimSection:AddToggle({
    Name = "Prediction",
    Default = false,
    Option = true,
    Callback = function(val) predictionEnabled = val end
})

predToggle.Option:AddSlider({
    Name = "Prediction Strength",
    Min = 0,
    Max = 100,
    Default = 100,
    Round = 0,
    Callback = function(val) predictionStrength = val / 500 end
})

local highlightToggle = aimSection:AddToggle({
    Name = "Highlight",
    Default = true,
    Option = true,
    Callback = function(val)
        highlightEnabled = val
        if currentTarget then updateHighlight(currentTarget.Parent) else updateHighlight(nil) end
    end
})

highlightToggle.Option:AddColorPicker({
    Name = "Highlight Color",
    Default = highlightColor,
    Callback = function(color)
        highlightColor = color
        if highlight then highlight.FillColor = color end
    end
})

_G.unloadAIM = unloadAIM

local antiAimEnabled = false
local currentMode = "static"
local spinSpeed = 360
local yawEnabled = false
local yawAngle = 0
local atTargetFallbackAngle = 0

local antiAimRenderConn = nil

local yawJitterEnabled = false
local yawJitterMode = "Center"
local yawJitterRange = 30
local yawJitterInterval = 0
local yawJitterAccum = 0
local yawJitterOffset = 0
local way3IndexYaw = 0
local way5IndexYaw = 0

local function getClosestPlayer(maxDist)
    local LocalPlayer = Players.LocalPlayer
    local character = LocalPlayer.Character
    if not character then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local closestDist = maxDist or math.huge
    local closestPlayer = nil
    local myPos = root.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local targetChar = player.Character
            if targetChar then
                local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
                if not humanoid or humanoid.Health <= 0 then continue end
                
                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    local dist = (myPos - targetRoot.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPlayer
end

local function updateAntiAimMode(newMode)
    currentMode = newMode
end

local function antiAimMain(dt)
    if not antiAimEnabled then return end

    local LocalPlayer = Players.LocalPlayer
    local character = LocalPlayer.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local pos = root.Position
    local currentCF = root.CFrame
    local targetLookCF

    if currentMode == "attarget" then
        local targetPlayer = getClosestPlayer(500) 
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = targetPlayer.Character.HumanoidRootPart
            local targetPosFlat = Vector3.new(targetRoot.Position.X, pos.Y, targetRoot.Position.Z)
            targetLookCF = CFrame.lookAt(pos, targetPosFlat)
        else
            atTargetFallbackAngle = (atTargetFallbackAngle + math.rad(45 * dt)) % (math.pi * 2)
            local camera = Workspace.CurrentCamera
            if camera then
                local camLook = camera.CFrame.LookVector
                local dir = Vector3.new(camLook.X, 0, camLook.Z).Unit
                targetLookCF = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, atTargetFallbackAngle, 0)
            else
                targetLookCF = currentCF * CFrame.Angles(0, math.rad(45 * dt), 0)
            end
        end
    elseif currentMode == "spin" then
        local rotStep = math.rad(spinSpeed * dt)
        targetLookCF = currentCF * CFrame.Angles(0, rotStep, 0)
    else 
        local camera = Workspace.CurrentCamera
        if camera then
            local camLook = camera.CFrame.LookVector
            local dir = Vector3.new(camLook.X, 0, camLook.Z).Unit
            targetLookCF = CFrame.lookAt(pos, pos + dir)
        else
            targetLookCF = currentCF
        end
    end

    if yawJitterEnabled then
        local applyJitter = false
        if yawJitterInterval > 0 then
            yawJitterAccum = yawJitterAccum + dt
            if yawJitterAccum >= yawJitterInterval then
                yawJitterAccum = 0
                applyJitter = true
            end
        else
            applyJitter = true
        end
        
        if applyJitter then
            if yawJitterMode == "Center" then
                yawJitterOffset = (math.random() * 2 - 1) * math.rad(yawJitterRange)
            elseif yawJitterMode == "Random" then
                yawJitterOffset = math.random() * 2 * math.pi
            elseif yawJitterMode == "3-way" then
                way3IndexYaw = (way3IndexYaw + 1) % 3
                if way3IndexYaw == 0 then yawJitterOffset = -math.rad(yawJitterRange)
                elseif way3IndexYaw == 1 then yawJitterOffset = 0
                else yawJitterOffset = math.rad(yawJitterRange) end
            elseif yawJitterMode == "5-way" then
                way5IndexYaw = (way5IndexYaw + 1) % 5
                if way5IndexYaw == 0 then yawJitterOffset = -math.rad(yawJitterRange)
                elseif way5IndexYaw == 1 then yawJitterOffset = -math.rad(yawJitterRange / 2)
                elseif way5IndexYaw == 2 then yawJitterOffset = 0
                elseif way5IndexYaw == 3 then yawJitterOffset = math.rad(yawJitterRange / 2)
                else yawJitterOffset = math.rad(yawJitterRange) end
            end
        end
    else
        yawJitterOffset = 0
    end

    local _, yAngle, _ = targetLookCF:ToOrientation()
    local finalYaw = yAngle + yawJitterOffset
    if yawEnabled then finalYaw = finalYaw + math.rad(yawAngle) end
    root.CFrame = CFrame.new(pos) * CFrame.Angles(0, finalYaw, 0)
end

local function setAntiAimState(state)
    antiAimEnabled = state
    if state then
        if not antiAimRenderConn then
            antiAimRenderConn = RunService.RenderStepped:Connect(antiAimMain)
        end
    else
        if antiAimRenderConn then 
            antiAimRenderConn:Disconnect()
            antiAimRenderConn = nil 
        end
    end
end

local function unloadAntiAim()
    setAntiAimState(false)
end
_G.unloadAntiAim = unloadAntiAim

local antiAimSection = RageTab:AddSection({
    Name = "ANTI-AIM",
    Position = 'right'
})

local antiAimToggle = antiAimSection:AddToggle({
    Name = "Enable",
    Default = false,
    Option = true,
    Callback = function(val) setAntiAimState(val) end
})

antiAimToggle.Option:AddSlider({
    Name = "Spin Speed",
    Default = 360,
    Min = 10,
    Max = 2000,
    Type = "°",
    Callback = function(val) spinSpeed = val end
})

antiAimToggle.Option:AddSlider({
    Name = "Yaw Angle",
    Default = 0,
    Min = -180,
    Max = 180,
    Rounding = 0,
    Type = "°",
    Callback = function(val) 
        yawAngle = val
        yawEnabled = val ~= 0
    end
})

antiAimToggle.Option:AddDropdown({
    Name = "Yaw base",
    Values = {"Static", "At Target", "Spin"},
    Default = "Static",
    Callback = function(value)
        local modeMap = { Static = "static", ["At Target"] = "attarget", Spin = "spin" }
        updateAntiAimMode(modeMap[value] or "static")
    end
})

local yawJitterToggle = antiAimSection:AddToggle({
    Name = "Yaw jitter",
    Default = false,
    Option = true,
    Callback = function(val) yawJitterEnabled = val end
})
yawJitterToggle.Option:AddSlider({
    Name = "Range",
    Default = 30,
    Min = 1,
    Max = 180,
    Type = "°",
    Callback = function(val) yawJitterRange = val end
})
yawJitterToggle.Option:AddSlider({
    Name = "Delay",
    Default = 0,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Type = "ms",
    Callback = function(val) yawJitterInterval = val / 1000 end
})
yawJitterToggle.Option:AddDropdown({
    Name = "Mode",
    Values = {"Center", "3-way", "5-way", "Random"},
    Default = "Center",
    Callback = function(val) yawJitterMode = val end
})

local Player = game:GetService("Players").LocalPlayer
local fakeLagEnabled = false
local fakeLagLimit = 5
local GhostModel = nil
local tickCounter = 0
local realSmoothCF = nil
local laggedCF = nil
local heartbeatConn = nil
local fakeLagRestoreBound = false

local function DisableFakeLag()
    if not fakeLagEnabled and not fakeLagRestoreBound then return end
    fakeLagEnabled = false
    
    if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn = nil end
    if fakeLagRestoreBound then
        pcall(function() RunService:UnbindFromRenderStep("FakeLagRestore") end)
        fakeLagRestoreBound = false
    end
    
    if GhostModel then pcall(function() GhostModel:Destroy() end); GhostModel = nil end

    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if root and realSmoothCF then
        root.CFrame = realSmoothCF
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new()
            root.AssemblyAngularVelocity = Vector3.new()
        end)
    end
    if hum and hum.Health > 0 then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics) end)
    end
    
    realSmoothCF = nil
    laggedCF = nil
    tickCounter = 0
end

local function CreateGhost(char)
    char.Archivable = true
    local ghost = char:Clone()
    char.Archivable = false
    ghost.Name = "LD_Ghost_Clone"

    for _, v in pairs(ghost:GetDescendants()) do
        if v:IsA("LocalScript") or v:IsA("Script") or v:IsA("Humanoid") or v:IsA("Animator") or v:IsA("AnimationController") then
            pcall(function() v:Destroy() end)
        elseif v:IsA("BasePart") then
            v.Anchored = true
            v.CanCollide = false
            v.Massless = true
            pcall(function() v.CanQuery = false; v.CanTouch = false end)
            if v.Name == "HumanoidRootPart" then
                v.Transparency = 1
            else
                v.Transparency = 0.7
            end
        end
    end

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.7
    hl.OutlineTransparency = 0
    hl.Parent = ghost

    ghost.Parent = workspace
    return ghost
end

local function UpdateGhost(char, targetCF)
    if not GhostModel then return end
    
    pcall(function() GhostModel:PivotTo(targetCF) end)
    
    for _, realDesc in ipairs(char:GetDescendants()) do
        if realDesc:IsA("Motor6D") then
            local ghostDesc = GhostModel:FindFirstChild(realDesc.Name, true)
            if ghostDesc and ghostDesc:IsA("Motor6D") then
                ghostDesc.Transform = realDesc.Transform
            end
        end
    end
end

local function EnableFakeLag()
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    fakeLagEnabled = true
    realSmoothCF = root.CFrame
    laggedCF = root.CFrame
    tickCounter = 0

    GhostModel = CreateGhost(char)

    if fakeLagRestoreBound then
        pcall(function() RunService:UnbindFromRenderStep("FakeLagRestore") end)
        fakeLagRestoreBound = false
    end

    RunService:BindToRenderStep("FakeLagRestore", Enum.RenderPriority.Camera.Value - 1, function()
        if not fakeLagEnabled then return end
        local currentChar = Player.Character
        local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        if currentRoot and realSmoothCF then
            currentRoot.CFrame = realSmoothCF
        end
    end)
    fakeLagRestoreBound = true

    heartbeatConn = RunService.Heartbeat:Connect(function()
        if not fakeLagEnabled then return end
        local currentChar = Player.Character
        local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        local hum = currentChar and currentChar:FindFirstChild("Humanoid")
        
        if not currentRoot or not hum or hum.Health <= 0 then
            DisableFakeLag()
            return
        end

        realSmoothCF = currentRoot.CFrame

        tickCounter = tickCounter + 1
        if tickCounter >= fakeLagLimit then
            tickCounter = 0
            laggedCF = realSmoothCF
            UpdateGhost(currentChar, laggedCF)
        end

        local state = hum:GetState()
        local onGround = hum.FloorMaterial ~= Enum.Material.Air
        local canLag = laggedCF and onGround and state ~= Enum.HumanoidStateType.PlatformStanding
            and state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall
        if canLag then
            local oldVel = currentRoot.AssemblyLinearVelocity
            local oldAngVel = currentRoot.AssemblyAngularVelocity
            currentRoot.CFrame = laggedCF
            currentRoot.AssemblyLinearVelocity = oldVel
            currentRoot.AssemblyAngularVelocity = oldAngVel
        end
    end)
end

local fakeLagSection = RageTab:AddSection({
    Name = "FAKE LAG",
    Position = 'right'
})

local fakeLagToggle = fakeLagSection:AddToggle({
    Name = "Enable",
    Default = false,
    Option = true,
    Callback = function(val)
        if val then EnableFakeLag() else DisableFakeLag() end
    end
})

fakeLagToggle.Option:AddSlider({
    Name = "Fakelag limit",
    Default = 5,
    Min = 1,
    Max = 14,
    Rounding = 0,
    Type = "ticks",
    Callback = function(val) fakeLagLimit = val end
})

local ESP = {
    Enabled = false,
    TeamCheck = false,
    ShowTeam = false,
    BoxESP = false,
    BoxStyle = "Corner",
    BoxColor = Color3.fromRGB(255, 255, 255),
    BoxThickness = 1,
    BoxFillTransparency = 0.5,
    TracerESP = false,
    TracerOrigin = "Bottom",
    TracerThickness = 1,
    HealthESP = false,
    HealthStyle = "Bar",
    NameESP = false,
    NameMode = "DisplayName",
    WeaponESP = false,
    ShowDistance = false,
    DistanceUnit = "studs",
    TextSize = 14,
    MaxDistance = 1000,
    ChamsEnabled = false,
    ChamsVisibleColor = Color3.fromRGB(255, 0, 0),
    ChamsInvisibleColor = Color3.fromRGB(255, 255, 255),
    ChamsTransparency = 0.5,
    EnemyColor = Color3.fromRGB(255, 255, 255),
    AllyColor = Color3.fromRGB(255, 255, 255),
    HealthColor = Color3.fromRGB(0, 255, 0),
}

local Drawings = { ESP = {} }
local Highlights = {}

local function isVisible(character)
    local targetPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    if not targetPart then return false end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).unit * (targetPart.Position - origin).magnitude
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(origin, direction, params)
    return not result or result.Instance == nil
end

local function createESP(player)
    if player == LocalPlayer then return end
    local box = {
        TopLeft = Drawing.new("Line"),
        TopRight = Drawing.new("Line"),
        BottomLeft = Drawing.new("Line"),
        BottomRight = Drawing.new("Line"),
        Left = Drawing.new("Line"),
        Right = Drawing.new("Line"),
        Top = Drawing.new("Line"),
        Bottom = Drawing.new("Line")
    }
    for _, line in pairs(box) do
        line.Visible = false
        line.Color = ESP.EnemyColor
        line.Thickness = ESP.BoxThickness
    end
    local fillSquare = Drawing.new("Square")
    fillSquare.Visible = false
    fillSquare.Filled = true
    fillSquare.Color = ESP.EnemyColor
    fillSquare.Transparency = ESP.BoxFillTransparency
    box.Fill = fillSquare

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = ESP.EnemyColor
    tracer.Thickness = ESP.TracerThickness

    local healthBar = {
        Outline = Drawing.new("Square"),
        Fill = Drawing.new("Square"),
        Text = Drawing.new("Text")
    }
    healthBar.Outline.Visible = false
    healthBar.Outline.Color = Color3.new(1,1,1)
    healthBar.Outline.Filled = false
    healthBar.Outline.Thickness = 1
    healthBar.Fill.Visible = false
    healthBar.Fill.Filled = true
    healthBar.Text.Visible = false
    healthBar.Text.Center = true
    healthBar.Text.Size = ESP.TextSize
    healthBar.Text.Color = ESP.HealthColor
    healthBar.Text.Font = 2

    local info = {
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Weapon = Drawing.new("Text")
    }
    for _, text in pairs(info) do
        text.Visible = false
        text.Center = true
        text.Size = ESP.TextSize
        text.Color = ESP.EnemyColor
        text.Font = 2
        text.Outline = true
    end

    local snapline = Drawing.new("Line")
    snapline.Visible = false
    snapline.Color = ESP.EnemyColor
    snapline.Thickness = 1

    local highlight = Instance.new("Highlight")
    highlight.FillColor = ESP.ChamsVisibleColor
    highlight.FillTransparency = ESP.ChamsTransparency
    highlight.OutlineTransparency = 1
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false
    Highlights[player] = highlight

    Drawings.ESP[player] = {
        Box = box,
        Tracer = tracer,
        HealthBar = healthBar,
        Info = info,
        Snapline = snapline,
    }
end

local function removeESP(player)
    local esp = Drawings.ESP[player]
    if esp then
        for _, obj in pairs(esp.Box) do obj:Remove() end
        esp.Tracer:Remove()
        for _, obj in pairs(esp.HealthBar) do obj:Remove() end
        for _, obj in pairs(esp.Info) do obj:Remove() end
        if esp.Box.Fill then esp.Box.Fill:Remove() end
        esp.Snapline:Remove()
        Drawings.ESP[player] = nil
    end
    local highlight = Highlights[player]
    if highlight then
        highlight:Destroy()
        Highlights[player] = nil
    end
end

local function getPlayerColor(player)
    if player.Team and player.Team == LocalPlayer.Team then
        return ESP.AllyColor
    else
        return ESP.EnemyColor
    end
end

local function getTracerOrigin()
    local o = ESP.TracerOrigin
    local vp = Camera.ViewportSize
    if o == "Bottom" then return Vector2.new(vp.X/2, vp.Y)
    elseif o == "Top" then return Vector2.new(vp.X/2, 0)
    elseif o == "Mouse" then return UserInputService:GetMouseLocation()
    else return Vector2.new(vp.X/2, vp.Y/2) end
end

local function updateESP(player)
    if not ESP.Enabled then return end
    local esp = Drawings.ESP[player]
    if not esp then return end
    local character = player.Character
    if not character then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        local highlight = Highlights[player]
        if highlight then highlight.Enabled = false end
        return
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        local highlight = Highlights[player]
        if highlight then highlight.Enabled = false end
        return
    end
    local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude

    local shouldHide = not onScreen or distance > ESP.MaxDistance
    if shouldHide then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        local highlight = Highlights[player]
        if highlight then highlight.Enabled = false end
        return
    end

    if ESP.TeamCheck and player.Team == LocalPlayer.Team and not ESP.ShowTeam then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        local highlight = Highlights[player]
        if highlight then highlight.Enabled = false end
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        local highlight = Highlights[player]
        if highlight then highlight.Enabled = false end
        return
    end

    local color = getPlayerColor(player)
    local size = character:GetExtentsSize()
    local cf = rootPart.CFrame
    local top, topOn = Camera:WorldToViewportPoint(cf * CFrame.new(0, size.Y/2, 0).Position)
    local bottom, bottomOn = Camera:WorldToViewportPoint(cf * CFrame.new(0, -size.Y/2, 0).Position)
    if not topOn or not bottomOn then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        return
    end
    local screenSize = bottom.Y - top.Y
    local boxWidth = screenSize * 0.65
    local boxPos = Vector2.new(top.X - boxWidth/2, top.Y)
    local boxSize = Vector2.new(boxWidth, screenSize)
    for _, obj in pairs(esp.Box) do obj.Visible = false end

    if ESP.BoxESP then
        if ESP.BoxStyle == "Filled" then
            for _, obj in pairs(esp.Box) do if obj ~= esp.Box.Fill then obj.Visible = false end end
            local fill = esp.Box.Fill
            fill.Position = boxPos
            fill.Size = boxSize
            fill.Color = ESP.BoxColor
            fill.Transparency = ESP.BoxFillTransparency
            fill.Visible = true
        else
            if esp.Box.Fill then esp.Box.Fill.Visible = false end
            if ESP.BoxStyle == "Corner" then
                local corner = boxWidth * 0.2
                esp.Box.TopLeft.From = boxPos; esp.Box.TopLeft.To = boxPos + Vector2.new(corner, 0); esp.Box.TopLeft.Visible = true
                esp.Box.TopRight.From = boxPos + Vector2.new(boxSize.X, 0); esp.Box.TopRight.To = boxPos + Vector2.new(boxSize.X - corner, 0); esp.Box.TopRight.Visible = true
                esp.Box.BottomLeft.From = boxPos + Vector2.new(0, boxSize.Y); esp.Box.BottomLeft.To = boxPos + Vector2.new(corner, boxSize.Y); esp.Box.BottomLeft.Visible = true
                esp.Box.BottomRight.From = boxPos + Vector2.new(boxSize.X, boxSize.Y); esp.Box.BottomRight.To = boxPos + Vector2.new(boxSize.X - corner, boxSize.Y); esp.Box.BottomRight.Visible = true
                esp.Box.Left.From = boxPos; esp.Box.Left.To = boxPos + Vector2.new(0, corner); esp.Box.Left.Visible = true
                esp.Box.Right.From = boxPos + Vector2.new(boxSize.X, 0); esp.Box.Right.To = boxPos + Vector2.new(boxSize.X, corner); esp.Box.Right.Visible = true
                esp.Box.Top.From = boxPos + Vector2.new(0, boxSize.Y); esp.Box.Top.To = boxPos + Vector2.new(0, boxSize.Y - corner); esp.Box.Top.Visible = true
                esp.Box.Bottom.From = boxPos + Vector2.new(boxSize.X, boxSize.Y); esp.Box.Bottom.To = boxPos + Vector2.new(boxSize.X, boxSize.Y - corner); esp.Box.Bottom.Visible = true
            elseif ESP.BoxStyle == "Full" then
                esp.Box.Left.From = boxPos; esp.Box.Left.To = boxPos + Vector2.new(0, boxSize.Y); esp.Box.Left.Visible = true
                esp.Box.Right.From = boxPos + Vector2.new(boxSize.X, 0); esp.Box.Right.To = boxPos + Vector2.new(boxSize.X, boxSize.Y); esp.Box.Right.Visible = true
                esp.Box.Top.From = boxPos; esp.Box.Top.To = boxPos + Vector2.new(boxSize.X, 0); esp.Box.Top.Visible = true
                esp.Box.Bottom.From = boxPos + Vector2.new(0, boxSize.Y); esp.Box.Bottom.To = boxPos + Vector2.new(boxSize.X, boxSize.Y); esp.Box.Bottom.Visible = true
            end
            for _, obj in pairs(esp.Box) do
                if obj.Visible then obj.Color = ESP.BoxColor; obj.Thickness = ESP.BoxThickness end
            end
        end
    end

    if ESP.TracerESP then
        esp.Tracer.From = getTracerOrigin()
        esp.Tracer.To = Vector2.new(pos.X, pos.Y)
        esp.Tracer.Color = color
        esp.Tracer.Visible = true
    else
        esp.Tracer.Visible = false
    end

    if ESP.HealthESP then
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        local healthPercent = health / maxHealth
        local barHeight = screenSize * 0.8
        local barWidth = 4
        local barPos = Vector2.new(boxPos.X - barWidth - 2, boxPos.Y + (screenSize - barHeight)/2)
        if ESP.HealthStyle == "Bar" then
            esp.HealthBar.Outline.Size = Vector2.new(barWidth, barHeight)
            esp.HealthBar.Outline.Position = barPos
            esp.HealthBar.Outline.Visible = true
            esp.HealthBar.Fill.Size = Vector2.new(barWidth - 2, barHeight * healthPercent)
            esp.HealthBar.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + barHeight * (1-healthPercent))
            esp.HealthBar.Fill.Color = Color3.fromRGB(255 - 255*healthPercent, 255*healthPercent, 0)
            esp.HealthBar.Fill.Visible = true
            esp.HealthBar.Text.Visible = false
        elseif ESP.HealthStyle == "Text" then
            esp.HealthBar.Text.Text = math.floor(health) .. "HP"
            esp.HealthBar.Text.Position = Vector2.new(boxPos.X + boxWidth/2, boxPos.Y - 5)
            esp.HealthBar.Text.Color = color
            esp.HealthBar.Text.Visible = true
            esp.HealthBar.Outline.Visible = false
            esp.HealthBar.Fill.Visible = false
        end
    else
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
    end

    if ESP.NameESP then
        esp.Info.Name.Text = player.DisplayName
        esp.Info.Name.Position = Vector2.new(boxPos.X + boxWidth/2, boxPos.Y - 20)
        esp.Info.Name.Color = color
        esp.Info.Name.Visible = true
        if ESP.ShowDistance then
            esp.Info.Distance.Text = tostring(math.floor(distance)) .. " " .. ESP.DistanceUnit
            esp.Info.Distance.Position = Vector2.new(boxPos.X + boxWidth/2, boxPos.Y + screenSize + 5)
            esp.Info.Distance.Color = color
            esp.Info.Distance.Visible = true
        else
            esp.Info.Distance.Visible = false
        end
        if ESP.WeaponESP then
            local tool = character:FindFirstChildOfClass("Tool")
            local weaponName = tool and tool.Name or "None"
            esp.Info.Weapon.Text = weaponName
            esp.Info.Weapon.Position = Vector2.new(boxPos.X + boxWidth/2, boxPos.Y + screenSize + 25)
            esp.Info.Weapon.Color = color
            esp.Info.Weapon.Visible = true
        else
            esp.Info.Weapon.Visible = false
        end
    else
        esp.Info.Name.Visible = false
        esp.Info.Distance.Visible = false
        esp.Info.Weapon.Visible = false
    end

    local highlight = Highlights[player]
    if highlight then
        if ESP.ChamsEnabled and character and humanoid and humanoid.Health > 0 then
            if highlight.Parent ~= character then
                highlight.Parent = character
            end
            local visible = isVisible(character)
            highlight.FillColor = visible and ESP.ChamsVisibleColor or ESP.ChamsInvisibleColor
            highlight.FillTransparency = ESP.ChamsTransparency
            highlight.Enabled = true
        else
            if highlight.Parent then
                highlight.Parent = nil
            end
            highlight.Enabled = false
        end
    end
end

local worldSection = VisualTab:AddSection({
    Name = "WORLD",
    Position = 'right'
})

local motionBlurEnabled = false
local blurAmount = 15
local blurAmplifier = 5
local motionBlur = nil
local lastVector = Camera.CFrame.LookVector
local motionBlurConnection = nil

local function updateMotionBlur()
    if motionBlurEnabled then
        if not motionBlur or motionBlur.Parent == nil then
            motionBlur = Instance.new("BlurEffect")
            motionBlur.Parent = Camera
        end
        if not motionBlurConnection then
            motionBlurConnection = RunService.Heartbeat:Connect(function()
                if not motionBlurEnabled or not motionBlur or motionBlur.Parent == nil then return end
                local magnitude = (Camera.CFrame.LookVector - lastVector).Magnitude
                motionBlur.Size = math.abs(magnitude) * blurAmount * blurAmplifier / 2
                lastVector = Camera.CFrame.LookVector
            end)
        end
    else
        if motionBlurConnection then motionBlurConnection:Disconnect(); motionBlurConnection = nil end
        if motionBlur then motionBlur:Destroy(); motionBlur = nil end
    end
end

workspace.Changed:Connect(function(property)
    if property == "CurrentCamera" then
        local newCamera = workspace.CurrentCamera
        if newCamera then
            if motionBlurEnabled then
                if motionBlur then motionBlur.Parent = newCamera else motionBlur = Instance.new("BlurEffect", newCamera) end
            end
            lastVector = newCamera.CFrame.LookVector
        end
    end
end)

local motionBlurToggle = worldSection:AddToggle({
    Name = "Motion Blur",
    Default = false,
    Option = true,
    Callback = function(val) motionBlurEnabled = val; updateMotionBlur() end
})
motionBlurToggle.Option:AddSlider({ Name = "Blur Amount", Default = 15, Min = 0, Max = 50, Rounding = 0, Callback = function(val) blurAmount = val end })
motionBlurToggle.Option:AddSlider({ Name = "Blur Amplifier", Default = 5, Min = 1, Max = 20, Rounding = 0, Callback = function(val) blurAmplifier = val end })

local originalFog = { Color = Lighting.FogColor, Start = Lighting.FogStart, End = Lighting.FogEnd }
local fogEnabled = false
local fogStart = 0
local fogEnd = 100
local fogColor = Color3.fromRGB(255,255,255)

local function applyFog()
    if fogEnabled then
        Lighting.FogColor = fogColor
        Lighting.FogStart = fogStart
        Lighting.FogEnd = fogEnd
    else
        Lighting.FogColor = originalFog.Color
        Lighting.FogStart = originalFog.Start
        Lighting.FogEnd = originalFog.End
    end
end

local fogToggle = worldSection:AddToggle({
    Name = "Custom Fog",
    Default = false,
    Option = true,
    Callback = function(val) fogEnabled = val; applyFog() end
})
fogToggle.Option:AddSlider({ Name = "Start Distance", Default = 0, Min = 0, Max = 1000, Rounding = 0, Type = "studs", Callback = function(val) fogStart = val; if fogEnabled then applyFog() end end })
fogToggle.Option:AddSlider({ Name = "End Distance", Default = 100, Min = 1, Max = 1000, Rounding = 0, Type = "studs", Callback = function(val) fogEnd = val; if fogEnabled then applyFog() end end })
fogToggle.Option:AddColorPicker({ Name = "Fog Color", Default = fogColor, Callback = function(val) fogColor = val; if fogEnabled then applyFog() end end })

local worldColorsEnabled = false
local originalAmbient = Lighting.Ambient
local worldAmbient = Color3.fromRGB(255, 255, 255)

local function applyWorldColors()
    if worldColorsEnabled then
        Lighting.Ambient = worldAmbient
    else
        Lighting.Ambient = originalAmbient
    end
end

local worldColorsToggle = worldSection:AddToggle({
    Name = "World Colors",
    Default = false,
    Option = true,
    Callback = function(val)
        worldColorsEnabled = val
        applyWorldColors()
    end
})

worldColorsToggle.Option:AddColorPicker({
    Name = "Ambient Color",
    Default = worldAmbient,
    Callback = function(color)
        worldAmbient = color
        if worldColorsEnabled then Lighting.Ambient = color end
    end
})

local function espLoop()
    if not ESP.Enabled then
        for _, player in ipairs(Players:GetPlayers()) do
            local esp = Drawings.ESP[player]
            if esp then
                for _, obj in pairs(esp.Box) do obj.Visible = false end
                esp.Tracer.Visible = false
                for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
                for _, obj in pairs(esp.Info) do obj.Visible = false end
                esp.Snapline.Visible = false
            end
        end
        for _, highlight in pairs(Highlights) do if highlight then highlight.Enabled = false end end
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not Drawings.ESP[player] then createESP(player) end
            updateESP(player)
        end
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createESP(player)
        player.CharacterAdded:Connect(function(char) createESP(player) end)
        player.CharacterRemoving:Connect(function() removeESP(player) end)
    end
end

local espConnection = RunService.RenderStepped:Connect(espLoop)

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

local watermarkGui = Instance.new("ScreenGui")
watermarkGui.Name = "FatalityWatermark"
watermarkGui.Parent = CoreGui
watermarkGui.Enabled = false
watermarkGui.IgnoreGuiInset = true
watermarkGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
watermarkGui.ResetOnSpawn = false

local dimmer = Instance.new("Frame")
dimmer.Size = UDim2.new(1, 0, 1, 0)
dimmer.BackgroundColor3 = Color3.new(0, 0, 0)
dimmer.BackgroundTransparency = 0.7
dimmer.BorderSizePixel = 0
dimmer.Visible = false
dimmer.Parent = watermarkGui

local centerLineX = Instance.new("Frame")
centerLineX.Size = UDim2.new(0, 1, 1, 0)
centerLineX.Position = UDim2.new(0.5, -0.5, 0, 0)
centerLineX.BackgroundColor3 = Color3.new(1, 1, 1)
centerLineX.BackgroundTransparency = 0.5
centerLineX.BorderSizePixel = 0
centerLineX.Visible = false
centerLineX.Parent = watermarkGui

local centerLineY = Instance.new("Frame")
centerLineY.Size = UDim2.new(1, 0, 0, 1)
centerLineY.Position = UDim2.new(0, 0, 0.5, -0.5)
centerLineY.BackgroundColor3 = Color3.new(1, 1, 1)
centerLineY.BackgroundTransparency = 0.5
centerLineY.BorderSizePixel = 0
centerLineY.Visible = false
centerLineY.Parent = watermarkGui

local watermarkFrame = Instance.new("Frame")
watermarkFrame.Size = UDim2.new(0, 100, 0, 28)
watermarkFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
watermarkFrame.BackgroundTransparency = 0.2
watermarkFrame.BorderSizePixel = 0
watermarkFrame.Active = true
watermarkFrame.Parent = watermarkGui

local corner1 = Instance.new("UICorner")
corner1.CornerRadius = UDim.new(0, 18)
corner1.Parent = watermarkFrame

local watermarkText = Instance.new("TextLabel")
watermarkText.Size = UDim2.new(1, -10, 1, 0)
watermarkText.Position = UDim2.new(0.5, 0, 0.5, 0)
watermarkText.AnchorPoint = Vector2.new(0.5, 0.5)
watermarkText.Font = Enum.Font.SourceSans
watermarkText.TextSize = 14
watermarkText.TextColor3 = Color3.fromRGB(255, 106, 133)
watermarkText.BackgroundTransparency = 1
watermarkText.TextXAlignment = Enum.TextXAlignment.Center
watermarkText.Text = "FATALITY | Ping: 0ms | FPS: 0"
watermarkText.Parent = watermarkFrame

local showPing = true
local showFPS = true
local showWatermark = false
local showTime = true
local showUsername = false
local watermarkHeight = 28
local isDragging = false
local wasDragged = false
local dragThread = nil
local dragStartMouse = Vector2.new(0,0)
local dragStartPos = Vector2.new(0,0)
local currentPosX = 0
local currentPosY = 0
local snapThreshold = 30

local lastText = ""
local lastWidth = 0
local lastHeight = watermarkHeight
local lastTime = os.clock()
local frameCount = 0
local currentFPS = 0
local updateInterval = 0.2
local updateLoopRunning = false
local updateThread = nil

local function clampPosition(posX, posY, width, height)
    local screenSize = Camera.ViewportSize
    return math.clamp(posX, 0, screenSize.X - width), math.clamp(posY, 0, screenSize.Y - height)
end

local function getSnappedX(posX, width)
    local screenSize = Camera.ViewportSize
    local leftThreshold = snapThreshold
    local rightThreshold = screenSize.X - width - snapThreshold
    local centerX = (screenSize.X - width) / 2
    if posX < leftThreshold then return 0, 'left'
    elseif posX > rightThreshold then return screenSize.X - width, 'right'
    elseif math.abs(posX - centerX) < snapThreshold then return centerX, 'center'
    else return posX, 'none' end
end

local function showGrid(show)
    centerLineX.Visible = show
    centerLineY.Visible = show
end

local function stopDrag()
    if not isDragging then return end
    isDragging = false
    dimmer.Visible = false
    showGrid(false)
    local size = watermarkFrame.AbsoluteSize
    local newX, side = getSnappedX(currentPosX, size.X)
    if side ~= 'none' then
        currentPosX = newX
    end
    watermarkFrame.Position = UDim2.new(0, currentPosX, 0, currentPosY)
    if dragThread then task.cancel(dragThread); dragThread = nil end
end

local function startDrag()
    if isDragging then stopDrag() end
    isDragging = true
    wasDragged = true
    dimmer.Visible = true
    showGrid(true)
    local mousePos = UserInputService:GetMouseLocation()
    dragStartMouse = Vector2.new(mousePos.X, mousePos.Y)
    dragStartPos = Vector2.new(currentPosX, currentPosY)
    dragThread = task.spawn(function()
        while isDragging do
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then break end
            local mousePos = UserInputService:GetMouseLocation()
            local deltaX = mousePos.X - dragStartMouse.X
            local deltaY = mousePos.Y - dragStartMouse.Y
            local newX = dragStartPos.X + deltaX
            local newY = dragStartPos.Y + deltaY
            local size = watermarkFrame.AbsoluteSize
            newX, newY = clampPosition(newX, newY, size.X, size.Y)
            local snappedX = getSnappedX(newX, size.X)
            newX = snappedX
            currentPosX, currentPosY = newX, newY
            watermarkFrame.Position = UDim2.new(0, currentPosX, 0, currentPosY)
            task.wait()
        end
        stopDrag()
    end)
end

watermarkFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        startDrag()
    end
end)
UserInputService.WindowFocusReleased:Connect(stopDrag)

local function getTextWidth(text)
    return TextService:GetTextSize(text, watermarkText.TextSize, watermarkText.Font, Vector2.new(1000, 1000)).X
end

local function refreshWatermark()
    if not showWatermark then
        watermarkFrame.Visible = false
        return
    end
    watermarkFrame.Visible = true

    local pingMs = LocalPlayer:GetNetworkPing() * 1000
    local parts = {"FATALITY"}
    if showUsername then table.insert(parts, LocalPlayer.DisplayName) end
    if showTime then table.insert(parts, os.date("%H:%M")) end
    if showPing then table.insert(parts, string.format("Ping: %.0fms", pingMs)) end
    if showFPS then table.insert(parts, string.format("FPS: %.0f", currentFPS)) end
    if #parts == 1 then
        watermarkFrame.Visible = false
        return
    end

    local newText = table.concat(parts, " | ")
    if newText == lastText and watermarkHeight == lastHeight then return end
    lastText = newText

    local textWidth = getTextWidth(newText)
    local newWidth = textWidth + 20
    local fontSize = math.floor(watermarkHeight * 0.5)
    fontSize = math.clamp(fontSize, 10, 24)
    watermarkText.TextSize = fontSize

    if lastHeight ~= watermarkHeight or lastWidth ~= newWidth then
        watermarkFrame.Size = UDim2.new(0, newWidth, 0, watermarkHeight)
        lastHeight = watermarkHeight
        lastWidth = newWidth

        if not wasDragged then
            local screenSize = Camera.ViewportSize
            currentPosX = (screenSize.X - newWidth) / 2
            currentPosY = 0
            watermarkFrame.Position = UDim2.new(0, currentPosX, 0, currentPosY)
        else
            local screenSize = Camera.ViewportSize
            currentPosX = math.clamp(currentPosX, 0, screenSize.X - newWidth)
            currentPosY = math.clamp(currentPosY, 0, screenSize.Y - watermarkHeight)
            watermarkFrame.Position = UDim2.new(0, currentPosX, 0, currentPosY)
        end
    end

    if watermarkText.Text ~= newText then
        watermarkText.Text = newText
    end
end

local function frameCounter()
    frameCount = frameCount + 1
    local now = os.clock()
    if now - lastTime >= 1 then
        currentFPS = frameCount / (now - lastTime)
        frameCount = 0
        lastTime = now
    end
end

local function updateLoop()
    while updateLoopRunning do
        if showWatermark then refreshWatermark() end
        task.wait(updateInterval)
    end
end

updateLoopRunning = true
updateThread = task.spawn(updateLoop)
local frameCounterConnection = RunService.RenderStepped:Connect(frameCounter)

local function setWatermarkHeight(value)
    watermarkHeight = value
    refreshWatermark()
end

local function cleanupWatermark()
    updateLoopRunning = false
    if updateThread then task.cancel(updateThread); updateThread = nil end
    if frameCounterConnection then frameCounterConnection:Disconnect(); frameCounterConnection = nil end
    if watermarkGui then watermarkGui:Destroy() end
end

local espSection = VisualTab:AddSection({
    Name = "ESP",
    Position = 'left'
})

local espEnableToggle = espSection:AddToggle({
    Name = "Enable",
    Default = false,
    Option = true,
    Callback = function(val) ESP.Enabled = val end
})

espEnableToggle.Option:AddToggle({
    Name = "Team Check",
    Default = false,
    Callback = function(val) ESP.TeamCheck = val end
})

espEnableToggle.Option:AddSlider({
    Name = "Max Distance",
    Min = 100,
    Max = 5000,
    Default = 1000,
    Round = 0,
    Type = "studs",
    Callback = function(val) ESP.MaxDistance = val end
})

local nameToggle = espSection:AddToggle({ Name = "Name", Default = false, Option = true, Callback = function(val) ESP.NameESP = val end })
nameToggle.Option:AddToggle({ Name = "Show Distance", Default = false, Callback = function(val) ESP.ShowDistance = val end })
nameToggle.Option:AddToggle({ Name = "Weapon", Default = false, Callback = function(val) ESP.WeaponESP = val end })

local boxToggle = espSection:AddToggle({ Name = "Box", Default = false, Option = true, Callback = function(val) ESP.BoxESP = val end })
boxToggle.Option:AddSlider({ Name = "Box Thickness", Min = 1, Max = 5, Default = 1, Round = 0, Callback = function(val) ESP.BoxThickness = val end })
boxToggle.Option:AddColorPicker({ Name = "Box Color", Default = ESP.BoxColor, Callback = function(val) ESP.BoxColor = val end })
boxToggle.Option:AddSlider({ Name = "Fill Transparency", Min = 0, Max = 10, Default = 5, Round = 0, Type = "", Callback = function(val) ESP.BoxFillTransparency = val / 10 end })
boxToggle.Option:AddDropdown({ Name = "Box Style", Values = {"Corner", "Full", "Filled"}, Default = "Corner", Callback = function(val) ESP.BoxStyle = val end })

local tracerToggle = espSection:AddToggle({ Name = "Tracer", Default = false, Option = true, Callback = function(val) ESP.TracerESP = val end })
tracerToggle.Option:AddDropdown({ Name = "Tracer Origin", Values = {"Bottom", "Top", "Mouse", "Center"}, Default = "Bottom", Callback = function(val) ESP.TracerOrigin = val end })

local healthToggle = espSection:AddToggle({ Name = "Health", Default = false, Option = true, Callback = function(val) ESP.HealthESP = val end })
healthToggle.Option:AddDropdown({ Name = "Health Style", Values = {"Bar", "Text"}, Default = "Bar", Callback = function(val) ESP.HealthStyle = val end })

local chamsToggle = espSection:AddToggle({ Name = "Chams", Default = false, Option = true, Callback = function(val) ESP.ChamsEnabled = val end })
chamsToggle.Option:AddColorPicker({ Name = "Visible Color", Default = ESP.ChamsVisibleColor, Callback = function(color) ESP.ChamsVisibleColor = color end })
chamsToggle.Option:AddColorPicker({ Name = "Invisible Color", Default = ESP.ChamsInvisibleColor, Callback = function(color) ESP.ChamsInvisibleColor = color end })
chamsToggle.Option:AddSlider({ Name = "Fill Transparency", Min = 0, Max = 10, Default = 5, Round = 0, Type = "", Callback = function(val) ESP.ChamsTransparency = val / 10 end })

local uiSection = Misc:AddSection({
    Name = "UI",
    Position = 'left'
})

local watermarkMainToggle = uiSection:AddToggle({
    Name = "Show Watermark",
    Default = false,
    Option = true,
    Callback = function(val)
        showWatermark = val
        if watermarkGui then watermarkGui.Enabled = val end
        refreshWatermark()
    end
})
watermarkMainToggle.Option:AddSlider({ Name = "Height", Min = 20, Max = 50, Default = 28, Round = 0, Type = "px", Callback = function(val) setWatermarkHeight(val) end })
watermarkMainToggle.Option:AddToggle({ Name = "Show Ping", Default = true, Callback = function(val) showPing = val; refreshWatermark() end })
watermarkMainToggle.Option:AddToggle({ Name = "Show FPS", Default = true, Callback = function(val) showFPS = val; refreshWatermark() end })
watermarkMainToggle.Option:AddToggle({ Name = "Show Time", Default = true, Callback = function(val) showTime = val; refreshWatermark() end })
watermarkMainToggle.Option:AddToggle({ Name = "Show Username", Default = true, Callback = function(val) showUsername = val; refreshWatermark() end })

local movementSection = Misc:AddSection({
    Name = "MOVEMENT",
    Position = 'center'
})

local strafeEnabled = false
local strafeSpeed = 35
local strafeBodyVelocity = nil
local strafeConnection = nil

local function strafeLoop()
    if not strafeEnabled then
        if strafeBodyVelocity then strafeBodyVelocity:Destroy(); strafeBodyVelocity = nil end
        return
    end
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end
    local isGrounded = (humanoid.FloorMaterial ~= Enum.Material.Air) or (humanoid:GetState() == Enum.HumanoidStateType.Seated)
    if isGrounded then
        if strafeBodyVelocity then strafeBodyVelocity:Destroy(); strafeBodyVelocity = nil end
        return
    end
    local moveDir = humanoid.MoveDirection
    if moveDir.Magnitude > 0.1 then
        if not strafeBodyVelocity then
            strafeBodyVelocity = Instance.new("BodyVelocity")
            strafeBodyVelocity.MaxForce = Vector3.new(10000, 0, 10000)
            strafeBodyVelocity.P = 10000
            strafeBodyVelocity.Parent = rootPart
        end
        local targetVel = moveDir * strafeSpeed
        strafeBodyVelocity.Velocity = Vector3.new(targetVel.X, rootPart.Velocity.Y, targetVel.Z)
    else
        if strafeBodyVelocity then strafeBodyVelocity:Destroy(); strafeBodyVelocity = nil end
    end
end

local function setStrafeState(state)
    strafeEnabled = state
    if state and not strafeConnection then
        strafeConnection = RunService.RenderStepped:Connect(strafeLoop)
    elseif not state and strafeConnection then
        strafeConnection:Disconnect(); strafeConnection = nil
        if strafeBodyVelocity then strafeBodyVelocity:Destroy(); strafeBodyVelocity = nil end
    end
end

local strafeToggle = movementSection:AddToggle({ Name = "Air Strafe", Default = false, Option = true, Callback = function(val) setStrafeState(val) end })
strafeToggle.Option:AddSlider({ Name = "Speed", Min = 10, Max = 120, Default = 35, Round = 1, Type = "studs/s", Callback = function(val) strafeSpeed = val end })

local luaSection = LuaTab:AddSection({
    Name = "SCRIPTS",
    Position = 'left'
})
luaSection:AddButton({
    Name = "Load Infinite Yield",
    Description = "Load admin script Infinite Yield",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
    end
})

local ScriptSettingsSection = Misc:AddSection({
    Name = "UNLOAD",
    Position = 'right'
})

ScriptSettingsSection:AddButton({
    Name = "Unload Script",
    Callback = function()
        print("[Fatality] Initializing full unload...")
        
        task.spawn(function()
            local function nukeUI(container)
                if not container then return end
                for _, gui in ipairs(container:GetChildren()) do
                    if gui:IsA("ScreenGui") then
                        local isTarget = false
                        
                        if gui.Name:lower():find("fatality") then 
                            isTarget = true 
                        end
                        
                        if not isTarget then
                            pcall(function()
                                for _, desc in ipairs(gui:GetDescendants()) do
                                    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                                        local text = tostring(desc.Text)
                                        if text:find("FATALITY") or text:find("1488 days") or text:find("RAGE") then
                                            isTarget = true
                                            break
                                        end
                                    end
                                end
                            end)
                        end
                        
                        if isTarget then
                            pcall(function()
                                gui.Enabled = false
                                gui:Destroy()
                            end)
                        end
                    end
                end
            end

            pcall(function() nukeUI(game:GetService("CoreGui")) end)
            pcall(function() nukeUI(game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")) end)
            if gethui then pcall(function() nukeUI(gethui()) end) end
            
            print("[Fatality] interface unloaded")
        end)

        pcall(function()
            if DisableFakeLag then DisableFakeLag() end
            if ESP then ESP.Enabled = false end
            if espConnection then espConnection:Disconnect() end
            
            local function clearVisuals(folder)
                if not folder then return end
                for _, obj in ipairs(folder:GetChildren()) do
                    local name = obj.Name:lower()
                    if name:find("esp") or name:find("box") or name:find("tracer") or name:find("name") or name:find("health") or name:find("drawing") then
                        pcall(function() obj:Destroy() end)
                    end
                end
            end
            pcall(function() clearVisuals(game:GetService("CoreGui")) end)
            pcall(function() clearVisuals(game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")) end)

            for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
                if player.Character then
                    for _, obj in ipairs(player.Character:GetDescendants()) do
                        if obj:IsA("Highlight") or obj.Name == "Chams" or obj.Name:find("Highlight") then
                            pcall(function() obj:Destroy() end)
                        end
                        if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                            local objName = obj.Name:lower()
                            if objName:find("esp") or objName:find("name") or objName:find("health") or objName:find("box") or objName:find("tag") then
                                pcall(function() obj:Destroy() end)
                            end
                        end
                    end
                end
            end

            for _, hl in pairs(workspace:GetDescendants()) do
                if (hl:IsA("Highlight") and hl.Name == "LD_Ghost_Clone") or hl.Name == "LD_Ghost_Clone" then
                    pcall(function() hl:Destroy() end)
                end
            end

            local Lighting = game:GetService("Lighting")
            local Camera = workspace.CurrentCamera
            
            local function removeBlurFrom(container)
                if not container then return end
                for _, obj in ipairs(container:GetChildren()) do
                    if obj:IsA("BlurEffect") or obj:IsA("MotionBlur") or obj.Name:lower():find("blur") or obj.Name == "motionblur" then
                        pcall(function() obj:Destroy() end)
                    end
                    if obj:IsA("Sky") or obj:IsA("ColorCorrectionEffect") or obj:IsA("Atmosphere") or obj.Name:find("Custom") then
                        pcall(function() obj:Destroy() end)
                    end
                end
            end
            
            removeBlurFrom(Lighting)
            removeBlurFrom(Camera)

            Lighting.Ambient = Color3.fromRGB(128, 128, 128)
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            Lighting.FogColor = Color3.fromRGB(192, 192, 192)
            Lighting.FogStart = 0
            Lighting.FogEnd = 100000
            Lighting.ClockTime = 14

            if strafeConnection then strafeConnection:Disconnect() end
            if _G.DisableStrafe then pcall(_G.DisableStrafe) end
            
            local LocalPlayer = game:GetService("Players").LocalPlayer
            if LocalPlayer and LocalPlayer.Character then
                local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.AutoRotate = true
                end
            end

            if _G.unloadAntiAim then _G.unloadAntiAim() end
            
            if _G.unloadAIM then _G.unloadAIM() end
            
            if cleanupWatermark then cleanupWatermark() end
        end)

        Window = nil
        Fatality = nil
    end
})

Window:AddInfo(function()
    Notification:Notify({
        Title = "Fatality",
        Content = "Fatality.win by vener4zet",
        Duration = 3,
        Icon = "info"
    })
end)

Notification:Notify({
    Title = "Fatality.win",
    Content = "Fatality Loaded",
    Duration = 4,
    Icon = "info"
})

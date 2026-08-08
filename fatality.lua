local Fatality = loadstring(game:HttpGet("https://raw.githubusercontent.com/4lpaca-pin/Fatality/refs/heads/main/src/source.luau"))();
local Notification = Fatality:CreateNotifier();

Fatality:Loader({
    Name = "FATALITY",
    Duration = 4,
    Scale = 3
});

Notification:Notify({
    Title = "FATALITY",
    Content = "Hello, "..game.Players.LocalPlayer.Name..' Welcome back!',
    Icon = "clipboard"
})

local Window = Fatality.new({
    Name = "FATALITY",
    Expire = "1488 days",
    Keybind = "Delete"
});
-- ==================== Вкладки ====================
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
-- ==================== Сервисы Roblox ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
-- ==================== AIM ====================
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local aimlockEnabled = false
local activationKey = Enum.KeyCode.Z
local currentTarget = nil
local locked = false
local highlight = nil

-- Настройки Aimlock
local predictionEnabled = false
local predictionStrength = 0.2
local highlightEnabled = true
local highlightColor = Color3.fromRGB(255, 255, 255)
local aimPriority = "Crosshair" -- Crosshair, Distance

-- Проверки
local aimTeamCheck = false
local aimDownedCheck = false

-- Подключения для очистки
local connections = {}

-- Поиск цели с учетом выбранного приоритета (Безопасный, без зависаний)
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
            -- Team Check
            if aimTeamCheck and p.Team == localPlayer.Team then continue end
            
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then continue end
            
            -- Downed Check
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
                
                -- ОПРЕДЕЛЕНИЕ ПРИОРИТЕТА
                if aimPriority == "Crosshair" then
                    -- Ближе всего к центру экрана (курсору)
                    currentValue = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                elseif aimPriority == "Distance" then
                    -- Ближе всего к самому игроку в 3D пространстве
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

-- Обработка ввода для Aimlock (активация по клавише)
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

-- Основной цикл Aimlock
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

        -- Автоматический поиск новой цели, если старая пропала или умерла
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

-- Функция для выгрузки
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

-- ==================== UI ====================
local aimSection = RageTab:AddSection({
    Name = "AIM",
    Position = 'left'
})

-- Aimlock тумблер
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

-- Старый бинд на месте
aimToggle.Option:AddKeybind({
    Name = "Aimlock Key",
    Default = "Z",
    Callback = function(key)
        activationKey = Enum.KeyCode[key] or Enum.UserInputType[key] or Enum.KeyCode.Z
        setupInput()
    end
})

-- Проверки
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

-- Выпадающий список приоритетов в самом низу меню опций аимлока
aimToggle.Option:AddDropdown({
    Name = "Target Priority",
    Values = {"Crosshair", "Distance"},
    Default = "Crosshair",
    Callback = function(val)
        aimPriority = val
    end
})

-- Prediction тумблер
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

-- Highlight тумблер
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
-- ==================== ANTI-AIM ====================
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local antiAimEnabled = false
local currentMode = "static"
local spinSpeed = 360
local yawEnabled = false
local yawAngle = 0
local pitchEnabled = true 
local pitchAngle = 0      
local antiAimDownedCheck = true 
local atTargetFallbackAngle = 0 

-- Коннекты разделены для физики и анимаций
local antiAimRenderConn = nil
local antiAimSteppedConn = nil

-- Настройки YAW Jitter
local yawJitterEnabled = false
local yawJitterMode = "Center"
local yawJitterRange = 30
local yawJitterInterval = 0
local yawJitterAccum = 0
local yawJitterOffset = 0
local way3IndexYaw = 0
local way5IndexYaw = 0

-- Настройки PITCH Jitter
local pitchJitterEnabled = false
local pitchJitterMode = "Center"
local pitchJitterRange = 30
local pitchJitterInterval = 0
local pitchJitterAccum = 0
local pitchJitterOffset = 0
local way3IndexPitch = 0
local way5IndexPitch = 0

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
                
                if antiAimDownedCheck then
                    if humanoid:GetState() == Enum.HumanoidStateType.Dead or humanoid:GetState() == Enum.HumanoidStateType.Physics then
                        continue
                    end
                end

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

-- ==================== 1. ЛОГИКА YAW (Вращение RootPart - Видят все) ====================
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

    -- Подсчет Yaw Jitter
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

    -- Подсчет Pitch Jitter (Для применения в следующем блоке)
    if pitchJitterEnabled then
        local applyJitter = false
        if pitchJitterInterval > 0 then
            pitchJitterAccum = pitchJitterAccum + dt
            if pitchJitterAccum >= pitchJitterInterval then
                pitchJitterAccum = 0
                applyJitter = true
            end
        else
            applyJitter = true
        end
        
        if applyJitter then
            if pitchJitterMode == "Center" then
                pitchJitterOffset = (math.random() * 2 - 1) * pitchJitterRange
            elseif pitchJitterMode == "Random" then
                pitchJitterOffset = (math.random() * 2 - 1) * 90
            elseif pitchJitterMode == "3-way" then
                way3IndexPitch = (way3IndexPitch + 1) % 3
                if way3IndexPitch == 0 then pitchJitterOffset = -pitchJitterRange
                elseif way3IndexPitch == 1 then pitchJitterOffset = 0
                else pitchJitterOffset = pitchJitterRange end
            elseif pitchJitterMode == "5-way" then
                way5IndexPitch = (way5IndexPitch + 1) % 5
                if way5IndexPitch == 0 then pitchJitterOffset = -pitchJitterRange
                elseif way5IndexPitch == 1 then pitchJitterOffset = -pitchJitterRange / 2
                elseif way5IndexPitch == 2 then pitchJitterOffset = 0
                elseif way5IndexPitch == 3 then pitchJitterOffset = pitchJitterRange / 2
                else pitchJitterOffset = pitchJitterRange end
            end
        end
    else
        pitchJitterOffset = 0
    end

    -- Применение YAW к Рутпарту
    local _, yAngle, _ = targetLookCF:ToOrientation()
    local finalYaw = yAngle + yawJitterOffset
    if yawEnabled then finalYaw = finalYaw + math.rad(yawAngle) end
    root.CFrame = CFrame.new(pos) * CFrame.Angles(0, finalYaw, 0)
end

-- ==================== 2. ЛОГИКА PITCH (Перезапись анимаций костей) ====================
local function antiAimBones()
    if not antiAimEnabled or not pitchEnabled then return end
    
    local player = Players.LocalPlayer
    local activeChar = player.Character
    -- Ищем настоящее серверное тело с хайлайтом (оно остается под твоим ником при Fake Lag)
    local realChar = Workspace:FindFirstChild(player.Name)

    -- Собираем обе модельки в список, чтобы согнуть их синхронно
    local charsToBend = {}
    if activeChar then table.insert(charsToBend, activeChar) end
    if realChar and realChar ~= activeChar then table.insert(charsToBend, realChar) end

    local finalPitchDeg = math.clamp(pitchAngle + pitchJitterOffset, -90, 90)
    local pRad = math.rad(finalPitchDeg)

    for _, char in ipairs(charsToBend) do
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            local neck = char:FindFirstChild("Neck", true)
            local waist = char:FindFirstChild("Waist", true)

            -- Накладываем наклон на кости каждой найденной модельки
            if waist then
                waist.Transform = waist.Transform * CFrame.Angles(pRad, 0, 0)
            end
            if neck then
                neck.Transform = neck.Transform * CFrame.Angles(pRad, 0, 0)
            end
        end
    end
end

-- Основная функция управления состояниями (Вкл/Выкл)
local function setAntiAimState(state)
    antiAimEnabled = state
    if state then
        -- RenderStepped для перемещения хитбокса (Yaw)
        if not antiAimRenderConn then
            antiAimRenderConn = RunService.RenderStepped:Connect(antiAimMain)
        end
        -- Stepped для модификации костей без конфликта с анимациями (Pitch)
        if not antiAimSteppedConn then
            antiAimSteppedConn = RunService.Stepped:Connect(antiAimBones)
        end
    else
        if antiAimRenderConn then 
            antiAimRenderConn:Disconnect()
            antiAimRenderConn = nil 
        end
        if antiAimSteppedConn then 
            antiAimSteppedConn:Disconnect()
            antiAimSteppedConn = nil 
        end
        -- Нам больше не нужно принудительно возвращать кости на место.
        -- Как только мы отключаем Stepped коннект, движок Роблокса моментально
        -- выпрямляет персонажа в его дефолтную анимацию.
    end
end

-- Глобальная очистка для кнопки Unload Script
local function unloadAntiAim()
    setAntiAimState(false)
end
_G.unloadAntiAim = unloadAntiAim

-- ==================== UI ANTI-AIM ====================
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

antiAimToggle.Option:AddSlider({
    Name = "Pitch Angle",
    Default = 0,
    Min = -90,
    Max = 90,
    Rounding = 0,
    Type = "°",
    Callback = function(val) pitchAngle = val end
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
-- НАСТРОЙКИ YAW JITTER
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

-- НАСТРОЙКИ PITCH JITTER
local pitchJitterToggle = antiAimSection:AddToggle({
    Name = "Pitch jitter",
    Default = false,
    Option = true,
    Callback = function(val) pitchJitterEnabled = val end
})
pitchJitterToggle.Option:AddSlider({
    Name = "Range",
    Default = 30,
    Min = 1,
    Max = 90,
    Type = "°",
    Callback = function(val) pitchJitterRange = val end
})
pitchJitterToggle.Option:AddSlider({
    Name = "Delay",
    Default = 0,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Type = "ms",
    Callback = function(val) pitchJitterInterval = val / 1000 end
})
pitchJitterToggle.Option:AddDropdown({
    Name = "Mode",
    Values = {"Center", "3-way", "5-way", "Random"},
    Default = "Center",
    Callback = function(val) pitchJitterMode = val end
})
-- ==================== FAKE LAG (серверная часть – прозрачный силуэт с обводкой) ====================
local Player = game:GetService("Players").LocalPlayer
local fakeLagEnabled = false
local fakeLagLimit = 5            
local RealChar = nil
local FakeChar = nil
local fakeLagConnections = {}
local fakeLagAnimTracks = {}
local realLagAnimTracks = {} -- Анимации для серверной модели (с обводкой)
local updateThread = nil
local serverHighlight = nil
local freezeBV = nil
local originalWalkSpeed = 16

local function GetAnimID(char, name, subName)
    local animScript = char:FindFirstChild("Animate")
    if animScript then
        local value = animScript:FindFirstChild(name)
        if value then
            local anim = value:FindFirstChild(subName) or value:FindFirstChildOfClass("Animation")
            if anim then return anim.AnimationId end
        end
    end
    return nil
end

local function StopAllAnims()
    for _, track in pairs(fakeLagAnimTracks) do
        if track then pcall(function() track:Stop(0.1) end) end
    end
    for _, track in pairs(realLagAnimTracks) do
        if track then pcall(function() track:Stop(0.1) end) end
    end
end

local function DisableFakeLag()
    if not fakeLagEnabled then return end
    fakeLagEnabled = false
    
    for _, conn in pairs(fakeLagConnections) do pcall(function() conn:Disconnect() end) end
    fakeLagConnections = {}
    
    -- Останавливаем наши Action4 анимации, чтобы оригинальный Animate снова заработал
    StopAllAnims()
    fakeLagAnimTracks = {}
    realLagAnimTracks = {}
    
    if updateThread then pcall(function() task.cancel(updateThread) end); updateThread = nil end
    if serverHighlight then pcall(function() serverHighlight:Destroy() end); serverHighlight = nil end
    if freezeBV then pcall(function() freezeBV:Destroy() end); freezeBV = nil end

    if RealChar and RealChar:FindFirstChild("HumanoidRootPart") then
        local realHum = RealChar:FindFirstChildOfClass("Humanoid")
        if realHum then realHum.WalkSpeed = originalWalkSpeed end
        
        for _, part in ipairs(RealChar:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name == "HumanoidRootPart" then
                    part.Transparency = 1
                else
                    part.Transparency = 0
                end
                part.CanCollide = true
            end
        end
        
        local savedCamCF = workspace.CurrentCamera.CFrame
        Player.Character = RealChar
        if realHum then workspace.CurrentCamera.CameraSubject = realHum end
        task.spawn(function()
            for i = 1, 5 do
                workspace.CurrentCamera.CFrame = savedCamCF
                game:GetService("RunService").RenderStepped:Wait()
            end
        end)
    end
    
    if FakeChar then pcall(function() FakeChar:Destroy() end); FakeChar = nil end
    RealChar = nil
end

local function EnableFakeLag()
    RealChar = Player.Character
    if not RealChar or not RealChar:FindFirstChild("HumanoidRootPart") or not RealChar:FindFirstChildOfClass("Humanoid") then return end

    fakeLagEnabled = true
    
    local realHum = RealChar:FindFirstChildOfClass("Humanoid")
    originalWalkSpeed = realHum.WalkSpeed
    local savedCamCF = workspace.CurrentCamera.CFrame
    
    for _, part in ipairs(RealChar:GetDescendants()) do
        if part:IsA("BasePart") then
            if part.Name == "HumanoidRootPart" then part.Transparency = 1 else part.Transparency = 0.7 end
        end
    end
    
    serverHighlight = Instance.new("Highlight")
    serverHighlight.Parent = RealChar
    serverHighlight.FillColor = Color3.fromRGB(255, 255, 255)
    serverHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    serverHighlight.FillTransparency = 0.7
    serverHighlight.OutlineTransparency = 0

    RealChar.Archivable = true
    FakeChar = RealChar:Clone()
    FakeChar.Name = "LD_Ghost_Clone"
    FakeChar.Parent = workspace
    RealChar.Archivable = false

    for _, v in pairs(FakeChar:GetDescendants()) do
        if v:IsA("LocalScript") or v:IsA("Script") then pcall(function() v:Destroy() end) end
    end
    local cloneHighlight = FakeChar:FindFirstChildOfClass("Highlight")
    if cloneHighlight then cloneHighlight:Destroy() end

    for _, part in pairs(FakeChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
            pcall(function() part.CanTouch = false; part.CanQuery = false end)
            if part.Name == "HumanoidRootPart" then part.Transparency = 1 else part.Transparency = 0 end
        end
    end

    local fakeHum = FakeChar:FindFirstChild("Humanoid")
    local fakeRoot = FakeChar:FindFirstChild("HumanoidRootPart")
    
    -- Загружаем анимации для клона и для сервера
    if fakeHum and realHum then
        fakeHum.WalkSpeed = originalWalkSpeed 
        fakeHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        
        local function Load(hum, id, isPriority)
            if not id then return nil end
            local a = Instance.new("Animation") a.AnimationId = id
            local track = hum:LoadAnimation(a)
            if isPriority then track.Priority = Enum.AnimationPriority.Action4 end
            return track
        end

        local runId = GetAnimID(RealChar, "run", "RunAnim") or GetAnimID(RealChar, "walk", "WalkAnim") or "rbxassetid://180426354"
        local idleId = GetAnimID(RealChar, "idle", "Animation1") or "rbxassetid://180435571"
        local jumpId = GetAnimID(RealChar, "jump", "JumpAnim") or "rbxassetid://125750702"
        local climbId = GetAnimID(RealChar, "climb", "ClimbAnim") or "rbxassetid://180436334"

        -- Анимации клона
        fakeLagAnimTracks.Run = Load(fakeHum, runId, false)
        fakeLagAnimTracks.Idle = Load(fakeHum, idleId, false)
        fakeLagAnimTracks.Jump = Load(fakeHum, jumpId, false)
        fakeLagAnimTracks.Climb = Load(fakeHum, climbId, false)
        
        -- Анимации сервера (перекрывают сломанный Animate, не трогая его)
        realLagAnimTracks.Run = Load(realHum, runId, true)
        realLagAnimTracks.Idle = Load(realHum, idleId, true)
        realLagAnimTracks.Jump = Load(realHum, jumpId, true)
        realLagAnimTracks.Climb = Load(realHum, climbId, true)

        if fakeLagAnimTracks.Idle then pcall(function() fakeLagAnimTracks.Idle:Play() end) end
        if realLagAnimTracks.Idle then pcall(function() realLagAnimTracks.Idle:Play() end) end
    end

    realHum.WalkSpeed = 0 
    
    -- Физическая заморозка в воздухе без отключения сетевых апдейтов (Anchored=false)
    freezeBV = Instance.new("BodyVelocity")
    freezeBV.Name = "FakeLagFreeze"
    freezeBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    freezeBV.Velocity = Vector3.new(0, 0, 0)
    freezeBV.P = 100000
    freezeBV.Parent = RealChar.HumanoidRootPart

    Player.Character = FakeChar
    if fakeHum then workspace.CurrentCamera.CameraSubject = fakeHum end

    task.spawn(function()
        for i = 1, 5 do
            workspace.CurrentCamera.CFrame = savedCamCF
            game:GetService("RunService").RenderStepped:Wait()
        end
    end)

    table.insert(fakeLagConnections, game:GetService("UserInputService").JumpRequest:Connect(function()
        if fakeLagEnabled and fakeHum then pcall(function() fakeHum.Jump = true end) end
    end))

    table.insert(fakeLagConnections, game:GetService("RunService").Heartbeat:Connect(function()
        if not fakeLagEnabled or not FakeChar or not RealChar then return end
        for _, part in ipairs(FakeChar:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        for _, part in ipairs(RealChar:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end))

    -- Управление и синхронизация анимаций
    table.insert(fakeLagConnections, game:GetService("RunService").RenderStepped:Connect(function()
        if not fakeLagEnabled or not FakeChar or not fakeHum or not fakeRoot then return end
        local moveDir = Vector3.new(0,0,0)
        local camCF = workspace.CurrentCamera.CFrame
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
        local finalDir = Vector3.new(moveDir.X, 0, moveDir.Z)
        fakeHum:Move(finalDir.Magnitude > 0 and finalDir.Unit or Vector3.new(0,0,0), false)

        local velocity = fakeRoot.Velocity
        local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        local isClimbing = fakeHum:GetState() == Enum.HumanoidStateType.Climbing
        
        -- Синхронный запуск анимаций для клона и сервера
        if isClimbing then
            if fakeLagAnimTracks.Climb and not fakeLagAnimTracks.Climb.IsPlaying then
                StopAllAnims()
                pcall(function() fakeLagAnimTracks.Climb:Play() end)
                pcall(function() realLagAnimTracks.Climb:Play() end)
            end
        elseif velocity.Y > 5 then
            if fakeLagAnimTracks.Jump and not fakeLagAnimTracks.Jump.IsPlaying then
                StopAllAnims()
                pcall(function() fakeLagAnimTracks.Jump:Play() end)
                pcall(function() realLagAnimTracks.Jump:Play() end)
            end
        elseif speed > 0.5 then
            if fakeLagAnimTracks.Run and not fakeLagAnimTracks.Run.IsPlaying then
                StopAllAnims()
                pcall(function() fakeLagAnimTracks.Run:Play() end)
                pcall(function() realLagAnimTracks.Run:Play() end)
            end
        else
            if fakeLagAnimTracks.Idle and not fakeLagAnimTracks.Idle.IsPlaying then
                StopAllAnims()
                pcall(function() fakeLagAnimTracks.Idle:Play() end)
                pcall(function() realLagAnimTracks.Idle:Play() end)
            end
        end
    end))

    local function updateRealChar()
        while fakeLagEnabled do
            task.wait(fakeLagLimit * (1.5 / 14))
            if fakeLagEnabled and RealChar and RealChar:FindFirstChild("HumanoidRootPart") and FakeChar and FakeChar:FindFirstChild("HumanoidRootPart") then
                -- Телепортация серверной модели к клону (freezeBV удержит её в воздухе между тиками)
                RealChar.HumanoidRootPart.CFrame = FakeChar.HumanoidRootPart.CFrame
                RealChar.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
            end
        end
    end

    if updateThread then task.cancel(updateThread) end
    updateThread = task.spawn(updateRealChar)
end

-- UI
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
    Type = "",
    Callback = function(val) fakeLagLimit = val end
})
-- ==================== ESP ====================
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
    HealthColor = Color3.fromRGB(0, 255, 0)
}

local Drawings = { ESP = {} }
local Highlights = {}

-- Проверка видимости цели
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
        Snapline = snapline
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

    -- Проверка видимости и дистанции
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

    -- Team Check
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

-- ==================== WORLD ====================
local worldSection = VisualTab:AddSection({
    Name = "WORLD",
    Position = 'right'
})

-- Motion Blur
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

-- Custom Fog
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

-- World Colors
local worldColorsEnabled = false
local originalAmbient = Lighting.Ambient
local worldAmbient = Color3.fromRGB(255, 255, 255)  -- белый по умолчанию

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

-- ==================== ESP LOOP ====================
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
-- ==================== WATERMARK ====================
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
-- ==================== VISUAL UI ====================
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

-- ==================== UI SECTION ====================
local uiSection = Misc:AddSection({
    Name = "UI",
    Position = 'left'
})

-- Watermark
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
-- ==================== MOVEMENT ====================
local movementSection = Misc:AddSection({
    Name = "MOVEMENT",
    Position = 'center'
})
-- Strafe
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

-- ==================== LUA ====================
local luaSection = LuaTab:AddSection({
    Name = "SCRIPTS",
    Position = 'left'
})
luaSection:AddButton({
    Name = "Load Infinite Yield",
    Description = "Загрузить админ-скрипт Infinite Yield",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
    end
})
-- ==================== СЕКЦИЯ НАСТРОЕК СКРИПТА (Вкладка MISC) ====================
local ScriptSettingsSection = Misc:AddSection({
    Name = "UNLOAD",
    Position = 'right' -- Можно поменять на 'right', если слева уже занято
})

-- ==================== КНОПКА ПОЛНОЙ И БЕЗОПАСНОЙ ВЫГРУЗКИ ====================
ScriptSettingsSection:AddButton({
    Name = "Unload Script",
    Callback = function()
        print("[Fatality] Инициализация полной выгрузки...")
        
        -- ГАРАНТИРОВАННОЕ УДАЛЕНИЕ ИНТЕРФЕЙСА (в отдельном потоке)
        task.spawn(function()
            local function nukeUI(container)
                if not container then return end
                for _, gui in ipairs(container:GetChildren()) do
                    if gui:IsA("ScreenGui") then
                        local isTarget = false
                        
                        -- Проверка по имени
                        if gui.Name:lower():find("fatality") then 
                            isTarget = true 
                        end
                        
                        -- Глубокая проверка по тексту (если имя зашифровано библиотекой)
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
                        
                        -- Уничтожаем найденный интерфейс
                        if isTarget then
                            pcall(function()
                                gui.Enabled = false
                                gui:Destroy()
                            end)
                        end
                    end
                end
            end

            -- Сканируем все папки
            pcall(function() nukeUI(game:GetService("CoreGui")) end)
            pcall(function() nukeUI(game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")) end)
            if gethui then pcall(function() nukeUI(gethui()) end) end
            
            print("[Fatality] Интерфейс успешно уничтожен!")
        end)

        -- ОСТАНОВКА ВСЕХ ФУНКЦИЙ И ОЧИСТКА ОКРУЖЕНИЯ
        pcall(function()
            -- Выключаем Fake Lag
            if DisableFakeLag then DisableFakeLag() end
            -- Отключаем глобальный тумблер ESP, если он есть в скрипте
            if ESP then ESP.Enabled = false end
            if espConnection then espConnection:Disconnect() end
            
            -- ТОТАЛЬНАЯ ЗАЧИСТКА ESP (Тексты, Имена, Здоровье, Боксы)
            -- Очищаем 2D-элементы из CoreGui и PlayerGui
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

            -- Очищаем 3D-элементы (BillboardGui, чистящие Name/Health/Box) внутри персонажей игроков
            for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
                if player.Character then
                    for _, obj in ipairs(player.Character:GetDescendants()) do
                        -- Удаляем Chams (Подсветку)
                        if obj:IsA("Highlight") or obj.Name == "Chams" or obj.Name:find("Highlight") then
                            pcall(function() obj:Destroy() end)
                        end
                        -- Удаляем BillboardGui, внутри которых рендерятся Name, Health, HealthBar и Box
                        if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                            local objName = obj.Name:lower()
                            if objName:find("esp") or objName:find("name") or objName:find("health") or objName:find("box") or objName:find("tag") then
                                pcall(function() obj:Destroy() end)
                            end
                        end
                    end
                end
            end

            -- Очищаем клон-силуэты фейклага из workspace
            for _, hl in pairs(workspace:GetDescendants()) do
                if (hl:IsA("Highlight") and hl.Name == "LD_Ghost_Clone") or hl.Name == "LD_Ghost_Clone" then
                    pcall(function() hl:Destroy() end)
                end
            end

            -- УДАЛЕНИЕ MOTION BLUR И ВОССТАНОВЛЕНИЕ ГРАФИКИ
            local Lighting = game:GetService("Lighting")
            local Camera = workspace.CurrentCamera
            
            -- Функция удаления эффектов размытия и кастомных фильтров
            local function removeBlurFrom(container)
                if not container then return end
                for _, obj in ipairs(container:GetChildren()) do
                    if obj:IsA("BlurEffect") or obj:IsA("MotionBlur") or obj.Name:lower():find("blur") or objName == "motionblur" then
                        pcall(function() obj:Destroy() end)
                    end
                    if obj:IsA("Sky") or obj:IsA("ColorCorrectionEffect") or obj:IsA("Atmosphere") or obj.Name:find("Custom") then
                        pcall(function() obj:Destroy() end)
                    end
                end
            end
            
            removeBlurFrom(Lighting)
            removeBlurFrom(Camera)

            -- Сброс стандартных параметров освещения игры
            Lighting.Ambient = Color3.fromRGB(128, 128, 128)
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            Lighting.FogColor = Color3.fromRGB(192, 192, 192)
            Lighting.FogStart = 0
            Lighting.FogEnd = 100000
            Lighting.ClockTime = 14

            -- ОТКЛЮЧЕНИЕ СТРАФОВ И ДВИЖЕНИЯ (Strafe)
            if strafeConnection then strafeConnection:Disconnect() end
            if _G.DisableStrafe then pcall(_G.DisableStrafe) end
            
            -- Сбрасываем кастомные параметры ходьбы персонажа, которые мог изменить Strafe
            local LocalPlayer = game:GetService("Players").LocalPlayer
            if LocalPlayer and LocalPlayer.Character then
                local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.AutoRotate = true -- Возвращаем авто-поворот тела за камерой
                end
            end

            -- Выключаем Anti-Aim и полностью выпрямляем спину
            if _G.unloadAntiAim then _G.unloadAntiAim() end
            
            -- Выключаем Aimlock
            if _G.unloadAIM then _G.unloadAIM() end
            
            -- Выключаем ватермарку
            if cleanupWatermark then cleanupWatermark() end
        end)

        -- ОЧИСТКА ПАМЯТИ
        Window = nil
        Fatality = nil
    end
})
-- ==================== INFO BUTTON ====================
Window:AddInfo(function()
    Notification:Notify({
        Title = "Fatality",
        Content = "Fatality.win by vener4zet",
        Duration = 3,
        Icon = "info"
    })
end)
-- ==================== INIT ====================

Notification:Notify({
    Title = "Fatality.win",
    Content = "Fatality Loaded",
    Duration = 4,
    Icon = "info"
})

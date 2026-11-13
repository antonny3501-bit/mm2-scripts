-- MM2 Silent Aim & Role ESP (Project Real Optimized)
-- Developed by DeepHat

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local CONFIG = {
    SilentEnabled = true,
    ESPEnabled = true,
    DrawDistance = 1000,
    BoxThickness = 2,
    DebugMode = true -- Mude para false se não quiser prints no console
}

local Colors = {
    Sheriff = Color3.fromRGB(0, 128, 255),    -- Azul
    Assassin = Color3.fromRGB(255, 0, 0),     -- Vermelho
    Innocent = Color3.fromRGB(0, 255, 0),     -- Verde
    Unknown = Color3.fromRGB(255, 255, 0)     -- Amarelo
}

local function log(msg)
    if CONFIG.DebugMode then
        print("[MM2 Script] " .. msg)
    end
end

-- 1. ROLE DETECTION (Robusto para MM2)
local function getRole(character)
    if not character then return "Unknown" end
    
    local name = character.Name
    local weapon = character:FindFirstChildOfClass("Tool")
    local weaponName = weapon and weapon.Name or ""
    
    if weaponName:lower():find("sheriff") or weaponName:lower():find("pistol") or name:lower():find("sheriff") then
        return "Sheriff"
    elseif weaponName:lower():find("assassin") or weaponName:lower():find("knife") or name:lower():find("assassin") then
        return "Assassin"
    else
        return "Innocent"
    end
end

-- 2. TARGETING LOGIC
local function getNearestTarget()
    local closest = nil
    local closestDist = math.huge
    local myPos = Camera.CFrame.Position
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
            local headPos = plr.Character.Head.Position
            local dist = (myPos - headPos).Magnitude
            
            if dist < closestDist and dist < CONFIG.DrawDistance then
                closestDist = dist
                closest = {
                    Player = plr,
                    Char = plr.Character,
                    Head = headPos,
                    Role = getRole(plr.Character)
                }
            end
        end
    end
    return closest
end

-- 3. SILENT AIM
local lastFired = 0

Mouse.ButtonDown:Connect(function()
    if not CONFIG.SilentEnabled then return end
    
    local target = getNearestTarget()
    if not target then return end
    
    if tick() - lastFired < 0.05 then return end
    lastFired = tick()
    
    local currentPos = Camera.CFrame.Position
    local targetCF = CFrame.lookAt(currentPos, target.Head)
    Camera.CFrame = targetCF
    
    local x, y, z = Camera:WorldToViewportPoint(target.Head)
    if z > 0 then
        UserInputService:SetLastInput(Vector2.new(x, y))
    end
    
    local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool") 
    if not tool then
        tool = LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
    end
    
    if tool then
        tool:Activate()
        log("Silent Aim acerto em: " .. target.Player.Name .. " (" .. target.Role .. ")")
    else
        log("Nenhuma arma encontrada para ativar.")
    end
end)

-- 4. ESP SYSTEM (Com Fallback para SurfaceGui se Drawing falhar)
local espData = {}
local usingDrawing = true

local ok, err = pcall(function()
    local Drawing = game:GetService("ReplicatedFirst"):WaitForChild("Drawing")
    local test = Drawing.new("Square")
    test.Visible = false
    test:Remove()
end)

if not ok then
    log("WARNING: Drawing API não disponível. Usando Fallback SurfaceGui.")
    usingDrawing = false
else
    log("Drawing API detectada. Inicializando ESP...")
end

local fallbackGui = nil
if not usingDrawing and CONFIG.ESPEnabled then
    fallbackGui = Instance.new("SurfaceGui")
    fallbackGui.Name = "MM2_ESP_Fallback"
    fallbackGui.Parent = CoreGui
    fallbackGui.Face = Enum.SurfaceOrientation.Up
    fallbackGui.AlwaysOnTop = true
    fallbackGui.SizingMode = Enum.AGuiSizingMode.Pixel
    fallbackGui.Scale = 1
    log("Fallback SurfaceGui criado em CoreGui.")
end

local function worldToScreen(position)
    local x, y, z = Camera:WorldToViewportPoint(position)
    return x, y, z
end

local function createDrawingForPlayer()
    local Drawing = game:GetService("ReplicatedFirst"):WaitForChild("Drawing")
    local box = Drawing.new("Square")
    box.Thickness = CONFIG.BoxThickness
    box.Filled = false
    box.Visible = false
    
    local name = Drawing.new("Text")
    name.TextSize = 14
    name.Center = true
    name.Outline = true
    name.OutlineColor = Color3.new(0,0,0)
    name.Visible = false
    
    return { Box = box, Name = name }
end

local function updateESP()
    if not CONFIG.ESPEnabled then return end
    
    local activePlayers = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
            activePlayers[plr] = true
        end
    end
    
    -- Limpar ESPs de jogadores que saíram
    for plr, data in pairs(espData) do
        if not activePlayers[plr] then
            if usingDrawing then
                data.Box.Visible = false
                data.Name.Visible = false
            end
            if data.Frame then
                data.Frame:Destroy()
            end
            espData[plr] = nil
        end
    end
    
    -- Atualizar/Criar ESPs
    for plr in pairs(activePlayers) do
        local char = plr.Character
        local head = char:FindFirstChild("Head")
        if not head then continue end
        
        local x, y, z = worldToScreen(head.Position)
        
        if z <= 0 then
            if espData[plr] then
                if usingDrawing then
                    espData[plr].Box.Visible = false
                    espData[plr].Name.Visible = false
                end
                if espData[plr].Frame then espData[plr].Frame.Visible = false end
            end
            continue
        end
        
        local role = getRole(char)
        local color = Colors[role] or Colors.Unknown
        
        if not espData[plr] then
            if usingDrawing then
                espData[plr] = createDrawingForPlayer()
            else
                local frame = Instance.new("Frame")
                frame.Name = "ESP_" .. plr.Name
                frame.Size = UDim2.fromOffset(100, 50)
                frame.BackgroundColor3 = color
                frame.BackgroundTransparency = 0.5
                frame.BorderSizePixel = 0
                frame.Position = UDim2.new(0, 0, 0, 0)
                frame.Visible = true
                frame.Parent = fallbackGui
                
                local label = Instance.new("TextLabel")
                label.Name = "Label"
                label.Size = UDim2.fromScale(1, 1)
                label.BackgroundTransparency = 1
                label.Text = plr.Name .. " [" .. role .. "]"
                label.TextColor3 = Color3.new(1,1,1)
                label.TextScaled = true
                label.Font = Enum.Font.GothamBold
                label.Parent = frame
                
                espData[plr] = { Frame = frame, Label = label }
            end
        end
        
        local data = espData[plr]
        
        if usingDrawing then
            local dist = (Camera.CFrame.Position - head.Position).Magnitude
            local scale = 50 / dist
            local size = 1.5 * scale
            
            data.Box.Visible = true
            data.Box.Position = Vector2.new(x - size, y - size)
            data.Box.Size = Vector2.new(size * 2, size * 2)
            data.Box.Color = color
            
            data.Name.Visible = true
            data.Name.Text = plr.Name .. " [" .. role .. "]"
            data.Name.Position = Vector2.new(x, y - size - 20)
            data.Name.Color = color
        else
            data.Frame.Position = UDim2.new(0, x - 50, 0, y - 25)
            data.Frame.Visible = true
            data.Label.Text = plr.Name .. " [" .. role .. "]"
            data.Frame.BackgroundColor3 = color
        end
    end
end

-- 5. MAIN LOOP
RunService.RenderStepped:Connect(function()
    task.spawn(function()
        updateESP()
    end)
end)

log("Script Carregado. Silent: " .. CONFIG.SilentEnabled .. " | ESP: " .. CONFIG.ESPEnabled .. " | Drawing: " .. usingDrawing)

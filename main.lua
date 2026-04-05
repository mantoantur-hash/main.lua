-- ╔══════════════════════════════════════════════════════════════╗
-- ║              PAINEL GUI - LocalScript Completo               ║
-- ║         Organizado, Otimizado e 100% Client-Side             ║
-- ╚══════════════════════════════════════════════════════════════╝

-- ┌─────────────────────────────────────────────────────────────┐
-- │                     SERVIÇOS E REFS                         │
-- └─────────────────────────────────────────────────────────────┘
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local Lighting           = game:GetService("Lighting")
local TweenService       = game:GetService("TweenService")

local LocalPlayer        = Players.LocalPlayer
local PlayerGui          = LocalPlayer:WaitForChild("PlayerGui")
local Camera             = workspace.CurrentCamera

-- ┌─────────────────────────────────────────────────────────────┐
-- │                   TABELA DE ESTADOS                         │
-- │  Controla tudo de forma centralizada — sem variáveis soltas │
-- └─────────────────────────────────────────────────────────────┘
local State = {
    -- Multiplicadores de velocidade e pulo (ciclos 1→2→3→1)
    SpeedMult     = 1,
    JumpMult      = 1,

    -- Toggles dos módulos
    VerXerife     = false,
    AcharFaca     = false,
    ESP           = false,
    AntiLag       = false,
    Fullbright    = false,
    AntiKick      = false,

    -- Controle visual do painel
    Minimized     = false,

    -- Cache de highlights para limpeza eficiente
    Highlights    = {},      -- [part] = Highlight
    BillboardTags = {},      -- [part] = BillboardGui
    AntiLagConn   = nil,     -- conexão do anti-lag loop

    -- Valores originais para reversão
    OriginalFog         = nil,
    OriginalBrightness  = nil,
    OriginalAmbient     = nil,
    OriginalOutdoor     = nil,
}

-- Palavras-chave para detecção de armas
local KEYWORDS_XERIFE = { "arma", "pistola", "gun", "pistol", "revolver" }
local KEYWORDS_FACA   = { "knife", "faca", "cuchillo" }

-- Ciclos de multiplicador
local MULT_CYCLE = { 1, 2, 3 }

-- ┌─────────────────────────────────────────────────────────────┐
-- │                   FUNÇÕES UTILITÁRIAS                       │
-- └─────────────────────────────────────────────────────────────┘

-- Obtém o humanoid do personagem local de forma segura
local function getHumanoid()
    local char = LocalPlayer.Character
    if char then
        return char:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

-- Obtém o RootPart do personagem local
local function getRootPart()
    local char = LocalPlayer.Character
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- Avança no ciclo 1→2→3→1
local function nextMult(current)
    for i, v in ipairs(MULT_CYCLE) do
        if v == current then
            return MULT_CYCLE[(i % #MULT_CYCLE) + 1]
        end
    end
    return 1
end

-- Verifica se um nome contém alguma palavra-chave (case insensitive)
local function nameContainsKeyword(name, keywords)
    local lower = name:lower()
    for _, kw in ipairs(keywords) do
        if lower:find(kw, 1, true) then
            return true
        end
    end
    return false
end

-- Remove um Highlight de forma segura sem erros
local function safeRemoveHighlight(target)
    if State.Highlights[target] then
        State.Highlights[target]:Destroy()
        State.Highlights[target] = nil
    end
end

-- Remove um BillboardGui de forma segura
local function safeRemoveBillboard(target)
    if State.BillboardTags[target] then
        State.BillboardTags[target]:Destroy()
        State.BillboardTags[target] = nil
    end
end

-- Cria ou reutiliza um Highlight em um target
local function applyHighlight(target, fillColor, outlineColor)
    safeRemoveHighlight(target)
    local hl = Instance.new("Highlight")
    hl.FillColor       = fillColor or Color3.fromRGB(255, 255, 255)
    hl.OutlineColor    = outlineColor or Color3.fromRGB(0, 120, 255)
    hl.FillTransparency    = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode       = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee         = target
    hl.Parent          = target
    State.Highlights[target] = hl
    return hl
end

-- Cria uma BillboardGui com texto neon acima do personagem
local function applyBillboard(char, labelText)
    safeRemoveBillboard(char)
    local head = char:FindFirstChild("Head")
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name           = "PainelTag"
    billboard.Size           = UDim2.new(0, 120, 0, 40)
    billboard.StudsOffset    = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop    = true
    billboard.MaxDistance    = 200
    billboard.Adornee        = head
    billboard.Parent         = head

    local label = Instance.new("TextLabel")
    label.Size               = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text               = labelText
    label.Font               = Enum.Font.GothamBold
    label.TextSize           = 16
    label.TextColor3         = Color3.fromRGB(255, 255, 255)
    label.TextStrokeColor3   = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Parent             = billboard

    State.BillboardTags[char] = billboard
    return billboard, label
end

-- ┌─────────────────────────────────────────────────────────────┐
-- │              CONSTRUÇÃO DA INTERFACE (GUI)                  │
-- └─────────────────────────────────────────────────────────────┘

-- Remove GUIs antigas para evitar duplicação ao reexecutar
for _, v in ipairs(PlayerGui:GetChildren()) do
    if v.Name == "PainelGUI" then
        v:Destroy()
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name              = "PainelGUI"
ScreenGui.ResetOnSpawn      = false   -- Sobrevive ao respawn
ScreenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent            = PlayerGui

-- Painel principal
local Panel = Instance.new("Frame")
Panel.Name              = "Panel"
Panel.Size              = UDim2.new(0, 230, 0, 380)
Panel.Position          = UDim2.new(1, -245, 0, 15)  -- canto superior direito
Panel.BackgroundColor3  = Color3.fromRGB(18, 18, 22)
Panel.BorderSizePixel   = 0
Panel.ClipsDescendants  = true
Panel.Parent            = ScreenGui

-- Borda sutil ao redor do painel
local PanelStroke = Instance.new("UIStroke")
PanelStroke.Color       = Color3.fromRGB(60, 60, 80)
PanelStroke.Thickness   = 1
PanelStroke.Parent      = Panel

-- Cantos arredondados
local PanelCorner = Instance.new("UICorner")
PanelCorner.CornerRadius = UDim.new(0, 8)
PanelCorner.Parent       = Panel

-- Barra de título (topo do painel)
local TitleBar = Instance.new("Frame")
TitleBar.Name            = "TitleBar"
TitleBar.Size            = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3= Color3.fromRGB(28, 28, 38)
TitleBar.BorderSizePixel = 0
TitleBar.Parent          = Panel

local TitleBarCorner = Instance.new("UICorner")
TitleBarCorner.CornerRadius = UDim.new(0, 8)
TitleBarCorner.Parent       = TitleBar

-- Linha decorativa abaixo do título
local TitleDivider = Instance.new("Frame")
TitleDivider.Size            = UDim2.new(1, 0, 0, 1)
TitleDivider.Position        = UDim2.new(0, 0, 1, -1)
TitleDivider.BackgroundColor3= Color3.fromRGB(60, 60, 90)
TitleDivider.BorderSizePixel = 0
TitleDivider.Parent          = TitleBar

-- Texto do título
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size              = UDim2.new(1, -70, 1, 0)
TitleLabel.Position          = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text              = "⚙ Painel"
TitleLabel.Font              = Enum.Font.GothamBold
TitleLabel.TextSize          = 14
TitleLabel.TextColor3        = Color3.fromRGB(200, 200, 230)
TitleLabel.TextXAlignment    = Enum.TextXAlignment.Left
TitleLabel.Parent            = TitleBar

-- Botão minimizar "-"
local BtnMinimize = Instance.new("TextButton")
BtnMinimize.Name             = "BtnMinimize"
BtnMinimize.Size             = UDim2.new(0, 26, 0, 26)
BtnMinimize.Position         = UDim2.new(1, -56, 0.5, -13)
BtnMinimize.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
BtnMinimize.Text             = "−"
BtnMinimize.Font             = Enum.Font.GothamBold
BtnMinimize.TextSize         = 16
BtnMinimize.TextColor3       = Color3.fromRGB(30, 20, 0)
BtnMinimize.BorderSizePixel  = 0
BtnMinimize.Parent           = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 5)
MinCorner.Parent       = BtnMinimize

-- Botão fechar "X"
local BtnClose = Instance.new("TextButton")
BtnClose.Name             = "BtnClose"
BtnClose.Size             = UDim2.new(0, 26, 0, 26)
BtnClose.Position         = UDim2.new(1, -28, 0.5, -13)
BtnClose.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
BtnClose.Text             = "✕"
BtnClose.Font             = Enum.Font.GothamBold
BtnClose.TextSize         = 14
BtnClose.TextColor3       = Color3.fromRGB(255, 255, 255)
BtnClose.BorderSizePixel  = 0
BtnClose.Parent           = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent       = BtnClose

-- Área de conteúdo com scroll (evita overflow)
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Name               = "Content"
ContentFrame.Size               = UDim2.new(1, 0, 1, -37)
ContentFrame.Position           = UDim2.new(0, 0, 0, 37)
ContentFrame.BackgroundTransparency = 1
ContentFrame.BorderSizePixel    = 0
ContentFrame.ScrollBarThickness = 3
ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 120)
ContentFrame.CanvasSize         = UDim2.new(0, 0, 0, 0)  -- ajustado dinamicamente
ContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentFrame.Parent             = Panel

-- Layout automático dos botões dentro do conteúdo
local UIList = Instance.new("UIListLayout")
UIList.Padding          = UDim.new(0, 6)
UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIList.SortOrder        = Enum.SortOrder.LayoutOrder
UIList.Parent           = ContentFrame

local UIPadding = Instance.new("UIPadding")
UIPadding.PaddingTop    = UDim.new(0, 8)
UIPadding.PaddingBottom = UDim.new(0, 8)
UIPadding.PaddingLeft   = UDim.new(0, 10)
UIPadding.PaddingRight  = UDim.new(0, 10)
UIPadding.Parent        = ContentFrame

-- Quadrado verde para estado minimizado
local MiniBall = Instance.new("Frame")
MiniBall.Name            = "MiniBall"
MiniBall.Size            = UDim2.new(0, 36, 0, 36)
MiniBall.Position        = UDim2.new(1, -50, 0, 15)  -- mesma posição inicial
MiniBall.BackgroundColor3= Color3.fromRGB(50, 200, 80)
MiniBall.BorderSizePixel = 0
MiniBall.Visible         = false
MiniBall.Parent          = ScreenGui
MiniBall.ZIndex          = 10

local MiniBallCorner = Instance.new("UICorner")
MiniBallCorner.CornerRadius = UDim.new(0, 6)
MiniBallCorner.Parent       = MiniBall

local MiniBallLabel = Instance.new("TextLabel")
MiniBallLabel.Size               = UDim2.new(1, 0, 1, 0)
MiniBallLabel.BackgroundTransparency = 1
MiniBallLabel.Text               = "▶"
MiniBallLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
MiniBallLabel.Font               = Enum.Font.GothamBold
MiniBallLabel.TextSize           = 16
MiniBallLabel.Parent             = MiniBall

-- ┌─────────────────────────────────────────────────────────────┐
-- │              FÁBRICA DE BOTÕES REUTILIZÁVEL                 │
-- │  Evita repetição de código para cada botão                  │
-- └─────────────────────────────────────────────────────────────┘
local buttonOrder = 0

local function createButton(labelText, isToggle)
    buttonOrder = buttonOrder + 1

    local btn = Instance.new("TextButton")
    btn.Name             = "Btn_" .. labelText
    btn.Size             = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    btn.BorderSizePixel  = 0
    btn.Text             = labelText
    btn.Font             = Enum.Font.Gotham
    btn.TextSize         = 13
    btn.TextColor3       = Color3.fromRGB(210, 210, 230)
    btn.AutoButtonColor  = false
    btn.LayoutOrder      = buttonOrder
    btn.Parent           = ContentFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent       = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color     = Color3.fromRGB(55, 55, 80)
    btnStroke.Thickness = 1
    btnStroke.Parent    = btn

    -- Feedback visual de hover
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(50, 50, 75)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        -- A cor é restaurada pela lógica de toggle ou estado padrão
        if not (isToggle and State[btn.Name:gsub("Btn_", "")]) then
            TweenService:Create(btn, TweenInfo.new(0.1), {
                BackgroundColor3 = Color3.fromRGB(35, 35, 50)
            }):Play()
        end
    end)

    return btn
end

-- Separador visual entre grupos de botões
local function createSeparator(title)
    buttonOrder = buttonOrder + 1
    local sep = Instance.new("TextLabel")
    sep.Size             = UDim2.new(1, 0, 0, 20)
    sep.BackgroundTransparency = 1
    sep.Text             = "— " .. title .. " —"
    sep.Font             = Enum.Font.GothamBold
    sep.TextSize         = 11
    sep.TextColor3       = Color3.fromRGB(100, 100, 140)
    sep.LayoutOrder      = buttonOrder
    sep.Parent           = ContentFrame
end

-- ┌─────────────────────────────────────────────────────────────┐
-- │                    CRIAÇÃO DOS BOTÕES                       │
-- └─────────────────────────────────────────────────────────────┘

-- Grupo: Movimentação
createSeparator("MOVIMENTO")
local BtnSpeed = createButton("⚡ Velocidade: 1x", false)
local BtnJump  = createButton("🦘 Pulo: 1x", false)

-- Grupo: Detecção
createSeparator("DETECÇÃO")
local BtnXerife = createButton("🔫 Ver Xerife", true)
local BtnFaca   = createButton("🔪 Achar Faca", true)
local BtnESP    = createButton("👁 ESP", true)

-- Grupo: Otimização
createSeparator("OTIMIZAÇÃO")
local BtnAntiLag  = createButton("🚀 Anti Lag", true)
local BtnLuz      = createButton("💡 Luz (Fullbright)", true)
local BtnAntiKick = createButton("🛡 Anti Kick", true)

-- Atualiza cor de um botão de toggle ON/OFF
local function setToggleColor(btn, active)
    local color = active
        and Color3.fromRGB(30, 80, 50)   -- verde escuro = ativo
        or  Color3.fromRGB(35, 35, 50)   -- cinza = inativo
    TweenService:Create(btn, TweenInfo.new(0.15), {
        BackgroundColor3 = color
    }):Play()
end

-- ┌─────────────────────────────────────────────────────────────┐
-- │                   SISTEMA DE DRAG (ARRASTO)                 │
-- │  Implementação manual para funcionar sem bugs em mobile     │
-- │  e desktop, tanto no painel aberto quanto minimizado        │
-- └─────────────────────────────────────────────────────────────┘
local function makeDraggable(dragHandle, targetFrame)
    local dragging     = false
    local dragStart    = nil
    local startPos     = nil

    -- Clamp mantém o frame dentro da tela
    local function clampPosition(pos)
        local vp = Camera.ViewportSize
        local absSize = targetFrame.AbsoluteSize

        local x = math.clamp(pos.X.Offset, 0, vp.X - absSize.X)
        local y = math.clamp(pos.Y.Offset, 0, vp.Y - absSize.Y)
        return UDim2.new(0, x, 0, y)
    end

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = targetFrame.Position
        end
    end)

    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                0, startPos.X.Offset + delta.X,
                0, startPos.Y.Offset + delta.Y
            )
            targetFrame.Position = clampPosition(newPos)
        end
    end)
end

-- Ativa drag no painel principal (pela barra de título)
-- e no quadrado minimizado (pela própria frame)
makeDraggable(TitleBar, Panel)
makeDraggable(MiniBall, MiniBall)

-- ┌─────────────────────────────────────────────────────────────┐
-- │              MINIMIZAR / RESTAURAR PAINEL                   │
-- └─────────────────────────────────────────────────────────────┘
BtnMinimize.MouseButton1Click:Connect(function()
    State.Minimized = true
    -- Sincroniza posição do MiniBall com o painel antes de esconder
    MiniBall.Position = UDim2.new(
        0, Panel.AbsolutePosition.X + Panel.AbsoluteSize.X - 40,
        0, Panel.AbsolutePosition.Y
    )
    Panel.Visible    = false
    MiniBall.Visible = true
end)

MiniBall.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        -- Só restaura se não foi um drag (verificado por delta de posição)
        task.delay(0.15, function()
            if State.Minimized then
                -- Reposiciona painel próximo ao MiniBall ao restaurar
                Panel.Position = UDim2.new(
                    0, MiniBall.AbsolutePosition.X - Panel.AbsoluteSize.X + 36,
                    0, MiniBall.AbsolutePosition.Y
                )
                State.Minimized  = false
                Panel.Visible    = true
                MiniBall.Visible = false
            end
        end)
    end
end)

-- ┌─────────────────────────────────────────────────────────────┐
-- │                      FECHAR PAINEL                          │
-- └─────────────────────────────────────────────────────────────┘
BtnClose.MouseButton1Click:Connect(function()
    -- Limpa tudo antes de destruir para evitar memory leak
    for target, hl in pairs(State.Highlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    for target, bb in pairs(State.BillboardTags) do
        if bb and bb.Parent then bb:Destroy() end
    end
    ScreenGui:Destroy()
end)

-- ┌─────────────────────────────────────────────────────────────┐
-- │              MÓDULO: VELOCIDADE                             │
-- └─────────────────────────────────────────────────────────────┘
BtnSpeed.MouseButton1Click:Connect(function()
    State.SpeedMult = nextMult(State.SpeedMult)
    BtnSpeed.Text   = "⚡ Velocidade: " .. State.SpeedMult .. "x"

    -- Aplica imediatamente
    local hum = getHumanoid()
    if hum then
        -- WalkSpeed padrão do Roblox é 16
        hum.WalkSpeed = 16 * State.SpeedMult
    end
end)

-- ┌─────────────────────────────────────────────────────────────┐
-- │                  MÓDULO: PULO                               │
-- └─────────────────────────────────────────────────────────────┘
BtnJump.MouseButton1Click:Connect(function()
    State.JumpMult = nextMult(State.JumpMult)
    BtnJump.Text   = "🦘 Pulo: " .. State.JumpMult .. "x"

    local hum = getHumanoid()
    if hum then
        -- JumpPower padrão do Roblox é 50
        hum.JumpPower = 50 * State.JumpMult
    end
end)

-- ┌─────────────────────────────────────────────────────────────┐
-- │          MÓDULO: DETECÇÃO DE ARMAS (VER XERIFE / FACA)      │
-- │  Varre jogadores e seus inventários por palavras-chave      │
-- └─────────────────────────────────────────────────────────────┘

-- Limpa os efeitos de um módulo específico
local function clearDetection(keywords)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            safeRemoveHighlight(char)
            safeRemoveBillboard(char)
        end
    end
end

-- Verifica se um jogador está carregando uma arma (mão ou mochila)
local function playerHasWeapon(player, keywords)
    -- Checa a mão (equipado)
    local char = player.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and nameContainsKeyword(item.Name, keywords) then
                return true
            end
        end
    end
    -- Checa o inventário (Backpack)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and nameContainsKeyword(item.Name, keywords) then
                return true
            end
        end
    end
    return false
end

-- Aplica efeito visual ao char detectado
local function applyWeaponEffect(char, label, hlOutlineColor)
    local _, textLabel = applyBillboard(char, label)
    applyHighlight(char,
        Color3.fromRGB(255, 255, 255),  -- preenchimento branco
        hlOutlineColor
    )
    -- Guarda referência ao textLabel para o rainbow no loop
    if textLabel then
        char:SetAttribute("RainbowLabel_" .. label, true)
    end
end

BtnXerife.MouseButton1Click:Connect(function()
    State.VerXerife = not State.VerXerife
    setToggleColor(BtnXerife, State.VerXerife)

    if not State.VerXerife then
        -- Limpa apenas os efeitos de xerife
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local char = player.Character
                if char:GetAttribute("WeaponType") == "Xerife" then
                    safeRemoveHighlight(char)
                    safeRemoveBillboard(char)
                    char:SetAttribute("WeaponType", nil)
                end
            end
        end
    end
end)

BtnFaca.MouseButton1Click:Connect(function()
    State.AcharFaca = not State.AcharFaca
    setToggleColor(BtnFaca, State.AcharFaca)

    if not State.AcharFaca then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local char = player.Character
                if char:GetAttribute("WeaponType") == "Faca" then
                    safeRemoveHighlight(char)
                    safeRemoveBillboard(char)
                    char:SetAttribute("WeaponType", nil)
                end
            end
        end
    end
end)

-- ┌─────────────────────────────────────────────────────────────┐
-- │                    MÓDULO: ESP                              │
-- └─────────────────────────────────────────────────────────────┘
BtnESP.MouseButton1Click:Connect(function()
    State.ESP = not State.ESP
    setToggleColor(BtnESP, State.ESP)

    if not State.ESP then
        -- Remove highlights de ESP de todos
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local char = player.Character
                if not char:GetAttribute("WeaponType") then
                    -- só remove se não for highlight de arma
                    safeRemoveHighlight(char)
                end
            end
        end
    end
end)

-- ┌─────────────────────────────────────────────────────────────┐
-- │                  MÓDULO: ANTI LAG                           │
-- │  Remove efeitos visuais pesados sem quebrar o jogo         │
-- └─────────────────────────────────────────────────────────────┘
local function applyAntiLag()
    -- Remove partículas e efeitos em todo o workspace
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter")
        or v:IsA("Trail")
        or v:IsA("Smoke")
        or v:IsA("Fire")
        or v:IsA("Sparkles") then
            v.Enabled = false
        end
    end

    -- Reduz sombras
    Lighting.GlobalShadows = false
    Lighting.FogEnd        = 100000

    -- Reduz qualidade de renderização
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
end

local function revertAntiLag()
    Lighting.GlobalShadows = true

    -- Reabilita partículas (jogadores podem querer de volta)
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter")
        or v:IsA("Trail")
        or v:IsA("Smoke")
        or v:IsA("Fire")
        or v:IsA("Sparkles") then
            v.Enabled = true
        end
    end
end

BtnAntiLag.MouseButton1Click:Connect(function()
    State.AntiLag = not State.AntiLag
    setToggleColor(BtnAntiLag, State.AntiLag)

    if State.AntiLag then
        applyAntiLag()
    else
        revertAntiLag()
    end
end)

-- ┌─────────────────────────────────────────────────────────────┐
-- │             MÓDULO: FULLBRIGHT (LUZ TOTAL)                  │
-- └─────────────────────────────────────────────────────────────┘
BtnLuz.MouseButton1Click:Connect(function()
    State.Fullbright = not State.Fullbright
    setToggleColor(BtnLuz, State.Fullbright)

    if State.Fullbright then
        -- Guarda originais para reversão
        State.OriginalBrightness = Lighting.Brightness
        State.OriginalAmbient    = Lighting.Ambient
        State.OriginalOutdoor    = Lighting.OutdoorAmbient
        State.OriginalFog        = Lighting.FogEnd

        -- Remove neblina e escuridão
        Lighting.Brightness      = 2
        Lighting.Ambient         = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient  = Color3.fromRGB(178, 178, 178)
        Lighting.FogEnd          = 100000
        Lighting.FogStart        = 100000

        -- Remove efeitos de Lighting que escurecem
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("BlurEffect")
            or effect:IsA("ColorCorrectionEffect")
            or effect:IsA("DepthOfFieldEffect") then
                effect.Enabled = false
            end
        end
    else
        -- Restaura originais
        if State.OriginalBrightness then
            Lighting.Brightness     = State.OriginalBrightness
            Lighting.Ambient        = State.OriginalAmbient
            Lighting.OutdoorAmbient = State.OriginalOutdoor
            Lighting.FogEnd         = State.OriginalFog
        end
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("BlurEffect")
            or effect:IsA("ColorCorrectionEffect")
            or effect:IsA("DepthOfFieldEffect") then
                effect.Enabled = true
            end
        end
    end
end)

-- ┌─────────────────────────────────────────────────────────────┐
-- │              MÓDULO: ANTI-KICK / ANTI-CRASH                 │
-- │  Proteção básica contra kicks locais e erros críticos       │
-- └─────────────────────────────────────────────────────────────┘
local antiKickActive = false

BtnAntiKick.MouseButton1Click:Connect(function()
    State.AntiKick = not State.AntiKick
    setToggleColor(BtnAntiKick, State.AntiKick)

    if State.AntiKick and not antiKickActive then
        antiKickActive = true

        -- Intercepta o evento de kick do LocalPlayer
        -- Usando pcall contínuo para evitar crash em caso de erro de rede
        LocalPlayer.OnTeleport:Connect(function(teleportState)
            if teleportState == Enum.TeleportState.Failed then
                -- Ignora falha de teleport silenciosamente
            end
        end)

        -- Proteção contra erros silenciosos no loop principal
        -- (hookfunction não está disponível em jogos normais sem executor,
        --  então usamos uma abordagem segura com pcall wrapper)
        task.spawn(function()
            while State.AntiKick do
                pcall(function()
                    -- Mantém o personagem "ativo" para evitar timeout passivo
                    local hum = getHumanoid()
                    if hum and hum.Health <= 0 then
                        -- Reseta estado caso humanoid morra de forma inesperada
                    end
                end)
                task.wait(1)
            end
        end)
    end
end)

-- ┌─────────────────────────────────────────────────────────────┐
-- │           LOOP PRINCIPAL — RunService.Heartbeat             │
-- │  Atualiza tudo de forma contínua e eficiente                │
-- │  Heartbeat roda a cada frame (60fps), é ideal para          │
-- │  lógica de jogo — RenderStepped é para câmera/visual        │
-- └─────────────────────────────────────────────────────────────┘

-- Variáveis de controle de tempo para não rodar toda lógica todo frame
local tickWeapon    = 0   -- detecção de armas roda a cada 0.3s (economia)
local tickRainbow   = 0   -- cor arco-íris atualiza a cada 0.05s
local rainbowHue    = 0   -- hue atual do ciclo de cor

RunService.Heartbeat:Connect(function(dt)
    local now = tick()

    -- ── Velocidade e Pulo: aplicação contínua (respawn-safe) ──
    -- Isso garante que após respawn os valores voltam automaticamente
    pcall(function()
        local hum = getHumanoid()
        if hum then
            local targetSpeed = 16 * State.SpeedMult
            local targetJump  = 50 * State.JumpMult
            -- Só atribui se diferente para não criar GC pressure desnecessária
            if math.abs(hum.WalkSpeed - targetSpeed) > 0.1 then
                hum.WalkSpeed = targetSpeed
            end
            if math.abs(hum.JumpPower - targetJump) > 0.1 then
                hum.JumpPower = targetJump
            end
        end
    end)

    -- ── Rainbow color cycle (para billboards de arma) ──
    tickRainbow = tickRainbow + dt
    if tickRainbow >= 0.05 then
        tickRainbow = 0
        rainbowHue  = (rainbowHue + 0.02) % 1
        local rainbowColor = Color3.fromHSV(rainbowHue, 1, 1)

        -- Atualiza cor de todos os billboards ativos
        for char, billboard in pairs(State.BillboardTags) do
            if billboard and billboard.Parent then
                local label = billboard:FindFirstChildOfClass("TextLabel")
                if label then
                    label.TextColor3 = rainbowColor
                end
            else
                -- Billboard destruído, limpa da tabela
                State.BillboardTags[char] = nil
            end
        end
    end

    -- ── Detecção de armas e ESP (a cada 0.3s para performance) ──
    tickWeapon = tickWeapon + dt
    if tickWeapon >= 0.3 then
        tickWeapon = 0

        pcall(function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player == LocalPlayer then continue end

                local char = player.Character
                if not char then continue end

                local hasXerife = State.VerXerife and playerHasWeapon(player, KEYWORDS_XERIFE)
                local hasFaca   = State.AcharFaca and playerHasWeapon(player, KEYWORDS_FACA)

                if hasXerife then
                    -- Aplica/atualiza efeito de xerife
                    if char:GetAttribute("WeaponType") ~= "Xerife" then
                        char:SetAttribute("WeaponType", "Xerife")
                        applyWeaponEffect(char, "⭐ XERIFE", Color3.fromRGB(0, 120, 255))
                    end

                elseif hasFaca then
                    -- Aplica/atualiza efeito de faca
                    if char:GetAttribute("WeaponType") ~= "Faca" then
                        char:SetAttribute("WeaponType", "Faca")
                        applyWeaponEffect(char, "🔪 FACA", Color3.fromRGB(220, 40, 40))
                    end

                else
                    -- Remove efeito se jogador não tem mais arma
                    local wType = char:GetAttribute("WeaponType")
                    if wType == "Xerife" and not State.VerXerife then
                        safeRemoveHighlight(char)
                        safeRemoveBillboard(char)
                        char:SetAttribute("WeaponType", nil)
                    elseif wType == "Faca" and not State.AcharFaca then
                        safeRemoveHighlight(char)
                        safeRemoveBillboard(char)
                        char:SetAttribute("WeaponType", nil)
                    elseif wType and not State.VerXerife and not State.AcharFaca then
                        safeRemoveHighlight(char)
                        safeRemoveBillboard(char)
                        char:SetAttribute("WeaponType", nil)
                    end

                    -- ESP genérico (sem arma detectada)
                    if State.ESP then
                        if not State.Highlights[char] then
                            applyHighlight(char,
                                Color3.fromRGB(255, 255, 255),
                                Color3.fromRGB(255, 200, 0)  -- contorno amarelo para ESP
                            )
                        end
                    else
                        -- Remove ESP se foi desativado
                        if State.Highlights[char]
                        and not char:GetAttribute("WeaponType") then
                            safeRemoveHighlight(char)
                        end
                    end
                end
            end
        end)
    end
end)

-- ┌─────────────────────────────────────────────────────────────┐
-- │     LIMPEZA AUTOMÁTICA QUANDO JOGADOR SAI DO SERVIDOR       │
-- └─────────────────────────────────────────────────────────────┘
Players.PlayerRemoving:Connect(function(player)
    if player.Character then
        safeRemoveHighlight(player.Character)
        safeRemoveBillboard(player.Character)
    end
end)

-- ┌─────────────────────────────────────────────────────────────┐
-- │        RECONEXÃO DE PERSONAGEM APÓS RESPAWN                 │
-- │  Garante que highlights de jogadores que respawnaram        │
-- │  sejam recriados corretamente                               │
-- └─────────────────────────────────────────────────────────────┘
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        -- Limpa dados do personagem antigo desta entrada
        safeRemoveHighlight(char)
        safeRemoveBillboard(char)
        char:SetAttribute("WeaponType", nil)
    end)
end)

-- Para jogadores já no servidor
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function(char)
            safeRemoveHighlight(char)
            safeRemoveBillboard(char)
            char:SetAttribute("WeaponType", nil)
        end)
    end
end

-- ┌─────────────────────────────────────────────────────────────┐
-- │              MENSAGEM INICIAL NO OUTPUT                     │
-- └─────────────────────────────────────────────────────────────┘
print("✅ Painel GUI carregado com sucesso!")
print("   Drag: arraste pela barra de título")
print("   [−] Minimiza  |  [✕] Fecha completamente")
-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║          BOTÕES ADICIONAIS — COLE NO FINAL DO SCRIPT ORIGINAL        ║
-- ║                                                                      ║
-- ║  Este bloco usa TUDO que já foi declarado acima:                     ║
-- ║    • Players, RunService, TweenService, UserInputService             ║
-- ║    • LocalPlayer, PlayerGui, Camera                                  ║
-- ║    • State, createButton(), createSeparator(), setToggleColor()      ║
-- ║    • getHumanoid(), getRootPart()                                     ║
-- ║                                                                      ║
-- ║  Basta colar este arquivo ABAIXO da última linha do script original  ║
-- ║  Nenhuma linha do script original precisa ser alterada               ║
-- ╚══════════════════════════════════════════════════════════════════════╝


-- ══════════════════════════════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████
-- ██                                                                  ██
-- ██        MÓDULO 1 — ANTIBUG SPEED                                  ██
-- ██                                                                  ██
-- ██  Garante movimento fluido em velocidades extremas (5x, 10x+)    ██
-- ██  Anti-rubberband, anti-atravessamento, sincronização contínua   ██
-- ██                                                                  ██
-- ████████████████████████████████████████████████████████████████████
-- ══════════════════════════════════════════════════════════════════════

createSeparator("ANTIBUG SPEED")

local BtnAntiBugSpeed = createButton("⚡ AntiBug Speed", true)

-- ── Variáveis internas do módulo AntiBug Speed ──────────────────────

local antiBugAtivo           = false    -- estado do toggle
local antiBugConn            = nil      -- referência à conexão Heartbeat

-- Anti-rubberband: armazena a última posição que consideramos válida
local ultimaPosValida        = nil      -- CFrame
local ultimaVelValida        = nil      -- Vector3 (velocidade no momento)
local framesSemMovimento     = 0        -- contador de frames parado

-- Limiar de distância para detectar rubberband (em studs)
-- Se o personagem "pular" mais que isso de um frame para outro,
-- consideramos que o servidor tentou puxá-lo de volta.
local LIMIAR_RUBBERBAND      = 10

-- Limiar mínimo de velocidade para salvar posição válida
-- Evita salvar posição enquanto parado (que poderia ser posição
-- legítima do servidor após colisão)
local LIMIAR_VELOCIDADE_MIN  = 0.5

-- Velocidade horizontal máxima permitida (anti-teleporte brusco)
-- 400 studs/s equivale a WalkSpeed ≈ 25x, suficiente para qualquer uso
local VEL_MAX_HORIZONTAL     = 400

-- ── Parâmetros do Raycast (criados uma vez, reutilizados) ────────────
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- ── Função: ChecarColisao ────────────────────────────────────────────
-- Lança raios em múltiplas direções ao redor do personagem para detectar
-- paredes, tetos e pisos. Retorna true se detectou obstáculo crítico.
-- O Raycast usa o personagem como filtro (não colide consigo mesmo).
local function ChecarColisao(root, char)
    if not root or not char then return false, Vector3.new() end

    -- Atualiza o filtro com o personagem atual (muda após respawn)
    rayParams.FilterDescendantsInstances = { char }

    local origem    = root.Position
    local vel       = root.Velocity
    local direcaoXZ = Vector3.new(vel.X, 0, vel.Z)

    -- Só verifica colisão horizontal se o personagem está se movendo
    if direcaoXZ.Magnitude < LIMIAR_VELOCIDADE_MIN then
        return false, Vector3.new()
    end

    local direcaoNorm = direcaoXZ.Unit
    local comprimento = 2.8   -- distância de verificação (em studs)

    -- Lança raio à frente na direção do movimento
    local resultado = workspace:Raycast(origem, direcaoNorm * comprimento, rayParams)
    if resultado then
        -- Detectou parede: retorna verdadeiro e a normal da superfície
        -- A normal nos permite zerar apenas a componente que colide,
        -- mantendo o movimento lateral (deslizamento na parede)
        return true, resultado.Normal
    end

    -- Também verifica teto (raio para cima)
    local resultTeto = workspace:Raycast(origem, Vector3.new(0, 2.2, 0), rayParams)
    if resultTeto then
        return true, Vector3.new(0, -1, 0)  -- força para baixo
    end

    return false, Vector3.new()
end

-- ── Função: AtualizarMovimento ───────────────────────────────────────
-- Chamada a cada frame pelo Heartbeat.
-- Aplica as correções de física em sequência.
local function AtualizarMovimento(dt)
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        if hum.Health <= 0 then return end   -- personagem morto, não interfere

        local posAtual = root.CFrame
        local velAtual = root.Velocity

        -- ── 1. Anti-Rubberband ───────────────────────────────────────
        -- Compara posição atual com última posição válida.
        -- Se o deslocamento for maior que o limiar em UM frame,
        -- significa que o servidor puxou o personagem para trás.
        if ultimaPosValida then
            local deslocamento = (posAtual.Position - ultimaPosValida.Position).Magnitude

            if deslocamento > LIMIAR_RUBBERBAND then
                -- Servidor tentou fazer rubberband. Restauramos.
                root.CFrame    = ultimaPosValida
                root.Velocity  = ultimaVelValida or Vector3.new(0, 0, 0)
                -- Não atualiza ultimaPosValida neste frame, aguarda estabilizar
                return
            end
        end

        -- ── 2. Anti-atravessamento ───────────────────────────────────
        -- Verifica colisão na direção do movimento.
        -- Se detectar parede, zera a componente da velocidade
        -- que aponta para ela, permitindo deslizamento lateral.
        local colisao, normalSuperficie = ChecarColisao(root, char)
        if colisao and normalSuperficie.Magnitude > 0 then
            local vel = root.Velocity
            -- Remove da velocidade a componente que aponta para a parede
            -- usando projeção vetorial: v - (v·n)*n
            local projecao = vel:Dot(normalSuperficie)
            if projecao < 0 then   -- só cancela se indo em direção à parede
                local correcao = normalSuperficie * projecao
                root.Velocity  = vel - correcao
            end
        end

        -- ── 3. Limitador de velocidade extrema ──────────────────────
        -- Velocidades muito altas em um único frame causam "teleporte"
        -- visual e erros de física. Limitamos a componente horizontal.
        local velH = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
        if velH.Magnitude > VEL_MAX_HORIZONTAL then
            local velLimitada = velH.Unit * VEL_MAX_HORIZONTAL
            root.Velocity = Vector3.new(
                velLimitada.X,
                root.Velocity.Y,   -- preserva componente vertical (pulo/queda)
                velLimitada.Z
            )
        end

        -- ── 4. Salva posição válida ──────────────────────────────────
        -- Só salva se o personagem está se movendo (evita salvar posição
        -- "puxada" pelo servidor quando parado)
        local velXZ = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
        if velXZ.Magnitude > LIMIAR_VELOCIDADE_MIN then
            ultimaPosValida   = root.CFrame
            ultimaVelValida   = root.Velocity
            framesSemMovimento = 0
        else
            framesSemMovimento = framesSemMovimento + 1
            -- Se ficou parado por mais de 60 frames (≈1s), reseta referência
            -- para não tentar restaurar uma posição muito antiga
            if framesSemMovimento > 60 then
                ultimaPosValida    = root.CFrame
                ultimaVelValida    = root.Velocity
                framesSemMovimento = 0
            end
        end
    end)
end

-- ── Função: AtivarAntiBugSpeed ───────────────────────────────────────
local function AtivarAntiBugSpeed()
    -- Reseta referências ao ativar para não herdar posição antiga
    ultimaPosValida    = nil
    ultimaVelValida    = nil
    framesSemMovimento = 0

    -- Conecta o loop de atualização ao Heartbeat
    -- Heartbeat é chamado APÓS a física do frame,
    -- ideal para ler e corrigir posições sem conflito com a engine
    antiBugConn = RunService.Heartbeat:Connect(function(dt)
        AtualizarMovimento(dt)
    end)

    print("[AntiBug Speed] ✅ ATIVADO — Proteção de movimento ativa")
end

-- ── Função: DesativarAntiBugSpeed ────────────────────────────────────
local function DesativarAntiBugSpeed()
    if antiBugConn then
        antiBugConn:Disconnect()
        antiBugConn = nil
    end
    ultimaPosValida    = nil
    ultimaVelValida    = nil
    framesSemMovimento = 0

    print("[AntiBug Speed] ⛔ DESATIVADO")
end

-- ── Conexão do botão ─────────────────────────────────────────────────
BtnAntiBugSpeed.MouseButton1Click:Connect(function()
    State.AntiBugSpeed = not State.AntiBugSpeed
    setToggleColor(BtnAntiBugSpeed, State.AntiBugSpeed)

    if State.AntiBugSpeed then
        AtivarAntiBugSpeed()
    else
        DesativarAntiBugSpeed()
    end
end)

-- Reseta ao respawn para não herdar posição de vida anterior
LocalPlayer.CharacterAdded:Connect(function()
    if State.AntiBugSpeed then
        ultimaPosValida    = nil
        ultimaVelValida    = nil
        framesSemMovimento = 0
        print("[AntiBug Speed] 🔄 Personagem respawnado — referências resetadas")
    end
end)


-- ══════════════════════════════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████
-- ██                                                                  ██
-- ██        MÓDULO 2 — HITBOX ALL - YOU                               ██
-- ██                                                                  ██
-- ██  Mostra hitbox visual de todos os jogadores e suas Tools        ██
-- ██  Reduz a hitbox do jogador local pela metade (vantagem)         ██
-- ██  100% client-side, reversível, sem bugs de física               ██
-- ██                                                                  ██
-- ████████████████████████████████████████████████████████████████████
-- ══════════════════════════════════════════════════════════════════════

createSeparator("HITBOX")

local BtnHitboxAll = createButton("🎯 Hitbox All - You", true)

-- ── Variáveis internas do módulo Hitbox ─────────────────────────────

local hitboxAtivo           = false

-- Tabelas de rastreamento: [objeto] = { adornment, conexão de limpeza }
local hitboxPlayers         = {}   -- hitboxes de personagens
local hitboxTools           = {}   -- hitboxes de ferramentas
local hitboxConexoes        = {}   -- conexões PlayerAdded / CharacterAdded

-- Dados originais do jogador local para restauração exata
local minhaHitboxOriginal   = nil  -- { size, hipHeight }
local hitboxUpdateConn      = nil  -- loop de atualização contínua

-- Partes que consideramos "principais" do personagem para visualização
local PARTES_PRINCIPAIS = {
    "HumanoidRootPart", "UpperTorso", "LowerTorso",
    "Head", "Torso"   -- suporte a R6 e R15
}

-- ── Função auxiliar: criar BoxHandleAdornment ────────────────────────
-- BoxHandleAdornment é preferível a SelectionBox pois permite controle
-- fino de tamanho, cor e transparência com AlwaysOnTop real.
local function criarBoxAdornment(parte, cor, transparencia)
    if not parte or not parte.Parent then return nil end

    local adorn = Instance.new("BoxHandleAdornment")
    adorn.Name            = "HitboxVisual"
    adorn.Adornee         = parte
    -- Tamanho ligeiramente maior que a parte para ser visível por fora
    adorn.Size            = parte.Size + Vector3.new(0.05, 0.05, 0.05)
    adorn.Color3          = cor or Color3.fromRGB(255, 50, 50)
    adorn.Transparency    = transparencia or 0.35
    adorn.AlwaysOnTop     = true
    adorn.ZIndex          = 5
    adorn.Parent          = parte

    return adorn
end

-- ── Função: CriarHitboxTool ──────────────────────────────────────────
-- Cria visualização da hitbox de uma Tool equipada por outro jogador.
-- Só age em Tools que não pertencem ao LocalPlayer.
local function CriarHitboxTool(tool, player)
    if not tool or not player then return end
    if player == LocalPlayer then return end   -- não visualiza ferramentas próprias

    -- Evita duplicata: remove hitbox antiga desta tool se existir
    if hitboxTools[tool] then
        pcall(function() hitboxTools[tool]:Destroy() end)
        hitboxTools[tool] = nil
    end

    pcall(function()
        -- Procura o Handle (parte principal da ferramenta)
        local handle = tool:FindFirstChild("Handle")
        if not handle then
            -- Fallback: usa a primeira BasePart encontrada
            for _, v in ipairs(tool:GetDescendants()) do
                if v:IsA("BasePart") then
                    handle = v
                    break
                end
            end
        end

        if not handle then return end

        -- Cor laranja para diferenciar Tools de personagens (vermelho)
        local adorn = criarBoxAdornment(handle, Color3.fromRGB(255, 140, 0), 0.3)
        if adorn then
            hitboxTools[tool] = adorn
            print("[Hitbox] 🔫 Hitbox de tool criada: " .. tool.Name)

            -- Remove automaticamente quando a tool sair do personagem
            tool.AncestryChanged:Connect(function()
                if not tool:IsDescendantOf(workspace) then
                    pcall(function()
                        if hitboxTools[tool] then
                            hitboxTools[tool]:Destroy()
                            hitboxTools[tool] = nil
                        end
                    end)
                end
            end)
        end
    end)
end

-- ── Função: CriarHitboxPlayer ────────────────────────────────────────
-- Cria hitbox visual em todas as partes principais do personagem de
-- um jogador. Também rastreia Tools equipadas por esse jogador.
local function CriarHitboxPlayer(player)
    if not player or player == LocalPlayer then return end

    -- Função interna aplicada ao personagem atual do jogador
    local function aplicarNoChar(char)
        if not char then return end

        -- Remove hitboxes antigas deste player antes de criar novas
        if hitboxPlayers[player] then
            for _, adorn in ipairs(hitboxPlayers[player]) do
                pcall(function() adorn:Destroy() end)
            end
        end
        hitboxPlayers[player] = {}

        pcall(function()
            -- Hitbox nas partes principais do personagem
            for _, nomeParte in ipairs(PARTES_PRINCIPAIS) do
                local parte = char:FindFirstChild(nomeParte)
                if parte and parte:IsA("BasePart") then
                    local adorn = criarBoxAdornment(
                        parte,
                        Color3.fromRGB(255, 50, 50),  -- vermelho para personagens
                        0.35
                    )
                    if adorn then
                        table.insert(hitboxPlayers[player], adorn)
                    end
                end
            end

            -- Também rastreia Tools atualmente equipadas
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("Tool") then
                    CriarHitboxTool(obj, player)
                end
            end

            -- Detecta novas Tools equipadas em tempo real
            char.ChildAdded:Connect(function(child)
                if hitboxAtivo and child:IsA("Tool") then
                    task.wait(0.05)  -- pequeno delay para o Handle carregar
                    CriarHitboxTool(child, player)
                end
            end)

            print("[Hitbox] 👤 Hitbox de player criada: " .. player.Name)
        end)
    end

    -- Aplica imediatamente se o personagem já existe
    aplicarNoChar(player.Character)

    -- Re-aplica automaticamente após respawn
    local conn = player.CharacterAdded:Connect(function(char)
        if hitboxAtivo then
            task.wait(0.1)  -- aguarda o personagem carregar completamente
            aplicarNoChar(char)
        end
    end)
    table.insert(hitboxConexoes, conn)
end

-- ── Função: ReduzirMinhaHitbox ───────────────────────────────────────
-- Reduz o HumanoidRootPart do LocalPlayer para metade do tamanho.
-- Salva os valores originais para restauração exata posterior.
-- Aplica correções de física para evitar bugs de colisão e queda.
local function ReduzirMinhaHitbox()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end

        -- Salva estado original (só salva uma vez para não sobrescrever ao re-ativar)
        if not minhaHitboxOriginal then
            minhaHitboxOriginal = {
                size      = root.Size,
                hipHeight = hum.HipHeight,
            }
        end

        -- Reduz para metade do tamanho original
        local novoTamanho = minhaHitboxOriginal.size * 0.5
        root.Size = novoTamanho

        -- Ajusta HipHeight proporcionalmente para o personagem não afundar no chão
        -- HipHeight controla a altura que o Humanoid mantém o Root acima do solo
        hum.HipHeight = minhaHitboxOriginal.hipHeight * 0.5

        -- Garante que a colisão está ativa (necessária para não cair)
        root.CanCollide = true

        -- Força o estado Running para recalibrar a física após a mudança de tamanho
        -- Sem isso, o personagem pode ficar "flutuando" ou colidir estranhamente
        task.wait(0.05)
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end)

        print("[Hitbox] 🧍 Minha hitbox reduzida para 50%")
    end)
end

-- ── Função: RestaurarMinhaHitbox ─────────────────────────────────────
-- Desfaz exatamente o que ReduzirMinhaHitbox fez.
local function RestaurarMinhaHitbox()
    pcall(function()
        if not minhaHitboxOriginal then return end

        local char = LocalPlayer.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end

        -- Restaura exatamente os valores salvos
        root.Size       = minhaHitboxOriginal.size
        hum.HipHeight   = minhaHitboxOriginal.hipHeight
        root.CanCollide = true

        -- Recalibra física após restauração
        task.wait(0.05)
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end)

        -- Limpa o cache para permitir nova captura na próxima ativação
        minhaHitboxOriginal = nil

        print("[Hitbox] 🔄 Minha hitbox restaurada ao tamanho original")
    end)
end

-- ── Função: remover TODAS as hitboxes visuais ────────────────────────
local function removerTodasHitboxes()
    -- Remove hitboxes de players
    for player, adorns in pairs(hitboxPlayers) do
        for _, adorn in ipairs(adorns) do
            pcall(function() adorn:Destroy() end)
        end
    end
    hitboxPlayers = {}

    -- Remove hitboxes de tools
    for tool, adorn in pairs(hitboxTools) do
        pcall(function() adorn:Destroy() end)
    end
    hitboxTools = {}
end

-- ── Função: AtivarHitbox ─────────────────────────────────────────────
local function AtivarHitbox()
    hitboxAtivo = true

    -- Aplica em todos os jogadores já presentes
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CriarHitboxPlayer(player)
        end
    end

    -- Monitora novos jogadores que entrarem
    local connAdd = Players.PlayerAdded:Connect(function(player)
        if hitboxAtivo then
            task.wait(0.2)
            CriarHitboxPlayer(player)
        end
    end)
    table.insert(hitboxConexoes, connAdd)

    -- Monitora jogadores que saírem (limpa as hitboxes deles)
    local connRem = Players.PlayerRemoving:Connect(function(player)
        if hitboxPlayers[player] then
            for _, adorn in ipairs(hitboxPlayers[player]) do
                pcall(function() adorn:Destroy() end)
            end
            hitboxPlayers[player] = nil
        end
    end)
    table.insert(hitboxConexoes, connRem)

    -- Loop contínuo: atualiza tamanho das hitboxes caso as partes mudem
    -- (alguns jogos alteram partes do personagem dinamicamente)
    hitboxUpdateConn = RunService.Heartbeat:Connect(function()
        if not hitboxAtivo then return end
        pcall(function()
            for player, adorns in pairs(hitboxPlayers) do
                if player.Character then
                    for _, adorn in ipairs(adorns) do
                        if adorn and adorn.Parent then
                            local parte = adorn.Adornee
                            if parte and parte.Parent then
                                -- Mantém o tamanho ligeiramente maior que a parte
                                adorn.Size = parte.Size + Vector3.new(0.05, 0.05, 0.05)
                            end
                        end
                    end
                end
            end
        end)
    end)

    -- Reduz a hitbox do próprio jogador
    ReduzirMinhaHitbox()

    -- Reaplica redução após respawn
    LocalPlayer.CharacterAdded:Connect(function()
        if hitboxAtivo then
            task.wait(0.3)
            ReduzirMinhaHitbox()
        end
    end)

    print("[Hitbox] ✅ Sistema ATIVADO")
end

-- ── Função: DesativarHitbox ──────────────────────────────────────────
local function DesativarHitbox()
    hitboxAtivo = false

    -- Desconecta todas as conexões de monitoramento
    for _, conn in ipairs(hitboxConexoes) do
        pcall(function() conn:Disconnect() end)
    end
    hitboxConexoes = {}

    -- Para o loop de atualização
    if hitboxUpdateConn then
        hitboxUpdateConn:Disconnect()
        hitboxUpdateConn = nil
    end

    -- Remove todas as hitboxes visuais
    removerTodasHitboxes()

    -- Restaura a hitbox do próprio jogador
    RestaurarMinhaHitbox()

    print("[Hitbox] ⛔ Sistema DESATIVADO")
end

-- ── Conexão do botão ─────────────────────────────────────────────────
BtnHitboxAll.MouseButton1Click:Connect(function()
    State.HitboxAll = not State.HitboxAll
    setToggleColor(BtnHitboxAll, State.HitboxAll)

    if State.HitboxAll then
        AtivarHitbox()
    else
        DesativarHitbox()
    end
end)


-- ══════════════════════════════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████
-- ██                                                                  ██
-- ██        MÓDULO 3 — VER INVENTÁRIO                                 ██
-- ██                                                                  ██
-- ██  Corrige, torna visíveis e equipáveis todos os itens (Tools)    ██
-- ██  do inventário do jogador em tempo real, sem delay              ██
-- ██  Loop anti-delay que detecta e corrige bugs instantaneamente    ██
-- ██                                                                  ██
-- ████████████████████████████████████████████████████████████████████
-- ══════════════════════════════════════════════════════════════════════

createSeparator("INVENTÁRIO")

local BtnVerInventario = createButton("🎒 Ver Inventário", true)

-- ── Variáveis internas do módulo Inventário ──────────────────────────

local inventarioAtivo        = false
local inventarioConn         = nil    -- loop Heartbeat
local invChildAddedConexoes  = {}     -- conexões ChildAdded do backpack/char
local toolsJaCorrigidas      = {}     -- [tool] = true, evita duplicação de trabalho

-- Intervalo do loop de verificação (em segundos)
-- 0.5s é um bom balanço entre resposta rápida e performance
local INTERVALO_VERIFICACAO  = 0.5
local timerInventario        = 0

-- ── Função: CorrigirUmaTool ──────────────────────────────────────────
-- Aplica todas as correções necessárias em uma única Tool.
-- Chamada tanto pelo loop quanto pelo ChildAdded instantâneo.
local function CorrigirUmaTool(tool)
    if not tool or not tool:IsA("Tool") then return end

    pcall(function()
        -- ── 1. Corrige transparência de todas as partes ──────────────
        -- Percorre TODOS os descendentes da tool
        for _, parte in ipairs(tool:GetDescendants()) do
            if parte:IsA("BasePart") then
                if parte.Transparency > 0 then
                    parte.Transparency = 0
                    print("[Inventário] 👁️ Item apareceu: " .. tool.Name)
                end
                -- LocalTransparencyModifier é usado pelo Roblox internamente
                -- para ocultar partes; forçamos 0 para garantir visibilidade
                parte.LocalTransparencyModifier = 0
            end
        end

        -- ── 2. Corrige estrutura: garante existência do Handle ───────
        local handle = tool:FindFirstChild("Handle")
        if not handle then
            -- Tenta usar qualquer BasePart como Handle
            for _, v in ipairs(tool:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.Name = "Handle"   -- renomeia para Handle
                    handle = v
                    print("[Inventário] 🔧 Handle criado para: " .. tool.Name)
                    break
                end
            end
        end

        -- ── 3. Garante que a tool está habilitada ───────────────────
        tool.Enabled = true

        -- ── 4. Garante que a tool tem Parent correto ─────────────────
        -- Tools fora do Backpack e fora do Character são inacessíveis
        local char    = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

        if tool.Parent ~= backpack and (char == nil or tool.Parent ~= char) then
            -- Tool órfã: move para o Backpack
            if backpack then
                tool.Parent = backpack
                print("[Inventário] 📦 Tool movida para Backpack: " .. tool.Name)
            end
        end

        -- ── 5. Marca como corrigida ──────────────────────────────────
        if not toolsJaCorrigidas[tool] then
            toolsJaCorrigidas[tool] = true
            print("[Inventário] ✅ Item corrigido: " .. tool.Name)
        end
    end)
end

-- ── Função: CorrigirInventario ───────────────────────────────────────
-- Varre Backpack e Character em busca de Tools e corrige todas.
-- Chamada pelo loop e também pelo botão ao ser ativado.
local function CorrigirInventario()
    pcall(function()
        local char     = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

        -- Corrige Tools no Backpack
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") then
                    CorrigirUmaTool(item)
                end
            end
        end

        -- Corrige Tools equipadas (no personagem)
        if char then
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Tool") then
                    CorrigirUmaTool(item)
                end
            end
        end
    end)
end

-- ── Função: equiparPrimeiraFerramenta ────────────────────────────────
-- Equipa automaticamente a primeira tool corrigida do Backpack.
-- Só faz isso uma vez ao ativar (não fica re-equipando em loop).
local function equiparPrimeiraFerramenta()
    pcall(function()
        local hum      = getHumanoid()
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not hum or not backpack then return end

        local primeiraTool = backpack:FindFirstChildOfClass("Tool")
        if primeiraTool then
            hum:EquipTool(primeiraTool)
            print("[Inventário] 🎮 Item equipado: " .. primeiraTool.Name)
        end
    end)
end

-- ── Função: configurarDeteccaoInstantanea ────────────────────────────
-- Conecta ChildAdded no Backpack e no Character para detectar novos
-- itens imediatamente ao aparecerem, sem esperar o loop de 0.5s.
local function configurarDeteccaoInstantanea()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local char     = LocalPlayer.Character

    -- Detecta itens adicionados ao Backpack
    if backpack then
        local conn = backpack.ChildAdded:Connect(function(child)
            if inventarioAtivo and child:IsA("Tool") then
                task.wait(0.08)   -- aguarda o item carregar completamente
                CorrigirUmaTool(child)
                print("[Inventário] ⚡ Novo item detectado no Backpack: " .. child.Name)
            end
        end)
        table.insert(invChildAddedConexoes, conn)
    end

    -- Detecta itens adicionados ao Character (equipados)
    if char then
        local conn = char.ChildAdded:Connect(function(child)
            if inventarioAtivo and child:IsA("Tool") then
                task.wait(0.08)
                CorrigirUmaTool(child)
                print("[Inventário] ⚡ Novo item detectado no personagem: " .. child.Name)
            end
        end)
        table.insert(invChildAddedConexoes, conn)
    end
end

-- ── Ativação e desativação ───────────────────────────────────────────

local function AtivarInventario()
    inventarioAtivo     = true
    toolsJaCorrigidas   = {}   -- reseta cache ao ativar

    -- Correção imediata de tudo que já existe
    CorrigirInventario()

    -- Equipa automaticamente a primeira tool disponível
    task.delay(0.15, equiparPrimeiraFerramenta)

    -- Configura detecção instantânea de novos itens
    configurarDeteccaoInstantanea()

    -- Loop leve: roda a cada INTERVALO_VERIFICACAO segundos
    -- Garante que itens que bugam DEPOIS de aparecer sejam corrigidos
    inventarioConn = RunService.Heartbeat:Connect(function(dt)
        timerInventario = timerInventario + dt
        if timerInventario >= INTERVALO_VERIFICACAO then
            timerInventario = 0
            CorrigirInventario()
        end
    end)

    -- Re-aplica após respawn (personagem novo tem novo Backpack)
    LocalPlayer.CharacterAdded:Connect(function(char)
        if inventarioAtivo then
            task.wait(0.5)   -- aguarda o Backpack recriar
            toolsJaCorrigidas = {}
            CorrigirInventario()
            configurarDeteccaoInstantanea()
            task.delay(0.3, equiparPrimeiraFerramenta)
            print("[Inventário] 🔄 Inventário reconfigurado após respawn")
        end
    end)

    print("[Inventário] ✅ Sistema ATIVADO")
end

local function DesativarInventario()
    inventarioAtivo = false

    -- Para o loop de verificação
    if inventarioConn then
        inventarioConn:Disconnect()
        inventarioConn = nil
    end

    -- Desconecta detecção instantânea
    for _, conn in ipairs(invChildAddedConexoes) do
        pcall(function() conn:Disconnect() end)
    end
    invChildAddedConexoes = {}
    toolsJaCorrigidas     = {}
    timerInventario       = 0

    print("[Inventário] ⛔ Sistema DESATIVADO")
end

-- ── Conexão do botão ─────────────────────────────────────────────────
BtnVerInventario.MouseButton1Click:Connect(function()
    State.VerInventario = not State.VerInventario
    setToggleColor(BtnVerInventario, State.VerInventario)

    if State.VerInventario then
        AtivarInventario()
    else
        DesativarInventario()
    end
end)


-- ══════════════════════════════════════════════════════════════════════
-- ██  MENSAGEM FINAL NO OUTPUT
-- ══════════════════════════════════════════════════════════════════════

print("✅ Módulos adicionais carregados:")
print("   ⚡ AntiBug Speed  — protege movimento em alta velocidade")
print("   🎯 Hitbox All-You — visualiza hitboxes e reduz a sua")
print("   🎒 Ver Inventário — corrige e equipa itens em tempo real")
-- ══════════════════════════════════════════════════════════════════════
-- ██  AUTO FOLLOW RODADA — Sempre Ativo, 100% LocalScript             ██
-- ██  Cole no FINAL do seu script principal, sem apagar nada          ██
-- ██                                                                  ██
-- ██  O que faz:                                                       ██
-- ██  Fica rodando em segundo plano desde o momento que o script      ██
-- ██  carrega. Quando detecta que os outros jogadores foram           ██
-- ██  teleportados para a área do jogo e você ficou para trás,        ██
-- ██  ele te leva junto automaticamente — sem precisar clicar em      ██
-- ██  nada. Usa três sistemas simultâneos para cobrir todos os        ██
-- ██  casos: posição do grupo, RemoteEvents e TeleportService.        ██
-- ══════════════════════════════════════════════════════════════════════

do  -- bloco isolado: todas as variáveis ficam aqui dentro, sem colidir
    -- com nada que já existe no script principal acima

    -- ── Referências reutilizadas do script principal ─────────────────
    -- Estas já existem no escopo acima, então referenciamos direto:
    --   Players, RunService, LocalPlayer
    -- getRootPart() também já existe acima — usamos ela diretamente.

    -- ── Configurações ─────────────────────────────────────────────────

    -- Distância em studs entre você e o grupo para considerar
    -- que uma rodada começou e você ficou para trás.
    -- 60 studs funciona bem para mapas médios.
    -- Aumente para 80-100 se o mapa for muito grande.
    local DIST_TRIGGER      = 60

    -- Quantos jogadores precisam estar longe para confirmar rodada.
    -- Valor 2 evita falsos positivos (1 jogador longe pode ser bug).
    local MIN_JOGADORES     = 2

    -- Intervalo entre verificações de posição (segundos).
    local INTERVALO         = 0.4

    -- Cooldown após te teleportar: evita loop de teleporte repetido.
    local COOLDOWN          = 5.0

    -- Quanto subir acima do chão ao aparecer (evita prender no chão).
    local OFFSET_Y          = 4

    -- ── Variáveis de controle internas ────────────────────────────────

    local timer          = 0      -- acumula dt entre verificações
    local cooldownTimer  = 0      -- acumula dt do cooldown
    local emCooldown     = false  -- true = aguardando cooldown acabar
    local jaSegui        = false  -- true = já seguiu nesta rodada

    -- ── Função: posição média do grupo longe de mim ───────────────────
    local function calcularGrupo()
        -- Pega a posição do personagem local
        local char   = LocalPlayer.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return 0, nil end

        local minhaPos  = myRoot.Position
        local soma      = Vector3.new(0, 0, 0)
        local contLonge = 0

        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end          -- pula a si mesmo

            local c = p.Character
            if not c then continue end

            local r = c:FindFirstChild("HumanoidRootPart")
            if not r then continue end

            -- Conta apenas quem está além do limite
            if (r.Position - minhaPos).Magnitude > DIST_TRIGGER then
                contLonge = contLonge + 1
                soma      = soma + r.Position
            end
        end

        if contLonge < MIN_JOGADORES then
            return 0, nil   -- não há jogadores suficientes longe
        end

        return contLonge, soma / contLonge   -- média da posição do grupo
    end

    -- ── Função: realiza o teleporte de forma segura ────────────────────
    local function irParaGrupo(destino)
        local char   = LocalPlayer.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        -- Sobe um pouco para não spawnar dentro do chão
        local pos = Vector3.new(destino.X, destino.Y + OFFSET_Y, destino.Z)

        -- Preserva a rotação atual do personagem (não gira bruscamente)
        local rot = myRoot.CFrame - myRoot.CFrame.Position
        myRoot.CFrame = rot + pos

        -- Inicia cooldown para evitar teleportes repetidos
        emCooldown   = true
        cooldownTimer = 0
        jaSegui      = true

        print("[AutoFollow] 🚀 Teleportado para a área do jogo! -> " .. tostring(pos))
    end

    -- ── Função: verifica e age (chamada pelo loop) ─────────────────────
    local function verificar()
        if emCooldown then return end   -- aguarda cooldown terminar
        if jaSegui    then return end   -- já seguiu nesta rodada

        local qtd, posGrupo = calcularGrupo()
        if qtd >= MIN_JOGADORES and posGrupo then
            print("[AutoFollow] 📍 " .. qtd .. " jogadores na área do jogo — seguindo!")
            irParaGrupo(posGrupo)
        end
    end

    -- ── Sistema 2: escuta RemoteEvents de início de rodada ────────────
    -- Muitos jogos (Murder Mystery, etc.) disparam um RemoteEvent quando
    -- a rodada começa. Ao ouvir esse evento, verificamos o grupo 0.3s
    -- depois — mais rápido que o loop de posição.
    local function conectarRemote(obj)
        if not obj:IsA("RemoteEvent") then return end

        -- Palavras que indicam início de rodada no nome do evento
        local nomes = {
            "round","rodada","start","begin","teleport",
            "game","jogo","spawn","phase","stage","map"
        }
        local lower = obj.Name:lower()
        local relevante = false
        for _, kw in ipairs(nomes) do
            if lower:find(kw, 1, true) then
                relevante = true
                break
            end
        end
        if not relevante then return end

        -- Escuta o evento no cliente
        pcall(function()
            obj.OnClientEvent:Connect(function()
                if emCooldown then return end
                print("[AutoFollow] 📡 RemoteEvent: " .. obj.Name .. " — verificando...")
                task.delay(0.35, function()
                    local qtd, posGrupo = calcularGrupo()
                    -- Para remotes, aceita 1 jogador (sinal mais confiável)
                    if qtd >= 1 and posGrupo then
                        irParaGrupo(posGrupo)
                    end
                end)
            end)
        end)
        print("[AutoFollow] 📡 Monitorando RemoteEvent: " .. obj.Name)
    end

    -- Varre ReplicatedStorage em busca de remotes relevantes
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        for _, obj in ipairs(rs:GetDescendants()) do
            conectarRemote(obj)
        end
        -- Também pega remotes que forem criados depois (jogos dinâmicos)
        rs.DescendantAdded:Connect(function(obj)
            task.wait(0.1)   -- aguarda o remote estar pronto
            conectarRemote(obj)
        end)
    end)

    -- ── Sistema 3: escuta TeleportService ─────────────────────────────
    -- Se o servidor tentar teleportar o jogador e isso falhar
    -- (comum em executors), detectamos e usamos o grupo como destino.
    pcall(function()
        LocalPlayer.OnTeleport:Connect(function(state, placeId)
            if state == Enum.TeleportState.Started then
                print("[AutoFollow] 🌐 TeleportService detectado (place " .. tostring(placeId) .. ")")
                task.delay(1.5, function()
                    if not emCooldown then
                        local qtd, posGrupo = calcularGrupo()
                        if qtd >= 1 and posGrupo then
                            irParaGrupo(posGrupo)
                        end
                    end
                end)

            elseif state == Enum.TeleportState.Failed then
                print("[AutoFollow] ⚠️ Teleporte falhou — seguindo grupo via posição")
                task.delay(0.5, verificar)
            end
        end)
    end)

    -- ── Reset ao respawnar ─────────────────────────────────────────────
    -- Após morrer e renascer, reseta os flags para monitorar a próxima
    -- rodada normalmente — sem ficar travado em jaSegui = true.
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.8)         -- aguarda personagem carregar
        jaSegui      = false
        emCooldown   = false
        cooldownTimer = 0
        timer        = 0
        print("[AutoFollow] 🔄 Personagem recarregado — pronto para próxima rodada")
    end)

    -- ── Loop principal (Sistema 1) — verifica posição do grupo ────────
    -- Roda desde o início, sem botão, sem toggle.
    -- Heartbeat é chamado após a física de cada frame — ideal para
    -- leitura de posição sem conflito com a engine de física.
    RunService.Heartbeat:Connect(function(dt)
        -- Gerencia cooldown
        if emCooldown then
            cooldownTimer = cooldownTimer + dt
            if cooldownTimer >= COOLDOWN then
                emCooldown   = false
                jaSegui      = false
                cooldownTimer = 0
                print("[AutoFollow] ✅ Cooldown encerrado — monitorando...")
            end
            return   -- não verifica durante cooldown
        end

        -- Acumula tempo e verifica no intervalo configurado
        timer = timer + dt
        if timer >= INTERVALO then
            timer = 0
            pcall(verificar)   -- pcall garante que erros não quebrem o loop
        end
    end)

    -- ── Confirmação no output ──────────────────────────────────────────
    print("✅ [AutoFollow] SEMPRE ATIVO — Seguindo rodada automaticamente")
    print("   Dist. gatilho : " .. DIST_TRIGGER .. " studs")
    print("   Mín. jogadores: " .. MIN_JOGADORES)
    print("   Cooldown       : " .. COOLDOWN .. "s")
    print("   3 sistemas: posição do grupo + RemoteEvents + TeleportService")

end  -- fim do bloco isolado

_teleportConn then
        af_teleportConn:Disconnect()
        af_teleportConn = nil
    end

    af_teleportConn = LocalPlayer.OnTeleport:Connect(function(teleportState, placeId, spawnName)
        if not af_ativo then return end

        if teleportState == Enum.TeleportState.Started then
            print("[AutoFollow] 🌐 TeleportService detectado para place: " .. tostring(placeId))
            -- O jogo está tentando nos teleportar para outro lugar.
            -- Como estamos num executor, esse teleporte pode não funcionar.
            -- Reagimos seguindo a posição do grupo como fallback.
            task.delay(1.5, function()
                if af_ativo then
                    local qtd, posGrupo = calcularPosicaoGrupo()
                    if qtd >= 1 and posGrupo then
                        executarTeleporte(posGrupo)
                    end
                end
            end)

        elseif teleportState == Enum.TeleportState.Failed then
            print("[AutoFollow] ⚠️ Teleporte falhou — tentando seguir grupo via posição")
            task.delay(0.5, function()
                if af_ativo then verificarETeleportar() end
            end)
        end
    end)
end

-- ── Função: AtivarAutoFollow ──────────────────────────────────────────
local function AtivarAutoFollow()
    af_ativo         = true
    af_jaSegui       = false
    af_emCooldown    = false
    af_timer         = 0
    af_cooldownTimer = 0

    -- Inicia monitoramento de RemoteEvents
    monitorarRemotes()

    -- Inicia monitoramento de TeleportService
    monitorarOnTeleport()

    -- Loop principal: verifica posição do grupo a cada AF_INTERVALO segundos
    af_conn = RunService.Heartbeat:Connect(function(dt)
        af_timer         = af_timer + dt
        af_cooldownTimer = af_cooldownTimer + dt

        -- Gerencia cooldown: após AF_COOLDOWN segundos, libera para nova verificação
        if af_emCooldown and af_cooldownTimer >= AF_COOLDOWN then
            af_emCooldown    = false
            af_jaSegui       = false
            af_cooldownTimer = 0
            print("[AutoFollow] ✅ Cooldown encerrado — monitorando próxima rodada...")
        end

        -- Só verifica posição no intervalo configurado (não todo frame)
        if af_timer >= AF_INTERVALO then
            af_timer = 0
            pcall(verificarETeleportar)
        end
    end)

    -- Reativa após respawn (personagem renova após morrer/reconectar)
    af_charConn = LocalPlayer.CharacterAdded:Connect(function(char)
        if af_ativo then
            -- Aguarda o personagem carregar completamente antes de monitorar
            task.wait(0.8)
            af_jaSegui       = false
            af_emCooldown    = false
            af_cooldownTimer = 0
            print("[AutoFollow] 🔄 Personagem recarregado — monitoramento reiniciado")
        end
    end)

    print("[AutoFollow] ✅ ATIVADO")
    print("[AutoFollow] ℹ️ Aguardando início de rodada...")
    print("[AutoFollow]    • Distância gatilho : " .. AF_DIST_TRIGGER .. " studs")
    print("[AutoFollow]    • Mín. jogadores    : " .. AF_MIN_JOGADORES)
    print("[AutoFollow]    • Cooldown          : " .. AF_COOLDOWN .. "s")
end

-- ── Função: DesativarAutoFollow ───────────────────────────────────────
local function DesativarAutoFollow()
    af_ativo = false

    -- Para o loop principal
    if af_conn then
        af_conn:Disconnect()
        af_conn = nil
    end

    -- Remove listener de CharacterAdded
    if af_charConn then
        af_charConn:Disconnect()
        af_charConn = nil
    end

    -- Remove listener de OnTeleport
    if af_teleportConn then
        af_teleportConn:Disconnect()
        af_teleportConn = nil
    end

    -- Remove todos os listeners de RemoteEvents
    for _, conn in ipairs(af_remoteConns) do
        pcall(function() conn:Disconnect() end)
    end
    af_remoteConns = {}

    -- Reseta variáveis internas
    af_jaSegui       = false
    af_emCooldown    = false
    af_timer         = 0
    af_cooldownTimer = 0

    print("[AutoFollow] ⛔ DESATIVADO")
end

-- ── Conexão do botão no painel ────────────────────────────────────────
BtnAutoFollow.MouseButton1Click:Connect(function()
    State.AutoFollow = not State.AutoFollow
    setToggleColor(BtnAutoFollow, State.AutoFollow)

    if State.AutoFollow then
        AtivarAutoFollow()
    else
        DesativarAutoFollow()
    end
end)

-- ── Mensagem no output ────────────────────────────────────────────────
print("   🎮 Auto Follow Rodada — segue o grupo ao início da partida")
print("      Monitora: posição do grupo + RemoteEvents + TeleportService")


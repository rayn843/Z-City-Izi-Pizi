MODE.name = "smo"
local MODE = MODE

local StartTime = 0
local PointsProgress = {}
local Tickets = {}

net.Receive("SWO_TicketsUpdate", function()
    Tickets = net.ReadTable() or {}
end)

net.Receive("swo_start", function()
    StartTime = CurTime()
    MODE.RevealSounds = {} -- Сбрасываем звуки при старте раунда
    RemoveEndSMORoundStatsPanel()

    timer.Simple(.5, function()
        surface.PlaySound(LocalPlayer():Team() == 1 and "ukraineround.wav" or "hohols.mp3")
    end)

    zb.RemoveFade()
    PointsProgress = {}
    Tickets = {}
end)

local respawntime = CurTime()
local RESPAWN_HOOK = "SWO_Respawn"

net.Receive("swo_respawn", function()
    respawntime = net.ReadFloat() + 5

    hook.Add("HUDPaint", RESPAWN_HOOK, function()
        -- Время вышло или игрок жив — убираем таймер
        if respawntime < CurTime() or lply:Alive() then
            hook.Remove("HUDPaint", RESPAWN_HOOK)
            return
        end

        draw.SimpleText("Respawn in " .. string.FormattedTime(respawntime - CurTime(), "%02i:%02i:%02i"), "ZB_HomicideMedium", sw * 0.5, sh * 0.8, ColorObj, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
end)

local teams = {
    [0] = {
        objective = "Your task is to destroy the enemy forces of Russia.",
        name = "an Ukraine soldier",
        color1 = Color(90,75,0),
        color2 = Color(90,75,0)
    },
    [1] = {
        objective = "Your task is to destroy the enemy forces of Ukraine.",
        name = "a Russian soldier",
        color1 = Color(10,75,0),
        color2 = Color(10,75,0)
    },
}

function MODE:RenderScreenspaceEffects()
    if StartTime + 7.5 < CurTime() then return end

    local fade = math.Clamp(StartTime + 7.5 - CurTime(), 0, 1)

    surface.SetDrawColor(0, 0, 0, 255 * fade)
    surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

net.Receive("SWO_PointsUpdate", function()
    PointsProgress = net.ReadTable() or {}
end)

-- Цвета команд для полос прогресса точек (RU — зелёный, UA — жёлто-коричневый)
local RU_COLOR = Color(33,109,0,255)
local UA_COLOR = Color(150,128,42,255)
local NEUTRAL_COLOR = Color(120,120,120,255)
local BAR_BG = Color(0,0,0,180)

local CAPTURE_RADIUS = 250 -- радиус в юнитах (должен совпадать с sv_smo CAP_CAPTURE_RANGE)
local BAR_WIDTH = ScreenScale(50)
local BAR_HEIGHT = ScreenScale(8)
local MAX_PROGRESS = 100

-- Возвращает (balance, ownTeam): balance — перевес сил на точке в радиусе,
-- ownTeam — 0/1 = локальный игрок и его сторона
local function ComputePointBalance(pos, radius)
    local ply = LocalPlayer()
    local ru, ua = 0, 0
    local r2 = radius * radius

    for _, other in ipairs(player.GetAll()) do
        if not IsValid(other) or not other:Alive() then continue end

        if other:GetPos():DistToSqr(pos) <= r2 then
            if other:Team() == 1 then
                ru = ru + 1
            elseif other:Team() == 0 then
                ua = ua + 1
            end
        end
    end

    return ru - ua, ply:Team()
end

net.Receive("SWO_PointsPositions", function()
    MODE.PointPositions = net.ReadTable() or {}
end)

function MODE:HUDPaint()
    if not MODE.PointPositions then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local myTeam = ply:Team()
    local plyPos = ply:EyePos()

    for name, pos in pairs(MODE.PointPositions) do
        local screen = pos:ToScreen()
        if not screen.visible then continue end

        local distance = math.Round(plyPos:Distance(pos) * 0.0254, 0)
        local isOnPoint = plyPos:DistToSqr(pos) <= (CAPTURE_RADIUS ^ 2)

        local left = screen.x - BAR_WIDTH / 2
        local top = 0

        -- Прогресс точки: -MAX_PROGRESS..+MAX_PROGRESS
        local rawProgress = (PointsProgress and PointsProgress[name]) or 0
        local absProgress = math.abs(rawProgress)

        -- Фон полосы
        surface.SetDrawColor(BAR_BG)
        surface.DrawRect(left, top, BAR_WIDTH, BAR_HEIGHT)

        -- Заполнение: |progress|/MAX_PROGRESS от центра к краю в сторону команды-владельца
        local perc = math.Clamp(absProgress / MAX_PROGRESS, 0, 1)
        local fillClr

        if rawProgress > 0 then
            fillClr = RU_COLOR
        elseif rawProgress < 0 then
            fillClr = UA_COLOR
        else
            fillClr = NEUTRAL_COLOR
        end

        if perc > 0 then
            surface.SetDrawColor(fillClr)

            -- Если точка на 100% за команду — рисуем полосой целиком
            if absProgress >= MAX_PROGRESS then
                surface.DrawRect(left, top, BAR_WIDTH, BAR_HEIGHT)
            else
                -- Заполнение от центра к краю: длина половины * perc
                local halfW = BAR_WIDTH * 0.5
                local fillW = halfW * perc

                if rawProgress > 0 then
                    surface.DrawRect(screen.x, top, fillW, BAR_HEIGHT)       -- вправо (RU)
                else
                    surface.DrawRect(screen.x - fillW, top, fillW, BAR_HEIGHT) -- влево (UA)
                end
            end
        end

        -- Название точки и дистанция
        local txt = name .. ": " .. distance .. "m"
        surface.SetFont("ZB_HomicideSmall")
        surface.SetTextColor(color_white:Unpack())

        local tw, th = surface.GetTextSize(txt)
        surface.SetTextPos(screen.x - tw / 2, BAR_HEIGHT + 2)
        surface.DrawText(txt)

        -- Стейт точки, когда локальный игрок на ней
        if isOnPoint then
            local balance = ComputePointBalance(pos, CAPTURE_RADIUS)
            local alert, aClr

            local fullyRU = rawProgress >= MAX_PROGRESS
            local fullyUA = rawProgress <= -MAX_PROGRESS

            if fullyRU or fullyUA then
                -- Точка под контролем одной из команд
                if (fullyRU and myTeam == 1) or (fullyUA and myTeam == 0) then
                    alert, aClr = "Controlled", Color(100, 255, 100)
                else
                    alert, aClr = "Enemy Held", Color(255, 80, 80)
                end
            elseif balance == 0 then
                alert, aClr = "Contested", Color(255, 200, 60)
            elseif (balance > 0 and myTeam == 1) or (balance < 0 and myTeam == 0) then
                alert, aClr = "Capturing", Color(100, 255, 100)
            else
                alert, aClr = "Losing", Color(255, 80, 80)
            end

            surface.SetFont("ZB_HomicideSmall")
            surface.SetTextColor(aClr)

            local aw = surface.GetTextSize(alert)
            surface.SetTextPos(screen.x - aw / 2, BAR_HEIGHT + th + 4)
            surface.DrawText(alert)
        end
    end

    -- Жизни игрока показываем только если battlefield-билеты выключены
    local lives = ply:GetNWInt("SWO_Lives", -1)

    if lives >= 0 and table.IsEmpty(Tickets or {}) then
        local livesTxt = "Lives: " .. lives
        surface.SetFont("ZB_HomicideMedium")
        surface.SetTextColor(255, 255, 255)

        local lw = surface.GetTextSize(livesTxt)
        surface.SetTextPos(sw * 0.5 - lw / 2, sh * 0.06)
        surface.DrawText(livesTxt)
    end

    -- Battlefield tickets
    local ruTickets = math.floor((Tickets and Tickets[1]) or -1)
    local uaTickets = math.floor((Tickets and Tickets[0]) or -1)

    if ruTickets >= 0 or uaTickets >= 0 then
        local ticketTxt = string.format("RF: %d | UA: %d", math.max(ruTickets, 0), math.max(uaTickets, 0))

        surface.SetFont("ZB_HomicideMedium")
        surface.SetTextColor(255, 255, 255)

        local twTickets = surface.GetTextSize(ticketTxt)
        surface.SetTextPos(sw * 0.5 - twTickets / 2, sh * 0.05)
        surface.DrawText(ticketTxt)
    end

    -- Таймер раунда
    local roundStart = zb.ROUND_START or 0
    local roundTime = zb.ROUND_TIME or self.ROUND_TIME or 1200
    local remaining = math.max(roundStart + roundTime - CurTime(), 0)
    local timeTxt = string.FormattedTime(remaining, "%02i:%02i:%02i")

    surface.SetFont("ZB_HomicideMedium")
    surface.SetTextColor(255, 255, 255)

    local tw2 = surface.GetTextSize(timeTxt)
    surface.SetTextPos(sw * 0.5 - tw2 / 2, sh * 0.95)
    surface.DrawText(timeTxt)

    -- Остальной код без изменений...
    if StartTime + 8.5 < CurTime() then return end
    if not ply:Alive() then return end

    zb.RemoveFade()

    -- Адаптированная поэтапная отрисовка начала раунда (как в homicide)
    local team_ = ply:Team()
    local teamInfo = teams[team_]
    if not teamInfo then return end

    local timeElapsed = CurTime() - StartTime
    local maxTime = 6 -- Общее время отображения UI (в секундах)
    if timeElapsed > maxTime then return end

    -- Глобальное появление и затухание
    local globalFade = 1

    if timeElapsed < 0.5 then
        globalFade = timeElapsed / 0.5
    elseif timeElapsed > 4.5 then
        globalFade = math.Clamp(1 - (timeElapsed - 4.5) / 1.5, 0, 1)
    end

    -- 1. Фон в зависимости от команды
    local bgColor = Color(teamInfo.color1.r * 0.1, teamInfo.color1.g * 0.1, teamInfo.color1.b * 0.1, 255 * globalFade)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, ScrW(), ScrH())

    -- Виньетка/градиент
    local mat = Material("vgui/gradient-d")
    surface.SetMaterial(mat)
    surface.SetDrawColor(0, 0, 0, 200 * globalFade)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

    -- 2. Настройки стадий
    local function getStageAlpha(t)
        return math.Clamp((timeElapsed - t) / 0.3, 0, 1) * globalFade
    end

    local a_title = getStageAlpha(0.5)
    local a_role = getStageAlpha(1.5)
    local a_obj = getStageAlpha(3.5)

    -- Звуки появления
    MODE.RevealSounds = MODE.RevealSounds or {}

    local function playStageSound(t, snd)
        if timeElapsed >= t and not MODE.RevealSounds[t] then
            surface.PlaySound(snd)
            MODE.RevealSounds[t] = true
        end
    end

    -- 3. Верхний текст (Title)
    if a_title > 0 then
        draw.SimpleText("ZVBattle | Special Military Operation", "ZB_HomicideMediumLarge", ScrW() * 0.5, ScrH() * 0.1, Color(0, 162, 255, 255 * a_title), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(0.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end

    -- 4. Роль
    local ColorRole = Color(teamInfo.color1.r, teamInfo.color1.g, teamInfo.color1.b, 255 * a_role)

    if a_role > 0 then
        draw.SimpleText("You are " .. teamInfo.name, "ZB_HomicideMediumLarge", ScrW() * 0.5, ScrH() * 0.5, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(1.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end

    -- 5. Нижний текст (Objective)
    local ColorObj = Color(teamInfo.color2.r, teamInfo.color2.g, teamInfo.color2.b, 255 * a_obj)

    if a_obj > 0 then
        draw.SimpleText(teamInfo.objective, "ZB_HomicideMedium", ScrW() * 0.5, ScrH() * 0.9, ColorObj, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(3.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end
end

local CreateEndMenu

-- Панели завершения раунда
SMO_EndStatsPanel = nil

function RemoveEndSMORoundStatsPanel()
    if IsValid(SMO_EndStatsPanel) then
        SMO_EndStatsPanel:Remove()
        SMO_EndStatsPanel = nil
    end
end

local colGray = Color(122,122,122,255)
local colBlue = Color(130,10,10)
local colBlueUp = Color(160,30,30)
local col = Color(255,255,255,255)
local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(85,85,85,255)

local function CreateEndRoundStatsPanel()
    RemoveEndSMORoundStatsPanel()

    if not IsValid(lply) then return end

    net.Start("zb_xp_get")
        net.WriteEntity(lply)
    net.SendToServer()

    local padding = ScreenScale(4)
    local topW = ScreenScale(210)
    local topH = ScreenScale(32)
    local medalW = ScreenScale(52)
    local medalH = ScreenScale(105)
    local posX = padding + ScreenScale(25)
    local posY = padding + ScreenScale(25)

    SMO_EndStatsPanel = vgui.Create("DPanel")
    SMO_EndStatsPanel:SetPos(posX, posY)
    SMO_EndStatsPanel:SetSize(topW, topH + medalH + padding)
    SMO_EndStatsPanel:MakePopup()
    SMO_EndStatsPanel:SetKeyboardInputEnabled(false)
    SMO_EndStatsPanel:SetMouseInputEnabled(false)
    SMO_EndStatsPanel.Paint = function(self, pw, ph) end

    local pnl1 = vgui.Create("DPanel", SMO_EndStatsPanel)
    pnl1:SetPos(0, 0)
    pnl1:SetSize(topW, topH)

    pnl1.Paint = function(self, pw, ph)
        draw.RoundedBox(0, 0, 0, pw, ph, Color(20, 20, 20, 220))

        surface.SetDrawColor(255, 0, 0, 100)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)

        surface.SetDrawColor(colBlueUp.r, colBlueUp.g, colBlueUp.b, colBlueUp.a)
        surface.SetDrawColor(colBlue.r, colBlue.g, colBlue.b, colBlue.a)
        surface.DrawRect(0, 0, pw, ph)

        surface.SetDrawColor(colBlueUp.r, colBlueUp.g, colBlueUp.b, colBlueUp.a)
        surface.DrawRect(5, 35, pw - 10, (ph / 1.65) - 5)
    end

    local avatarSize = topH - ScreenScale(4)
    local avatar = vgui.Create("AvatarImage", pnl1)
    avatar:SetSize(avatarSize, avatarSize)
    avatar:SetPos(ScreenScale(2), ScreenScale(2))
    avatar:SetPlayer(lply, 64)

    local textX = avatarSize + ScreenScale(6)

    local topLbl = vgui.Create("DLabel", pnl1)
    topLbl:SetPos(textX, ScreenScale(2))
    topLbl:SetFont("ZB_HomicideSuperSuperSmall")
    topLbl:SetTextColor(Color(137, 137, 137))
    topLbl:SetText("MVP: " .. "Wait for stats...")
    topLbl:SizeToContents()

    local mainLbl = vgui.Create("DLabel", pnl1)
    mainLbl:SetPos(textX, ScreenScale(4))
    mainLbl:SetFont("ZB_HomicideLarge")
    mainLbl:SetTextColor(Color(255, 255, 255))
    mainLbl:SetText(lply:Nick())
    mainLbl:SizeToContents()

    local pnl2 = vgui.Create("DPanel", SMO_EndStatsPanel)
    pnl2:SetPos(0, topH + padding)
    pnl2:SetSize(medalW, medalH)
    pnl2.Band = nil
    pnl2.Medal = nil

    local statsLbl = vgui.Create("DLabel", pnl2)
    statsLbl:Dock(TOP)
    statsLbl:DockMargin(ScreenScale(3), ScreenScale(2) - 5, ScreenScale(3), 0)
    statsLbl:SetFont("ZB_HomicideSuperSuperSmall")
    statsLbl:SetTextColor(Color(200, 200, 200))
    statsLbl:SetText("Wait for stats...")
    statsLbl:SetContentAlignment(7)
    statsLbl:SetTall(ScreenScale(12))

    SMO_EndStatsPanel.statsLbl = statsLbl
    SMO_EndStatsPanel.pnl2 = pnl2

    pnl2.Paint = function(self, pw, ph)
        draw.RoundedBox(0, 0, 0, pw, ph, Color(20, 20, 20, 220))

        surface.SetDrawColor(255, 0, 0, 100)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)

        surface.SetDrawColor(colBlue.r, colBlue.g, colBlue.b, colBlue.a)
        surface.DrawRect(0, 0, pw, ph)

        surface.SetDrawColor(colBlueUp.r, colBlueUp.g, colBlueUp.b, colBlueUp.a)
        surface.DrawRect(5, 20, 146, ph / 1.09)

        if not self.Band or not self.Medal then return end

        local topMargin = statsLbl:GetTall() + ScreenScale(2)
        local medalSize = math.min(pw + ScreenScale(4), ph + topMargin + ScreenScale(4))

        local x = (pw - medalSize) / 2 - 50
        local y = topMargin + ((ph - topMargin) - medalSize) / 2 - 50

        surface.SetDrawColor(0, 0, 0, 155)
        surface.SetMaterial(self.Band.icon)
        surface.DrawTexturedRect(x + 10, y + 10, medalSize + 100, medalSize + 100)

        surface.SetMaterial(self.Medal.icon)
        surface.DrawTexturedRect(x + 10, y + 10, medalSize + 100, medalSize + 100)

        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(self.Band.icon)
        surface.DrawTexturedRect(x, y, medalSize + 100, medalSize + 100)

        surface.SetMaterial(self.Medal.icon)
        surface.DrawTexturedRect(x, y, medalSize + 100, medalSize + 100)
    end
end

net.Receive("swo_roundend", function()
    CreateEndMenu()
    CreateEndRoundStatsPanel()
end)

local colGray = Color(85,85,85,255)
local colRed = Color(130,10,10)
local colRedUp = Color(160,30,30)
local colBlue = Color(10,10,160)
local colBlueUp = Color(40,40,160)
local col = Color(255,255,255,255)
local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(255,255,255)
local colorBG = Color(55,55,55,255)
local colorBGBlacky = Color(40,40,40,255)
local blurMat = Material("pp/blurscreen")
local Dynamic = 0

BlurBackground = BlurBackground or hg.DrawBlur

if IsValid(hmcdEndMenu) then
    hmcdEndMenu:Remove()
    hmcdEndMenu = nil
end

CreateEndMenu = function()
    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end

    RemoveEndSMORoundStatsPanel()

    Dynamic = 0
    hmcdEndMenu = vgui.Create("ZFrame")

    surface.PlaySound("ambient/alarms/warningbell1.wav")

    local sizeX, sizeY = ScrW() / 2.5, ScrH() / 1.2
    local posX, posY = ScrW() / 1.3 - sizeX / 2, ScrH() / 2 - sizeY / 2

    hmcdEndMenu:SetPos(posX, posY)
    hmcdEndMenu:SetSize(sizeX, sizeY)
    hmcdEndMenu:MakePopup()
    hmcdEndMenu:SetKeyboardInputEnabled(false)
    hmcdEndMenu:ShowCloseButton(false)

    local closebutton = vgui.Create("DButton", hmcdEndMenu)
    closebutton:SetPos(5, 5)
    closebutton:SetSize(ScrW() / 20, ScrH() / 30)
    closebutton:SetText("")

    closebutton.DoClick = function()
        if IsValid(hmcdEndMenu) then
            hmcdEndMenu:Close()
            hmcdEndMenu = nil
        end

        RemoveEndSMORoundStatsPanel()
    end

    timer.Simple(3, function()
        if IsValid(SMO_EndStatsPanel) then
            SMO_EndStatsPanel:Remove()
            SMO_EndStatsPanel = nil
        end
    end)

    closebutton.Paint = function(self, w, h)
        surface.SetDrawColor(122, 122, 122, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)

        surface.SetFont("ZB_InterfaceMedium")
        surface.SetTextColor(col.r, col.g, col.b, col.a)

        local lenghtX, lenghtY = surface.GetTextSize("Close")
        surface.SetTextPos(lenghtX - lenghtX / 1.1, 4)
        surface.DrawText("Close")
    end

    hmcdEndMenu.Paint = function(self, w, h)
        BlurBackground(self)

        surface.SetFont("ZB_InterfaceMediumLarge")
        surface.SetTextColor(col.r, col.g, col.b, col.a)

        local lenghtX, lenghtY = surface.GetTextSize("Players:")
        surface.SetTextPos(w / 2 - lenghtX / 2, 20)
        surface.DrawText("Players:")

        surface.SetDrawColor(255, 0, 0, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
    end

    -- PLAYERS
    local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
    DScrollPanel:SetPos(10, 80)
    DScrollPanel:SetSize(sizeX - 20, sizeY - 90)

    function DScrollPanel:Paint(w, h)
        BlurBackground(self)

        surface.SetDrawColor(255, 0, 0, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
    end

    for i, ply in ipairs(player.GetAll()) do
        if ply:Team() == TEAM_SPECTATOR then continue end

        local but = vgui.Create("DButton", DScrollPanel)
        but:SetSize(100, 50)
        but:Dock(TOP)
        but:DockMargin(8, 6, 8, -1)
        but:SetText("")

        but.Paint = function(self, w, h)
            local col1 = (ply:Alive() and colRed) or colGray
            local col2 = (ply:Alive() and colRedUp) or colSpect1

            surface.SetDrawColor(col1.r, col1.g, col1.b, col1.a)
            surface.DrawRect(0, 0, w, h)

            surface.SetDrawColor(col2.r, col2.g, col2.b, col2.a)
            surface.DrawRect(0, h / 2, w, h / 2)

            local col = ply:GetPlayerColor():ToColor()

            surface.SetFont("ZB_InterfaceMediumLarge")
            local lenghtX, lenghtY = surface.GetTextSize(ply:GetPlayerName() or "He quited...")

            surface.SetTextColor(0, 0, 0, 255)
            surface.SetTextPos(w / 2 + 1, h / 2 - lenghtY / 2 + 1)
            surface.DrawText(ply:GetPlayerName() or "He quited...")

            surface.SetTextColor(col.r, col.g, col.b, col.a)
            surface.SetTextPos(w / 2, h / 2 - lenghtY / 2)
            surface.DrawText(ply:GetPlayerName() or "He quited...")

            local col = colSpect2

            surface.SetFont("ZB_InterfaceMediumLarge")
            surface.SetTextColor(col.r, col.g, col.b, col.a)

            local lenghtX, lenghtY = surface.GetTextSize(ply:GetPlayerName() or "He quited...")
            surface.SetTextPos(15, h / 2 - lenghtY / 2)
            surface.DrawText((ply:Name() .. (not ply:Alive() and " - died" or "")) or "He quited...")

            surface.SetFont("ZB_InterfaceMediumLarge")
            surface.SetTextColor(col.r, col.g, col.b, col.a)

            local lenghtX, lenghtY = surface.GetTextSize(ply:Frags() or "He quited...")
            surface.SetTextPos(w - lenghtX - 15, h / 2 - lenghtY / 2)
            surface.DrawText(ply:Frags() or "He quited...")
        end

        function but:DoClick()
            if ply:IsBot() then
                chat.AddText(Color(255, 0, 0), "no, you can't")
                return
            end

            gui.OpenURL("https://steamcommunity.com/profiles/" .. ply:SteamID64())
        end

        DScrollPanel:AddItem(but)
    end

    return true
end

function MODE:RoundStart()
    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end
end
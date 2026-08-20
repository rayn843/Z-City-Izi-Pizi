MODE.name = "laststand"
local MODE = MODE

local playstart
local ended
local MusicVolume = GetConVar("snd_musicvolume")
local LS_PrepEnd = nil -- Переменная для таймера

net.Receive("laststand_start", function()
    surface.PlaySound("zbattle/nigshit.mp3")
    zb.RemoveFade()
    playstart = true
    ended = nil
    MODE.RevealSounds = {}
    RemoveEndLSRoundStatsPanel()

    sound.PlayFile("sound/zc_dyna_music/comb_team/c8.mp3", "noblock noplay", function(station, errCode, errStr)
        if IsValid(station) then
            GWARS_LoopStation = station
            station:SetVolume(1 * MusicVolume:GetFloat())
            station:EnableLooping(true)
        end
    end)
end)

-- Получаем сигнал начала 20-секундного таймера
net.Receive("laststand_start_prep", function()
    LS_PrepEnd = CurTime() + 20
end)

local teams = {
    [0] = {
        objective = "Choose your loadout and survive! (3 lives)",
        name = "a Light Survivor",
        color1 = Color(180, 0, 0),
        color2 = Color(180, 0, 0)
    },
    [1] = {
        objective = "Eliminate all Light Survivors!",
        name = "a Heavy Unit",
        color1 = Color(0, 0, 180),
        color2 = Color(0, 0, 180)
    },
}

local lerpsnd = 0.3
function MODE:RenderScreenspaceEffects()
    if zb.ROUND_START + 7.5 < CurTime() then return end
    local fade = math.Clamp(zb.ROUND_START + 7.5 - CurTime(), 0, 1)
    surface.SetDrawColor(0, 0, 0, 255 * fade)
    surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

local hg_font = ConVarExists("hg_font") and GetConVar("hg_font") or CreateClientConVar("hg_font", "Bahnschrift", true, false, "Change UI text font")
local font = function() -- hg_coolvetica:GetBool() and "Coolvetica" or "Bahnschrift"
    local usefont = "Bahnschrift"

    if hg_font:GetString() != "" then
        usefont = hg_font:GetString()
    end

    return usefont
end

-- Создаем современные шрифты
surface.CreateFont("LS_LArgsdafasdf", { font = font(), size = ScreenScale(25), extended = true, weight = 800, antialias = true })
surface.CreateFont("LS_LArg", { font = font(), size = ScreenScale(20), extended = true, weight = 800, antialias = true })
surface.CreateFont("LS_Title", { font = font(), size = ScreenScale(13), extended = true, weight = 800, antialias = true })
surface.CreateFont("LS_Header", { font = font(), size = ScreenScale(6), extended = true, weight = 700, antialias = true })
surface.CreateFont("LS_Normal", { font = font(), size = ScreenScale(5), extended = true, weight = 500, antialias = true })
surface.CreateFont("LS_Small", { font = font(), size = ScreenScale(4), extended = true, weight = 400, antialias = true })
surface.CreateFont("timer_Font2", { font = font(), size = ScreenScale(12), extended = true, weight = 650, antialias = true })

-- Цвета для UI
local UI_BG = Color(20, 20, 25, 245)
local UI_Header = Color(30, 30, 35, 255)
local UI_Card = Color(35, 35, 40, 255)
local UI_CardHover = Color(45, 45, 50, 255)
local UI_Accent = Color(200, 30, 30, 255)
local UI_AccentDim = Color(120, 20, 20, 255)
local UI_Text = Color(230, 230, 230, 255)
local UI_TextDim = Color(150, 150, 150, 255)

net.Receive("laststand_open_menu", function()
    if IsValid(LS_Menu) then LS_Menu:Remove() end

    local selWepCost = 0
    local selEqCost = 0
    local selWep = "none"
    local selEq = "none"

    -- Создаем главное окно
    LS_Menu = vgui.Create("DFrame")
    LS_Menu:SetSize(720, 540)
    LS_Menu:Center()
    LS_Menu:SetTitle("")
    LS_Menu:MakePopup()
    LS_Menu.ShowCloseButton = false

    -- Кастомная отрисовка фона окна
    LS_Menu.Paint = function(self, w, h)
        if BlurBackground then BlurBackground(self) end
        
        -- Основной фон
        draw.RoundedBox(6, 0, 0, w, h, UI_BG)
        
        -- Шапка
        draw.RoundedBoxEx(6, 0, 0, w, 60, UI_Header, true, true, false, false)
        
        -- Неоновая линия под шапкой
        surface.SetDrawColor(UI_Accent)
        surface.DrawRect(0, 58, w, 2)
        surface.SetDrawColor(UI_Accent.r, UI_Accent.g, UI_Accent.b, 50)
        surface.DrawRect(0, 60, w, 4)
        
        -- Заголовок
        draw.SimpleText("LAST STAND", "LS_Title", 20, 30, UI_Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("LOADOUT SELECTION", "LS_Normal", 20, 48, UI_Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Индикатор оставшихся очков
    local ptsLabel = vgui.Create("DLabel", LS_Menu)
    ptsLabel:SetPos(500, 20)
    ptsLabel:SetFont("LS_Header")
    ptsLabel:SetSize(200, 25)
    ptsLabel:SetText("POINTS: 5/5")
    ptsLabel:SetTextColor(UI_Text)
    ptsLabel:SetContentAlignment(5)

    -- Таймер на 20 секунд
    local timeLabel = vgui.Create("DLabel", LS_Menu)
    timeLabel:SetPos(500, 45)
    timeLabel:SetFont("LS_Normal")
    timeLabel:SetSize(200, 20)
    timeLabel:SetText("TIME LEFT: 20s")
    timeLabel:SetTextColor(UI_TextDim)
    timeLabel:SetContentAlignment(5)

    local timeLeft = 20
    timer.Create("LS_Countdown", 1, 20, function()
        timeLeft = timeLeft - 1
        if IsValid(timeLabel) then 
            timeLabel:SetText("TIME LEFT: " .. timeLeft .. "s")
            if timeLeft <= 5 then
                timeLabel:SetTextColor(Color(255, 50, 50))
            end
        end
        if timeLeft <= 0 then
            timer.Remove("LS_Countdown")
            if IsValid(LS_Menu) then LS_Menu:Close() end
        end
    end)

    local function updatePts()
        local rem = 5 - (selWepCost + selEqCost)
        ptsLabel:SetText("POINTS: " .. rem .. "/5")
        if rem < 0 then
            ptsLabel:SetTextColor(Color(255, 50, 50))
        else
            ptsLabel:SetTextColor(UI_Text)
        end
    end

    -- Функция-генератор сетки с 2D-иконками
    local function CreateIconGrid(parent, x, y, title, items, isWeapon)
        local lbl = vgui.Create("DLabel", parent)
        lbl:SetPos(x, y)
        lbl:SetFont("LS_Header")
        lbl:SetText(title)
        lbl:SetTextColor(UI_Text)
        lbl:SizeToContents()

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:SetPos(x, y + 30)
        scroll:SetSize(330, 320)
        
        -- Кастомный скроллбар
        local sbar = scroll:GetVBar()
        sbar:SetSize(4)
        sbar.Paint = function(s, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(50, 50, 50)) end
        sbar.btnUp.Paint = function() end
        sbar.btnDown.Paint = function() end
        sbar.btnGrip.Paint = function(s, w, h) draw.RoundedBox(2, 0, 0, w, h, UI_Accent) end

        local layout = vgui.Create("DIconLayout", scroll)
        layout:Dock(FILL)
        layout:SetSpaceY(8)
        layout:SetSpaceX(8)

        for _, item in ipairs(items) do
            local btn = layout:Add("DButton")
            btn:SetSize(100, 100)
            btn:SetText("")
            
            local iconPath = "vgui/avatar_default"
            
            if isWeapon then
                local wepTable = weapons.Get(item.class)
                if wepTable and wepTable.IconOverride then
                    iconPath = wepTable.IconOverride
                end
            else
                local entTable = scripted_ents.Get(item.class)
                if entTable and entTable.IconOverride then
                    iconPath = entTable.IconOverride
                end
            end

            local iconMat = Material(iconPath, "noclamp smooth")

            btn.Paint = function(self, w, h)
                local isSelected = (isWeapon and selWep == item.class) or (not isWeapon and selEq == item.class)
                local isHovered = self:IsHovered()
                
                -- Фон карточки
                local cardCol = UI_Card
                if isHovered then cardCol = UI_CardHover end
                if isSelected then cardCol = Color(40, 15, 15, 255) end
                
                draw.RoundedBox(4, 0, 0, w, h, cardCol)
                
                -- Рамка
                local borderCol = isHovered and UI_AccentDim or Color(50, 50, 55)
                if isSelected then borderCol = UI_Accent end
                
                surface.SetDrawColor(borderCol)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
                
                -- Свечение при выборе
                if isSelected then
                    surface.SetDrawColor(UI_Accent.r, UI_Accent.g, UI_Accent.b, 20)
                    surface.DrawRect(0, 0, w, h)
                end

                -- Отрисовка 2D иконки
                if iconMat and not iconMat:IsError() then
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(iconMat)
                    surface.DrawTexturedRect(12, 8, w - 24, h - 36)
                end

                -- Нижняя плашка для текста
                draw.RoundedBoxEx(4, 0, h - 26, w, 26, Color(0, 0, 0, 180), false, false, true, true)

                -- Текст
                draw.SimpleText(item.name, "LS_Small", 8, h - 13, UI_Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                
                local costCol = isSelected and Color(255, 100, 100) or UI_TextDim
                draw.SimpleText(item.cost .. " PT", "LS_Small", w - 8, h - 13, costCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                
                -- Галочка выбора
                if isSelected then
                    draw.SimpleText("✔", "LS_Small", w - 10, 10, UI_Accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                end
            end

            btn.DoClick = function()
                if isWeapon then
                    selWep = item.class
                    selWepCost = item.cost
                else
                    selEq = item.class
                    selEqCost = item.cost
                end
                updatePts()
                surface.PlaySound("UI/buttonclick.wav")
            end
        end
    end

    -- Отрисовываем сетки
    CreateIconGrid(LS_Menu, 20, 90, "PRIMARY WEAPON", LS_LightWeps, true)
    CreateIconGrid(LS_Menu, 370, 90, "EQUIPMENT", LS_LightEquip, false)

    -- Кнопка подтверждения
    local btnConfirm = vgui.Create("DButton", LS_Menu)
    btnConfirm:SetPos(20, 460)
    btnConfirm:SetSize(680, 60)
    btnConfirm:SetFont("LS_Header")
    btnConfirm:SetText("")
    
    btnConfirm.Paint = function(self, w, h)
        local canBuy = (selWepCost + selEqCost) <= 5
        local isHovered = self:IsHovered() and canBuy
        
        local btnCol = canBuy and (isHovered and UI_Accent or UI_AccentDim) or Color(40, 40, 40)
        
        draw.RoundedBox(4, 0, 0, w, h, btnCol)
        
        if canBuy then
            surface.SetDrawColor(255, 255, 255, isHovered and 50 or 0)
            surface.DrawRect(0, 0, w, h)
            
            surface.SetDrawColor(255, 100, 100, isHovered and 255 or 150)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
            
            draw.SimpleText("CONFIRM LOADOUT", "LS_Header", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            surface.SetDrawColor(100, 30, 30)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
            draw.SimpleText("POINT LIMIT EXCEEDED", "LS_Header", w/2, h/2, Color(255, 50, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    btnConfirm.DoClick = function()
        if (selWepCost + selEqCost) <= 5 then
            net.Start("laststand_select_loadout")
                net.WriteString(selWep)
                net.WriteString(selEq)
            net.SendToServer()
            timer.Remove("LS_Countdown")
            LS_Menu:Close()
            surface.PlaySound("UI/buttonclickrelease.wav")
        else
            surface.PlaySound("buttons/button10.wav")
        end
    end
end)

function MODE:HUDPaint()
    local lply = LocalPlayer()
    local sw, sh = ScrW(), ScrH()

    -- Отрисовка таймера подготовки для обеих команд
    if LS_PrepEnd and CurTime() < LS_PrepEnd then
        local timeLeft = math.ceil(LS_PrepEnd - CurTime())
        
        -- Фон для текста
        draw.SimpleText("ROUND STARTS IN", "LS_Title", sw * 0.5, sh * 0.08, UI_TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        local timeColor = timeLeft <= 5 and Color(255, 50, 50) or UI_Accent
        draw.SimpleText(timeLeft, "LS_Title", sw * 0.5, sh * 0.12, timeColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        if lply:Team() == 0 then
            draw.SimpleText("Select your loadout!", "LS_Title", sw * 0.5, sh * 0.15, Color(255, 100, 100, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("Stand by...", "LS_Title", sw * 0.5, sh * 0.15, Color(100, 100, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    elseif LS_PrepEnd and CurTime() >= LS_PrepEnd then
        LS_PrepEnd = nil
    end

    if lply:Team() == 0 and lply:Alive() then
        local lives = lply:GetNWInt("LivesLeft", 0)
        draw.SimpleText("LIVES: " .. lives, "LS_Title", sw * 0.01, sh * 0.03, Color(255, 50, 50, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if zb.ROUND_START + 8 < CurTime() then
        if playstart then
            sound.PlayFile("sound/music_themes/ghetto_start.wav", "noblock noplay", function(station)
                if IsValid(station) then
                    station:SetVolume(0.3 * MusicVolume:GetFloat())
                    station:Play()
                end
            end)
            playstart = nil
        end

        lerpsnd = LerpFT(0.01, lerpsnd, !ended and (lply:Alive() and lply.organism and !lply.organism.otrub and lply.organism.fear and math.Clamp(lply.organism.fear + 0.3, 0, 1) or 0.3) or 0)
        
        if zb.ROUND_START + 12 < CurTime() then
            if IsValid(GWARS_LoopStation) then
                GWARS_LoopStation:SetVolume(lerpsnd * MusicVolume:GetFloat())
                GWARS_LoopStation:Play()
            end
        end
    end

    if zb.ROUND_START + 8.5 < CurTime() then return end
    
    local team_ = lply:Team()
    local teamInfo = teams[team_]
    if not teamInfo then return end

    -- ИСПРАВЛЕНИЕ: Позволяем лёгкой команде видеть вступление, даже если они мертвы в процессе подготовки
    local isLightPrepping = (team_ == 0 and not lply:Alive() and lply:GetNWInt("LivesLeft", 0) > 0)
    if not lply:Alive() and not isLightPrepping then return end
    
    zb.RemoveFade()

    local timeElapsed = CurTime() - zb.ROUND_START
    local maxTime = 6 
    if timeElapsed > maxTime then return end

    local globalFade = 1
    if timeElapsed < 0.5 then
        globalFade = timeElapsed / 0.5
    elseif timeElapsed > 4.5 then
        globalFade = math.Clamp(1 - (timeElapsed - 4.5) / 1.5, 0, 1)
    end

    local bgColor = Color(teamInfo.color1.r * 0.1, teamInfo.color1.g * 0.1, teamInfo.color1.b * 0.1, 255 * globalFade)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, ScrW(), ScrH())

    local mat = Material("vgui/gradient-d")
    surface.SetMaterial(mat)
    surface.SetDrawColor(0, 0, 0, 200 * globalFade)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

    local function getStageAlpha(t)
        return math.Clamp((timeElapsed - t) / 0.3, 0, 1) * globalFade
    end

    local a_title = getStageAlpha(0.5)
    local a_role = getStageAlpha(1.5)
    local a_obj = getStageAlpha(2.2)

    MODE.RevealSounds = MODE.RevealSounds or {}
    local function playStageSound(t, snd)
        if timeElapsed >= t and not MODE.RevealSounds[t] then
            surface.PlaySound(snd)
            MODE.RevealSounds[t] = true
        end
    end

    if a_title > 0 then
        draw.SimpleText("ZBattle | Last Stand", "LS_LArgsdafasdf", sw * 0.5, sh * 0.1, Color(0, 162, 255, 255 * a_title), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(0.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end

    local Rolename = teamInfo.name
    local ColorRole = Color(teamInfo.color1.r, teamInfo.color1.g, teamInfo.color1.b, 255 * a_role)

    if a_role > 0 then
        draw.SimpleText("You are " .. Rolename, "LS_LArgsdafasdf", sw * 0.5, sh * 0.5, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(1.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end

    local Objective = teamInfo.objective
    local ColorObj = Color(teamInfo.color2.r, teamInfo.color2.g, teamInfo.color2.b, 255 * a_obj)

    if a_obj > 0 then
        draw.SimpleText(Objective, "LS_LArgsdafasdf", sw * 0.5, sh * 0.9, ColorObj, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(2.2, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end
end

local CreateEndMenu

--\\ Панели завершения раунда
LS_EndStatsPanel = nil

function RemoveEndLSRoundStatsPanel()
    if IsValid(LS_EndStatsPanel) then
        LS_EndStatsPanel:Remove()
        LS_EndStatsPanel = nil
    end
end

local colGray = Color(122,122,122,255)
local colBlue = Color(130,10,10)
local colBlueUp = Color(160,30,30)
local col = Color(255,255,255,255)

local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(85,85,85,255)

local function CreateEndRoundStatsPanel()
    RemoveEndLSRoundStatsPanel()

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

    LS_EndStatsPanel = vgui.Create("DPanel")
    LS_EndStatsPanel:SetPos(posX, posY)
    LS_EndStatsPanel:SetSize(topW, topH + medalH + padding)
    LS_EndStatsPanel:MakePopup()
    LS_EndStatsPanel:SetKeyboardInputEnabled(false)
    LS_EndStatsPanel:SetMouseInputEnabled(false)

    LS_EndStatsPanel.Paint = function(self, pw, ph) end

    local pnl1 = vgui.Create("DPanel", LS_EndStatsPanel)
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
    topLbl:SetPos( textX, ScreenScale(2))
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

    local pnl2 = vgui.Create("DPanel", LS_EndStatsPanel)
    pnl2:SetPos(0, topH + padding)
    pnl2:SetSize(medalW, medalH)
    pnl2.Band = nil
    pnl2.Medal = nil

    local statsLbl = vgui.Create("DLabel", pnl2)
    statsLbl:Dock(TOP)
    statsLbl:DockMargin(ScreenScale(3), ScreenScale(2) - 5 , ScreenScale(3), 0)
    statsLbl:SetFont("ZB_HomicideSuperSuperSmall")
    statsLbl:SetTextColor(Color(200, 200, 200))
    statsLbl:SetText("Wait for stats...")
    statsLbl:SetContentAlignment(7)
    statsLbl:SetTall(ScreenScale(12))

    LS_EndStatsPanel.statsLbl = statsLbl
    LS_EndStatsPanel.pnl2 = pnl2

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
--//

net.Receive("laststand_roundend", function()
    ended = true
    CreateEndMenu()
    CreateEndRoundStatsPanel()  -- добавлено
end)

local colGray = Color(85, 85, 85, 255)
local colRed = Color(130, 10, 10)
local colRedUp = Color(160, 30, 30)
local colBlue = Color(10, 10, 160)
local colBlueUp = Color(40, 40, 160)
local col = Color(255, 255, 255, 255)
local colSpect1 = Color(75, 75, 75, 255)
local colSpect2 = Color(255, 255, 255)
local colorBG = Color(55, 55, 55, 255)
local colorBGBlacky = Color(40, 40, 40, 255)
local blurMat = Material("pp/blurscreen")
local Dynamic = 0
BlurBackground = BlurBackground or hg.DrawBlur

CreateEndMenu = function()
    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end
    Dynamic = 0
    hmcdEndMenu = vgui.Create("ZFrame")

    surface.PlaySound("ambient/alarms/warningbell1.wav")

    local sizeX,sizeY = ScrW() / 2.5 ,ScrH() / 1.2
    local posX,posY = ScrW() / 1.3 - sizeX / 2,ScrH() / 2 - sizeY / 2

    hmcdEndMenu:SetPos(posX,posY)
    hmcdEndMenu:SetSize(sizeX,sizeY)
    --hmcdEndMenu:SetBackgroundColor(colGray)
    hmcdEndMenu:MakePopup()
    hmcdEndMenu:SetKeyboardInputEnabled(false)
    hmcdEndMenu:ShowCloseButton(false)

    local closebutton = vgui.Create("DButton",hmcdEndMenu)
    closebutton:SetPos(5,5)
    closebutton:SetSize(ScrW() / 20,ScrH() / 30)
    closebutton:SetText("")
    
    closebutton.DoClick = function()
        if IsValid(hmcdEndMenu) then
            hmcdEndMenu:Close()
            hmcdEndMenu = nil
        end

        RemoveEndLSRoundStatsPanel()
    end

    timer.Simple( 3, function() 
        if IsValid(LS_EndStatsPanel) then
            LS_EndStatsPanel:Remove()
            LS_EndStatsPanel = nil
        end
	end )


    closebutton.Paint = function(self,w,h)
        surface.SetDrawColor( 122, 122, 122, 255)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
        surface.SetFont( "ZB_InterfaceMedium" )
        surface.SetTextColor(col.r,col.g,col.b,col.a)
        local lengthX, lengthY = surface.GetTextSize("Close")
        surface.SetTextPos( lengthX - lengthX/1.1, 4)
        surface.DrawText("Close")
    end

    hmcdEndMenu.Paint = function(self,w,h)
        BlurBackground(self)

        surface.SetFont( "ZB_InterfaceMediumLarge" )
        surface.SetTextColor(col.r,col.g,col.b,col.a)
        local lengthX, lengthY = surface.GetTextSize("Players:")
        surface.SetTextPos(w / 2 - lengthX/2,20)
        surface.DrawText("Players:")

        surface.SetDrawColor( 255, 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
    end
    -- PLAYERS
    local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
    DScrollPanel:SetPos(10, 80)
    DScrollPanel:SetSize(sizeX - 20, sizeY - 90)
    function DScrollPanel:Paint( w, h )
        BlurBackground(self)

        surface.SetDrawColor( 255, 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
    end

    for i, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        local but = vgui.Create("DButton",DScrollPanel)
        but:SetSize(100,50)
        but:Dock(TOP)
        but:DockMargin( 8, 6, 8, -1 )
        but:SetText("")
        but.Paint = function(self,w,h)
            local col1 = (ply:Alive() and colRed) or colGray
            local col2 = (ply:Alive() and colRedUp) or colSpect1
            surface.SetDrawColor(col1.r,col1.g,col1.b,col1.a)
            surface.DrawRect(0,0,w,h)
            surface.SetDrawColor(col2.r,col2.g,col2.b,col2.a)
            surface.DrawRect(0,h/2,w,h/2)

            local col = ply:GetPlayerColor():ToColor()
            surface.SetFont( "ZB_InterfaceMediumLarge" )
            local lengthX, lengthY = surface.GetTextSize( ply:GetPlayerName() or "He quited..." )
            
            surface.SetTextColor(0,0,0,255)
            surface.SetTextPos(w / 2 + 1,h/2 - lengthY/2 + 1)
            surface.DrawText(ply:GetPlayerName() or "He quited...")

            surface.SetTextColor(col.r,col.g,col.b,col.a)
            surface.SetTextPos(w / 2,h/2 - lengthY/2)
            surface.DrawText(ply:GetPlayerName() or "He quited...")

            
            local col = colSpect2
            surface.SetFont( "ZB_InterfaceMediumLarge" )
            surface.SetTextColor(col.r,col.g,col.b,col.a)
            local lengthX, lengthY = surface.GetTextSize( ply:GetPlayerName() or "He quited..." )
            surface.SetTextPos(15,h/2 - lengthY/2)
            surface.DrawText((ply:Name() .. (not ply:Alive() and " - died" or "")) or "He quited...")

            surface.SetFont( "ZB_InterfaceMediumLarge" )
            surface.SetTextColor(col.r,col.g,col.b,col.a)
            local lengthX, lengthY = surface.GetTextSize( ply:Frags() or "He quited..." )
            surface.SetTextPos(w - lengthX -15,h/2 - lengthY/2)
            surface.DrawText(ply:Frags() or "He quited...")
        end

        function but:DoClick()
            if ply:IsBot() then chat.AddText(Color(255,0,0), "no, you can't") return end
            gui.OpenURL("https://steamcommunity.com/profiles/"..ply:SteamID64())
        end

        DScrollPanel:AddItem(but)
    end

    return true
end

function MODE:RoundStart()
    if IsValid(hmcdEndMenu) then hmcdEndMenu:Remove() hmcdEndMenu = nil end
end
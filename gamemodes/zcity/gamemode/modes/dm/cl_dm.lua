MODE.name = "dm"

local MODE = MODE

local radius = nil
local mapsize = 7500

local roundend = false

local snds = {
    "https://kappa.vgmsite.com/soundtracks/superfighters-deluxe-original-soundtrack-2018/ujuwzquyre/01.%20A%20Grim%20Feeling.mp3",
    "https://kappa.vgmsite.com/soundtracks/superfighters-deluxe-original-soundtrack-2018/zgagxqybov/02.%20Alley%20.mp3",
    "https://kappa.vgmsite.com/soundtracks/superfighters-deluxe-original-soundtrack-2018/qsoislqepd/17.%20Hazardous.mp3",
    "https://kappa.vgmsite.com/soundtracks/superfighters-deluxe-original-soundtrack-2018/zqxkrixwbn/26.%20Rooftops.mp3",
    "https://kappa.vgmsite.com/soundtracks/superfighters-deluxe-original-soundtrack-2018/kvlgywwwnt/13.%20Escape.mp3"
}

local deathmatch_nozone = ConVarExists("deathmatch_nozone") and GetConVar("deathmatch_nozone") or CreateConVar("deathmatch_nozone", 0, FCVAR_REPLICATED, "Allows to disable deathmatch mode zone.", 0, 1)

local function restartMusic()
    local snd = snds[math.random(#snds)]

    if IsValid(dmmusic) then
        dmmusic:Stop()
        dmmusic = nil
    end
    
    sound.PlayURL(snd, "mono noblock noplay", function(station, errID, err)
        if IsValid(station) then
            station:EnableLooping(true)
            station:SetVolume(0.1)
            
            dmmusic = station
        else
            print(errID, err)
        end
    end)
end


net.Receive("dm_start",function()
    roundend = false
    MODE.RevealSounds = {} -- Сбрасываем звуки появления при старте ДМ

    print("[DM] dm_start called, removing stats panel")
    RemoveEndDMRoundStatsPanel()
    print("[DM] DM_EndStatsPanel after removal:", DM_EndStatsPanel and "exists" or "nil")

    hg.DynaMusic:Start( "mirrors_edge" )

    zb.RemoveFade()
    
    ZonePos = net.ReadVector()
    zonedistance = net.ReadFloat()

    surface.PlaySound("snd_jack_hmcd_deathmatch.mp3")
    sound.PlayFile( "sound/ambient/energy/force_field_loop1.wav", "noblock", function( station, errCode, errStr )
        if ( IsValid( station ) ) then
            zb.SoundStation = station
            
            station:Play()
            station:EnableLooping( true )
            station:SetVolume(0)
        end
    end )
end)

hook.Add("Think", "ZoneSoundThink", function()
    if CurrentRound() and CurrentRound().name ~= "dm" then return end
    local station = zb.SoundStation
    if not IsValid(station) then return end
    if deathmatch_nozone:GetBool() then return end
    local radius = MODE.GetZoneRadius()
    local volume = math.Clamp((LocalPlayer():GetPos():Distance(ZonePos) - radius) + 200,0,200) / 200
    station:SetVolume(volume)
end)

local fighter = {
    objective = "Kill everyone.",
    name = "Fighter",
    color1 = Color(0,120,190)
}

local mat = Material("hmcd_dmzone")

local mapsize = 7500

function MODE:PostDrawTranslucentRenderables(bDepth, bSkybox, isDraw3DSkybox)
    if(!bSkybox and !isDraw3DSkybox) and !deathmatch_nozone:GetBool() then
        local radius = MODE.GetZoneRadius()
        render.SetMaterial(mat)
        render.DrawSphere( ZonePos, -radius, 60, 60, color_white )
    end
end

function MODE:RenderScreenspaceEffects()
    -- Убрали сплошной черный экран, чтобы не перекрывал новый фон в HUDPaint
end

-- Вспомогательная функция для получения прозрачности на стадии
local function getStageAlpha(timeElapsed, t, globalFade)
    return math.Clamp((timeElapsed - t) / 0.3, 0, 1) * globalFade
end

function MODE:HUDPaint()
    RemoveEndDMRoundStatsPanel()

    -- Отрисовка таймера
    if zb.ROUND_START + 20 > CurTime() then
        draw.SimpleText( string.FormattedTime(zb.ROUND_START + 20 - CurTime(), "%02i:%02i:%02i"	), "ZB_HomicideMedium", sw * 0.5, sh * 0.75, Color(255,55,55), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    if not lply:Alive() then return end
    if zb.ROUND_START + 8.5 < CurTime() then return end
    zb.RemoveFade()
    
    local timeElapsed = CurTime() - zb.ROUND_START
    local maxTime = 8.5
    
    if timeElapsed > maxTime then return end
    
    -- Глобальное появление и затухание
    local globalFade = 1
    if timeElapsed < 0.5 then
        globalFade = timeElapsed / 0.5
    elseif timeElapsed > 6.5 then
        globalFade = math.Clamp(1 - (timeElapsed - 6.5) / 2, 0, 1)
    end
    
    -- 1. Улучшенный фон
    local bgColor = Color(10, 15, 25, 255 * globalFade) -- Тёмно-синий оттенок для ДМ
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, ScrW(), ScrH())
    
    -- Виньетка/Градиент
    local gradMat = Material("vgui/gradient-d")
    surface.SetMaterial(gradMat)
    surface.SetDrawColor(0, 0, 0, 200 * globalFade)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
    
    -- 2. Настройки стадий
    local a_title = getStageAlpha(timeElapsed, 0.5, globalFade)
    local a_role = getStageAlpha(timeElapsed, 1.5, globalFade)
    local a_obj = getStageAlpha(timeElapsed, 2.5, globalFade)
    
    -- Звуки появления
    MODE.RevealSounds = MODE.RevealSounds or {}
    local function playStageSound(t, snd)
        if timeElapsed >= t and not MODE.RevealSounds[t] then
            surface.PlaySound(snd)
            MODE.RevealSounds[t] = true
        end
    end
    
    -- 3. Рисуем Верхний Текст (Title)
    if a_title > 0 then
        draw.SimpleText("Homicide | DeathMatch", "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, Color(0,162,255, 255 * a_title), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(0.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end
    
    -- 4. Рисуем Роль
    local Rolename = fighter.name
    local ColorRole = fighter.color1
    
    if a_role > 0 then
        ColorRole.a = 255 * a_role
        draw.SimpleText("You are a "..Rolename , "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(1.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end
    
    -- 5. Рисуем Нижний Текст (Objective)
    local Objective = fighter.objective
    local ColorObj = fighter.color1
    
    if a_obj > 0 then
        ColorObj.a = 255 * a_obj
        draw.SimpleText( Objective, "ZB_HomicideMedium", sw * 0.5, sh * 0.9, ColorObj, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(2.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end
    
    -- PluvTown Madness
    if a_obj > 0 and hg.PluvTown.Active then
        surface.SetMaterial(hg.PluvTown.PluvMadness)
        surface.SetDrawColor(255, 255, 255, math.random(175, 255) * a_obj / 2)
        surface.DrawTexturedRect(sw * 0.25, sh * 0.44 - ScreenScale(15), sw / 2, ScreenScale(30))

        draw.SimpleText("SOMEWHERE IN PLUVTOWN", "ZB_ScrappersLarge", sw / 2, sh * 0.44 - ScreenScale(2), Color(0, 0, 0, 255 * a_obj), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local CreateEndMenu = nil
local wonply = nil

--\\ Панели завершения раунда
DM_EndStatsPanel = nil

function RemoveEndDMRoundStatsPanel()
    if IsValid(DM_EndStatsPanel) then
        DM_EndStatsPanel:Remove()
        DM_EndStatsPanel = nil
    end

end

local colGray = Color(122,122,122,255)
local colBlue = Color(130,10,10)
local colBlueUp = Color(160,30,30)
local col = Color(255,255,255,255)

local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(85,85,85,255)

local function CreateEndRoundStatsPanel()

    RemoveEndDMRoundStatsPanel()
    if not IsValid(lply) then return end
    -- Запрашиваем актуальные данные с сервера
    net.Start("zb_xp_get")
        net.WriteEntity(lply)
    net.SendToServer()

    local padding = ScreenScale(4)

    -- Размеры блоков согласно скриншоту
    local topW = ScreenScale(210)   -- Широкая верхняя плашка
    local topH = ScreenScale(32)    -- Высота верхней плашки

    local medalW = ScreenScale(52)  -- Вертикальный блок медали
    local medalH = ScreenScale(105) -- Высота блока медали

    -- НОВЫЕ ПЕРЕМЕННЫЕ ПОЗИЦИИ (Смещение вниз и вправо)
    -- Меняйте число 15, если нужно сдвинуть панель еще дальше или ближе
    local posX = padding + ScreenScale(25)
    local posY = padding + ScreenScale(25)

    DM_EndStatsPanel = vgui.Create("DPanel")
    -- Используем новые переменные вместо padding, padding
    DM_EndStatsPanel:SetPos(posX, posY)
    DM_EndStatsPanel:SetSize(topW, topH + medalH + padding)
    DM_EndStatsPanel:MakePopup()
    DM_EndStatsPanel:SetKeyboardInputEnabled(false)
    DM_EndStatsPanel:SetMouseInputEnabled(false)

    DM_EndStatsPanel.Paint = function(self, pw, ph) end

    -- Панель 1: Верхняя горизонтальная плашка (Аватар + Ник / Заголовок)
    local pnl1 = vgui.Create("DPanel", DM_EndStatsPanel)
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

    -- Маленький верхний текст ("MVP: Nick")
    local topLbl = vgui.Create("DLabel", pnl1)
    topLbl:SetPos( textX, ScreenScale(2))
    topLbl:SetFont("ZB_HomicideSuperSuperSmall")
    topLbl:SetTextColor(Color(137, 137, 137))
    topLbl:SetText("MVP: " .. "Wait for stats...")
    topLbl:SizeToContents()

    -- Большой нижний текст (Никнейм)
    local mainLbl = vgui.Create("DLabel", pnl1)
    mainLbl:SetPos(textX, ScreenScale(4))
    mainLbl:SetFont("ZB_HomicideLarge")
    mainLbl:SetTextColor(Color(255, 255, 255))
    mainLbl:SetText(lply:Nick())
    mainLbl:SizeToContents()

    -- Панель 2: Вертикальная карточка медали (снизу слева)
    local pnl2 = vgui.Create("DPanel", DM_EndStatsPanel)
    pnl2:SetPos(0, topH + padding)
    pnl2:SetSize(medalW, medalH)
    pnl2.Band = nil
    pnl2.Medal = nil

    -- Текст статистики вверху карточки медали (+exp / +skill)
    local statsLbl = vgui.Create("DLabel", pnl2)
    statsLbl:Dock(TOP)
    statsLbl:DockMargin(ScreenScale(3), ScreenScale(2) - 5 , ScreenScale(3), 0)
    statsLbl:SetFont("ZB_HomicideSuperSuperSmall")
    statsLbl:SetTextColor(Color(200, 200, 200))
    statsLbl:SetText("Wait for stats...")
    statsLbl:SetContentAlignment(7)
    statsLbl:SetTall(ScreenScale(12))

    -- Сохраняем ссылки для работы с обработчиком сети в cl_menu.lua[cite: 1, 2]
    DM_EndStatsPanel.statsLbl = statsLbl
    DM_EndStatsPanel.pnl2 = pnl2

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

        -- Тень
        surface.SetDrawColor(0, 0, 0, 155)
        surface.SetMaterial(self.Band.icon)
        surface.DrawTexturedRect(x + 10, y + 10, medalSize + 100, medalSize + 100)
        surface.SetMaterial(self.Medal.icon)
        surface.DrawTexturedRect(x + 10, y + 10, medalSize + 100, medalSize + 100)

        -- Иконки ленты и медали
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(self.Band.icon)
        surface.DrawTexturedRect(x, y, medalSize + 100, medalSize + 100)

        surface.SetMaterial(self.Medal.icon)
        surface.DrawTexturedRect(x, y, medalSize + 100, medalSize + 100)
    end
end
--//

net.Receive("dm_end",function()
    print("[DM] dm_end called")
    local ent = net.ReadEntity()
    local most_violent_player = net.ReadEntity()

    if IsValid(most_violent_player) then
        most_violent_player.most_violent_player = true
    end

    wonply = nil
    if IsValid(ent) then
        ent.won = true
        wonply = ent
    end

    zb.SoundStation = nil
    roundend = CurTime()

    if(MODE.SoundStation and MODE.SoundStation:IsValid())then
        MODE.SoundStation:Stop()

        MODE.SoundStation = nil
    end

    CreateEndMenu()
    CreateEndRoundStatsPanel()
end)

local colGray = Color(85,85,85,255)
local colRed = Color(217,201,99)
local colRedUp = Color(207,181,59)

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
    print("[DM] CreateEndMenu called")
    if IsValid(hmcdEndMenu) then
        print("[DM] Removing old hmcdEndMenu")
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end

    RemoveEndDMRoundStatsPanel()

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

        -- Добавляем удаление панели статистики при закрытии меню
        RemoveEndDMRoundStatsPanel()
    end

    timer.Simple( 3, function() 
        if IsValid(DM_EndStatsPanel) then
            DM_EndStatsPanel:Remove()
            DM_EndStatsPanel = nil
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

    hmcdEndMenu.PaintOver = function(self,w,h)

        local txt = (wonply and wonply:GetPlayerName() or "Nobody").." won!"
        surface.SetFont( "ZB_InterfaceMediumLarge" )
        surface.SetTextColor(col.r,col.g,col.b,col.a)
        local lengthX, lengthY = surface.GetTextSize(txt)
        surface.SetTextPos(w / 2 - lengthX/2,20)
        surface.DrawText(txt)
    end
    
    local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
    DScrollPanel:SetPos(10, 80)
    DScrollPanel:SetSize(sizeX - 20, sizeY - 90)

    for i,ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        local but = vgui.Create("DButton",DScrollPanel)
        but:SetSize(100,50)
        but:Dock(TOP)
        but:DockMargin( 8, 6, 8, -1 )
        but:SetText("")
        but.Paint = function(self,w,h)
            local col1 = ((ply.won or ply.most_violent_player) and colRed) or (ply:Alive() and colBlue) or colGray
            local col2 = ((ply.won or ply.most_violent_player) and colRedUp) or (ply:Alive() and colBlueUp) or colSpect1
            
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
            surface.DrawText((ply:Name() .. (ply.most_violent_player and " - MVP" or (not ply:Alive() and " - died" or ""))))

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
    for i,ply in player.Iterator() do
        ply.won = nil
        ply.most_violent_player = nil
    end

    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end
end